<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class ServiceRequest extends Model
{
    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'requests';
    
    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'customer_id',
        'technician_id',
        'service_id',
        'category_id',
        'description',
        'status',
        // location fields
        'latitude',
        'longitude',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'latitude'   => 'float',
        'longitude'  => 'float',
    ];

    // ============================================================
    // STATUS CONSTANTS
    // ============================================================

    const STATUS_PENDING     = 'pending';
    const STATUS_ACCEPTED    = 'accepted';
    const STATUS_ON_THE_WAY  = 'on_the_way';
    const STATUS_ARRIVED     = 'arrived';
    const STATUS_IN_PROGRESS = 'in_progress';
    const STATUS_COMPLETED   = 'completed';
    const STATUS_CANCELLED   = 'cancelled';
    const STATUS_REJECTED    = 'rejected';

    // ============================================================
    // RELATIONSHIPS
    // ============================================================

    /**
     * Get the customer who created the request.
     */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    /**
     * Get the technician assigned to the request.
     */
    public function technician(): BelongsTo
    {
        return $this->belongsTo(Technician::class);
    }

    /**
     * Get the service for this request.
     */
    public function service(): BelongsTo
    {
        return $this->belongsTo(Service::class);
    }

    /**
     * Get the category for this request.
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(ServiceCategory::class, 'category_id', 'service_categoryID');
    }

    /**
     * Get the logs for this request.
     */
    public function logs(): HasMany
    {
        return $this->hasMany(RequestLog::class, 'request_id');
    }

    /**
     * Get the review for this request (if any).
     * Explicitly specify foreign key 'request_id'.
     */
    public function review(): HasOne
    {
        return $this->hasOne(Review::class, 'request_id');
    }

    // ============================================================
    // SCOPES
    // ============================================================

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    /**
     * Scope to include all active statuses (from pending to in_progress)
     */
    public function scopeActive($query)
    {
        return $query->whereIn('status', [
            self::STATUS_PENDING,
            self::STATUS_ACCEPTED,
            self::STATUS_ON_THE_WAY,
            self::STATUS_ARRIVED,
            self::STATUS_IN_PROGRESS,
        ]);
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    public function scopeCancelled($query)
    {
        return $query->where('status', self::STATUS_CANCELLED);
    }

    public function scopeRejected($query)
    {
        return $query->where('status', self::STATUS_REJECTED);
    }

    // ============================================================
    // STATUS CHECK HELPERS
    // ============================================================

    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isAccepted(): bool
    {
        return $this->status === self::STATUS_ACCEPTED;
    }

    public function isOnTheWay(): bool
    {
        return $this->status === self::STATUS_ON_THE_WAY;
    }

    public function isArrived(): bool
    {
        return $this->status === self::STATUS_ARRIVED;
    }

    public function isInProgress(): bool
    {
        return $this->status === self::STATUS_IN_PROGRESS;
    }

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isCancelled(): bool
    {
        return $this->status === self::STATUS_CANCELLED;
    }

    public function isRejected(): bool
    {
        return $this->status === self::STATUS_REJECTED;
    }

    /**
     * Check if the request is active (not terminal)
     */
    public function isActive(): bool
    {
        return in_array($this->status, [
            self::STATUS_PENDING,
            self::STATUS_ACCEPTED,
            self::STATUS_ON_THE_WAY,
            self::STATUS_ARRIVED,
            self::STATUS_IN_PROGRESS,
        ]);
    }

    // ============================================================
    // ACCESSORS
    // ============================================================

    public function getServiceWithCategoryAttribute(): string
    {
        $serviceName = $this->service->name ?? 'Unknown Service';
        $categoryName = $this->category->category_name ?? '';
        return $categoryName ? "{$serviceName} ({$categoryName})" : $serviceName;
    }

    public function getNotificationData(): array
    {
        return [
            'id'          => $this->id,
            'description' => $this->description,
            'status'      => $this->status,
            'service'     => [
                'id'   => $this->service_id,
                'name' => $this->service->name ?? null,
            ],
            'category'    => $this->category ? [
                'id'   => $this->category_id,
                'name' => $this->category->category_name,
            ] : null,
            'customer'    => $this->customer ? [
                'id'    => $this->customer->id,
                'name'  => $this->customer->name,
                'email' => $this->customer->email,
            ] : null,
            'technician'  => $this->technician ? [
                'id'   => $this->technician->id,
                'name' => $this->technician->user->name ?? null,
            ] : null,
            'created_at'  => $this->created_at,
        ];
    }
}