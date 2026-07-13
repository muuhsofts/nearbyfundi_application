<?php
// app/Notifications/PendingRequestAlert.php

namespace App\Notifications;

use App\Models\ServiceRequest;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Messages\BroadcastMessage;
use Illuminate\Notifications\Notification;

class PendingRequestAlert extends Notification implements ShouldQueue
{
    use Queueable;

    protected $serviceRequest;

    public function __construct(ServiceRequest $serviceRequest)
    {
        $this->serviceRequest = $serviceRequest;
    }

    public function via($notifiable)
    {
        return ['mail', 'broadcast', 'database'];
    }

    public function toMail($notifiable)
    {
        $minutes = round($this->serviceRequest->created_at->diffInMinutes(now()));

        return (new MailMessage)
            ->subject('🚨 Pending Request Alert #' . $this->serviceRequest->id)
            ->greeting('Hello ' . $notifiable->name . '!')
            ->line('A service request has been pending for ' . $minutes . ' minutes.')
            ->line('Request Details:')
            ->line('- Customer: ' . ($this->serviceRequest->customer->name ?? 'Unknown'))
            ->line('- Service: ' . ($this->serviceRequest->service->name ?? 'N/A'))
            ->line('- Description: ' . $this->serviceRequest->description)
            ->action('View Request', url('/monitoring/requests/' . $this->serviceRequest->id))
            ->line('Please assign a technician or take appropriate action.');
    }

    public function toBroadcast($notifiable)
    {
        return new BroadcastMessage([
            'type' => 'pending_alert',
            'request_id' => $this->serviceRequest->id,
            'customer_name' => $this->serviceRequest->customer->name ?? 'Unknown',
            'service_name' => $this->serviceRequest->service->name ?? 'N/A',
            'minutes_elapsed' => round($this->serviceRequest->created_at->diffInMinutes(now())),
            'created_at' => $this->serviceRequest->created_at->toIso8601String(),
            'message' => 'Request #' . $this->serviceRequest->id . ' pending for ' . 
                round($this->serviceRequest->created_at->diffInMinutes(now())) . ' minutes',
        ]);
    }

    public function toDatabase($notifiable)
    {
        return [
            'type' => 'pending_alert',
            'request_id' => $this->serviceRequest->id,
            'customer_name' => $this->serviceRequest->customer->name ?? 'Unknown',
            'service_name' => $this->serviceRequest->service->name ?? 'N/A',
            'minutes_elapsed' => round($this->serviceRequest->created_at->diffInMinutes(now())),
            'created_at' => $this->serviceRequest->created_at->toIso8601String(),
        ];
    }
}