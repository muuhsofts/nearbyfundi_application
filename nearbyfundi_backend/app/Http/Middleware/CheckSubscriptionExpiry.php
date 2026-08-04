<?php
// app/Console/Commands/CheckSubscriptionExpiry.php

namespace App\Console\Commands;

use App\Models\Subscription;
use App\Models\User;
use App\Models\Notification;
use Illuminate\Console\Command;
use Carbon\Carbon;

class CheckSubscriptionExpiry extends Command
{
    protected $signature = 'subscriptions:check-expiry';
    protected $description = 'Check and handle subscription expirations';

    public function handle()
    {
        $this->info('Checking for expired subscriptions...');

        // Find active subscriptions that have expired
        $expiredSubscriptions = Subscription::where('status', Subscription::STATUS_ACTIVE)
            ->where('expiry_date', '<=', now())
            ->get();

        $expiredCount = 0;
        $notifiedCount = 0;

        foreach ($expiredSubscriptions as $subscription) {
            // Mark as expired
            $subscription->status = Subscription::STATUS_EXPIRED;
            $subscription->save();

            // Lock the user account
            $user = $subscription->user;
            if ($user) {
                $user->subscription_status = 'expired';
                $user->save();

                // Create notification
                Notification::create([
                    'user_id' => $user->id,
                    'title' => 'Subscription Expired',
                    'body' => "Your {$subscription->rateCard->name} subscription has expired. Please renew to continue.",
                    'type' => 'subscription_expired',
                    'data' => json_encode([
                        'subscription_id' => $subscription->id,
                        'expiry_date' => $subscription->expiry_date,
                        'rate_card' => $subscription->rateCard->name,
                    ]),
                    'is_read' => false,
                ]);

                $expiredCount++;
                $this->info("User {$user->email} subscription expired and account locked.");
            }
        }

        // Check for subscriptions expiring in 3 days (send reminder)
        $soonExpiring = Subscription::where('status', Subscription::STATUS_ACTIVE)
            ->whereBetween('expiry_date', [now(), now()->addDays(3)])
            ->get();

        foreach ($soonExpiring as $subscription) {
            $user = $subscription->user;
            if ($user) {
                // Check if already notified (within last 24 hours)
                $existing = Notification::where('user_id', $user->id)
                    ->where('type', 'subscription_expiring_soon')
                    ->where('created_at', '>', now()->subDay())
                    ->first();

                if (!$existing) {
                    Notification::create([
                        'user_id' => $user->id,
                        'title' => 'Subscription Expiring Soon ⏰',
                        'body' => "Your {$subscription->rateCard->name} subscription will expire on {$subscription->expiry_date->format('M d, Y')}. Please renew.",
                        'type' => 'subscription_expiring_soon',
                        'data' => json_encode([
                            'subscription_id' => $subscription->id,
                            'expiry_date' => $subscription->expiry_date,
                            'days_remaining' => now()->diffInDays($subscription->expiry_date),
                            'rate_card' => $subscription->rateCard->name,
                        ]),
                        'is_read' => false,
                    ]);
                    $notifiedCount++;
                }
            }
        }

        $this->info("Subscription expiry check completed.");
        $this->info("Expired: {$expiredCount} | Reminders sent: {$notifiedCount}");
    }
}