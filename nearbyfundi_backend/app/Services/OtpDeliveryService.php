<?php

namespace App\Services;

use App\Models\User;
use App\Models\Otp;
use App\Models\SmsLog;
use App\Mail\OtpVerificationMail;
use App\Mail\PasswordResetOtpMail;
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
        // Determine message based on OTP type
        $message = $this->getOtpMessage($otp);

        // 1. Attempt SMS Delivery if user has a phone number
        if (!empty($user->phone)) {
            $smsError = $this->trySms($user, $otp, $message);

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
     * Get the appropriate message based on OTP type
     */
    protected function getOtpMessage(Otp $otp): string
    {
        $expiresInMinutes = $otp->expires_at 
            ? max(1, (int) now()->diffInMinutes($otp->expires_at)) 
            : 5;

        switch ($otp->type) {
            case Otp::TYPE_EMAIL_VERIFICATION:
                return "Your Fundi App verification code is: {$otp->otp}. It expires in {$expiresInMinutes} minutes.";
            
            case Otp::TYPE_PASSWORD_RESET:
                return "Your Fundi App password reset code is: {$otp->otp}. It expires in {$expiresInMinutes} minutes.";
            
            case Otp::TYPE_PHONE_VERIFICATION:
                return "Your Fundi App phone verification code is: {$otp->otp}. It expires in {$expiresInMinutes} minutes.";
            
            default:
                return "Your Fundi App OTP code is: {$otp->otp}. It expires in {$expiresInMinutes} minutes.";
        }
    }

    /**
     * Send SMS via RafikiSMS Service & record to sms_logs table.
     */
    protected function trySms(User $user, Otp $otp, string $message): ?string
    {
        // Format phone number (ensure it's in correct format)
        $phone = $this->formatPhoneNumber($user->phone);
        
        if (!$phone) {
            return 'Invalid phone number format';
        }

        try {
            $result = $this->smsService->sendSms($phone, $message);

            $isSuccess = ($result['success'] ?? false) === true
                || ($result['status'] ?? '') === 'success'
                || !empty($result['message_id'])
                || !empty($result['id']);

            // Save log record to database
            SmsLog::create([
                'user_id'       => $user->id,
                'recipient'     => $phone,
                'message'       => $message,
                'status'        => $isSuccess ? 'sent' : 'failed',
                'message_id'    => $result['message_id'] ?? $result['id'] ?? null,
                'response_data' => $result,
                'error_message' => $isSuccess ? null : ($result['message'] ?? 'SMS dispatch failed.'),
            ]);

            if ($isSuccess) {
                Log::info('OTP SMS sent successfully', [
                    'user_id' => $user->id,
                    'phone' => $phone,
                    'otp_type' => $otp->type,
                ]);
                return null;
            }

            return $result['message'] ?? 'SMS dispatch failed.';

        } catch (Throwable $e) {
            // Save failed execution log
            SmsLog::create([
                'user_id'       => $user->id,
                'recipient'     => $phone,
                'message'       => $message,
                'status'        => 'failed',
                'error_message' => $e->getMessage(),
            ]);

            Log::error('SMS sending exception', [
                'user_id' => $user->id,
                'phone' => $phone,
                'error' => $e->getMessage(),
            ]);

            return $e->getMessage();
        }
    }

    /**
     * Format phone number to international format
     */
    protected function formatPhoneNumber(?string $phone): ?string
    {
        if (empty($phone)) {
            return null;
        }

        // Remove all non-numeric characters except +
        $phone = preg_replace('/[^0-9+]/', '', $phone);

        if (empty($phone)) {
            return null;
        }

        // Remove + if present
        $phone = ltrim($phone, '+');

        // If it starts with 0, replace with 255 (Tanzania)
        if (strpos($phone, '0') === 0) {
            $phone = '255' . substr($phone, 1);
        }

        // If it doesn't start with 255, add 255
        if (!str_starts_with($phone, '255')) {
            $phone = '255' . $phone;
        }

        // Validate length (Tanzania numbers should be 12 digits including 255)
        if (strlen($phone) !== 12) {
            Log::warning('Invalid phone number length after formatting', [
                'phone' => $phone,
                'length' => strlen($phone),
                'expected' => 12,
            ]);
            return null;
        }

        return $phone;
    }

    protected function sendEmail(User $user, Otp $otp): void
    {
        // Determine which email to send based on OTP type
        if ($otp->type === Otp::TYPE_PASSWORD_RESET) {
            Mail::to($user->email)->send(new PasswordResetOtpMail($user, $otp));
        } else {
            Mail::to($user->email)->send(new OtpVerificationMail($user, $otp));
        }
    }
}