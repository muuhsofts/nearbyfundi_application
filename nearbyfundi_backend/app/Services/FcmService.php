<?php

namespace App\Services;

use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Firebase\Exception\MessagingException;
use Illuminate\Support\Facades\Log;

class FcmService
{
    protected $messaging;
    protected $enabled;

    public function __construct()
    {
        $this->enabled = config('firebase.send_notifications', false);
        
        if (!$this->enabled) {
            Log::debug('FCM notifications disabled in config.');
            return;
        }

        $credentialsPath = config('firebase.credentials');

        if (!$credentialsPath) {
            Log::warning('FCM credentials path not set in config.');
            return;
        }

        // Check if path is absolute or relative to storage
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
        }
    }

    /**
     * Send notification to a single device
     */
    public function sendToDevice(string $deviceToken, string $title, string $body, array $data = []): bool
    {
        if (!$this->enabled) {
            Log::debug("FCM disabled: would send to device: {$title}");
            return false;
        }

        if (!$this->messaging) {
            Log::error('FCM messaging not initialized.');
            return false;
        }

        if (empty($deviceToken)) {
            Log::warning('Empty device token provided.');
            return false;
        }

        try {
            // Sanitize data - ensure all values are strings
            $sanitizedData = [];
            foreach ($data as $key => $value) {
                if ($value === null) {
                    $sanitizedData[$key] = '';
                } elseif (is_int($value) || is_float($value)) {
                    $sanitizedData[$key] = (string) $value;
                } elseif (is_bool($value)) {
                    $sanitizedData[$key] = $value ? 'true' : 'false';
                } elseif (is_array($value) || is_object($value)) {
                    $sanitizedData[$key] = json_encode($value);
                } else {
                    $sanitizedData[$key] = (string) $value;
                }
            }

            $notification = Notification::create($title, $body);
            
            $message = CloudMessage::new()
                ->withToken($deviceToken)
                ->withNotification($notification)
                ->withData($sanitizedData);

            $this->messaging->send($message);
            
            Log::info("FCM sent successfully", [
                'token' => substr($deviceToken, 0, 10) . '...',
                'title' => $title,
            ]);
            
            return true;
            
        } catch (MessagingException $e) {
            Log::error('FCM messaging error: ' . $e->getMessage(), [
                'token' => substr($deviceToken, 0, 10) . '...',
                'error_code' => $e->getCode(),
            ]);
            return false;
        } catch (\Exception $e) {
            Log::error('FCM send failed: ' . $e->getMessage(), [
                'token' => substr($deviceToken, 0, 10) . '...',
            ]);
            return false;
        }
    }

    /**
     * Send notification to a user
     */
    public function sendToUser($user, string $title, string $body, array $data = []): bool
    {
        if (!$user) {
            Log::warning('Cannot send FCM: user is null');
            return false;
        }

        // Check if user has a device token stored in the user model
        $token = null;
        
        // Try different possible token field names
        if (property_exists($user, 'fcm_device_token') && !empty($user->fcm_device_token)) {
            $token = $user->fcm_device_token;
        } elseif (property_exists($user, 'device_token') && !empty($user->device_token)) {
            $token = $user->device_token;
        } elseif (method_exists($user, 'deviceTokens') && $user->deviceTokens) {
            // If you have a device_tokens relationship
            $latestToken = $user->deviceTokens()->latest()->first();
            if ($latestToken) {
                $token = $latestToken->token;
            }
        }

        if (empty($token)) {
            Log::info("User #{$user->id} has no FCM device token");
            return false;
        }

        // Add user info to data
        $data = array_merge($data, [
            'user_id' => (string) $user->id,
            'user_name' => $user->name ?? 'Unknown',
            'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            'sound' => 'default',
            'priority' => 'high',
        ]);

        return $this->sendToDevice($token, $title, $body, $data);
    }

    /**
     * Send notification to multiple devices
     */
    public function sendToMultipleDevices(array $tokens, string $title, string $body, array $data = []): array
    {
        if (!$this->enabled) {
            Log::debug("FCM disabled: would send to " . count($tokens) . " devices");
            return ['success' => false, 'sent' => 0, 'failed' => count($tokens)];
        }

        if (!$this->messaging) {
            Log::error('FCM messaging not initialized.');
            return ['success' => false, 'sent' => 0, 'failed' => count($tokens)];
        }

        $tokens = array_filter($tokens);
        if (empty($tokens)) {
            return ['success' => false, 'sent' => 0, 'failed' => 0];
        }

        $results = [
            'success' => 0,
            'failed' => 0,
            'errors' => [],
        ];

        foreach ($tokens as $token) {
            try {
                $sent = $this->sendToDevice($token, $title, $body, $data);
                if ($sent) {
                    $results['success']++;
                } else {
                    $results['failed']++;
                }
            } catch (\Exception $e) {
                $results['failed']++;
                $results['errors'][] = [
                    'token' => substr($token, 0, 10) . '...',
                    'error' => $e->getMessage(),
                ];
            }
        }

        return $results;
    }

    /**
     * Send chat notification
     */
    public function sendChatNotification($receiver, $sender, $message, $conversationId): bool
    {
        if (!$receiver || !$sender || !$message) {
            Log::warning('Missing data for chat notification');
            return false;
        }

        $title = $sender->name ?? 'New Message';
        
        // Build body based on message type
        $body = $this->getNotificationBody($message);

        // Build notification data
        $data = [
            'type' => 'chat_message',
            'conversation_id' => (string) $conversationId,
            'message_id' => (string) ($message->id ?? ''),
            'sender_id' => (string) $sender->id,
            'sender_name' => $sender->name ?? 'Unknown',
            'message_type' => $message->message_type ?? 'text',
            'has_attachment' => !empty($message->file_path) ? 'true' : 'false',
            'timestamp' => now()->toIso8601String(),
            'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            'sound' => 'default',
            'priority' => 'high',
        ];

        // Add file info if exists
        if (!empty($message->file_path)) {
            $data['file_url'] = asset('storage/' . $message->file_path);
            $data['file_name'] = $message->file_name ?? 'attachment';
            $data['file_type'] = $message->file_mime_type ?? 'unknown';
        }

        return $this->sendToUser($receiver, $title, $body, $data);
    }

    /**
     * Get notification body based on message type
     */
    protected function getNotificationBody($message): string
    {
        if (empty($message)) {
            return 'New message';
        }

        if (isset($message->message_type) && $message->message_type === 'text') {
            return $message->content ?? 'New message';
        }

        $fileTypeMap = [
            'image' => '📷 Image',
            'video' => '🎬 Video',
            'voice' => '🎤 Voice Message',
            'file' => '📎 File',
        ];

        $type = $fileTypeMap[$message->message_type ?? 'file'] ?? '📎 Attachment';
        
        // For files, show file name if available
        if (!empty($message->file_name)) {
            $type .= ': ' . $message->file_name;
        }

        // If there's content, append it
        if (!empty($message->content)) {
            $type .= ' - ' . substr($message->content, 0, 50);
        }

        return $type;
    }
}