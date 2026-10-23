<?php

namespace App\Services;

use App\Models\ServiceRequest;
use App\Models\SmsLog;
use App\Models\Technician;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Throwable;

class SmsNotificationService
{
    public function __construct(protected RafikiSmsService $smsService)
    {
    }

    /** Send the registration OTP by SMS. */
    public function notifyUserOtp(User $user, string $otp, int $validMinutes = 10): array
    {
        $message = "Nearbyfundi: Your code is {$otp}. "
                 . "It expires in {$validMinutes} minutes. Never share it with anyone.";

        return $this->sendSms($user, $message, 'registration_otp', ['user_id' => $user->id]);
    }

    /**
     * Notify every active ADMINISTRATOR (with a phone) that a fundi
     * has submitted a registration for approval.
     */
    public function notifyAdminsNewFundiRegistration(string $fundiName, ?string $fundiContact, int $technicianId): array
    {
        $admins = User::role('ADMINISTRATOR', 'web')
            ->where('is_active', true)
            ->whereNotNull('phone')
            ->where('phone', '!=', '')
            ->get()
            ->unique('phone'); // avoid duplicate SMS to the same number

        if ($admins->isEmpty()) {
            Log::warning('No active administrators with a phone number to notify', [
                'technician_id' => $technicianId,
            ]);
            return [];
        }

        $contact = $fundiContact ?: 'N/A';
        $message = "Nearbyfundi: New fundi {$fundiName} ({$contact}) is waiting for approval. "
                 . "Open the admin panel to review.";

        $results = [];
        foreach ($admins as $admin) {
            $results[] = $this->sendSms($admin, $message, 'admin_new_fundi_registration', [
                'technician_id' => $technicianId,
                'admin_id'      => $admin->id,
                'fundi_name'    => $fundiName,
            ]);
        }

        return $results;
    }

    /** Tell a fundi their account is approved. */
    public function notifyFundiApproved(User $user, int $trialDays = 1): array
    {
        $message = "Nearbyfundi: Congratulations {$user->name}! Your account is approved. "
                 . "Enjoy your {$trialDays}-day free trial. Open the app to start getting jobs.";

        return $this->sendSms($user, $message, 'fundi_approved', ['user_id' => $user->id]);
    }

    public function notifyTechnicianNewRequest(ServiceRequest $request, Technician $technician): array
    {
        $customerName = $request->customer->name ?? 'Customer';
        $serviceName  = $request->service->name ?? 'a service';

        $message = "Nearbyfundi: New {$serviceName} request from {$customerName}. "
                 . "Open the app to view and accept.";

        return $this->sendSms($technician->user, $message, 'technician_new_request', [
            'request_id'    => $request->id,
            'customer_id'   => $request->customer->id ?? null,
            'technician_id' => $technician->id,
            'service_name'  => $serviceName,
        ]);
    }

    public function notifyCustomerRequestAccepted(ServiceRequest $request, Technician $technician): array
    {
        $customer       = $request->customer;
        $technicianName = $technician->user->name ?? 'Technician';
        $serviceName    = $request->service->name ?? 'your service';

        $message = "Nearbyfundi: {$technicianName} accepted your {$serviceName} request "
                 . "and will contact you shortly.";

        return $this->sendSms($customer, $message, 'request_accepted', [
            'request_id'      => $request->id,
            'technician_id'   => $technician->id,
            'customer_id'     => $customer->id ?? null,
            'technician_name' => $technicianName,
            'service_name'    => $serviceName,
        ]);
    }

    public function notifyMultipleTechnicians(ServiceRequest $request, array $technicianIds): array
    {
        $results = [];

        foreach ($technicianIds as $technicianId) {
            $technician = Technician::with('user')->find($technicianId);
            if ($technician?->user) {
                $results[] = $this->notifyTechnicianNewRequest($request, $technician);
            }
        }

        return $results;
    }

    protected function sendSms(User $user, string $message, string $type, array $metadata = []): array
    {
        if (empty($user->phone)) {
            Log::warning('SMS not sent: user has no phone number', ['user_id' => $user->id, 'type' => $type]);
            return ['success' => false, 'error' => 'User has no phone number', 'type' => $type];
        }

        $logMessage = $type === 'registration_otp' ? 'Nearbyfundi: [OTP hidden]' : $message;

        try {
            $result = $this->smsService->sendSms($user->phone, $message);

            $isSuccess = ($result['success'] ?? false) === true
                || ($result['status'] ?? '') === 'success'
                || !empty($result['message_id']);

            SmsLog::create([
                'user_id'       => $user->id,
                'recipient'     => $user->phone,
                'message'       => $logMessage,
                'status'        => $isSuccess ? 'sent' : 'failed',
                'message_id'    => $result['message_id'] ?? $result['id'] ?? null,
                'response_data' => array_merge($result, ['type' => $type, 'metadata' => $metadata]),
                'error_message' => $isSuccess ? null : ($result['message'] ?? 'SMS dispatch failed'),
            ]);

            return [
                'success'    => $isSuccess,
                'message_id' => $result['message_id'] ?? null,
                'type'       => $type,
                'recipient'  => $user->phone,
            ];
        } catch (Throwable $e) {
            Log::error('SMS notification failed', ['user_id' => $user->id, 'type' => $type, 'error' => $e->getMessage()]);

            SmsLog::create([
                'user_id'       => $user->id,
                'recipient'     => $user->phone,
                'message'       => $logMessage,
                'status'        => 'failed',
                'error_message' => $e->getMessage(),
                'response_data' => ['type' => $type, 'metadata' => $metadata],
            ]);

            return ['success' => false, 'error' => $e->getMessage(), 'type' => $type];
        }
    }
}