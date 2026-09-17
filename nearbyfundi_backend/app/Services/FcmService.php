<?php

namespace App\Services;

use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Illuminate\Support\Facades\Log;

class FcmService
{
    protected $messaging = null;
    protected bool $enabled = false;

    public function __construct()
    {
        $this->enabled = (bool) config('firebase.send_notifications', false);

        if (!$this->enabled) {
            Log::debug('FCM notifications disabled in config.');
            return;
        }

        $credentialsPath = config('firebase.credentials');

        if (!$credentialsPath) {
            Log::warning('FCM credentials path not set in config.');
            return;
        }

        $credentials = str_starts_with($credentialsPath, '/')
            ? $credentialsPath
            : storage_path('app/' . $credentialsPath);

        if (!file_exists($credentials)) {
            Log::warning("FCM credentials file not found at: {$credentials}");
            return;
        }

        try {
            $factory = (new Factory)->withServiceAccount($credentials);
            $this->messaging = $factory->createMessaging();
            Log::info('FCM service initialized successfully.');
        } catch (\Exception $e) {
            Log::error('FCM initialization failed: ' . $e->getMessage());
            $this->messaging = null;
        }
    }

    // ============================================================
    // PUBLIC METHODS
    // ============================================================

    /**
     * Send notification to a User model (looks up the device token automatically)
     * Used by RequestController and other places.
     */
    public function sendToUser($user, string $title, string $body, array $data = []): bool
    {
        $token = $this->getUserToken($user);

        if (!$token) {
            Log::info('User has no FCM token', ['user_id' => $user->id ?? null]);
            return false;
        }

        return $this->sendToDevice($token, $title, $body, $data);
    }

    /**
     * Send standard notification with System Tray Popup
     * (Used for non-chat alerts: requests, approvals, etc.)
     */
    public function sendToDevice(string $deviceToken, string $title, string $body, array $data = []): bool
    {
        if (!$this->enabled || !$this->messaging || empty($deviceToken)) {
            return false;
        }

        // Never allow empty or pure numbers as title/body
        $cleanTitle = $this->sanitizeText($title, 'NearbyFundi');
        $cleanBody  = $this->sanitizeText($body, 'You have a new update');

        try {
            $notification = Notification::create($cleanTitle, $cleanBody);

            $message = CloudMessage::new()
                ->withToken($deviceToken)
                ->withNotification($notification)
                ->withData($this->sanitizeData($data));

            $this->messaging->send($message);
            return true;
        } catch (\Exception $e) {
            Log::error('FCM send failed: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Send DATA-ONLY message (no system tray popup)
     * Used for silent badge updates and chat messages.
     */
    public function sendSilentDataToDevice(string $deviceToken, array $data = []): bool
    {
        if (!$this->enabled || !$this->messaging || empty($deviceToken)) {
            return false;
        }

        try {
            $message = CloudMessage::new()
                ->withToken($deviceToken)
                ->withData($this->sanitizeData($data));

            $this->messaging->send($message);
            Log::info('Silent FCM data message sent successfully');
            return true;
        } catch (\Exception $e) {
            Log::error('Silent FCM send failed: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Send Chat Notification (Silent / Data-Only – no system tray)
     */
    public function sendChatNotification($receiver, $sender, $message, $conversationId): bool
    {
        if (!$receiver || !$sender || !$message) {
            Log::warning('Missing data for chat notification');
            return false;
        }

        $token = $this->getUserToken($receiver);
        if (!$token) {
            Log::info("Receiver #{$receiver->id} has no FCM token");
            return false;
        }

        // Unread count for badge (you can later exclude chat if needed)
        $unreadCount = $receiver->notifications()
            ->where('is_read', false)
            ->count();

        $data = [
            'type'            => 'chat_message',
            'title'           => $sender->name ?? 'New Message',
            'body'            => $this->getNotificationBody($message),
            'conversation_id' => (string) $conversationId,
            'message_id'      => (string) ($message->id ?? ''),
            'sender_id'       => (string) $sender->id,
            'sender_name'     => $sender->name ?? 'Unknown',
            'message_type'    => $message->message_type ?? 'text',
            'unread_count'    => (string) ($unreadCount + 1),
            'timestamp'       => now()->toIso8601String(),
            'priority'        => 'high',
        ];

        if (!empty($message->file_path)) {
            $data['file_url']  = asset('storage/' . $message->file_path);
            $data['file_name'] = $message->file_name ?? 'attachment';
            $data['file_type'] = $message->file_mime_type ?? 'unknown';
        }

        return $this->sendSilentDataToDevice($token, $data);
    }

    // ============================================================
    // HELPERS
    // ============================================================

    /**
     * Sanitize title/body – never empty, never pure number
     */
    protected function sanitizeText(?string $value, string $fallback): string
    {
        $text = trim((string) $value);

        if ($text === '' || is_numeric($text)) {
            return $fallback;
        }

        return $text;
    }

    /**
     * Convert any payload values to strings (FCM requirement)
     */
    protected function sanitizeData(array $data): array
    {
        $sanitized = [];

        foreach ($data as $key => $value) {
            if ($value === null) {
                $sanitized[$key] = '';
            } elseif (is_int($value) || is_float($value)) {
                $sanitized[$key] = (string) $value;
            } elseif (is_bool($value)) {
                $sanitized[$key] = $value ? 'true' : 'false';
            } elseif (is_array($value) || is_object($value)) {
                $sanitized[$key] = json_encode($value);
            } else {
                $sanitized[$key] = (string) $value;
            }
        }

        return $sanitized;
    }

    /**
     * Resolve the device token from a user model
     */
    protected function getUserToken($user): ?string
    {
        if (!$user) {
            return null;
        }

        if (!empty($user->fcm_device_token)) {
            return $user->fcm_device_token;
        }

        if (!empty($user->device_token)) {
            return $user->device_token;
        }

        if (method_exists($user, 'deviceTokens') && $user->deviceTokens) {
            $latest = $user->deviceTokens()->latest()->first();
            if ($latest) {
                return $latest->token;
            }
        }

        return null;
    }

    /**
     * Build a readable body for chat messages
     */
    protected function getNotificationBody($message): string
    {
        if (empty($message)) {
            return 'New message';
        }

        if (isset($message->message_type) && $message->message_type === 'text') {
            $content = trim((string) ($message->content ?? ''));
            return $content !== '' ? $content : 'New message';
        }

        $fileTypeMap = [
            'image' => '📷 Image',
            'video' => '🎬 Video',
            'voice' => '🎤 Voice Message',
            'file'  => '📎 File',
        ];

        $type = $fileTypeMap[$message->message_type ?? 'file'] ?? '📎 Attachment';

        if (!empty($message->file_name)) {
            $type .= ': ' . $message->file_name;
        }

        if (!empty($message->content)) {
            $type .= ' - ' . substr($message->content, 0, 50);
        }

        return $type;
    }
}