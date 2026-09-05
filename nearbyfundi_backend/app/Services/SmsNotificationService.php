<?php

namespace App\Services;

use App\Models\User;
use App\Models\ServiceRequest;
use App\Models\Technician;
use App\Models\SmsLog;
use Illuminate\Support\Facades\Log;
use Throwable;

class SmsNotificationService
{
    protected RafikiSmsService $smsService;

    public function __construct(RafikiSmsService $smsService)
    {
        $this->smsService = $smsService;
    }

    /**
     * Send notification to technician about new request
     * Format: "Nearbyfundi: New request for {service} created by {customer_name}. Login into app for more detail."
     */
    public function notifyTechnicianNewRequest(ServiceRequest $request, Technician $technician): array
    {
        $customer = $request->customer;
        $customerName = $customer->name ?? 'Customer';
        $serviceName  = $request->service->name ?? 'a service';

        $message = "Nearbyfundi: New request for {$serviceName} created by {$customerName}. Login into app for more detail.";

        return $this->sendSms($technician->user, $message, 'technician_new_request', [
            'request_id'    => $request->id,
            'customer_id'   => $customer->id ?? null,
            'technician_id' => $technician->id,
            'service_name'  => $serviceName,
        ]);
    }

    /**
     * Send notification to customer when technician accepts request
     * Format: "Your request for {service} has been accepted by {technician_name}. Wait, technician checks you in a few minutes."
     */
    public function notifyCustomerRequestAccepted(ServiceRequest $request, Technician $technician): array
    {
        $customer        = $request->customer;
        $technicianName  = $technician->user->name ?? 'Technician';
        $serviceName     = $request->service->name ?? 'your service';

        $message = "Your request for {$serviceName} has been accepted by {$technicianName}. Wait, technician checks you in a few minutes.";

        return $this->sendSms($customer, $message, 'request_accepted', [
            'request_id'      => $request->id,
            'technician_id'   => $technician->id,
            'customer_id'     => $customer->id ?? null,
            'technician_name' => $technicianName,
            'service_name'    => $serviceName,
        ]);
    }

    /**
     * Send SMS and log result
     */
    protected function sendSms(User $user, string $message, string $type, array $metadata = []): array
    {
        if (empty($user->phone)) {
            Log::warning("SMS not sent: User has no phone number", [
                'user_id' => $user->id,
                'type'    => $type,
            ]);

            return [
                'success' => false,
                'error'   => 'User has no phone number',
                'type'    => $type,
            ];
        }

        try {
            $result = $this->smsService->sendSms($user->phone, $message);

            $isSuccess = ($result['success'] ?? false) === true
                || ($result['status'] ?? '') === 'success'
                || !empty($result['message_id']);

            // Log SMS
            SmsLog::create([
                'user_id'       => $user->id,
                'recipient'     => $user->phone,
                'message'       => $message,
                'status'        => $isSuccess ? 'sent' : 'failed',
                'message_id'    => $result['message_id'] ?? $result['id'] ?? null,
                'response_data' => array_merge($result, ['type' => $type, 'metadata' => $metadata]),
                'error_message' => $isSuccess ? null : ($result['message'] ?? 'SMS dispatch failed'),
            ]);

            return [
                'success'   => $isSuccess,
                'message_id'=> $result['message_id'] ?? null,
                'type'      => $type,
                'recipient' => $user->phone,
            ];

        } catch (Throwable $e) {
            Log::error("SMS notification failed", [
                'user_id' => $user->id,
                'type'    => $type,
                'error'   => $e->getMessage(),
            ]);

            SmsLog::create([
                'user_id'       => $user->id,
                'recipient'     => $user->phone,
                'message'       => $message,
                'status'        => 'failed',
                'error_message' => $e->getMessage(),
                'response_data' => ['type' => $type, 'metadata' => $metadata],
            ]);

            return [
                'success' => false,
                'error'   => $e->getMessage(),
                'type'    => $type,
            ];
        }
    }

    /**
     * Notify multiple technicians about a new request
     */
    public function notifyMultipleTechnicians(ServiceRequest $request, array $technicianIds): array
    {
        $results = [];

        foreach ($technicianIds as $technicianId) {
            $technician = Technician::with('user')->find($technicianId);
            if ($technician && $technician->user) {
                $results[] = $this->notifyTechnicianNewRequest($request, $technician);
            }
        }

        return $results;
    }
}