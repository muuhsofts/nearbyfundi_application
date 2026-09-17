<?php

namespace App\Http\Controllers\Api;

use App\Models\Notification;
use App\Traits\Auditable;
use Illuminate\Http\Request;

class NotificationController extends BaseApiController
{
    use Auditable;

    /**
     * Get notifications for the authenticated user
     */
    public function index(Request $request)
    {
        $query = $request->user()->notifications();

        if ($request->has('exclude_type')) {
            $query->excludeType($request->query('exclude_type'));
        }

        if ($request->has('type')) {
            $query->type($request->query('type'));
        }

        $paginator = $query->latest()->paginate($request->get('per_page', 20));

        // Transform collection – guarantee clean title/body (no numbers, no empty)
        $paginator->getCollection()->transform(function ($notification) {
            $dataPayload = $notification->data;
            if (is_string($dataPayload)) {
                $decoded = json_decode($dataPayload, true);
                $dataPayload = json_last_error() === JSON_ERROR_NONE ? $decoded : $dataPayload;
            }

            $rawTitle = trim((string) ($notification->title ?? ''));
            $rawBody  = trim((string) ($notification->body ?? ''));

            $title = ($rawTitle !== '' && !is_numeric($rawTitle))
                ? $rawTitle
                : 'NearbyFundi';

            $body = ($rawBody !== '' && !is_numeric($rawBody))
                ? $rawBody
                : 'You have a new update';

            return [
                'id'         => (string) $notification->id,
                'user_id'    => (string) $notification->user_id,
                'title'      => $title,
                'body'       => $body,
                'type'       => (string) ($notification->type ?? 'general'),
                'data'       => $dataPayload ?? [],
                'is_read'    => (bool) $notification->is_read,
                'read_at'    => $notification->read_at ? $notification->read_at->toIso8601String() : null,
                'created_at' => $notification->created_at ? $notification->created_at->toIso8601String() : null,
                'updated_at' => $notification->updated_at ? $notification->updated_at->toIso8601String() : null,
            ];
        });

        return $this->successResponse($paginator, 'Notifications retrieved successfully.');
    }

    /**
     * Get unread notification count
     */
    public function unreadCount(Request $request)
    {
        $query = $request->user()->notifications()->unread();

        if ($request->has('exclude_type')) {
            $query->excludeType($request->query('exclude_type'));
        }

        $count = $query->count();

        return $this->successResponse(['count' => (int) $count], 'Unread count retrieved.');
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

        return $this->successResponse([
            'id'      => (string) $notification->id,
            'is_read' => true,
            'read_at' => $notification->read_at
                ? $notification->read_at->toIso8601String()
                : now()->toIso8601String(),
        ], 'Notification marked as read.');
    }

    /**
     * Mark all notifications as read
     */
    public function markAllAsRead(Request $request)
    {
        $query = $request->user()->notifications()->unread();

        if ($request->has('exclude_type')) {
            $query->excludeType($request->query('exclude_type'));
        }

        $count = $query->update([
            'is_read' => true,
            'read_at' => now(),
        ]);

        $this->logAudit('mark_all_notifications_read', 'notification', null, "All notifications marked as read ({$count} updated)");

        return $this->successResponse(['updated_count' => (int) $count], 'All notifications marked as read.');
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
        $query = $request->user()->notifications();

        if ($request->has('exclude_type')) {
            $query->excludeType($request->query('exclude_type'));
        }

        $count = $query->delete();

        $this->logAudit('clear_all_notifications', 'notification', null, "All notifications cleared ({$count} deleted)");

        return $this->successResponse(['deleted_count' => (int) $count], 'All notifications cleared.');
    }
}