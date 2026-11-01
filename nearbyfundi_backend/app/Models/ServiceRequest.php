<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * requests.status: pending | accepted | in_progress | cancelled | rejected
 *
 *   pending     → accepted | rejected   (assigned fundi)
 *   pending     → cancelled             (the customer)
 *   accepted    → in_progress           (customer taps "Mark as Job")
 *   Anything other than pending is locked for accept / reject / cancel.
 */
class ServiceRequest extends Model
{
    use SoftDeletes;

    protected $table = 'requests';

    public const STATUS_PENDING     = 'pending';
    public const STATUS_ACCEPTED    = 'accepted';
    public const STATUS_IN_PROGRESS = 'in_progress';
    public const STATUS_CANCELLED   = 'cancelled';
    public const STATUS_REJECTED    = 'rejected';

    public const STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_ACCEPTED,
        self::STATUS_IN_PROGRESS,
        self::STATUS_CANCELLED,
        self::STATUS_REJECTED,
    ];

    protected $fillable = [
        'customer_id', 'technician_id', 'service_id', 'category_id',
        'description', 'status', 'latitude', 'longitude',
    ];

    protected $casts = [
        'latitude'   => 'float',
        'longitude'  => 'float',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // ── Relationships ─────────────────────────────────────
    public function customer(): BelongsTo   { return $this->belongsTo(User::class, 'customer_id'); }
    public function technician(): BelongsTo { return $this->belongsTo(Technician::class, 'technician_id'); }
    public function service(): BelongsTo    { return $this->belongsTo(Service::class, 'service_id'); }

    public function category(): BelongsTo
    {
        return $this->belongsTo(ServiceCategory::class, 'category_id', 'service_categoryID');
    }

    public function logs(): HasMany { return $this->hasMany(RequestLog::class, 'request_id'); }

    /** One request becomes at most one job. */
    public function job(): HasOne { return $this->hasOne(Job::class, 'request_id'); }

    // ── State helpers ─────────────────────────────────────
    public function isPending(): bool    { return $this->status === self::STATUS_PENDING; }
    public function isAccepted(): bool   { return $this->status === self::STATUS_ACCEPTED; }
    public function isInProgress(): bool { return $this->status === self::STATUS_IN_PROGRESS; }

    /** Accept / reject / cancel are possible only while pending. */
    public function canChange(): bool { return $this->isPending(); }

    /** The customer can turn an accepted request into a job. */
    public function canBeMarkedAsJob(): bool { return $this->isAccepted(); }
}