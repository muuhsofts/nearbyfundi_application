<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Otp;
use App\Models\FailedLoginAttempt;
use App\Models\UserSession;
use App\Mail\OtpMail;
use App\Traits\Auditable;
use App\Models\Technician;
use Carbon\Carbon;
use App\Services\GeocodingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Spatie\Permission\Models\Role;

class AuthController extends BaseApiController
{
    use Auditable;

    // ------------------ CUSTOMER REGISTRATION ------------------
    public function register(Request $request)
    {
        $data = $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users',
            'password' => 'required|string|min:8|confirmed',
            'phone'    => 'nullable|string|max:20',
        ]);

        DB::beginTransaction();
        try {
            $role = Role::where('name', 'CUSTOMER')->firstOrFail();

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

            Mail::to($user->email)->send(
                new OtpMail(
                    $otp->otp,
                    $user->email,
                    $user->name,
                    Otp::TYPE_EMAIL_VERIFICATION,
                    $otp->getVerificationUrl()
                )
            );

            DB::commit();

            $this->logAudit('register', 'auth', 'user', "Customer registered: {$user->email}");

            return $this->created(['email' => $user->email], 'Registration successful. Please verify email.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Registration failed: ' . $e->getMessage());
            return $this->serverError('Registration failed: ' . $e->getMessage());
        }
    }

    // ------------------ FUNDI REGISTRATION ------------------
    public function registerFundi(Request $request, GeocodingService $geocoder)
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

            Mail::to($user->email)->send(
                new OtpMail(
                    $otp->otp,
                    $user->email,
                    $user->name,
                    Otp::TYPE_EMAIL_VERIFICATION,
                    $otp->getVerificationUrl()
                )
            );

            DB::commit();

            $this->logAudit('register_fundi', 'auth', 'user', "Fundi registered: {$user->email}");

            return $this->created(['email' => $user->email], 'Fundi registered. Verify email and wait for admin approval.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Fundi registration failed: ' . $e->getMessage());
            return $this->serverError('Registration failed: ' . $e->getMessage());
        }
    }

    // ------------------ RESEND OTP ------------------
    public function resendOtp(Request $request)
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

        Mail::to($user->email)->send(
            new OtpMail(
                $otp->otp,
                $user->email,
                $user->name,
                Otp::TYPE_EMAIL_VERIFICATION,
                $otp->getVerificationUrl()
            )
        );

        return $this->successResponse(['email' => $user->email], 'OTP resent successfully.');
    }

    // ------------------ OTP VERIFICATION ------------------
    public function verifyOtp(Request $request)
{
    $request->validate([
        'email' => 'required|email',
        'otp'   => 'required|string|size:6',
        'fcm_token' => 'nullable|string|min:10',
    ]);

    $otp = Otp::where('email', $request->email)
        ->where('otp', $request->otp)
        ->whereIn('type', [Otp::TYPE_REGISTRATION, Otp::TYPE_EMAIL_VERIFICATION])
        ->latest()
        ->first();

    if (!$otp || !$otp->isValid()) {
        return $this->badRequest('Invalid or expired OTP.');
    }

    $user = User::where('email', $request->email)->firstOrFail();
    $user->update([
        'email_verified_at' => now(),
        'status'            => 'active',
        'is_active'         => true,
    ]);

    $otp->markAsUsed();

    // Store FCM token if provided
    if ($request->filled('fcm_token')) {
        $this->storeFcmToken($user, $request->fcm_token);
    }

    $token = $user->createToken('auth_token')->plainTextToken;
    $this->createSession($user, $request, $token);

    $this->logAudit('verify_email', 'auth', 'user', "Email verified: {$user->email}");

    return $this->successResponse([
        'user'  => $user->only(['id', 'name', 'email', 'phone', 'locale', 'fcm_device_token']),
        'roles' => $user->getRoleNames(),
        'token' => $token,
    ], 'Email verified.');
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
        'email'    => 'required|string', // can be email or phone
        'password' => 'required|string',
    ]);

    $login = $request->email;

    // Try to find user by email first, if not, by phone
    $user = User::where('email', $login)->first();
    if (!$user) {
        $user = User::where('phone', $login)->first();
    }

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

    // Generate token
    $token = $user->createToken('auth_token')->plainTextToken;
    $this->createSession($user, $request, $token);

    $user->update([
        'last_login_at' => now(),
        'last_login_ip' => $request->ip(),
    ]);

    if ($request->has('fcm_token') && !empty($request->fcm_token)) {
        $this->storeFcmToken($user, $request->fcm_token);
    }

    $this->logAudit('login', 'auth', 'user', "User logged in: {$user->email}");

    return $this->successResponse([
        'user'  => $user->only(['id', 'name', 'email', 'phone', 'locale', 'fcm_device_token']),
        'roles' => $user->getRoleNames(),
        'token' => $token,
    ], 'Login successful.');
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

    // ------------------ FORGOT PASSWORD (OPTIMIZED) ------------------
    public function forgotPassword(Request $request)
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

        // Queue email for faster response
        Mail::to($user->email)->queue(
            new OtpMail(
                $otp->otp,
                $user->email,
                $user->name,
                Otp::TYPE_PASSWORD_RESET
            )
        );

        $this->logAudit('forgot_password', 'auth', 'user', "Password reset OTP queued for {$user->email}");

        return $this->successResponse(null, 'OTP sent successfully.');
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
    //  ⭐⭐⭐ FCM TOKEN MANAGEMENT (IMPROVED) ⭐⭐⭐
    // ============================================================

    /**
     * Store or update FCM device token for the authenticated user
     * This is called from the mobile app after login
     */
    public function updateDeviceToken(Request $request)
    {
        $request->validate([
            'token' => 'required|string|min:10', // FCM tokens are long strings
        ]);

        $user = $request->user();
        
        if (!$user) {
            return $this->unauthorized('User not authenticated.');
        }

        $oldToken = $user->fcm_device_token;
        $newToken = $request->token;

        // Store the token
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
     * Get the current user's FCM token (for debugging)
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
     * Delete the user's FCM token (logout or remove device)
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
     * Optional: Store tokens in a separate table for multiple devices
     */
    public function updateDeviceTokens(Request $request)
    {
        $request->validate([
            'tokens' => 'required|array',
            'tokens.*' => 'required|string|min:10',
        ]);

        $user = $request->user();
        
        // Store primary token in user table
        if (!empty($request->tokens)) {
            $primaryToken = $request->tokens[0];
            $user->fcm_device_token = $primaryToken;
            $user->save();

            // TODO: Store additional tokens in a separate device_tokens table
            // DeviceToken::where('user_id', $user->id)->delete();
            // foreach ($request->tokens as $token) {
            //     DeviceToken::create(['user_id' => $user->id, 'token' => $token]);
            // }
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

    // ------------------ MY PERMISSIONS (for sidebar/UI gating) ------------------
    public function myPermissions(Request $request)
    {
        $user = $request->user();

        return $this->successResponse([
            'permissions' => $user->getAllPermissions()->pluck('name'),
        ], 'Permissions retrieved.');
    }
}