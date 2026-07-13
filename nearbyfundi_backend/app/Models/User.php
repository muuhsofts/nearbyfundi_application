<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;
use Illuminate\Database\Eloquent\SoftDeletes;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, HasRoles, SoftDeletes;

    protected $fillable = [
        'name', 'email', 'password', 'phone', 'status', 'is_active',
        'created_by', 'last_login_ip', 'last_login_at', 'locale', 'email_verified_at'
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'last_login_at' => 'datetime',
        'is_active' => 'boolean',
    ];

    public function getLocaleAttribute($value) { return $value ?: 'en'; }

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


    
    /**
     * Conversations where user is the customer
     */
    public function conversationsAsCustomer()
    {
        return $this->hasMany(Conversation::class, 'customer_id');
    }

    /**
     * Conversations where user is the fundi
     */
    public function conversationsAsFundi()
    {
        return $this->hasMany(Conversation::class, 'fundi_id');
    }

    /**
     * Get all conversations (as either customer or fundi)
     */
    public function allConversations()
    {
        return Conversation::where('customer_id', $this->id)
            ->orWhere('fundi_id', $this->id);
    }

    /**
     * Messages sent by this user
     */
    public function sentMessages()
    {
        return $this->hasMany(Message::class, 'sender_id');
    }

    /**
     * Messages received by this user
     */
    public function receivedMessages()
    {
        return $this->hasMany(Message::class, 'receiver_id');
    }

    /**
     * Get unread message count
     */
    public function getUnreadMessagesCount()
    {
        return Message::where('receiver_id', $this->id)
            ->where('is_read', false)
            ->count();
    }

    /**
     * Get unread messages per conversation
     */
    public function getUnreadPerConversation()
    {
        return Message::where('receiver_id', $this->id)
            ->where('is_read', false)
            ->select('conversation_id', \DB::raw('count(*) as unread_count'))
            ->groupBy('conversation_id')
            ->get();
    }
    // Add this relationship

public function notifications()
{
    return $this->hasMany(Notification::class)->orderBy('created_at', 'desc');
}

public function unreadNotifications()
{
    return $this->hasMany(Notification::class)->where('is_read', false);
}
}