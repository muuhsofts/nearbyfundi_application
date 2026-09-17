<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;
use NotificationChannels\Fcm\FcmChannel;
use NotificationChannels\Fcm\FcmMessage;
use NotificationChannels\Fcm\Resources\Notification as FcmNotification;

class NewActivityNotification extends Notification
{
    use Queueable;

    protected string $title;
    protected string $body;
    protected string $type;
    protected int $unreadCount;

    public function __construct(string $title, string $body, string $type = 'general', int $unreadCount = 0)
    {
        // Safety: never allow empty or pure numbers as title/body
        $this->title = (trim($title) !== '' && !is_numeric($title))
            ? trim($title)
            : 'NearbyFundi';

        $this->body = (trim($body) !== '' && !is_numeric($body))
            ? trim($body)
            : 'You have a new update';

        $this->type = $type ?: 'general';
        $this->unreadCount = max(0, $unreadCount);
    }

    public function via($notifiable)
    {
        return [FcmChannel::class, 'database'];
    }

    public function toFcm($notifiable)
    {
        return (new FcmMessage())
            ->setNotification(
                FcmNotification::create()
                    ->setTitle($this->title)
                    ->setBody($this->body)
            )
            ->setData([
                'type'         => $this->type,
                'unread_count' => (string) $this->unreadCount,
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            ]);
    }

    public function toArray($notifiable)
    {
        return [
            'title' => $this->title,
            'body'  => $this->body,
            'type'  => $this->type,
        ];
    }
}