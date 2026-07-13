<?php
// app/Models/ServiceRequest.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ServiceRequest extends Model
{
    protected $table = 'requests';
    
    protected $fillable = [
        'customer_id', 'technician_id', 'service_id', 'description', 'status'
    ];

    public function customer()
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    // ✅ FIXED: Use Technician, not XTechnician
    public function technician()
    {
        return $this->belongsTo(Technician::class);
    }

    public function service()
    {
        return $this->belongsTo(Service::class);
    }

    public function logs()
    {
        return $this->hasMany(RequestLog::class, 'request_id');
    }
}