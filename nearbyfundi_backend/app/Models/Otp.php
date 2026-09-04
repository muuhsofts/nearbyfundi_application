<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;
use Illuminate\Support\Str;

class Otp extends Model
{
    protected $fillable = [
        'email', 
        'otp', 
        'type', 
        'name', 
        'token', 
        'ip_address', 
        'user_agent', 
        'expires_at', 
        'is_used'
    ];

    // Match your database enum values
    const TYPE_REGISTRATION = 'registration';
    const TYPE_EMAIL_VERIFICATION = 'email_verification';
    const TYPE_PASSWORD_RESET = 'password_reset';
    const TYPE_PHONE_VERIFICATION = 'phone_verification'; 

    protected $casts = [
        'expires_at' => 'datetime',
        'is_used' => 'boolean',
    ];

    /**
     * Check if OTP is valid (not expired and not used)
     */
    public function isValid(): bool
    {
        return !$this->is_used && $this->expires_at && $this->expires_at->isFuture();
    }

    /**
     * Mark OTP as used
     */
    public function markAsUsed(): void
    {
        $this->is_used = true;
        $this->save();
    }

    /**
     * Get the verification URL for email verification
     */
    public function getVerificationUrl(): string
    {
        $frontendUrl = config('app.frontend_url', 'https://fundi.app');
        return "{$frontendUrl}/verify-email?email=" . urlencode($this->email) . "&token=" . $this->token;
    }

    /**
     * Generate a 6-digit OTP
     */
    public static function generateOtp(): string
    {
        return str_pad((string) random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
    }

    /**
     * Generate a unique token
     */
    public static function generateToken(): string
    {
        return bin2hex(random_bytes(32));
    }

    /**
     * Scope for valid (unused and not expired) OTPs
     */
    public function scopeValid($query)
    {
        return $query->where('is_used', false)
                     ->where('expires_at', '>', Carbon::now());
    }

    /**
     * Scope for specific type
     */
    public function scopeOfType($query, string $type)
    {
        return $query->where('type', $type);
    }

    /**
     * Check if OTP has expired
     */
    public function isExpired(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    /**
     * Get remaining minutes before expiry
     */
    public function getRemainingMinutes(): int
    {
        if (!$this->expires_at || $this->isExpired()) {
            return 0;
        }
        return max(1, (int) now()->diffInMinutes($this->expires_at));
    }

    /**
     * Get human-readable OTP type name
     */
    public function getTypeName(): string
    {
        $types = [
            self::TYPE_REGISTRATION => 'Registration',
            self::TYPE_EMAIL_VERIFICATION => 'Email Verification',
            self::TYPE_PASSWORD_RESET => 'Password Reset',
            self::TYPE_PHONE_VERIFICATION => 'Phone Verification',
        ];
        return $types[$this->type] ?? $this->type;
    }
}