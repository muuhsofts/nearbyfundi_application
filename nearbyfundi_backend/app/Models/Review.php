<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Review extends Model
{
    protected $fillable = [
        'request_id',      // foreign key to service_requests
        'customer_id',     // the user who wrote the review
        'technician_id',
        'rating',
        'comment',
    ];

    protected $casts = [
        'rating' => 'float',
    ];

    // ─── Events ───────────────────────────────────────────────────────

    protected static function booted()
    {
        static::saved(function ($review) {
            $review->technician->recalculateRating();
        });

        static::deleted(function ($review) {
            $review->technician->recalculateRating();
        });
    }

    // ─── Relationships ──────────────────────────────────────────────

    public function technician(): BelongsTo
    {
        return $this->belongsTo(Technician::class);
    }

    // The customer who wrote the review (aliased as 'customer')
    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    // The service request being reviewed
    public function serviceRequest(): BelongsTo
    {
        return $this->belongsTo(ServiceRequest::class, 'request_id');
    }
}