<?php

namespace App\Services;

use App\Models\Job;
use Illuminate\Support\Facades\Log;

/**
 * Notifications for the job lifecycle.
 *
 * WIRE-UP: I could not see RequestNotificationService / SmsNotificationService,
 * so each method below logs and then calls deliver(). Make deliver() use the
 * same in-app + push + SMS channels your RequestNotificationService uses.
 * Suggested in-app notification types (the Flutter app routes on these):
 *   job_started, job_completion_code, job_completed
 */
class JobNotificationService
{
    /** Customer marked an accepted request as a job → tell the fundi. */
    public function jobStarted(Job $job): void
    {
        $job->loadMissing(['technician.user', 'customer', 'request.service']);

        $this->deliver(
            $job->technician?->user?->id,
            'job_started',
            'New job started',
            "{$job->customer?->name} started job {$job->job_number}.",
            $job
        );
    }

    /**
     * Customer pressed "Mark Complete". The code goes to the FUNDI (never to
     * the customer): the fundi reads it out once the work is truly finished and
     * the customer types it in. This proves both sides agree the job is done.
     */
    public function completionCode(Job $job, string $plainOtp): void
    {
        $job->loadMissing(['technician.user']);

        $this->deliver(
            $job->technician?->user?->id,
            'job_completion_code',
            'Job completion code',
            "Code to close job {$job->job_number}: {$plainOtp}. Share it with the customer only when the work is done.",
            $job,
            sendSms: true
        );
    }

    /** OTP verified → job + ticket completed → tell both sides. */
    public function jobCompleted(Job $job): void
    {
        $job->loadMissing(['technician.user', 'customer']);

        $this->deliver(
            $job->technician?->user?->id,
            'job_completed',
            'Job completed',
            "Job {$job->job_number} was confirmed as completed.",
            $job
        );

        $this->deliver(
            $job->customer_id,
            'job_completed',
            'Job completed',
            "Job {$job->job_number} is now completed.",
            $job
        );
    }

    private function deliver(?int $userId, string $type, string $title, string $body, Job $job, bool $sendSms = false): void
    {
        if (!$userId) {
            return;
        }

        // TODO: replace with the project's real channel(s), e.g.
        //   NotificationService::send($userId, $type, $title, $body, ['job_id' => $job->id]);
        //   if ($sendSms) { app(SmsNotificationService::class)->send(...); }
        Log::info('[JobNotification]', compact('userId', 'type', 'title', 'sendSms') + ['job_id' => $job->id]);
    }
}
