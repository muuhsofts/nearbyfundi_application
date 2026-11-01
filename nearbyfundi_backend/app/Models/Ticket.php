<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class Ticket extends Model
{
    protected $table = 'tickets';

    public const STATUS_ON_PROGRESS = 'on-progress';
    public const STATUS_COMPLETED   = 'completed';

    public const STATUSES = [
        self::STATUS_ON_PROGRESS,
        self::STATUS_COMPLETED,
    ];

    protected $fillable = [
        'ticket_number',
        'job_id',
        'status',
        'title',
        'description',
        'completed_at',
    ];

    protected $casts = [
        'completed_at' => 'datetime',
        'created_at'   => 'datetime',
        'updated_at'   => 'datetime',
    ];

    protected static function booted(): void
    {
        // ticket number is generated automatically
        static::creating(function (Ticket $ticket) {
            if (empty($ticket->ticket_number)) {
                $ticket->ticket_number = self::generateTicketNumber();
            }
        });

        static::updated(function (Ticket $ticket) {
            if ($ticket->wasChanged('status') && $ticket->status === self::STATUS_COMPLETED) {

                if (!$ticket->completed_at) {
                    $ticket->completed_at = now();
                    $ticket->saveQuietly();
                }

                // Auto-complete parent job when all tickets are done
                $job = $ticket->job;
                if ($job && $job->status !== Job::STATUS_COMPLETED) {
                    $hasOpen = $job->tickets()
                        ->where('status', self::STATUS_ON_PROGRESS)
                        ->exists();

                    if (!$hasOpen) {
                        $job->status       = Job::STATUS_COMPLETED;
                        $job->completed_at = now();
                        $job->save(); // Job::updated completes any other open ticket
                    }
                }
            }
        });
    }

    public static function generateTicketNumber(): string
    {
        do {
            $number = 'TKT-' . now()->format('Ymd') . '-' . strtoupper(Str::random(6));
        } while (self::where('ticket_number', $number)->exists());

        return $number;
    }

    // ── Relationships ─────────────────────────────────────
    public function job(): BelongsTo
    {
        return $this->belongsTo(Job::class, 'job_id');
    }

    // ── Helpers ───────────────────────────────────────────
    public function isCompleted(): bool { return $this->status === self::STATUS_COMPLETED; }
}