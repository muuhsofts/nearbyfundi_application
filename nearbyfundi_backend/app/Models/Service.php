<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Service extends Model
{
    protected $fillable = ['name'];

    public function technicians()
    {
        return $this->belongsToMany(Technician::class, 'technician_services');
    }

    public function requests()
    {
        return $this->hasMany(ServiceRequest::class);
    }
}