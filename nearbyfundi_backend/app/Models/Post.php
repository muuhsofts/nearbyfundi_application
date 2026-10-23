<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class Post extends Model
{
    protected $fillable = [
        'technician_id',
        'title',
        'content',
        'images',          // ← now an array
        'youtube_url',
        'youtube_embed',
    ];

    protected $casts = [
        'images' => 'array',   // automatically converts JSON ↔ PHP array
    ];

    // Full public URLs for all images (ready for the frontend)
    public function getImageUrlsAttribute(): array
    {
        if (empty($this->images) || !is_array($this->images)) {
            return [];
        }

        return array_map(function ($path) {
            return $path ? url('storage/' . $path) : null;
        }, $this->images);
    }

    // Keep YouTube helpers exactly as they were
    public function getYoutubeEmbedAttribute($value)
    {
        if ($value) {
            return $value;
        }

        if ($this->youtube_url) {
            return $this->convertToEmbedUrl($this->youtube_url);
        }

        return null;
    }

    public function convertToEmbedUrl($url)
    {
        if (strpos($url, 'youtu.be') !== false) {
            $videoId = $this->extractVideoId($url);
            if ($videoId) {
                return "https://www.youtube.com/embed/{$videoId}";
            }
        }

        if (strpos($url, 'youtube.com/watch') !== false) {
            parse_str(parse_url($url, PHP_URL_QUERY), $params);
            if (isset($params['v'])) {
                return "https://www.youtube.com/embed/{$params['v']}";
            }
        }

        if (strpos($url, 'youtube.com/embed') !== false) {
            return $url;
        }

        return $url;
    }

    private function extractVideoId($url)
    {
        preg_match('/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([^&\n?#]+)/', $url, $matches);
        return $matches[1] ?? null;
    }

    // Delete all physical files when the post is deleted
    protected static function booted()
    {
        static::deleting(function (Post $post) {
            if (!empty($post->images) && is_array($post->images)) {
                foreach ($post->images as $path) {
                    if ($path && Storage::disk('public')->exists($path)) {
                        Storage::disk('public')->delete($path);
                    }
                }
            }
        });
    }

    public function technician()
    {
        return $this->belongsTo(Technician::class);
    }

    public function comments()
    {
        return $this->hasMany(Comment::class);
    }

    public function likes()
    {
        return $this->hasMany(Like::class);
    }
}