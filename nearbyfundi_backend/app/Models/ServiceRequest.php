<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

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
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

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
     * Scope a query to only include pending requests.
     */
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    /**
     * Scope a query to only include active requests (pending, accepted, in_progress).
     */
    public function scopeActive($query)
    {
        return $query->whereIn('status', ['pending', 'accepted', 'in_progress']);
    }

    /**
     * Scope a query to only include completed requests.
     */
    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    /**
     * Scope a query to only include cancelled requests.
     */
    public function scopeCancelled($query)
    {
        return $query->where('status', 'cancelled');
    }

    /**
     * Scope a query to only include rejected requests.
     */
    public function scopeRejected($query)
    {
        return $query->where('status', 'rejected');
    }

    /**
     * Check if the request is pending.
     */
    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    /**
     * Check if the request is accepted.
     */
    public function isAccepted(): bool
    {
        return $this->status === 'accepted';
    }

    /**
     * Check if the request is in progress.
     */
    public function isInProgress(): bool
    {
        return $this->status === 'in_progress';
    }

    /**
     * Check if the request is completed.
     */
    public function isCompleted(): bool
    {
        return $this->status === 'completed';
    }

    /**
     * Check if the request is cancelled.
     */
    public function isCancelled(): bool
    {
        return $this->status === 'cancelled';
    }

    /**
     * Check if the request is rejected.
     */
    public function isRejected(): bool
    {
        return $this->status === 'rejected';
    }

    /**
     * Check if the request is active (not completed, cancelled, or rejected).
     */
    public function isActive(): bool
    {
        return in_array($this->status, ['pending', 'accepted', 'in_progress']);
    }

    /**
     * Get the service name with category.
     */
    public function getServiceWithCategoryAttribute(): string
    {
        $serviceName = $this->service->name ?? 'Unknown Service';
        $categoryName = $this->category->category_name ?? '';
        
        return $categoryName ? "{$serviceName} ({$categoryName})" : $serviceName;
    }

    /**
     * Get the request details for notifications.
     */
    public function getNotificationData(): array
    {
        return [
            'id' => $this->id,
            'description' => $this->description,
            'status' => $this->status,
            'service' => [
                'id' => $this->service_id,
                'name' => $this->service->name ?? null,
            ],
            'category' => $this->category ? [
                'id' => $this->category_id,
                'name' => $this->category->category_name,
            ] : null,
            'customer' => $this->customer ? [
                'id' => $this->customer->id,
                'name' => $this->customer->name,
                'email' => $this->customer->email,
            ] : null,
            'technician' => $this->technician ? [
                'id' => $this->technician->id,
                'name' => $this->technician->user->name ?? null,
            ] : null,
            'created_at' => $this->created_at,
        ];
    }
}