<?php

namespace App\Http\Controllers\Api;

use App\Models\Notification;
use App\Traits\Auditable;
use Illuminate\Http\Request;

class NotificationController extends BaseApiController
{
    use Auditable;

    /**
     * Get all notifications for the authenticated user
     */
    public function index(Request $request)
    {
        $notifications = $request->user()
            ->notifications()
            ->orderBy('created_at', 'desc')
            ->get();

        return $this->successResponse($notifications, 'Notifications retrieved successfully.');
    }

    /**
     * Get unread notification count
     */
    public function unreadCount(Request $request)
    {
        $count = $request->user()
            ->notifications()
            ->where('is_read', false)
            ->count();

        return $this->successResponse(['count' => $count], 'Unread count retrieved.');
    }

    /**
     * Mark a single notification as read
     */
    public function markAsRead(Request $request, $id)
    {
        $notification = $request->user()
            ->notifications()
            ->where('id', $id)
            ->first();

        if (!$notification) {
            return $this->notFound('Notification not found.');
        }

        $notification->markAsRead();

        $this->logAudit('mark_notification_read', 'notification', $id, "Notification #{$id} marked as read");

        return $this->successResponse($notification, 'Notification marked as read.');
    }

    /**
     * Mark all notifications as read
     */
    public function markAllAsRead(Request $request)
    {
        $count = $request->user()
            ->notifications()
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
            ]);

        $this->logAudit('mark_all_notifications_read', 'notification', null, "All notifications marked as read ({$count} updated)");

        return $this->successResponse(['updated_count' => $count], 'All notifications marked as read.');
    }

    /**
     * Delete a single notification
     */
    public function destroy(Request $request, $id)
    {
        $notification = $request->user()
            ->notifications()
            ->where('id', $id)
            ->first();

        if (!$notification) {
            return $this->notFound('Notification not found.');
        }

        $notification->delete();

        $this->logAudit('delete_notification', 'notification', $id, "Notification #{$id} deleted");

        return $this->successResponse(null, 'Notification deleted.');
    }

    /**
     * Clear all notifications for the user
     */
    public function clearAll(Request $request)
    {
        $count = $request->user()
            ->notifications()
            ->delete();

        $this->logAudit('clear_all_notifications', 'notification', null, "All notifications cleared ({$count} deleted)");

        return $this->successResponse(['deleted_count' => $count], 'All notifications cleared.');
    }
}