<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;
use Illuminate\Database\Eloquent\SoftDeletes;
use Carbon\Carbon;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, HasRoles, SoftDeletes;

    protected $fillable = [
        'name', 'email', 'password', 'phone', 'status', 'is_active',
        'created_by', 'last_login_ip', 'last_login_at', 'locale', 'email_verified_at',
        // ✅ Subscription fields
        'subscription_status', 'subscription_expires_at', 'current_subscription_id'
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'last_login_at' => 'datetime',
        'is_active' => 'boolean',
        'subscription_expires_at' => 'datetime',
        'subscription_status' => 'string',
    ];

    // ============================================================
    // ACCESSORS
    // ============================================================

    public function getLocaleAttribute($value)
    {
        return $value ?: 'en';
    }

    // ============================================================
    // RELATIONSHIPS
    // ============================================================

    public function technician()
    {
        return $this->hasOne(Technician::class);
    }

    public function customerRequests()
    {
        return $this->hasMany(ServiceRequest::class, 'customer_id');
    }

    public function comments()
    {
        return $this->hasMany(Comment::class);
    }

    public function likes()
    {
        return $this->hasMany(Like::class);
    }

    public function sessions()
    {
        return $this->hasMany(UserSession::class);
    }

    public function auditTrails()
    {
        return $this->hasMany(AuditTrail::class);
    }

    // ============================================================
    // CHAT RELATIONSHIPS
    // ============================================================

    public function conversationsAsCustomer()
    {
        return $this->hasMany(Conversation::class, 'customer_id');
    }

    public function conversationsAsFundi()
    {
        return $this->hasMany(Conversation::class, 'fundi_id');
    }

    public function allConversations()
    {
        return Conversation::where('customer_id', $this->id)
            ->orWhere('fundi_id', $this->id);
    }

    public function sentMessages()
    {
        return $this->hasMany(Message::class, 'sender_id');
    }

    public function receivedMessages()
    {
        return $this->hasMany(Message::class, 'receiver_id');
    }

    public function getUnreadMessagesCount()
    {
        return Message::where('receiver_id', $this->id)
            ->where('is_read', false)
            ->count();
    }

    public function getUnreadPerConversation()
    {
        return Message::where('receiver_id', $this->id)
            ->where('is_read', false)
            ->select('conversation_id', \DB::raw('count(*) as unread_count'))
            ->groupBy('conversation_id')
            ->get();
    }

    // ============================================================
    // NOTIFICATION RELATIONSHIPS
    // ============================================================

    public function notifications()
    {
        return $this->hasMany(Notification::class)->orderBy('created_at', 'desc');
    }

    public function unreadNotifications()
    {
        return $this->hasMany(Notification::class)->where('is_read', false);
    }

    // ============================================================
    // SUBSCRIPTION RELATIONSHIPS - FIXED
    // ============================================================

    public function subscriptions()
    {
        return $this->hasMany(Subscription::class)->orderBy('created_at', 'desc');
    }

    public function activeSubscription()
    {
        return $this->hasOne(Subscription::class)
            ->where('status', Subscription::STATUS_ACTIVE)
            ->where(function($q) {
                $q->whereNull('expiry_date')
                  ->orWhere('expiry_date', '>', now());
            })
            ->latest();
    }

    public function currentSubscription()
    {
        return $this->belongsTo(Subscription::class, 'current_subscription_id');
    }

    public function invoices()
    {
        return $this->hasMany(Invoice::class)->orderBy('created_at', 'desc');
    }

    // ============================================================
    // SUBSCRIPTION HELPERS - FIXED
    // ============================================================

    /**
     * ✅ FIXED: Check if user has an active subscription
     * Handles both status check and expiry date check safely
     */
    public function hasActiveSubscription(): bool
    {
        // Check subscription status first
        if ($this->subscription_status !== 'active') {
            return false;
        }

        // If expiry date is null, consider it active
        if ($this->subscription_expires_at === null) {
            return true;
        }

        // Check if expiry date is in the future
        $expiry = $this->subscription_expires_at;
        if ($expiry instanceof \DateTime) {
            return $expiry->isFuture();
        }

        // Fallback: compare timestamps
        try {
            return Carbon::now()->lt($this->subscription_expires_at);
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * ✅ FIXED: Check if user's subscription is expired
     */
    public function isSubscriptionExpired(): bool
    {
        // If status is explicitly expired
        if ($this->subscription_status === 'expired') {
            return true;
        }

        // If expiry date is null, not expired
        if ($this->subscription_expires_at === null) {
            return false;
        }

        // Check if expiry date is in the past
        $expiry = $this->subscription_expires_at;
        if ($expiry instanceof \DateTime) {
            return $expiry->isPast();
        }

        // Fallback: compare timestamps
        try {
            return Carbon::now()->gt($this->subscription_expires_at);
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * ✅ FIXED: Check if user's account is locked
     */
    public function isAccountLocked(): bool
    {
        // If subscription is expired or inactive
        if ($this->subscription_status === 'expired' || $this->subscription_status === 'inactive') {
            return true;
        }

        // If active but expired
        if ($this->subscription_status === 'active' && $this->subscription_expires_at !== null) {
            try {
                return Carbon::now()->gt($this->subscription_expires_at);
            } catch (\Exception $e) {
                return false;
            }
        }

        return false;
    }

    /**
     * ✅ FIXED: Lock user account
     */
    public function lockAccount(): void
    {
        $this->subscription_status = 'expired';
        $this->save();
    }

    /**
     * ✅ FIXED: Activate user account with subscription
     */
    public function activateSubscription(Subscription $subscription): void
    {
        $this->subscription_status = 'active';
        $this->subscription_expires_at = $subscription->expiry_date;
        $this->current_subscription_id = $subscription->id;
        $this->save();
    }

    /**
     * ✅ FIXED: Check if user has valid subscription
     */
    public function hasValidSubscription(): bool
    {
        if (!$this->hasActiveSubscription()) {
            return false;
        }

        if ($this->subscription_expires_at === null) {
            return true;
        }

        try {
            return Carbon::now()->lt($this->subscription_expires_at);
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * ✅ NEW: Get days remaining for subscription
     */
    public function getSubscriptionDaysRemaining(): ?int
    {
        if ($this->subscription_expires_at === null) {
            return null;
        }

        try {
            $now = Carbon::now();
            $expiry = Carbon::parse($this->subscription_expires_at);
            $diff = $now->diffInDays($expiry, false);
            return $diff < 0 ? 0 : $diff;
        } catch (\Exception $e) {
            return null;
        }
    }

    /**
     * ✅ NEW: Get formatted expiry date
     */
    public function getFormattedExpiryDate(): ?string
    {
        if ($this->subscription_expires_at === null) {
            return null;
        }

        try {
            return Carbon::parse($this->subscription_expires_at)->format('M d, Y');
        } catch (\Exception $e) {
            return null;
        }
    }
}