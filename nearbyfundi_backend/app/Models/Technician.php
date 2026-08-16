<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;

class Technician extends Model
{
    protected $fillable = [
        'user_id', 'profile_photo', 'bio', 'nida', 'experience', 'rating',
        'latitude', 'longitude', 'area', 'verified',
        'last_activity_at', 'is_online', 'hourly_rate',
        'location_updated_at',
        // FOR 4-STEP REGISTRATION
        'verification_status',
        'id_document_type',
        'id_document_image',
        'completed_jobs_count',
        'registration_step',
        'registration_completed',
    ];

    protected $casts = [
        'verified'            => 'boolean',
        'rating'              => 'float',
        'is_online'           => 'boolean',
        'last_activity_at'    => 'datetime',
        'location_updated_at' => 'datetime',
        'hourly_rate'         => 'decimal:2',
        'completed_jobs_count'=> 'integer',
        'registration_completed' => 'boolean',
    ];

    protected $hidden = [
        'nida', // sensitive — hidden from public JSON
    ];

    // ─── Relationships ──────────────────────────────────────────────
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

    // ─── Heartbeat (kept — used by nearby search / monitoring) ──────
    // NOTE: getComputedOnlineAttribute() + ONLINE_THRESHOLD_MINUTES
    // removed — they were never appended to JSON output, so nothing
    // in the app was actually reading them. Raw `is_online` still
    // drives the profile screen's badge (now removed client-side)
    // and remains available for admin monitoring / nearby search,
    // which likely depend on it directly.
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

    // ─── Rating Recalculation ──────────────────────────────────────
    public function recalculateRating(): void
    {
        $avg = $this->reviews()->avg('rating') ?? 0.0;
        $this->rating = round($avg, 1);
        $this->save();
    }

    public function incrementCompletedJobs(): void
    {
        $this->increment('completed_jobs_count');
    }

    // ─── Accessors ──────────────────────────────────────────────────
    public function getDisplayNameAttribute(): string
    {
        return $this->user->name ?? 'Unknown Technician';
    }
}