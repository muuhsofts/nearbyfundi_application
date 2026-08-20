<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Otp;
use App\Traits\Auditable;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Carbon\Carbon;

class UserManagementController extends BaseApiController
{
    use Auditable;

    /**
     * Lean technician columns reused across list/detail endpoints so the
     * frontend always gets a predictable shape (id + verification fields).
     */
    private function technicianRelation()
    {
        return ['technician:id,user_id,verified,verification_status,is_online'];
    }

    // ===== LIST =====
    public function index(Request $request)
    {
        $this->checkPermission('users.view');

        $query = User::with(array_merge(['roles'], $this->technicianRelation()));

        // Apply filters
        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%")
                  ->orWhere('phone', 'LIKE', "%{$search}%");
            });
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('role')) {
            $query->whereHas('roles', function ($q) use ($request) {
                $q->where('name', $request->role);
            });
        }

        $perPage = $request->input('per_page', 20);
        $users = $query->orderBy('created_at', 'desc')->paginate($perPage);

        return $this->successResponse([
            'data' => $users->items(),
            'pagination' => [
                'total' => $users->total(),
                'per_page' => $users->perPage(),
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
                'from' => $users->firstItem(),
                'to' => $users->lastItem(),
            ]
        ], 'Users retrieved successfully');
    }

    public function customers(Request $request)
    {
        $this->checkPermission('users.view');

        $query = User::role('CUSTOMER')->with($this->technicianRelation());

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        $perPage = $request->input('per_page', 20);
        $users = $query->orderBy('created_at', 'desc')->paginate($perPage);

        return $this->successResponse([
            'data' => $users->items(),
            'pagination' => [
                'total' => $users->total(),
                'per_page' => $users->perPage(),
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
            ]
        ], 'Customers retrieved successfully');
    }

    public function fundis(Request $request)
    {
        $this->checkPermission('users.view');

        $query = User::role('FUNDI')->with($this->technicianRelation());

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        $perPage = $request->input('per_page', 20);
        $users = $query->orderBy('created_at', 'desc')->paginate($perPage);

        return $this->successResponse([
            'data' => $users->items(),
            'pagination' => [
                'total' => $users->total(),
                'per_page' => $users->perPage(),
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
            ]
        ], 'Fundis retrieved successfully');
    }

    public function stats()
    {
        $this->checkPermission('users.view');
        return $this->successResponse([
            'total'        => User::count(),
            'customers'    => User::role('CUSTOMER')->count(),
            'fundis'       => User::role('FUNDI')->count(),
            'admins'       => User::role('ADMINISTRATOR')->count(),
            'monitoring'   => User::role('MONITORING_OFFICER')->count(),
            'active'       => User::where('is_active', true)->count(),
            'inactive'     => User::where('is_active', false)->count(),
            'pending'      => User::where('status', 'pending')->count(),
            'suspended'    => User::where('status', 'suspended')->count(),
            'verified'     => User::whereNotNull('email_verified_at')->count(),
            'unverified'   => User::whereNull('email_verified_at')->count(),
        ]);
    }

    // ===== DROPDOWNS =====
    public function dropdownUsers(Request $request)
    {
        $this->checkPermission('users.view');

        $search = $request->get('search');
        $role = $request->get('role');

        $query = User::query();

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        if ($role) {
            $query->role($role);
        }

        $users = $query->select('id', 'name', 'email')
            ->orderBy('name')
            ->limit($request->get('limit', 100))
            ->get();

        return $this->successResponse($users);
    }

    public function dropdownCustomers(Request $request)
    {
        $this->checkPermission('users.view');

        $search = $request->get('search');

        $query = User::role('CUSTOMER');

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        $customers = $query->select('id', 'name', 'email')
            ->orderBy('name')
            ->limit($request->get('limit', 100))
            ->get();

        return $this->successResponse($customers);
    }

    public function dropdownFundis(Request $request)
    {
        $this->checkPermission('users.view');

        $search = $request->get('search');
        $verified = $request->get('verified');
        $serviceId = $request->get('service_id');

        $query = User::role('FUNDI')
            ->with(['technician' => function ($q) use ($serviceId) {
                if ($serviceId) {
                    $q->whereHas('services', function ($sq) use ($serviceId) {
                        $sq->where('service_id', $serviceId);
                    });
                }
                $q->select('id', 'user_id', 'profile_photo', 'verified', 'verification_status', 'rating', 'is_online');
            }]);

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        if ($verified !== null) {
            $query->whereHas('technician', function ($q) use ($verified) {
                $q->where('verified', $verified);
            });
        }

        $fundis = $query->select('id', 'name', 'email')
            ->orderBy('name')
            ->limit($request->get('limit', 100))
            ->get();

        $fundis->each(function ($fundi) {
            if ($fundi->technician) {
                $fundi->technician_profile = [
                    'id' => $fundi->technician->id,
                    'profile_photo' => $fundi->technician->profile_photo,
                    'verified' => $fundi->technician->verified,
                    'verification_status' => $fundi->technician->verification_status,
                    'rating' => $fundi->technician->rating,
                    'is_online' => $fundi->technician->is_online,
                ];
            }
        });

        return $this->successResponse($fundis);
    }

    public function dropdownActiveUsers(Request $request)
    {
        $this->checkPermission('users.view');

        $search = $request->get('search');
        $excludeRoles = $request->get('exclude_roles', []);

        $query = User::where('is_active', true);

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        if (!empty($excludeRoles)) {
            $query->whereDoesntHave('roles', function ($q) use ($excludeRoles) {
                $q->whereIn('name', $excludeRoles);
            });
        }

        $users = $query->select('id', 'name', 'email')
            ->orderBy('name')
            ->limit($request->get('limit', 100))
            ->get();

        return $this->successResponse($users);
    }

    // ===== SHOW, CREATE, UPDATE, DELETE =====
    public function show($id)
    {
        $this->checkPermission('users.view');
        $user = User::with(array_merge(['roles'], $this->technicianRelation()))->findOrFail($id);
        return $this->successResponse($user);
    }

    public function store(Request $request)
    {
        $this->checkPermission('users.create');

        $data = $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users',
            'password' => 'required|string|min:8|confirmed',
            'phone'    => 'nullable|string|max:20',
            'role'     => 'required|exists:roles,name',
            'status'   => 'nullable|in:active,inactive,pending,suspended',
        ]);

        $user = User::create([
            'name'       => $data['name'],
            'email'      => $data['email'],
            'password'   => Hash::make($data['password']),
            'phone'      => $data['phone'] ?? null,
            'status'     => $data['status'] ?? 'active',
            'is_active'  => ($data['status'] ?? 'active') === 'active',
            'email_verified_at' => now(),
        ]);

        $user->assignRole($data['role']);

        $this->logAudit('create_user', 'user', $user->id, "User created: {$user->email}");

        return $this->created($user->load('roles'), 'User created successfully.');
    }

    public function update(Request $request, $id)
    {
        $this->checkPermission('users.edit');
        $user = User::findOrFail($id);

        $data = $request->validate([
            'name'   => 'sometimes|string|max:255',
            'email'  => 'sometimes|email|unique:users,email,' . $id,
            'phone'  => 'nullable|string|max:20',
            'role'   => 'sometimes|exists:roles,name',
            'status' => 'sometimes|in:active,inactive,pending,suspended',
        ]);

        $old = $user->toArray();

        // Update user data
        $user->update($request->only(['name', 'email', 'phone', 'status']));

        // Update role if provided
        if ($request->has('role')) {
            $user->syncRoles([$request->role]);
        }

        $new = $user->fresh()->load('roles')->toArray();

        $this->logAudit('update_user', 'user', $id, "User #{$id} updated", $old, $new);

        return $this->successResponse($user->load('roles'), 'User updated successfully.');
    }

    public function destroy($id)
    {
        $this->checkPermission('users.delete');
        $user = User::findOrFail($id);
        $user->delete();
        $this->logAudit('delete_user', 'user', $id, "User #{$id} deleted");
        return $this->successResponse(null, 'User deleted successfully.');
    }

    // ===== SOFT DELETE RESTORE & FORCE =====
    public function trashed(Request $request)
    {
        $this->checkPermission('users.view');

        $query = User::onlyTrashed()->with('roles');

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        $perPage = $request->input('per_page', 20);
        $users = $query->orderBy('deleted_at', 'desc')->paginate($perPage);

        return $this->successResponse([
            'data' => $users->items(),
            'pagination' => [
                'total' => $users->total(),
                'per_page' => $users->perPage(),
                'current_page' => $users->currentPage(),
                'last_page' => $users->lastPage(),
            ]
        ], 'Deleted users retrieved successfully');
    }

    public function restore($id)
    {
        $this->checkPermission('users.edit');
        $user = User::onlyTrashed()->findOrFail($id);
        $user->restore();
        $this->logAudit('restore_user', 'user', $id, "User #{$id} restored");
        return $this->successResponse(null, 'User restored successfully.');
    }

    public function forceDelete($id)
    {
        $this->checkPermission('users.delete');
        $user = User::onlyTrashed()->findOrFail($id);
        $user->forceDelete();
        $this->logAudit('force_delete_user', 'user', $id, "User #{$id} permanently deleted");
        return $this->successResponse(null, 'User permanently deleted.');
    }

    // ===== ACTIVATE, DEACTIVATE, SUSPEND =====
    public function activate($id)
    {
        $this->checkPermission('users.edit');
        $user = User::findOrFail($id);
        $user->is_active = true;
        $user->status = 'active';
        $user->save();
        $this->logAudit('activate_user', 'user', $id, "User #{$id} activated");
        return $this->successResponse($user->load('roles'), 'User activated.');
    }

    public function deactivate($id)
    {
        $this->checkPermission('users.edit');
        $user = User::findOrFail($id);
        $user->is_active = false;
        $user->status = 'inactive';
        $user->save();
        $this->logAudit('deactivate_user', 'user', $id, "User #{$id} deactivated");
        return $this->successResponse($user->load('roles'), 'User deactivated.');
    }

    public function suspend($id)
    {
        $this->checkPermission('users.edit');
        $user = User::findOrFail($id);
        $user->is_active = false;
        $user->status = 'suspended';
        $user->save();
        $this->logAudit('suspend_user', 'user', $id, "User #{$id} suspended");
        return $this->successResponse($user->load('roles'), 'User suspended.');
    }

    // ===== RESET PASSWORD =====
    public function resetPassword(Request $request, $id)
    {
        $this->checkPermission('users.edit');

        $request->validate([
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::findOrFail($id);
        $user->password = Hash::make($request->password);
        $user->save();

        $this->logAudit('reset_user_password', 'user', $id, "Password reset for user #{$id}");

        return $this->successResponse([
            'message' => 'Password reset successfully',
            'user_id' => $user->id,
            'email' => $user->email,
        ], 'Password reset successfully.');
    }

    public function resetPasswordRandom($id)
    {
        $this->checkPermission('users.edit');

        $user = User::findOrFail($id);
        $newPassword = Str::random(10);
        $user->password = Hash::make($newPassword);
        $user->save();

        try {
            Mail::send('emails.password-reset-admin', [
                'user' => $user,
                'password' => $newPassword,
            ], function ($message) use ($user) {
                $message->to($user->email)
                        ->subject('Your Password Has Been Reset');
            });
        } catch (\Exception $e) {
            \Log::error('Password reset email failed: ' . $e->getMessage());
        }

        $this->logAudit('reset_user_password_random', 'user', $id, "Password reset for user #{$id}");

        return $this->successResponse([
            'new_password' => $newPassword,
            'user_id' => $user->id,
            'email' => $user->email,
        ], 'Password reset successfully.');
    }

    // ===== RESEND OTP =====
    public function resendOtp(Request $request, $id)
    {
        $this->checkPermission('users.edit');

        $user = User::findOrFail($id);

        if ($user->email_verified_at) {
            return $this->errorResponse('User is already verified.', 422);
        }

        $otpCode = rand(100000, 999999);
        $expiresAt = Carbon::now()->addMinutes(10);

        Otp::where('email', $user->email)->delete();

        $otp = Otp::create([
            'email' => $user->email,
            'otp' => $otpCode,
            'expires_at' => $expiresAt,
            'is_used' => false,
        ]);

        try {
            Mail::send('emails.otp', ['otp' => $otpCode, 'user' => $user], function ($message) use ($user) {
                $message->to($user->email)
                        ->subject('Your OTP Code');
            });

            $this->logAudit('resend_otp', 'user', $user->id, "OTP resent to user #{$user->id}");

            return $this->successResponse([
                'otp_expires_at' => $expiresAt->toDateTimeString(),
                'otp_sent_to' => $user->email,
            ], 'OTP has been resent successfully.');

        } catch (\Exception $e) {
            \Log::error('OTP sending failed: ' . $e->getMessage());
            return $this->errorResponse('Failed to send OTP. Please try again later.', 500);
        }
    }

    public function resendOtpPhone($id)
    {
        $this->checkPermission('users.edit');

        $user = User::findOrFail($id);

        if (!$user->phone) {
            return $this->errorResponse('User does not have a phone number.', 422);
        }

        if ($user->email_verified_at) {
            return $this->errorResponse('User is already verified.', 422);
        }

        $otpCode = rand(100000, 999999);
        $expiresAt = Carbon::now()->addMinutes(10);

        Otp::where('email', $user->email)->delete();

        $otp = Otp::create([
            'email' => $user->email,
            'otp' => $otpCode,
            'expires_at' => $expiresAt,
            'is_used' => false,
        ]);

        $this->logAudit('resend_otp_phone', 'user', $user->id, "OTP resent to phone for user #{$user->id}");

        return $this->successResponse([
            'otp_expires_at' => $expiresAt->toDateTimeString(),
            'otp_sent_to' => $user->phone,
        ], 'OTP has been resent to your phone.');
    }

    public function sendPasswordResetOtp(Request $request, $id)
    {
        $this->checkPermission('users.edit');

        $user = User::findOrFail($id);

        $token = Str::random(60);
        $expiresAt = Carbon::now()->addHours(24);

        \DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $user->email],
            [
                'token' => Hash::make($token),
                'created_at' => Carbon::now(),
                'expires_at' => $expiresAt,
            ]
        );

        try {
            Mail::send('emails.password-reset', [
                'user' => $user,
                'token' => $token,
                'expires_at' => $expiresAt->toDateTimeString()
            ], function ($message) use ($user) {
                $message->to($user->email)
                        ->subject('Password Reset Request');
            });

            $this->logAudit('send_password_reset', 'user', $user->id, "Password reset link sent to user #{$user->id}");

            return $this->successResponse([
                'reset_token' => $token,
                'expires_at' => $expiresAt->toDateTimeString(),
            ], 'Password reset link has been sent to the user.');

        } catch (\Exception $e) {
            \Log::error('Password reset email failed: ' . $e->getMessage());
            return $this->errorResponse('Failed to send password reset email.', 500);
        }
    }
}