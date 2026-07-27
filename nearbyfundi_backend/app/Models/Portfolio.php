<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Portfolio extends Model
{
    protected $fillable = [
        'technician_id',
        'image',
        'description',
        'instagram',
        'facebook',
        'tiktok',
        'twitter',
        'telegram',
    ];

    public function technician()
    {
        return $this->belongsTo(Technician::class);
    }
}