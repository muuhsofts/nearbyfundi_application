<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Otp;
use App\Models\FailedLoginAttempt;
use App\Models\UserSession;
use App\Traits\Auditable;
use App\Models\Technician;
use App\Services\OtpDeliveryService;
use Carbon\Carbon;
use App\Services\GeocodingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Google_Client;
use Illuminate\Support\Facades\Log;
use Spatie\Permission\Models\Role;
use Laravel\Socialite\Facades\Socialite;


class AuthController extends BaseApiController
{
   use Auditable;

    // ------------------ CUSTOMER REGISTRATION ------------------
    public function register(Request $request, OtpDeliveryService $otpDelivery)
    {
        $data = $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users',
            'password' => 'required|string|min:8|confirmed',
            'phone'    => 'required|string|unique:users,phone|max:20',
            'role'     => 'nullable|string|in:CUSTOMER,FUNDI',
        ]);

        $user = User::create([
            'name'              => $data['name'],
            'email'             => $data['email'],
            'phone'             => $data['phone'],
            'password'          => Hash::make($data['password']),
            'status'            => 'pending',
            'is_active'         => false,
            'email_verified_at' => null,
        ]);

        $role = $data['role'] ?? 'CUSTOMER';
        $user->assignRole($role);

        // Clear existing verification OTPs
        Otp::where('email', $user->email)
            ->where('type', Otp::TYPE_EMAIL_VERIFICATION)
            ->delete();

        $otp = Otp::create([
            'email'      => $user->email,
            'otp'        => Otp::generateOtp(),
            'token'      => Otp::generateToken(),
            'type'       => Otp::TYPE_EMAIL_VERIFICATION,
            'name'       => $user->name,
            'expires_at' => Carbon::now()->addMinutes(10),
            'is_used'    => false,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        $delivery = $otpDelivery->deliver($user, $otp, $otp->getVerificationUrl());

        return $this->created([
            'user'        => $user,
            'otp_channel' => $delivery['channel'],
            'sent_to'     => $delivery['channel'] === 'sms' ? $user->phone : $user->email,
        ], 'Registration successful. Please enter the OTP sent to verify your account.');
    }

    // ------------------ FUNDI REGISTRATION ------------------
    public function registerFundi(Request $request, GeocodingService $geocoder, OtpDeliveryService $otpDelivery)
    {
        $data = $request->validate([
            'name'          => 'required|string|max:255',
            'email'         => 'required|email|unique:users',
            'password'      => 'required|string|min:8|confirmed',
            'phone'         => 'nullable|string|max:20',
            'bio'           => 'nullable|string',
            'nida'          => 'required|string|size:20|unique:technicians,nida',
            'experience'    => 'nullable|integer|min:0',
            'hourly_rate'   => 'nullable|numeric|min:0|max:999999.99',
            'area'          => 'required|string|max:255',
            'latitude'      => 'nullable|numeric|between:-90,90',
            'longitude'     => 'nullable|numeric|between:-180,180',
            'service_ids'   => 'required|array|min:1',
            'service_ids.*' => 'exists:services,id',
            'profile_photo' => 'required|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        Log::info('AuthController - service_ids received:', [
            'service_ids' => $data['service_ids'],
            'count' => count($data['service_ids']),
        ]);

        $coords = $this->validateAndGeocodeArea($data['area'], $data['latitude'] ?? null, $data['longitude'] ?? null, $geocoder);
        $data['latitude']  = $coords['lat'];
        $data['longitude'] = $coords['lng'];

        DB::beginTransaction();
        try {
            $role = Role::where('name', 'FUNDI')->firstOrFail();

            $user = User::create([
                'name'       => $data['name'],
                'email'      => $data['email'],
                'password'   => Hash::make($data['password']),
                'phone'      => $data['phone'] ?? null,
                'status'     => 'pending',
                'is_active'  => false,
                'locale'     => 'en',
            ]);

            $user->assignRole($role);

            $technicianData = [
                'user_id'       => $user->id,
                'bio'           => $data['bio'] ?? null,
                'nida'          => $data['nida'],
                'experience'    => $data['experience'] ?? 0,
                'hourly_rate'   => $data['hourly_rate'] ?? null,
                'area'          => $data['area'],
                'latitude'      => $data['latitude'],
                'longitude'     => $data['longitude'],
                'verified'      => false,
                'is_online'     => false,
            ];

            if ($request->hasFile('profile_photo')) {
                $path = $request->file('profile_photo')->store('technicians', 'public');
                $technicianData['profile_photo'] = $path;
            }

            $technician = Technician::create($technicianData);
            $technician->services()->sync($data['service_ids']);

            $otp = Otp::create([
                'email'      => $user->email,
                'otp'        => Otp::generateOtp(),
                'token'      => Otp::generateToken(),
                'type'       => Otp::TYPE_EMAIL_VERIFICATION,
                'name'       => $user->name,
                'expires_at' => Carbon::now()->addMinutes(10),
                'is_used'    => false,
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);

            $delivery = $otpDelivery->deliver($user, $otp, $otp->getVerificationUrl());

            DB::commit();

            $this->logAudit(
                'register_fundi',
                'auth',
                'user',
                "Fundi registered: {$user->email} (OTP sent via {$delivery['channel']})"
            );

            if (!$delivery['success']) {
                Log::error('OTP delivery failed on both channels during fundi registration', [
                    'user_id'     => $user->id,
                    'sms_error'   => $delivery['sms_error'] ?? null,
                    'email_error' => $delivery['email_error'] ?? null,
                ]);
            }

            return $this->created([
                'email'       => $user->email,
                'otp_channel' => $delivery['channel'],
            ], 'Fundi registered. Verify your ' .
                ($delivery['channel'] === 'sms' ? 'phone' : 'email') .
                ' and wait for admin approval.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Fundi registration failed: ' . $e->getMessage());
            return $this->serverError('Registration failed: ' . $e->getMessage());
        }
    }

    // ------------------ RESEND OTP ------------------
    public function resendOtp(Request $request, OtpDeliveryService $otpDelivery)
    {
        $request->validate(['email' => 'required|email|exists:users,email']);

        $user = User::where('email', $request->email)->firstOrFail();

        Otp::where('email', $user->email)
            ->where('type', Otp::TYPE_EMAIL_VERIFICATION)
            ->delete();

        $otp = Otp::create([
            'email'      => $user->email,
            'otp'        => Otp::generateOtp(),
            'token'      => Otp::generateToken(),
            'type'       => Otp::TYPE_EMAIL_VERIFICATION,
            'name'       => $user->name,
            'expires_at' => Carbon::now()->addMinutes(10),
            'is_used'    => false,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        $delivery = $otpDelivery->deliver($user, $otp, $otp->getVerificationUrl());

        $this->logAudit(
            'resend_otp',
            'auth',
            'user',
            "OTP resent to {$user->email} (via {$delivery['channel']})"
        );

        return $this->successResponse([
            'email'       => $user->email,
            'otp_channel' => $delivery['channel'],
        ], 'OTP resent successfully.');
    }

    // ------------------ OTP VERIFICATION ------------------
    public function verifyOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp'   => 'required|string|size:6',
        ]);

        $otpRecord = Otp::where('email', $request->email)
            ->where('otp', $request->otp)
            ->where('type', Otp::TYPE_EMAIL_VERIFICATION)
            ->where('is_used', false)
            ->where('expires_at', '>', Carbon::now())
            ->first();

        if (!$otpRecord) {
            return $this->errorResponse('Invalid or expired OTP code.', 422);
        }

        $otpRecord->update(['is_used' => true]);

        $user = User::where('email', $request->email)->firstOrFail();
        $user->update([
            'status'            => 'active',
            'is_active'         => true,
            'email_verified_at' => Carbon::now(),
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return $this->successResponse([
            'user'  => $user->load('roles'),
            'token' => $token,
        ], 'Account verified and activated successfully.');
    }

    // ------------------ EMAIL VERIFICATION VIA TOKEN ------------------
    public function verifyToken(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'token' => 'required|string',
        ]);

        $otp = Otp::where('email', $request->email)
            ->where('token', $request->token)
            ->where('type', Otp::TYPE_EMAIL_VERIFICATION)
            ->where('is_used', false)
            ->where('expires_at', '>', now())
            ->latest()
            ->first();

        if (!$otp) {
            return view('emails.verify-result', [
                'success' => false,
                'message' => 'Invalid or expired verification link. Please request a new one.'
            ]);
        }

        $user = User::where('email', $request->email)->firstOrFail();

        if ($user->email_verified_at) {
            return view('emails.verify-result', [
                'success' => true,
                'message' => 'Your email is already verified. You can now log in.'
            ]);
        }

        $user->update([
            'email_verified_at' => now(),
            'status'            => 'active',
            'is_active'         => true,
        ]);

        $otp->markAsUsed();

        $this->logAudit('verify_email_token', 'auth', 'user', "Email verified via token: {$user->email}");

        return view('emails.verify-result', [
            'success' => true,
            'message' => 'Your email has been successfully verified! You can now log in to your account.'
        ]);
    }

    // ------------------ LOGIN (supports email OR phone) ------------------
    public function login(Request $request)
    {
        $request->validate([
            'email'    => 'required|string',
            'password' => 'required|string',
        ]);

        $login = $request->email;
        $user = User::where('email', $login)->first() ?? User::where('phone', $login)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            FailedLoginAttempt::record($login, $request->ip());
            $this->logAudit('login_failed', 'auth', 'user', "Failed login for: {$login}");
            return $this->unauthorized('Invalid credentials.');
        }

        if (is_null($user->email_verified_at)) {
            return $this->forbidden('Please verify your email first.');
        }

        if (!$user->is_active || $user->status !== 'active') {
            return $this->forbidden('Account is not active.');
        }

        if ($user->hasRole('FUNDI')) {
            $technician = Technician::where('user_id', $user->id)->first();
            if (!$technician || !$technician->verified || $technician->verification_status !== 'approved') {
                return $this->forbidden('Your technician account is not verified. Please wait for admin approval.');
            }
        }

        $token = $user->createToken('auth_token')->plainTextToken;
        $this->createSession($user, $request, $token);

        $user->update([
            'last_login_at' => now(),
            'last_login_ip' => $request->ip(),
        ]);

        if ($request->filled('fcm_token')) {
            $this->storeFcmToken($user, $request->fcm_token);
        }

        $this->logAudit('login', 'auth', 'user', "User logged in: {$user->email}");

        return $this->successResponse([
            'user'  => $user->only(['id', 'name', 'email', 'phone', 'locale', 'fcm_device_token']),
            'roles' => $user->getRoleNames(),
            'token' => $token,
        ], 'Login successful.');
    }

    // ------------------ GOOGLE LOGIN (ID Token) ------------------
    public function googleLogin(Request $request)
    {
        $request->validate([
            'id_token'  => 'required|string',
            'fcm_token' => 'nullable|string|min:10',
        ]);

        try {
            $client = new Google_Client(['client_id' => config('services.google.client_id')]);
            $payload = $client->verifyIdToken($request->id_token);

            if (!$payload) {
                return $this->unauthorized('Invalid Google token.');
            }

            $email    = $payload['email'];
            $name     = $payload['name'] ?? 'Google User';
            $googleId = $payload['sub'];

            $user = User::where('email', $email)->first();

            if (!$user) {
                $user = User::create([
                    'name'              => $name,
                    'email'             => $email,
                    'google_id'         => $googleId,
                    'password'          => bcrypt(Str::random(24)),
                    'email_verified_at' => now(),
                    'status'            => 'active',
                    'is_active'         => true,
                ]);

                $user->assignRole('CUSTOMER');
                $this->logAudit('register_google', 'auth', 'user', "Customer registered via Google ID Token: {$user->email}");
            } else {
                if (!$user->email_verified_at) {
                    $user->update(['email_verified_at' => now()]);
                }
                if ($user->status !== 'active') {
                    $user->update(['status' => 'active', 'is_active' => true]);
                }
            }

            $token = $user->createToken('auth_token')->plainTextToken;
            $this->createSession($user, $request, $token);

            if ($request->filled('fcm_token')) {
                $this->storeFcmToken($user, $request->fcm_token);
            }

            $this->logAudit('login_google', 'auth', 'user', "User logged in via Google ID Token: {$user->email}");

            return $this->successResponse([
                'user'  => $user->only(['id', 'name', 'email', 'phone', 'locale', 'fcm_device_token']),
                'roles' => $user->getRoleNames(),
                'token' => $token,
            ], 'Google login successful.');

        } catch (\Exception $e) {
            Log::error('Google ID token authentication failed: ' . $e->getMessage());
            return $this->serverError('Google authentication failed: ' . $e->getMessage());
        }
    }

    // ------------------ REDIRECT TO GOOGLE OAuth ------------------
    public function redirectToGoogle()
    {
        return response()->json([
            'url' => Socialite::driver('google')
                ->stateless()
                ->redirect()
                ->getTargetUrl(),
        ]);
    }

    // ------------------ HANDLE GOOGLE CALLBACK ------------------
    public function handleGoogleCallback(Request $request)
    {
        try {
            $code = $request->input('code');
            if (!$code) {
                return $this->errorResponse('No authorization code provided.', 422);
            }

            $response = Socialite::driver('google')->getAccessTokenResponse($code);
            $token = $response['access_token'] ?? null;

            if (!$token) {
                return $this->errorResponse('Failed to retrieve access token from Google.', 401);
            }

            $googleUser = Socialite::driver('google')->userFromToken($token);

            $user = User::where('email', $googleUser->getEmail())->first();

            if (!$user) {
                $user = User::create([
                    'name'              => $googleUser->getName(),
                    'email'             => $googleUser->getEmail(),
                    'password'          => bcrypt(Str::random(16)),
                    'email_verified_at' => now(),
                    'status'            => 'active',
                    'is_active'         => true,
                ]);
                $user->assignRole('CUSTOMER');
                $this->logAudit('register_google', 'auth', 'user', "Customer registered via Google: {$user->email}");
            } else {
                if (!$user->email_verified_at) {
                    $user->update(['email_verified_at' => now()]);
                }
                if ($user->status !== 'active') {
                    $user->update(['status' => 'active', 'is_active' => true]);
                }
            }

            $sanctumToken = $user->createToken('auth_token')->plainTextToken;
            $this->createSession($user, $request, $sanctumToken);

            if ($request->filled('fcm_token')) {
                $this->storeFcmToken($user, $request->fcm_token);
            }

            $this->logAudit('login_google', 'auth', 'user', "User logged in via Google: {$user->email}");

            return $this->successResponse([
                'user'  => $user->only(['id', 'name', 'email', 'phone', 'locale', 'fcm_device_token']),
                'roles' => $user->getRoleNames(),
                'token' => $sanctumToken,
            ], 'Google login successful.');

        } catch (\Exception $e) {
            Log::error('Google callback failed: ' . $e->getMessage());
            return $this->errorResponse('Google authentication failed: ' . $e->getMessage(), 500);
        }
    }

    // ------------------ LOGOUT ------------------
    public function logout(Request $request)
    {
        $user = $request->user();
        $tokenId = $user->currentAccessToken()->id;
        $user->currentAccessToken()->delete();
        UserSession::where('user_id', $user->id)
            ->where('token', $tokenId)
            ->update(['is_active' => false]);
        $this->logAudit('logout', 'auth', 'user', "User logged out: {$user->email}");
        return $this->successResponse(null, 'Logged out.');
    }

    // ------------------ ME / PROFILE ------------------
    public function me(Request $request)
    {
        $user = $request->user()->load('technician.services');
        if ($user->technician) {
            $user->technician->makeVisible('nida');
        }
        return $this->successResponse([
            'user'       => $user->only(['id', 'name', 'email', 'phone', 'status', 'locale', 'fcm_device_token']),
            'roles'      => $user->getRoleNames(),
            'technician' => $user->technician,
        ]);
    }

    // ------------------ UPDATE PROFILE ------------------
    public function updateProfile(Request $request)
    {
        $request->validate([
            'name'  => 'sometimes|string|max:255',
            'phone' => 'nullable|string|max:20',
            'locale'=> 'sometimes|string|in:en,sw',
        ]);
        $user = $request->user();
        $old = $user->toArray();
        $user->update($request->only(['name', 'phone', 'locale']));
        $this->logAudit('update_profile', 'user', 'profile', 'Profile updated', $old, $user->toArray());
        return $this->successResponse($user->only(['id', 'name', 'email', 'phone', 'locale', 'fcm_device_token']), 'Profile updated.');
    }

    // ------------------ FORGOT PASSWORD ------------------
    public function forgotPassword(Request $request, OtpDeliveryService $otpDelivery)
    {
        $request->validate(['email' => 'required|email|exists:users,email']);

        $user = User::where('email', $request->email)->firstOrFail();

        Otp::where('email', $user->email)
            ->where('type', Otp::TYPE_PASSWORD_RESET)
            ->delete();

        $otp = Otp::create([
            'email'      => $user->email,
            'otp'        => Otp::generateOtp(),
            'type'       => Otp::TYPE_PASSWORD_RESET,
            'name'       => $user->name,
            'expires_at' => Carbon::now()->addMinutes(10),
            'is_used'    => false,
        ]);

        $delivery = $otpDelivery->deliver($user, $otp);

        $this->logAudit(
            'forgot_password',
            'auth',
            'user',
            "Password reset OTP sent to {$user->email} (via {$delivery['channel']})"
        );

        return $this->successResponse([
            'otp_channel' => $delivery['channel'],
        ], 'OTP sent successfully.');
    }

    // ------------------ RESET PASSWORD ------------------
    public function resetPassword(Request $request)
    {
        $request->validate([
            'email'    => 'required|email',
            'otp'      => 'required|string|size:6',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $otp = Otp::where('email', $request->email)
            ->where('otp', $request->otp)
            ->where('type', Otp::TYPE_PASSWORD_RESET)
            ->where('is_used', false)
            ->latest()
            ->first();

        if (!$otp) {
            $usedOtp = Otp::where('email', $request->email)
                ->where('otp', $request->otp)
                ->where('type', Otp::TYPE_PASSWORD_RESET)
                ->where('is_used', true)
                ->first();

            if ($usedOtp) {
                return $this->errorResponse('This OTP has already been used. Please request a new one.', 422);
            }

            return $this->errorResponse('Invalid OTP. Please check and try again.', 422);
        }

        if (!$otp->isValid()) {
            return $this->errorResponse('OTP has expired. Please request a new one.', 422);
        }

        $user = User::where('email', $request->email)->firstOrFail();
        $user->password = Hash::make($request->password);
        $user->save();

        $otp->markAsUsed();

        $this->logAudit('reset_password', 'auth', 'user', "Password reset for {$user->email}");

        return $this->successResponse(null, 'Password reset successfully.');
    }

    // ------------------ CHANGE PASSWORD ------------------
    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required|string',
            'password'         => 'required|string|min:8|confirmed',
        ]);
        $user = $request->user();
        if (!Hash::check($request->current_password, $user->password)) {
            return $this->badRequest('Current password incorrect.');
        }
        $user->password = Hash::make($request->password);
        $user->save();
        $this->logAudit('change_password', 'auth', 'user', "Password changed for {$user->email}");
        return $this->successResponse(null, 'Password changed.');
    }

    // ------------------ UPDATE LOCALE ------------------
    public function updateLocale(Request $request)
    {
        $request->validate(['locale' => 'required|in:en,sw']);
        $user = $request->user();
        $old = $user->locale;
        $user->locale = $request->locale;
        $user->save();
        $this->logAudit('update_locale', 'user', 'profile', "Locale changed from {$old} to {$request->locale}");
        return $this->successResponse(null, 'Locale updated.');
    }

    // ============================================================
    //  FCM TOKEN MANAGEMENT
    // ============================================================

    /**
     * Store or update FCM device token for the authenticated user
     */
    public function updateDeviceToken(Request $request)
    {
        $request->validate([
            'token' => 'required|string|min:10',
        ]);

        $user = $request->user();
        
        if (!$user) {
            return $this->unauthorized('User not authenticated.');
        }

        $oldToken = $user->fcm_device_token;
        $newToken = $request->token;

        $user->fcm_device_token = $newToken;
        $user->save();

        Log::info('FCM token updated', [
            'user_id' => $user->id,
            'email' => $user->email,
            'old_token_exists' => !empty($oldToken),
            'new_token_preview' => substr($newToken, 0, 20) . '...',
        ]);

        $this->logAudit('update_device_token', 'user', 'device', 
            "FCM token updated for user {$user->email}");

        return $this->successResponse([
            'message' => 'Device token updated successfully.',
            'user' => $user->only(['id', 'name', 'email', 'fcm_device_token'])
        ], 'Device token updated.');
    }

    /**
     * Store FCM token directly (used during login)
     */
    private function storeFcmToken(User $user, string $token): void
    {
        try {
            if (empty($token)) {
                Log::warning('Attempted to store empty FCM token', ['user_id' => $user->id]);
                return;
            }

            $user->fcm_device_token = $token;
            $user->save();

            Log::info('FCM token stored during login', [
                'user_id' => $user->id,
                'email' => $user->email,
                'token_preview' => substr($token, 0, 20) . '...',
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to store FCM token', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * Get the current user's FCM token
     */
    public function getDeviceToken(Request $request)
    {
        $user = $request->user();
        
        return $this->successResponse([
            'fcm_device_token' => $user->fcm_device_token,
            'has_token' => !empty($user->fcm_device_token),
        ], 'FCM token retrieved.');
    }

    /**
     * Delete the user's FCM token
     */
    public function deleteDeviceToken(Request $request)
    {
        $user = $request->user();
        
        if (!$user) {
            return $this->unauthorized('User not authenticated.');
        }

        $user->fcm_device_token = null;
        $user->save();

        Log::info('FCM token deleted', [
            'user_id' => $user->id,
            'email' => $user->email,
        ]);

        $this->logAudit('delete_device_token', 'user', 'device', 
            "FCM token deleted for user {$user->email}");

        return $this->successResponse(null, 'Device token deleted.');
    }

    /**
     * Update multiple device tokens (for multi-device support)
     */
    public function updateDeviceTokens(Request $request)
    {
        $request->validate([
            'tokens' => 'required|array',
            'tokens.*' => 'required|string|min:10',
        ]);

        $user = $request->user();
        
        if (!empty($request->tokens)) {
            $primaryToken = $request->tokens[0];
            $user->fcm_device_token = $primaryToken;
            $user->save();
        }

        Log::info('Multiple FCM tokens updated', [
            'user_id' => $user->id,
            'email' => $user->email,
            'count' => count($request->tokens),
        ]);

        return $this->successResponse([
            'message' => 'Device tokens updated successfully.',
            'count' => count($request->tokens),
        ], 'Device tokens updated.');
    }

    // ------------------ DELETE ACCOUNT ------------------
    public function deleteAccount(Request $request)
    {
        $user = $request->user();
        DB::beginTransaction();
        try {
            $user->tokens()->delete();
            UserSession::where('user_id', $user->id)->delete();
            if ($user->technician) {
                $technician = $user->technician;
                $technician->services()->detach();
                foreach ($technician->portfolios as $portfolio) {
                    if ($portfolio->image && file_exists(public_path($portfolio->image))) {
                        unlink(public_path($portfolio->image));
                    }
                    $portfolio->delete();
                }
                foreach ($technician->posts as $post) {
                    if ($post->image && file_exists(public_path($post->image))) {
                        unlink(public_path($post->image));
                    }
                    $post->delete();
                }
                $technician->delete();
            }
            
            ServiceRequest::where('customer_id', $user->id)->update(['customer_id' => null]);
            
            $user->delete();
            DB::commit();
            $this->logAudit('delete_account', 'auth', $user->id, "User deleted own account");
            return $this->successResponse(null, 'Account deleted.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Account deletion failed: ' . $e->getMessage());
            return $this->serverError('Delete failed: ' . $e->getMessage());
        }
    }

    // ------------------ MY PERMISSIONS ------------------
    public function myPermissions(Request $request)
    {
        $user = $request->user();

        return $this->successResponse([
            'permissions' => $user->getAllPermissions()->pluck('name'),
        ], 'Permissions retrieved.');
    }

    // ------------------ PRIVATE HELPERS ------------------
    private function createSession(User $user, Request $request, string $token): void
    {
        $tokenId = explode('|', $token)[0] ?? null;
        if (!$tokenId) return;

        UserSession::create([
            'user_id'       => $user->id,
            'token'         => $tokenId,
            'ip_address'    => $request->ip(),
            'user_agent'    => $request->userAgent(),
            'device_name'   => $this->getDeviceName($request),
            'last_activity' => now(),
            'expires_at'    => now()->addDays(30),
            'is_active'     => true,
        ]);
    }

    private function getDeviceName(Request $request): string
    {
        $ua = $request->userAgent();
        if (str_contains($ua, 'Postman')) return 'Postman';
        if (str_contains($ua, 'Mozilla')) return 'Web Browser';
        if (str_contains($ua, 'Flutter')) return 'Mobile App';
        return 'Unknown';
    }

    private function validateAndGeocodeArea(string $area, ?float $lat, ?float $lng, GeocodingService $geocoder): array
    {
        if ($lat !== null && $lng !== null) {
            return ['lat' => $lat, 'lng' => $lng];
        }

        $coords = $geocoder->geocode($area);
        if (!$coords) {
            abort(422, "Could not locate the area '{$area}'. Please check the spelling or provide latitude/longitude manually.");
        }

        return $coords;
    }

    
}
