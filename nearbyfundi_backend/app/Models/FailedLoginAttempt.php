<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;

class FailedLoginAttempt extends Model
{
    protected $fillable = ['email', 'ip_address', 'attempt_count', 'last_attempt_at'];

    public static function record(string $email, string $ip)
    {
        $attempt = static::where('email', $email)->where('ip_address', $ip)->first();
        if ($attempt) {
            $attempt->increment('attempt_count');
            $attempt->last_attempt_at = Carbon::now();
            $attempt->save();
        } else {
            static::create([
                'email' => $email,
                'ip_address' => $ip,
                'attempt_count' => 1,
                'last_attempt_at' => Carbon::now(),
            ]);
        }
    }
}