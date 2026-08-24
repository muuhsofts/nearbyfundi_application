<?php
// app/Http/Controllers/Api/ChatController.php

namespace App\Http\Controllers\Api;

use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use App\Models\MessageReaction;
use App\Models\Notification;
use App\Events\NewMessage;
use App\Events\MessageRead;
use App\Events\UserTyping;
use App\Services\FcmService;
use App\Traits\Auditable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class ChatController extends BaseApiController
{
    use Auditable;

    // Allowed file types (SVG removed – XSS risk)
    const ALLOWED_IMAGE_TYPES = [
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
    ];

    const ALLOWED_DOCUMENT_TYPES = [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/plain',
        'application/rtf',
    ];

    const ALLOWED_AUDIO_TYPES = [
        'audio/mpeg',
        'audio/ogg',
        'audio/wav',
        'audio/webm',
        'audio/mp4',
        'audio/x-m4a',
        'audio/aac',
    ];

    const ALLOWED_VIDEO_TYPES = [
        'video/mp4',
        'video/webm',
        'video/ogg',
    ];

    const ALLOWED_ARCHIVE_TYPES = [
        'application/zip',
        'application/x-rar-compressed',
    ];

    // Aligned with typical mobile + nginx/php limits (15MB)
    const MAX_FILE_SIZE = 15 * 1024 * 1024;

    protected $fcmService;

    public function __construct(FcmService $fcmService)
    {
        $this->fcmService = $fcmService;
    }

    private function createNotification(int $userId, string $title, string $body, string $type, array $data = []): void
    {
        $sanitized = [];
        foreach ($data as $key => $value) {
            if ($value === null) {
                $sanitized[$key] = '';
            } elseif (is_bool($value)) {
                $sanitized[$key] = $value ? 'true' : 'false';
            } elseif (is_array($value) || is_object($value)) {
                $sanitized[$key] = json_encode($value);
            } else {
                $sanitized[$key] = (string) $value;
            }
        }

        Notification::create([
            'user_id' => $userId,
            'title'   => $title,
            'body'    => $body,
            'type'    => $type,
            'data'    => $sanitized,
            'is_read' => false,
        ]);
    }

    /**
     * Get or create conversation – role-bound
     */
    public function getOrCreateConversation(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'customer_id' => 'required|exists:users,id',
            'fundi_id'    => 'required|exists:users,id|different:customer_id',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse($validator->errors()->first(), 422);
        }

        $user = $request->user();

        // Must be a participant
        if ($user->id != $request->customer_id && $user->id != $request->fundi_id) {
            return $this->forbidden('Unauthorized to access this conversation.');
        }

        // Role binding
        if ($user->hasRole('CUSTOMER') && (int) $user->id !== (int) $request->customer_id) {
            return $this->forbidden('Customers can only open chats as the customer.');
        }
        if ($user->hasRole('FUNDI') && (int) $user->id !== (int) $request->fundi_id) {
            return $this->forbidden('Fundis can only open chats as the fundi.');
        }

        $conversation = Conversation::where('customer_id', $request->customer_id)
            ->where('fundi_id', $request->fundi_id)
            ->first();

        if (!$conversation) {
            $conversation = Conversation::create([
                'customer_id'     => $request->customer_id,
                'fundi_id'        => $request->fundi_id,
                'last_message_at' => now(),
            ]);

            $this->logAudit(
                'create_conversation',
                'chat',
                $conversation->id,
                "Conversation created between customer #{$request->customer_id} and fundi #{$request->fundi_id}"
            );
        }

        $conversation->load(['customer', 'fundi']);

        return $this->successResponse($conversation, 'Conversation retrieved.');
    }

    /**
     * Get user conversations – grouped where clause
     */
    public function getConversations(Request $request)
    {
        $user = $request->user();

        $conversations = Conversation::where(function ($q) use ($user) {
                $q->where('customer_id', $user->id)
                  ->orWhere('fundi_id', $user->id);
            })
            ->with(['customer', 'fundi', 'lastMessage'])
            ->withCount(['unreadMessages' => function ($query) use ($user) {
                $query->where('receiver_id', $user->id);
            }])
            ->orderBy('last_message_at', 'desc')
            ->get();

        $conversations->each(function ($conversation) use ($user) {
            $conversation->user_role = $conversation->customer_id == $user->id ? 'customer' : 'fundi';
            $conversation->other_party = $conversation->user_role == 'customer'
                ? $conversation->fundi
                : $conversation->customer;

            if ($conversation->lastMessage) {
                $conversation->last_message_formatted = $conversation->lastMessage->getFormattedMessage();
            }

            unset($conversation->customer, $conversation->fundi, $conversation->lastMessage);
        });

        return $this->successResponse($conversations, 'Conversations retrieved.');
    }

    public function getMessages(Request $request, $conversationId)
    {
        $user = $request->user();
        $conversation = Conversation::find($conversationId);

        if (!$conversation) {
            return $this->notFound('Conversation not found.');
        }

        if ($user->id != $conversation->customer_id && $user->id != $conversation->fundi_id) {
            return $this->forbidden('Unauthorized to view this conversation.');
        }

        $limit  = (int) $request->input('limit', 50);
        $offset = (int) $request->input('offset', 0);

        $messages = Message::where('conversation_id', $conversationId)
            ->with(['sender' => function ($query) {
                $query->select('id', 'name', 'email', 'phone');
            }])
            ->orderBy('created_at', 'desc')
            ->offset($offset)
            ->limit($limit + 1)
            ->get();

        $hasMore  = $messages->count() > $limit;
        $messages = $messages->take($limit)->reverse()->values();

        $formattedMessages = $messages->map(function ($message) {
            return $message->getFormattedMessage();
        });

        $unreadMessages = Message::where('conversation_id', $conversationId)
            ->where('receiver_id', $user->id)
            ->where('is_read', false)
            ->get();

        if ($unreadMessages->isNotEmpty()) {
            foreach ($unreadMessages as $message) {
                $message->markAsRead();
                broadcast(new MessageRead($message->id, $message->sender_id));
            }

            $this->logAudit(
                'read_messages',
                'chat',
                $conversationId,
                "User #{$user->id} read messages in conversation #{$conversationId}"
            );
        }

        return $this->successResponse([
            'messages'            => $formattedMessages,
            'unread_marked_count' => $unreadMessages->count(),
            'total'               => Message::where('conversation_id', $conversationId)->count(),
            'has_more'            => $hasMore,
            'offset'              => $offset,
            'limit'               => $limit,
        ], 'Messages retrieved.');
    }

    public function sendMessage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'conversation_id' => 'required|exists:conversations,id',
            'content'         => 'required_without:file|string|max:5000',
            'file'            => 'nullable|file|max:' . (self::MAX_FILE_SIZE / 1024),
            'message_type'    => 'nullable|in:text,image,file,voice,video',
            'voice_duration'  => 'nullable|integer|min:1|max:300',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse($validator->errors()->first(), 422);
        }

        $user = $request->user();
        $conversation = Conversation::find($request->conversation_id);

        if (!$conversation) {
            return $this->notFound('Conversation not found.');
        }

        if ($user->id != $conversation->customer_id && $user->id != $conversation->fundi_id) {
            return $this->forbidden('Unauthorized to send messages.');
        }

        $senderType = $user->id == $conversation->customer_id ? 'customer' : 'fundi';
        $receiverId = $user->id == $conversation->customer_id
            ? $conversation->fundi_id
            : $conversation->customer_id;

        DB::beginTransaction();
        try {
            $messageData = [
                'conversation_id' => $conversation->id,
                'sender_id'       => $user->id,
                'receiver_id'     => $receiverId,
                'sender_type'     => $senderType,
                'message_type'    => $request->input('message_type', 'text'),
                'content'         => $request->input('content', ''),
                'is_read'         => false,
                'is_delivered'    => false,
            ];

            if ($request->hasFile('file')) {
                $file = $request->file('file');
                $fileInfo = $this->processFileUpload($file);
                $messageData = array_merge($messageData, $fileInfo);

                if (!$request->has('message_type') || $request->message_type == 'text') {
                    $messageData['message_type'] = $this->detectMessageType($file);
                }
            }

            if ($request->filled('voice_duration') && ($messageData['message_type'] ?? '') === 'voice') {
                $messageData['voice_duration'] = (int) $request->voice_duration;
            }

            $message = Message::create($messageData);
            $conversation->update(['last_message_at' => now()]);

            $message->load(['sender' => function ($query) {
                $query->select('id', 'name', 'email', 'phone', 'fcm_device_token');
            }]);

            broadcast(new NewMessage($message, $conversation->id));
            $this->sendPushNotification($message, $conversation);

            $receiver = User::find($receiverId);
            if ($receiver) {
                $sender = $user;
                $notificationBody = $message->content ?? 'You have a new message';

                if ($message->message_type === 'image') {
                    $notificationBody = '📷 Image sent';
                } elseif ($message->message_type === 'file') {
                    $notificationBody = '📎 File sent: ' . ($message->file_name ?? 'attachment');
                } elseif ($message->message_type === 'voice') {
                    $notificationBody = '🎤 Voice message sent';
                } elseif ($message->message_type === 'video') {
                    $notificationBody = '🎬 Video sent';
                }

                $this->createNotification(
                    $receiverId,
                    "New message from {$sender->name}",
                    $notificationBody,
                    'chat_message',
                    [
                        'conversation_id' => $conversation->id,
                        'message_id'      => $message->id,
                        'sender_id'       => $sender->id,
                        'sender_name'     => $sender->name,
                        'message_type'    => $message->message_type,
                    ]
                );
            }

            DB::commit();

            $this->logAudit(
                'send_message',
                'chat',
                $conversation->id,
                "Message sent in conversation #{$conversation->id} by user #{$user->id}"
            );

            return $this->successResponse([
                'message'         => $message->getFormattedMessage(),
                'conversation_id' => $conversation->id,
            ], 'Message sent.');
        } catch (\Exception $e) {
            DB::rollBack();
            \Log::error('Send message error: ' . $e->getMessage());
            return $this->serverError('Failed to send message: ' . $e->getMessage());
        }
    }

    protected function sendPushNotification($message, $conversation)
    {
        try {
            $receiver = User::find($message->receiver_id);

            if (!$receiver || empty($receiver->fcm_device_token)) {
                return;
            }

            $sender = $message->sender;
            $title  = $sender->name ?? 'New Message';
            $body   = $this->getNotificationBody($message);

            $data = [
                'type'            => 'chat_message',
                'conversation_id' => (string) $conversation->id,
                'message_id'      => (string) $message->id,
                'sender_id'       => (string) $sender->id,
                'sender_name'     => $sender->name ?? 'Unknown',
                'message_type'    => $message->message_type,
                'has_attachment'  => !empty($message->file_path) ? 'true' : 'false',
                'timestamp'       => now()->toIso8601String(),
            ];

            if ($message->file_path) {
                $data['file_url']  = asset('storage/' . $message->file_path);
                $data['file_name'] = $message->file_name ?? 'attachment';
                $data['file_type'] = $message->file_mime_type ?? 'unknown';
            }

            $this->fcmService->sendToUser($receiver, $title, $body, $data);
        } catch (\Exception $e) {
            \Log::error('FCM notification error: ' . $e->getMessage());
        }
    }

    protected function getNotificationBody($message)
    {
        if ($message->message_type === 'text') {
            return $message->content ?? 'New message';
        }

        $fileTypeMap = [
            'image' => '📷 Image',
            'video' => '🎬 Video',
            'voice' => '🎤 Voice Message',
            'file'  => '📎 File',
        ];

        $type = $fileTypeMap[$message->message_type] ?? '📎 Attachment';

        if ($message->file_name) {
            $type .= ': ' . $message->file_name;
        }

        if ($message->content) {
            $type .= ' - ' . substr($message->content, 0, 50);
        }

        return $type;
    }

    private function processFileUpload($file)
    {
        $mimeType     = $file->getMimeType();
        $extension    = strtolower($file->getClientOriginalExtension());
        $size         = $file->getSize();
        $originalName = $file->getClientOriginalName();

        $allowedTypes = array_merge(
            self::ALLOWED_IMAGE_TYPES,
            self::ALLOWED_DOCUMENT_TYPES,
            self::ALLOWED_AUDIO_TYPES,
            self::ALLOWED_VIDEO_TYPES,
            self::ALLOWED_ARCHIVE_TYPES
        );

        if (!in_array($mimeType, $allowedTypes)) {
            throw new \Exception('File type not allowed.');
        }

        // Block SVG by extension as well
        if (in_array($extension, ['svg', 'svgz'], true)) {
            throw new \Exception('SVG files are not allowed.');
        }

        if ($size > self::MAX_FILE_SIZE) {
            throw new \Exception('File too large. Max size: ' . (self::MAX_FILE_SIZE / 1024 / 1024) . 'MB');
        }

        $fileName = time() . '_' . Str::random(10) . '.' . $extension;
        $path     = $file->storeAs('chat_files/' . date('Y/m/d'), $fileName, 'public');

        $data = [
            'file_name'      => $originalName,
            'file_path'      => $path,
            'file_size'      => $size,
            'file_mime_type' => $mimeType,
            'file_extension' => $extension,
        ];

        if (in_array($mimeType, self::ALLOWED_IMAGE_TYPES)) {
            $thumbnail = $this->generateThumbnail($file, $path);
            if ($thumbnail) {
                $data['thumbnail_path'] = $thumbnail;
            }
        }

        return $data;
    }

    private function generateThumbnail($file, $path)
    {
        try {
            if (!extension_loaded('gd') && !extension_loaded('imagick')) {
                return null;
            }

            $image    = null;
            $mimeType = $file->getMimeType();

            switch ($mimeType) {
                case 'image/jpeg':
                    $image = imagecreatefromjpeg($file);
                    break;
                case 'image/png':
                    $image = imagecreatefrompng($file);
                    break;
                case 'image/gif':
                    $image = imagecreatefromgif($file);
                    break;
                case 'image/webp':
                    $image = imagecreatefromwebp($file);
                    break;
                default:
                    return null;
            }

            if (!$image) {
                return null;
            }

            $width   = imagesx($image);
            $height  = imagesy($image);
            $maxSize = 200;
            $ratio   = min($maxSize / $width, $maxSize / $height);
            $newWidth  = (int) ($width * $ratio);
            $newHeight = (int) ($height * $ratio);

            $thumbnail = imagecreatetruecolor($newWidth, $newHeight);
            imagecopyresampled($thumbnail, $image, 0, 0, 0, 0, $newWidth, $newHeight, $width, $height);

            $thumbName = 'thumb_' . basename($path);
            $thumbPath = 'chat_files/thumbnails/' . date('Y/m/d') . '/' . $thumbName;
            $fullPath  = storage_path('app/public/' . $thumbPath);

            if (!is_dir(dirname($fullPath))) {
                mkdir(dirname($fullPath), 0755, true);
            }

            imagejpeg($thumbnail, $fullPath, 80);
            imagedestroy($image);
            imagedestroy($thumbnail);

            return $thumbPath;
        } catch (\Exception $e) {
            \Log::error('Thumbnail generation error: ' . $e->getMessage());
            return null;
        }
    }

    private function detectMessageType($file)
    {
        $mimeType = $file->getMimeType();

        if (in_array($mimeType, self::ALLOWED_IMAGE_TYPES)) {
            return 'image';
        }
        if (in_array($mimeType, self::ALLOWED_VIDEO_TYPES)) {
            return 'video';
        }
        if (in_array($mimeType, self::ALLOWED_AUDIO_TYPES)) {
            return 'voice';
        }
        return 'file';
    }

    public function markMessageAsRead(Request $request, $messageId)
    {
        $user    = $request->user();
        $message = Message::find($messageId);

        if (!$message) {
            return $this->notFound('Message not found.');
        }

        if ($message->receiver_id != $user->id) {
            return $this->forbidden('Cannot mark this message as read.');
        }

        if (!$message->is_read) {
            $message->markAsRead();
            broadcast(new MessageRead($message->id, $message->sender_id));

            $this->logAudit(
                'mark_message_read',
                'chat',
                $message->id,
                "Message #{$message->id} marked as read by user #{$user->id}"
            );
        }

        return $this->successResponse([
            'message_id' => $message->id,
            'is_read'    => $message->is_read,
            'read_at'    => $message->read_at?->toDateTimeString(),
        ], 'Message marked as read.');
    }

    public function markConversationAsRead(Request $request, $conversationId)
    {
        $user = $request->user();
        $conversation = Conversation::find($conversationId);

        if (!$conversation) {
            return $this->notFound('Conversation not found.');
        }

        if ($user->id != $conversation->customer_id && $user->id != $conversation->fundi_id) {
            return $this->forbidden('Unauthorized.');
        }

        $unreadMessages = Message::where('conversation_id', $conversationId)
            ->where('receiver_id', $user->id)
            ->where('is_read', false)
            ->get();

        $count = 0;
        if ($unreadMessages->isNotEmpty()) {
            foreach ($unreadMessages as $message) {
                $message->markAsRead();
                broadcast(new MessageRead($message->id, $message->sender_id));
                $count++;
            }

            $this->logAudit(
                'mark_conversation_read',
                'chat',
                $conversationId,
                "User #{$user->id} marked {$count} messages as read in conversation #{$conversationId}"
            );
        }

        return $this->successResponse([
            'conversation_id'   => $conversationId,
            'marked_read_count' => $count,
        ], 'Conversation marked as read.');
    }

    public function getUnreadCount(Request $request)
    {
        $user = $request->user();

        $totalUnread = Message::where('receiver_id', $user->id)
            ->where('is_read', false)
            ->count();

        $perConversation = Message::where('receiver_id', $user->id)
            ->where('is_read', false)
            ->select('conversation_id', \DB::raw('count(*) as count'))
            ->groupBy('conversation_id')
            ->get()
            ->map(function ($item) {
                return [
                    'conversation_id' => $item->conversation_id,
                    'unread_count'    => $item->count,
                ];
            });

        return $this->successResponse([
            'total_unread'     => $totalUnread,
            'per_conversation' => $perConversation,
        ], 'Unread count retrieved.');
    }

    public function deleteMessage(Request $request, $messageId)
    {
        $user    = $request->user();
        $message = Message::find($messageId);

        if (!$message) {
            return $this->notFound('Message not found.');
        }

        if ($message->sender_id != $user->id) {
            return $this->forbidden('Can only delete your own messages.');
        }

        DB::beginTransaction();
        try {
            if ($message->file_path) {
                Storage::disk('public')->delete($message->file_path);
                if ($message->thumbnail_path) {
                    Storage::disk('public')->delete($message->thumbnail_path);
                }
            }

            MessageReaction::where('message_id', $messageId)->delete();
            $conversationId = $message->conversation_id;
            $message->delete();

            $lastMessage = Message::where('conversation_id', $conversationId)
                ->orderBy('created_at', 'desc')
                ->first();

            Conversation::where('id', $conversationId)->update([
                'last_message_at' => $lastMessage?->created_at,
            ]);

            DB::commit();

            $this->logAudit(
                'delete_message',
                'chat',
                $messageId,
                "Message #{$messageId} deleted by user #{$user->id}"
            );

            return $this->successResponse([
                'message_id' => $messageId,
                'deleted'    => true,
            ], 'Message deleted successfully.');
        } catch (\Exception $e) {
            DB::rollBack();
            \Log::error('Delete message error: ' . $e->getMessage());
            return $this->serverError('Failed to delete message: ' . $e->getMessage());
        }
    }

    public function addReaction(Request $request, $messageId)
    {
        $validator = Validator::make($request->all(), [
            'reaction' => 'required|string|max:10',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse($validator->errors()->first(), 422);
        }

        $user    = $request->user();
        $message = Message::find($messageId);

        if (!$message) {
            return $this->notFound('Message not found.');
        }

        $conversation = $message->conversation;
        if ($user->id != $conversation->customer_id && $user->id != $conversation->fundi_id) {
            return $this->forbidden('Cannot react to this message.');
        }

        $reaction = MessageReaction::updateOrCreate(
            [
                'message_id' => $messageId,
                'user_id'    => $user->id,
            ],
            ['reaction' => $request->reaction]
        );

        $this->logAudit(
            'add_reaction',
            'chat',
            $messageId,
            "User #{$user->id} added reaction to message #{$messageId}"
        );

        return $this->successResponse($reaction, 'Reaction added.');
    }

    public function removeReaction(Request $request, $messageId)
    {
        $user = $request->user();

        $deleted = MessageReaction::where('message_id', $messageId)
            ->where('user_id', $user->id)
            ->delete();

        if (!$deleted) {
            return $this->notFound('Reaction not found.');
        }

        $this->logAudit(
            'remove_reaction',
            'chat',
            $messageId,
            "User #{$user->id} removed reaction from message #{$messageId}"
        );

        return $this->successResponse(null, 'Reaction removed.');
    }

    public function downloadFile(Request $request, $messageId)
    {
        $user    = $request->user();
        $message = Message::find($messageId);

        if (!$message || !$message->file_path) {
            return $this->notFound('File not found.');
        }

        $conversation = $message->conversation;
        if ($user->id != $conversation->customer_id && $user->id != $conversation->fundi_id) {
            return $this->forbidden('Unauthorized to download this file.');
        }

        $filePath = storage_path('app/public/' . $message->file_path);

        if (!file_exists($filePath)) {
            return $this->notFound('File not found on server.');
        }

        $this->logAudit(
            'download_file',
            'chat',
            $messageId,
            "File downloaded by user #{$user->id} for message #{$messageId}"
        );

        return response()->download($filePath, $message->file_name, [
            'Content-Type'        => $message->file_mime_type ?? 'application/octet-stream',
            'Cache-Control'       => 'private, max-age=86400',
            'Content-Disposition' => 'attachment; filename="' . $message->file_name . '"',
        ]);
    }

    public function getFileInfo(Request $request, $messageId)
    {
        $user    = $request->user();
        $message = Message::find($messageId);

        if (!$message || !$message->file_path) {
            return $this->notFound('File not found.');
        }

        $conversation = $message->conversation;
        if ($user->id != $conversation->customer_id && $user->id != $conversation->fundi_id) {
            return $this->forbidden('Unauthorized to access this file.');
        }

        return $this->successResponse([
            'message_id'      => $message->id,
            'file_name'       => $message->file_name,
            'file_size'       => $message->file_size,
            'file_mime_type'  => $message->file_mime_type,
            'file_extension'  => $message->file_extension,
            'file_url'        => asset('storage/' . $message->file_path),
            'thumbnail_url'   => $message->thumbnail_path
                ? asset('storage/' . $message->thumbnail_path)
                : null,
            'created_at'      => $message->created_at,
        ], 'File info retrieved.');
    }

    public function deleteFile(Request $request, $messageId)
    {
        $user    = $request->user();
        $message = Message::find($messageId);

        if (!$message) {
            return $this->notFound('Message not found.');
        }

        if ($message->sender_id != $user->id) {
            return $this->forbidden('Can only delete your own files.');
        }

        if (!$message->file_path) {
            return $this->notFound('No file attached to this message.');
        }

        DB::beginTransaction();
        try {
            Storage::disk('public')->delete($message->file_path);
            if ($message->thumbnail_path) {
                Storage::disk('public')->delete($message->thumbnail_path);
            }

            $message->update([
                'file_path'      => null,
                'file_name'      => null,
                'file_size'      => null,
                'file_mime_type' => null,
                'file_extension' => null,
                'thumbnail_path' => null,
                'message_type'   => 'text',
                'content'        => $message->content ?? 'File removed',
            ]);

            DB::commit();

            $this->logAudit(
                'delete_file',
                'chat',
                $messageId,
                "File deleted from message #{$messageId} by user #{$user->id}"
            );

            return $this->successResponse([
                'message_id'   => $messageId,
                'file_deleted' => true,
            ], 'File deleted successfully.');
        } catch (\Exception $e) {
            DB::rollBack();
            \Log::error('Delete file error: ' . $e->getMessage());
            return $this->serverError('Failed to delete file: ' . $e->getMessage());
        }
    }

    public function uploadFile(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'file' => 'required|file|max:' . (self::MAX_FILE_SIZE / 1024),
        ]);

        if ($validator->fails()) {
            return $this->errorResponse($validator->errors()->first(), 422);
        }

        try {
            $fileInfo = $this->processFileUpload($request->file('file'));

            return $this->successResponse([
                'file' => $fileInfo,
                'url'  => asset('storage/' . $fileInfo['file_path']),
            ], 'File uploaded successfully.');
        } catch (\Exception $e) {
            \Log::error('Upload file error: ' . $e->getMessage());
            return $this->serverError('Upload failed: ' . $e->getMessage());
        }
    }

    public function setTypingStatus(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'conversation_id' => 'required|exists:conversations,id',
            'is_typing'       => 'required|boolean',
        ]);

        if ($validator->fails()) {
            return $this->errorResponse($validator->errors()->first(), 422);
        }

        $user           = $request->user();
        $conversationId = $request->conversation_id;

        $conversation = Conversation::find($conversationId);
        if (!$conversation ||
            ($user->id != $conversation->customer_id && $user->id != $conversation->fundi_id)) {
            return $this->forbidden('Unauthorized.');
        }

        \DB::table('user_typing_status')->updateOrInsert(
            [
                'user_id'         => $user->id,
                'conversation_id' => $conversationId,
            ],
            [
                'is_typing'  => $request->is_typing,
                'updated_at' => now(),
            ]
        );

        broadcast(new UserTyping($user->id, $conversationId, $request->is_typing));

        return $this->successResponse(null, 'Typing status updated.');
    }

    public function deleteConversation(Request $request, $conversationId)
    {
        $user = $request->user();
        $conversation = Conversation::find($conversationId);

        if (!$conversation) {
            return $this->notFound('Conversation not found.');
        }

        if ($user->id != $conversation->customer_id && $user->id != $conversation->fundi_id) {
            return $this->forbidden('Unauthorized to delete this conversation.');
        }

        DB::beginTransaction();
        try {
            $messages = Message::where('conversation_id', $conversationId)->get();

            foreach ($messages as $message) {
                if ($message->file_path) {
                    Storage::disk('public')->delete($message->file_path);
                    if ($message->thumbnail_path) {
                        Storage::disk('public')->delete($message->thumbnail_path);
                    }
                }
            }

            Message::where('conversation_id', $conversationId)->delete();
            $conversation->delete();

            DB::commit();

            $this->logAudit(
                'delete_conversation',
                'chat',
                $conversationId,
                "Conversation #{$conversationId} deleted by user #{$user->id}"
            );

            return $this->successResponse([
                'conversation_id' => $conversationId,
                'deleted'         => true,
            ], 'Conversation deleted successfully.');
        } catch (\Exception $e) {
            DB::rollBack();
            \Log::error('Delete conversation error: ' . $e->getMessage());
            return $this->serverError('Failed to delete conversation: ' . $e->getMessage());
        }
    }
}