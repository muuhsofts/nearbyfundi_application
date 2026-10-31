<?php

namespace App\Services;

use App\Models\Notification as NotificationModel;
use App\Models\User;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Exception\Messaging\NotFound;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

class FcmService
{
    public const SILENT_TYPES = ['chat_message'];

    protected $messaging = null;
    protected bool $enabled = false;

    public function __construct()
    {
        $this->enabled = (bool) config('firebase.send_notifications', true);

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
            $this->messaging = (new Factory)->withServiceAccount($credentials)->createMessaging();
            Log::debug('FCM service initialized.');
        } catch (\Throwable $e) {
            Log::error('FCM initialization failed: ' . $e->getMessage());
            $this->messaging = null;
        }
    }

    public function isReady(): bool
    {
        return $this->enabled && $this->messaging !== null;
    }

    // ============================================================
    // PREFERRED ENTRY POINT
    // ============================================================

    public function sendFromNotification(NotificationModel $notification): bool
    {
        $user = $notification->user;

        if (!$user) {
            Log::warning('Notification has no user', ['id' => $notification->id]);
            return false;
        }

        $token = $this->getUserToken($user);
        if (!$token) {
            Log::info('User has no FCM token', ['user_id' => $user->id]);
            return false;
        }

        $title = trim((string) $notification->title);
        $body  = trim((string) $notification->body);

        if (!$this->isValidText($title) || !$this->isValidText($body)) {
            Log::error('Notification row has invalid title/body — push skipped', [
                'id'   => $notification->id,
                'type' => $notification->type,
            ]);
            return false;
        }

        $type = (string) ($notification->type ?? 'general');

        $data = array_merge(
            is_array($notification->data) ? $notification->data : [],
            [
                'type'            => $type,
                'notification_id' => (string) $notification->id,
                'title'           => $title,
                'body'            => $body,
                'click_action'    => 'FLUTTER_NOTIFICATION_CLICK',
            ]
        );

        if (in_array($type, self::SILENT_TYPES, true)) {
            return $this->sendSilentDataToDevice($token, $data);
        }

        return $this->sendVisible($token, $title, $body, $data, $this->unreadCountFor($user));
    }

    // ============================================================
    // SENDERS — kreait/firebase-php v7/v8 API
    // ============================================================

    protected function sendVisible(
        string $deviceToken,
        string $title,
        string $body,
        array $data,
        int $badge
    ): bool {
        if (!$this->ready($deviceToken)) {
            return false;
        }

        $message = CloudMessage::new()
            ->withToken($deviceToken)
            ->withNotification(Notification::create($title, $body))
            ->withAndroidConfig([
                'priority'     => 'high',
                'notification' => [
                    'sound'                   => 'default',
                    'click_action'            => 'FLUTTER_NOTIFICATION_CLICK',
                    'channel_id'              => 'fundi_channel',
                    'notification_priority'   => 'PRIORITY_MAX',
                    'default_vibrate_timings' => true,
                ],
            ])
            ->withApnsConfig([
                'headers' => [
                    'apns-priority'  => '10',
                    'apns-push-type' => 'alert',
                ],
                'payload' => [
                    'aps' => [
                        'alert' => ['title' => $title, 'body' => $body],
                        'sound' => 'default',
                        'badge' => $badge,
                    ],
                ],
            ])
            ->withData($this->sanitizeData($data));

        return $this->dispatch($message, $deviceToken);
    }

    public function sendSilentDataToDevice(string $deviceToken, array $data = []): bool
    {
        if (!$this->ready($deviceToken)) {
            return false;
        }

        $message = CloudMessage::new()
            ->withToken($deviceToken)
            ->withAndroidConfig(['priority' => 'high']) // no 'notification' key → nothing in the tray
            ->withApnsConfig([
                'headers' => [
                    'apns-priority'  => '5',
                    'apns-push-type' => 'background',
                ],
                'payload' => ['aps' => ['content-available' => 1]],
            ])
            ->withData($this->sanitizeData($data));

        return $this->dispatch($message, $deviceToken);
    }

    public function sendChatNotification($receiver, $sender, $message, $conversationId): bool
    {
        if (!$receiver || !$sender || !$message) {
            Log::warning('Missing data for chat notification');
            return false;
        }

        if (!is_object($sender) || !is_object($message)) {
            Log::error('sendChatNotification() requires model objects', [
                'sender_type'  => get_debug_type($sender),
                'message_type' => get_debug_type($message),
            ]);
            return false;
        }

        $token = $this->getUserToken($receiver);
        if (!$token) {
            Log::info("Receiver #{$receiver->id} has no FCM token");
            return false;
        }

        $senderName = trim((string) ($sender->name ?? ''));
        $title      = $senderName !== '' ? $senderName : 'New Message';

        $body = trim($this->getNotificationBody($message));
        if (!$this->isValidText($body)) {
            $body = 'New message';
        }

        $data = [
            'type'            => 'chat_message',
            'title'           => $title,
            'body'            => $body,
            'conversation_id' => (string) $conversationId,
            'message_id'      => (string) ($message->id ?? ''),
            'sender_id'       => (string) ($sender->id ?? ''),
            'sender_name'     => $senderName !== '' ? $senderName : 'Unknown',
            'message_type'    => $message->message_type ?? 'text',
            'unread_count'    => (string) ($this->unreadCountFor($receiver) + 1),
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

    protected function dispatch(CloudMessage $message, string $deviceToken): bool
    {
        try {
            $this->messaging->send($message);
            return true;
        } catch (NotFound $e) {
            // Token is unregistered / app uninstalled — stop using it.
            Log::warning('FCM token is no longer valid — clearing it.');
            User::where('fcm_device_token', $deviceToken)->update(['fcm_device_token' => null]);
            return false;
        } catch (\Throwable $e) {
            Log::error('FCM send failed: ' . $e->getMessage());
            return false;
        }
    }

    protected function ready(string $deviceToken): bool
    {
        return $this->isReady() && $deviceToken !== '';
    }

    protected function isValidText(string $value): bool
    {
        return $value !== '' && !is_numeric($value);
    }

    protected function unreadCountFor($user): int
    {
        try {
            return (int) $user->notifications()
                ->where('is_read', false)
                ->where('type', '!=', 'chat_message')
                ->count();
        } catch (\Throwable $e) {
            return 0;
        }
    }

    protected function sanitizeData(array $data): array
    {
        $sanitized = [];
        foreach ($data as $key => $value) {
            $sanitized[$key] = match (true) {
                $value === null                       => '',
                is_bool($value)                       => $value ? 'true' : 'false',
                is_array($value), is_object($value)   => json_encode($value),
                default                               => (string) $value,
            };
        }
        return $sanitized;
    }

    protected function getUserToken($user): ?string
    {
        if (!$user) return null;
        if (!empty($user->fcm_device_token)) return $user->fcm_device_token;
        if (!empty($user->device_token)) return $user->device_token;

        if (method_exists($user, 'deviceTokens')) {
            $latest = $user->deviceTokens()->latest()->first();
            if ($latest) return $latest->token;
        }

        return null;
    }

    protected function getNotificationBody($message): string
    {
        if (empty($message) || !is_object($message)) {
            return 'New message';
        }

        if (($message->message_type ?? 'text') === 'text') {
            $content = trim((string) ($message->content ?? ''));
            return $content !== '' ? $content : 'New message';
        }

        $labels = [
            'image' => '📷 Image',
            'video' => '🎬 Video',
            'voice' => '🎤 Voice Message',
            'file'  => '📎 File',
        ];

        $label = $labels[$message->message_type] ?? '📎 Attachment';

        if (!empty($message->file_name)) {
            $label .= ': ' . $message->file_name;
        }
        if (!empty($message->content)) {
            $label .= ' - ' . mb_substr($message->content, 0, 50);
        }

        return $label;
    }
}