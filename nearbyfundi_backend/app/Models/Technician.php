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
    ];

    protected $casts = [
        'verified'            => 'boolean',
        'rating'              => 'float',
        'is_online'           => 'boolean',
        'last_activity_at'    => 'datetime',
        'location_updated_at' => 'datetime',
        'hourly_rate'         => 'decimal:2',
    ];

    protected $hidden = [
        'nida', // sensitive — don't expose in default JSON; admins access via dedicated field selection
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function services()
    {
        return $this->belongsToMany(Service::class, 'technician_services');
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
}