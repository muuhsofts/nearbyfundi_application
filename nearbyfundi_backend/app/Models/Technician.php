<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Technician extends Model
{
    const ONLINE_THRESHOLD_MINUTES = 3;

    protected $fillable = [
        'user_id', 'profile_photo', 'bio', 'nida', 'experience', 'rating',
        'latitude', 'longitude', 'area', 'verified',
        'last_activity_at', 'is_online', 'hourly_rate',
        'location_updated_at',
        // NEW FIELDS
        'verification_status', 'id_document_type', 'id_document_image',
        'completed_jobs_count',
    ];

    protected $casts = [
        'verified'            => 'boolean',
        'rating'              => 'float',
        'is_online'           => 'boolean',
        'last_activity_at'    => 'datetime',
        'location_updated_at' => 'datetime',
        'hourly_rate'         => 'decimal:2',
        'completed_jobs_count'=> 'integer',
    ];

    protected $hidden = [
        'nida', // sensitive — don't expose in default JSON; admins access via dedicated field selection
    ];

    // ============================================================
    // RELATIONSHIPS
    // ============================================================

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function services()
    {
        return $this->belongsToMany(Service::class, 'technician_services');
    }

    /**
     * Service prices pivot with min/max
     */
    public function servicePrices()
    {
        return $this->belongsToMany(Service::class, 'technician_services')
                    ->withPivot('min_price', 'max_price')
                    ->withTimestamps();
    }

    public function portfolios()
    {
        return $this->hasMany(Portfolio::class);
    }

    public function posts()
    {
        return $this->hasMany(Post::class);
    }

    public function requests()
    {
        return $this->hasMany(ServiceRequest::class);
    }

    public function reviews()
    {
        return $this->hasMany(Review::class);
    }

    public function locationHistory()
    {
        return $this->hasMany(TechnicianLocationHistory::class);
    }

    // ============================================================
    // ONLINE STATUS
    // ============================================================

    public function getComputedOnlineAttribute(): bool
    {
        if (!$this->is_online || !$this->last_activity_at) {
            return false;
        }
        return $this->last_activity_at->gt(now()->subMinutes(self::ONLINE_THRESHOLD_MINUTES));
    }

    public function recordHeartbeat(?float $lat = null, ?float $lng = null): void
    {
        $this->is_online        = true;
        $this->last_activity_at = now();

        if ($lat !== null && $lng !== null) {
            $this->latitude            = $lat;
            $this->longitude           = $lng;
            $this->location_updated_at = now();
        }

        $this->save();
    }

    // ============================================================
    // RATING RECALCULATION (NEW)
    // ============================================================

    /**
     * Recalculate and update the average rating from all reviews.
     */
    public function recalculateRating(): void
    {
        $avg = $this->reviews()->avg('rating') ?? 0.0;
        $this->rating = round($avg, 1);
        $this->save();
    }

    // ============================================================
    // AGGREGATION HELPERS
    // ============================================================

    /**
     * Increment the completed jobs counter (called after a review is added)
     */
    public function incrementCompletedJobs(): void
    {
        $this->increment('completed_jobs_count');
    }

    /**
     * Get average rating from all reviews
     */
    public function getAverageRatingAttribute(): float
    {
        return $this->reviews()->avg('rating') ?? 0.0;
    }

    /**
     * Get the technician's display name (user name)
     */
    public function getDisplayNameAttribute(): string
    {
        return $this->user->name ?? 'Unknown Technician';
    }
}