<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Post extends Model
{
    protected $fillable = [
        'technician_id', 
        'title', 
        'content', 
        'image',
        'youtube_url',
        'youtube_embed'
    ];

    // Helper to get YouTube embed URL
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

    // Convert YouTube URL to embed URL
    public function convertToEmbedUrl($url)
    {
        // Handle youtu.be format
        if (strpos($url, 'youtu.be') !== false) {
            $videoId = $this->extractVideoId($url);
            if ($videoId) {
                return "https://www.youtube.com/embed/{$videoId}";
            }
        }
        
        // Handle youtube.com/watch?v= format
        if (strpos($url, 'youtube.com/watch') !== false) {
            parse_str(parse_url($url, PHP_URL_QUERY), $params);
            if (isset($params['v'])) {
                return "https://www.youtube.com/embed/{$params['v']}";
            }
        }
        
        // Handle youtube.com/embed/ format
        if (strpos($url, 'youtube.com/embed') !== false) {
            return $url;
        }
        
        // If it's already an embed URL or we can't parse it, return as is
        return $url;
    }

    private function extractVideoId($url)
    {
        preg_match('/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([^&\n?#]+)/', $url, $matches);
        return $matches[1] ?? null;
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