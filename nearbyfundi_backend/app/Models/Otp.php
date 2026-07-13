<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;

class Otp extends Model
{
    protected $fillable = [
        'email', 'otp', 'type', 'name', 'token', 
        'ip_address', 'user_agent', 'expires_at', 'is_used'
    ];

    // Match your database enum values
    const TYPE_REGISTRATION = 'registration';
    const TYPE_EMAIL_VERIFICATION = 'email_verification';
    const TYPE_PASSWORD_RESET = 'password_reset';

    protected $casts = [
        'expires_at' => 'datetime',
        'is_used' => 'boolean',
    ];

    public function isValid()
    {
        return !$this->is_used && $this->expires_at && $this->expires_at->isFuture();
    }

    public function markAsUsed()
    {
        $this->is_used = true;
        $this->save();
    }

    public function getVerificationUrl()
    {
        return config('app.frontend_url') . '/verify-email?email=' . urlencode($this->email) . '&token=' . $this->token;
    }

    public static function generateOtp()
    {
        return str_pad(random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
    }

    public static function generateToken()
    {
        return bin2hex(random_bytes(32));
    }
}