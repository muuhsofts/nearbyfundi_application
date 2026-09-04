<?php

namespace App\Services;

use App\Models\User;
use App\Models\Otp;
use App\Models\SmsLog;
use App\Mail\OtpVerificationMail;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;
use Throwable;

class OtpDeliveryService
{
    public function __construct(
        protected RafikiSmsService $smsService
    ) {}

    public function deliver(User $user, Otp $otp, ?string $verificationUrl = null): array
    {
        // 1. Attempt SMS Delivery if user has a phone number
        if (!empty($user->phone)) {
            $smsError = $this->trySms($user, $otp);

            if ($smsError === null) {
                return [
                    'success'     => true,
                    'channel'     => 'sms',
                    'otp_channel' => 'sms',
                    'otp_sent_to' => $user->phone,
                ];
            }

            Log::warning("OTP SMS delivery failed, falling back to email", [
                'user_id' => $user->id,
                'phone'   => $user->phone,
                'error'   => $smsError,
            ]);
        }

        // 2. Email Fallback
        try {
            $this->sendEmail($user, $otp);

            return [
                'success'     => true,
                'channel'     => 'email',
                'otp_channel' => 'email',
                'otp_sent_to' => $user->email,
            ];
        } catch (Throwable $e) {
            Log::error("OTP Email delivery failed", [
                'user_id' => $user->id,
                'email'   => $user->email,
                'error'   => $e->getMessage(),
            ]);

            return [
                'success'     => false,
                'channel'     => 'failed',
                'otp_channel' => 'failed',
                'otp_sent_to' => null,
            ];
        }
    }

    /**
     * Send SMS via RafikiSMS Service & record to sms_logs table.
     */
    protected function trySms(User $user, Otp $otp): ?string
    {
        $expiresInMinutes = $otp->expires_at 
            ? max(1, (int) now()->diffInMinutes($otp->expires_at)) 
            : 5;

        $message = "Your verification code is {$otp->otp}. It expires in {$expiresInMinutes} minutes.";

        try {
            $result = $this->smsService->sendSms($user->phone, $message);

            $isSuccess = ($result['success'] ?? false) === true
                || ($result['status'] ?? '') === 'success'
                || !empty($result['message_id'])
                || !empty($result['id']);

            // Save log record to database
            SmsLog::create([
                'user_id'       => $user->id,
                'recipient'     => $user->phone,
                'message'       => $message,
                'status'        => $isSuccess ? 'sent' : 'failed',
                'message_id'    => $result['message_id'] ?? $result['id'] ?? null,
                'response_data' => $result,
                'error_message' => $isSuccess ? null : ($result['message'] ?? 'SMS dispatch failed.'),
            ]);

            if ($isSuccess) {
                return null;
            }

            return $result['message'] ?? 'SMS dispatch failed.';

        } catch (Throwable $e) {
            // Save failed execution log
            SmsLog::create([
                'user_id'       => $user->id,
                'recipient'     => $user->phone,
                'message'       => $message,
                'status'        => 'failed',
                'error_message' => $e->getMessage(),
            ]);

            return $e->getMessage();
        }
    }

    protected function sendEmail(User $user, Otp $otp): void
    {
        Mail::to($user->email)->send(new OtpVerificationMail($user, $otp));
    }
}