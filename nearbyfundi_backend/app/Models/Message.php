<?php
// app/Models/Message.php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class Message extends Model
{
    use HasFactory;

    const TYPE_TEXT = 'text';
    const TYPE_IMAGE = 'image';
    const TYPE_FILE = 'file';
    const TYPE_VOICE = 'voice';
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
        'voice_duration',
        'thumbnail_path',
    ];

    protected $casts = [
        'is_read' => 'boolean',
        'is_delivered' => 'boolean',
        'read_at' => 'datetime',
        'delivered_at' => 'datetime',
        'file_size' => 'integer',
        'voice_duration' => 'integer',
    ];

    // ============ RELATIONSHIPS ============
    
    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function receiver()
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    public function reactions()
    {
        return $this->hasMany(MessageReaction::class);
    }

    // ============ ACCESSORS ============
    
    public function getFileUrlAttribute()
    {
        if ($this->file_path) {
            return asset('storage/' . $this->file_path);
        }
        return null;
    }

    public function getThumbnailUrlAttribute()
    {
        if ($this->thumbnail_path) {
            return asset('storage/' . $this->thumbnail_path);
        }
        return null;
    }

    public function getFileSizeFormattedAttribute()
    {
        if (!$this->file_size) return null;
        
        $units = ['B', 'KB', 'MB', 'GB'];
        $i = 0;
        while ($this->file_size >= 1024 && $i < count($units) - 1) {
            $this->file_size /= 1024;
            $i++;
        }
        return round($this->file_size, 2) . ' ' . $units[$i];
    }

    public function getIsImageAttribute()
    {
        return in_array($this->file_mime_type, ['image/jpeg', 'image/png', 'image/gif', 'image/webp']);
    }

    public function getIsVideoAttribute()
    {
        return in_array($this->file_mime_type, ['video/mp4', 'video/webm', 'video/ogg']);
    }

    public function getIsAudioAttribute()
    {
        return in_array($this->file_mime_type, ['audio/mpeg', 'audio/ogg', 'audio/wav']);
    }

    public function getIsPdfAttribute()
    {
        return $this->file_mime_type === 'application/pdf';
    }

    public function getIsExcelAttribute()
    {
        return in_array($this->file_mime_type, [
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ]);
    }

    public function getIsWordAttribute()
    {
        return in_array($this->file_mime_type, [
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        ]);
    }

    public function getFileIconAttribute()
    {
        if ($this->is_image) return 'image';
        if ($this->is_video) return 'video';
        if ($this->is_audio) return 'audio';
        if ($this->is_pdf) return 'pdf';
        if ($this->is_excel) return 'excel';
        if ($this->is_word) return 'word';
        return 'file';
    }

    // ============ HELPERS ============
    
    public function markAsRead()
    {
        if (!$this->is_read) {
            $this->update([
                'is_read' => true,
                'read_at' => now(),
            ]);
        }
    }

    public function markAsDelivered()
    {
        if (!$this->is_delivered) {
            $this->update([
                'is_delivered' => true,
                'delivered_at' => now(),
            ]);
        }
    }

    public function getFormattedMessage()
    {
        $data = [
            'id' => $this->id,
            'conversation_id' => $this->conversation_id,
            'sender_id' => $this->sender_id,
            'sender_name' => $this->sender->name ?? 'Unknown',
            'sender_type' => $this->sender_type,
            'receiver_id' => $this->receiver_id,
            'message_type' => $this->message_type,
            'content' => $this->content,
            'is_read' => $this->is_read,
            'read_at' => $this->read_at?->toDateTimeString(),
            'is_delivered' => $this->is_delivered,
            'delivered_at' => $this->delivered_at?->toDateTimeString(),
            'created_at' => $this->created_at->toDateTimeString(),
            'created_at_formatted' => $this->created_at->diffForHumans(),
        ];

        // Add file info if exists
        if ($this->file_path) {
            $data['file'] = [
                'url' => $this->file_url,
                'name' => $this->file_name,
                'size' => $this->file_size,
                'size_formatted' => $this->file_size_formatted,
                'mime_type' => $this->file_mime_type,
                'extension' => $this->file_extension,
                'icon' => $this->file_icon,
                'thumbnail_url' => $this->thumbnail_url,
                'is_image' => $this->is_image,
                'is_video' => $this->is_video,
                'is_audio' => $this->is_audio,
                'is_pdf' => $this->is_pdf,
                'is_excel' => $this->is_excel,
                'is_word' => $this->is_word,
            ];
        }

        // Add voice duration
        if ($this->message_type === 'voice' && $this->voice_duration) {
            $data['voice_duration'] = $this->voice_duration;
            $data['voice_duration_formatted'] = $this->formatDuration($this->voice_duration);
        }

        return $data;
    }

    private function formatDuration($seconds)
    {
        $minutes = floor($seconds / 60);
        $remainingSeconds = $seconds % 60;
        return sprintf('%02d:%02d', $minutes, $remainingSeconds);
    }

    // ============ SCOPES ============
    
    public function scopeUnread($query)
    {
        return $query->where('is_read', false);
    }

    public function scopeForUser($query, $userId)
    {
        return $query->where(function($q) use ($userId) {
            $q->where('sender_id', $userId)
              ->orWhere('receiver_id', $userId);
        });
    }

    public function scopeType($query, $type)
    {
        return $query->where('message_type', $type);
    }
}