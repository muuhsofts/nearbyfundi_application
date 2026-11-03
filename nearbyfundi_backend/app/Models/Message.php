<?php
// app/Models/Message.php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Message extends Model
{
    use HasFactory;

    const TYPE_TEXT  = 'text';
    const TYPE_IMAGE = 'image';
    const TYPE_FILE  = 'file';
    const TYPE_VIDEO = 'video';

    protected $fillable = [
        'conversation_id',
        'sender_id',
        'receiver_id',
        'sender_type',
        'message_type',
        'content',
        'file_name',
        'file_path',
        'file_size',
        'file_mime_type',
        'file_extension',
        'is_read',
        'read_at',
        'is_delivered',
        'delivered_at',
        'reply_to_id',
        'is_forwarded',
        'meta_updated_at',
    ];

    protected $casts = [
        'is_read'         => 'boolean',
        'is_delivered'    => 'boolean',
        'is_forwarded'    => 'boolean',
        'read_at'         => 'datetime',
        'delivered_at'    => 'datetime',
        'meta_updated_at' => 'datetime',
        'file_size'       => 'integer',
    ];

    // ── Relationships ─────────────────────────────────────
    public function conversation() { return $this->belongsTo(Conversation::class); }
    public function sender()       { return $this->belongsTo(User::class, 'sender_id'); }
    public function receiver()     { return $this->belongsTo(User::class, 'receiver_id'); }
    public function reactions()    { return $this->hasMany(MessageReaction::class); }
    public function stars()        { return $this->hasMany(MessageStar::class); }
    public function pin()          { return $this->hasOne(MessagePin::class); }

    public function replyTo(): BelongsTo
    {
        return $this->belongsTo(self::class, 'reply_to_id');
    }

    // ── Accessors ─────────────────────────────────────────
    /** Login-protected URL that streams the file (inline view, no public link). */
    public function getFileUrlAttribute(): ?string
    {
        return $this->file_path
            ? url('/api/v14/chat/messages/' . $this->id . '/file')
            : null;
    }

    // ── Helpers ───────────────────────────────────────────
    public function markAsRead(): void
    {
        if (!$this->is_read) {
            $this->update(['is_read' => true, 'read_at' => now()]);
        }
    }

    public function getFormattedMessage(): array
    {
        $data = [
            'id'              => $this->id,
            'conversation_id' => $this->conversation_id,
            'sender_id'       => $this->sender_id,
            'sender_name'     => $this->sender->name ?? 'Unknown',
            'sender_type'     => $this->sender_type,
            'receiver_id'     => $this->receiver_id,
            'message_type'    => $this->message_type,
            'content'         => $this->content,
            'is_read'         => (bool) $this->is_read,
            'is_forwarded'    => (bool) $this->is_forwarded,
            'read_at'         => $this->read_at?->toIso8601String(),
            'created_at'      => $this->created_at?->toIso8601String(),
        ];

        if ($this->file_path) {
            $data['file'] = [
                'url'       => $this->file_url,
                'name'      => $this->file_name,
                'size'      => $this->file_size,
                'mime_type' => $this->file_mime_type,
                'extension' => $this->file_extension,
            ];
        }

        return $data;
    }

    // ── Scopes ────────────────────────────────────────────
    public function scopeUnread($query)
    {
        return $query->where('is_read', false);
    }

    public function scopeForUser($query, $userId)
    {
        return $query->where(function ($q) use ($userId) {
            $q->where('sender_id', $userId)->orWhere('receiver_id', $userId);
        });
    }
}
