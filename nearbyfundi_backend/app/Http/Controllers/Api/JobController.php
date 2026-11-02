<?php

namespace App\Http\Controllers\Api;

use App\Models\Job;
use App\Models\RequestLog;
use App\Models\ServiceRequest;
use App\Services\JobNotificationService;
use App\Traits\Auditable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

/**
 * Customer journey after a request is accepted:
 *
 *   request accepted ──(automatic)──▶ Job (pending) + Ticket (pending, auto number)
 *                                     customer is told by SMS to open the Jobs section
 *   [Contact Fundi / Chat]  from the job
 *   [Mark Complete] ──▶ 6-digit OTP generated and SMS-ed to the CUSTOMER
 *   [Enter OTP]     ──▶ Job completed + Ticket completed
 *   [Review]        ──▶ Customer rates (1-5) + remark, once per job (ReviewController)
 *
 * The technician's phone and email are returned in the job payload so the
 * customer can use "Contact Fundi". Jobs are only visible to the customer or
 * fundi that own them. Chat is opened with technician.user_id.
 */
class JobController extends BaseApiController
{
    use Auditable;

    private const OTP_TTL_MINUTES  = 10;
    private const OTP_MAX_ATTEMPTS = 5;
    private const OTP_RESEND_SECS  = 60;

    private const WITH = [
        'request.service',
        'request.category',
        'technician.user',
        'customer',
        'tickets',
        'review',
    ];

    public function __construct(protected JobNotificationService $notifier)
    {
    }

    // ============================================================
    // LIST / SHOW
    // ============================================================

    public function index(Request $request)
    {
        $user  = $request->user();
        $query = Job::with(self::WITH)->latest();

        if ($user->hasRole('CUSTOMER')) {
            $query->where('customer_id', $user->id);
        } elseif ($user->hasRole('FUNDI') && $user->technician) {
            $query->where('technician_id', $user->technician->id);
        } else {
            return $this->forbidden('You are not allowed to view jobs.');
        }

        if ($request->filled('status') && in_array($request->status, Job::STATUSES, true)) {
            $query->where('status', $request->status);
        }

        return $this->successResponse(
            $query->get()->map(fn (Job $j) => $this->format($j)),
            'Jobs retrieved successfully'
        );
    }

    public function show(Request $request, $id)
    {
        $job = $this->findForUser($request, $id);

        return $job
            ? $this->successResponse($this->format($job))
            : $this->notFound('Job not found.');
    }

    // ============================================================
    // MARK COMPLETE → validates phone country code & enforces SMS
    // ============================================================

    public function requestCompletion(Request $request, $id)
    {
        $job = $this->findForUser($request, $id, customerOnly: true);

        if (!$job) {
            return $this->notFound('Job not found.');
        }
        if (!$job->canComplete()) {
            return $this->errorResponse('This job can no longer be completed.', 422);
        }

        $customer = $job->customer;
        $phone    = $customer ? $customer->phone : null;

        if (!$phone || !$this->isValidCountryCodePhone($phone)) {
            return $this->errorResponse(
                'A valid phone number with a valid country code format (e.g. 255XXXXXXXXX or +255XXXXXXXXX) is mandatory to receive the SMS verification code.',
                422
            );
        }

        $sentAt = $job->completion_otp_expires_at?->copy()->subMinutes(self::OTP_TTL_MINUTES);
        if ($sentAt && $sentAt->gt(now()->subSeconds(self::OTP_RESEND_SECS))) {
            return $this->successResponse($this->otpPayload($job, alreadySent: true), 'A code was just sent.');
        }

        $plain = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $job->forceFill([
            'completion_otp'            => Hash::make($plain),
            'completion_otp_expires_at' => now()->addMinutes(self::OTP_TTL_MINUTES),
            'completion_otp_attempts'   => 0,
        ])->save();

        $sent = false;
        try {
            $sent = $this->notifier->completionCode($job, $plain);
        } catch (\Throwable $e) {
            Log::error('completionCode notification failed: ' . $e->getMessage());
        }

        if (!$sent) {
            $job->forceFill([
                'completion_otp'            => null,
                'completion_otp_expires_at' => null,
                'completion_otp_attempts'   => 0,
            ])->save();

            return $this->errorResponse('Mandatory SMS delivery failed. Please check your country code phone format and try again.', 502);
        }

        return $this->successResponse($this->otpPayload($job), 'Completion code sent by SMS. Enter it to finish the job.');
    }

    // ============================================================
    // ENTER OTP → job + ticket completed (then customer can review)
    // ============================================================

    public function verifyCompletion(Request $request, $id)
    {
        try {
            $data = $request->validate(['otp' => 'required|digits:6']);
        } catch (ValidationException $e) {
            return $this->validationError($e->errors());
        }

        $user = $request->user();
        $job  = $this->findForUser($request, $id, customerOnly: true);

        if (!$job) {
            return $this->notFound('Job not found.');
        }
        if ($job->isCompleted()) {
            return $this->errorResponse('This job is already completed.', 422);
        }
        if (!$job->canComplete()) {
            return $this->errorResponse('This job can no longer be completed.', 422);
        }
        if (!$job->completion_otp || !$job->completion_otp_expires_at || $job->completion_otp_expires_at->isPast()) {
            return $this->errorResponse('The code expired. Tap Mark Complete to get a new one.', 422);
        }
        if ($job->completion_otp_attempts >= self::OTP_MAX_ATTEMPTS) {
            return $this->errorResponse('Too many wrong attempts. Tap Mark Complete to get a new code.', 429);
        }

        if (!Hash::check($data['otp'], $job->completion_otp)) {
            $job->increment('completion_otp_attempts');
            $left = max(0, self::OTP_MAX_ATTEMPTS - (int) $job->fresh()->completion_otp_attempts);

            return $this->errorResponse("Invalid code. {$left} attempt(s) left.", 422);
        }

        try {
            DB::transaction(function () use ($job, $request, $user) {
                $job->forceFill([
                    'status'                    => Job::STATUS_COMPLETED,
                    'completed_at'              => now(),
                    'completion_otp'            => null,
                    'completion_otp_expires_at' => null,
                    'completion_otp_attempts'   => 0,
                ])->save();

                $job->technician?->increment('completed_jobs_count');

                $sr = $job->request;
                $this->logRequestAction(
                    $job->request_id,
                    $user->id,
                    'job_completed',
                    $sr?->status,
                    $sr?->status ?? ServiceRequest::STATUS_ACCEPTED,
                    "Job {$job->job_number} completed with OTP",
                    $request->ip()
                );
            });
        } catch (\Throwable $e) {
            Log::error('verifyCompletion failed: ' . $e->getMessage());
            return $this->errorResponse('Failed to complete the job. Please try again.', 500);
        }

        $job->load(self::WITH);

        try {
            $this->notifier->jobCompleted($job);
        } catch (\Throwable $e) {
            Log::error('jobCompleted notification failed: ' . $e->getMessage());
        }

        $this->logAudit('complete_job', 'job', $job->id, "Job {$job->job_number} completed with OTP");

        return $this->successResponse($this->format($job), 'Job completed.');
    }

    // ============================================================
    // HELPERS
    // ============================================================

    private function isValidCountryCodePhone(string $phone): bool
    {
        $cleanPhone = preg_replace('/[^0-9+]/', '', trim($phone));

        return preg_match('/^\+?[1-9]\d{6,14}$/', $cleanPhone) === 1;
    }

    private function findForUser(Request $request, $id, bool $customerOnly = false): ?Job
    {
        $user = $request->user();
        $job  = Job::with(self::WITH)->find($id);

        if (!$job || !$user) {
            return null;
        }

        $isCustomer = (int) $job->customer_id === (int) $user->id;
        $isFundi    = $user->hasRole('FUNDI') && $user->technician
            && (int) $user->technician->id === (int) $job->technician_id;

        if ($customerOnly) {
            return $isCustomer ? $job : null;
        }

        return ($isCustomer || $isFundi) ? $job : null;
    }

    private function otpPayload(Job $job, bool $alreadySent = false): array
    {
        return [
            'job_id'       => $job->id,
            'already_sent' => $alreadySent,
            'channel'      => 'sms',
            'expires_at'   => $job->completion_otp_expires_at?->toIso8601String(),
            'ttl_seconds'  => self::OTP_TTL_MINUTES * 60,
            'resend_after' => self::OTP_RESEND_SECS,
        ];
    }

    private function logRequestAction(int $requestId, int $userId, string $action, ?string $old, string $new, ?string $notes, ?string $ip): void
    {
        try {
            RequestLog::create([
                'request_id' => $requestId,
                'user_id'    => $userId,
                'action'     => $action,
                'old_status' => $old,
                'new_status' => $new,
                'notes'      => $notes,
                'ip_address' => $ip,
            ]);
        } catch (\Throwable $e) {
            Log::error('Failed to log request action: ' . $e->getMessage());
        }
    }

    private function format(Job $job): array
    {
        $tech   = $job->technician;
        $sr     = $job->request;
        $ticket = $job->tickets->sortByDesc('id')->first();
        $review = $job->review;

        return [
            'id'           => $job->id,
            'job_number'   => $job->job_number,
            'status'       => $job->status,
            'started_at'   => $job->started_at,
            'completed_at' => $job->completed_at,
            'notes'        => $job->notes,
            'created_at'   => $job->created_at,
            'request'      => $sr ? [
                'id'          => $sr->id,
                'description' => $sr->description,
                'service'     => $sr->service ? ['id' => $sr->service->id, 'name' => $sr->service->name] : null,
                'category'    => $sr->category ? [
                    'id'   => $sr->category->service_categoryID,
                    'name' => $sr->category->category_name,
                ] : null,
            ] : null,
            'technician'   => $tech ? [
                'id'            => $tech->id,
                'user_id'       => $tech->user_id,
                'name'          => $tech->user->name ?? null,
                'phone'         => $tech->user->phone ?? null,
                'email'         => $tech->user->email ?? null,
                'profile_photo' => $tech->profile_photo ? url('storage/' . ltrim($tech->profile_photo, '/')) : null,
                'area'          => $tech->area,
                'rating'        => (float) ($tech->rating ?? 0),
            ] : null,
            'customer'     => $job->customer ? ['id' => $job->customer->id, 'name' => $job->customer->name] : null,
            'ticket'       => $ticket ? [
                'id'            => $ticket->id,
                'ticket_number' => $ticket->ticket_number,
                'status'        => $ticket->status,
                'title'         => $ticket->title,
                'description'   => $ticket->description,
                'completed_at'  => $ticket->completed_at,
            ] : null,
            'review'       => $review ? [
                'id'         => $review->id,
                'rating'     => (float) $review->rating,
                'comment'    => $review->comment,
                'created_at' => $review->created_at?->toIso8601String(),
            ] : null,
        ];
    }
}