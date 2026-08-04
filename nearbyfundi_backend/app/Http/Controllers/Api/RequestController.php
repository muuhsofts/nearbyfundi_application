<?php

namespace App\Http\Controllers\Api;

use App\Models\ServiceRequest;
use App\Models\RequestLog;
use App\Models\Notification;
use App\Events\RequestCreated;
use App\Events\RequestStatusUpdated;
use App\Mail\RequestAcceptedMail;
use App\Mail\RequestCreatedMail;
use App\Mail\RequestCompletedMail;
use App\Services\FcmService;
use App\Traits\Auditable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class RequestController extends BaseApiController
{
    use Auditable;

    protected FcmService $fcm;

    public function __construct(FcmService $fcm)
    {
        $this->fcm = $fcm;
    }

    /**
     * Log request actions
     */
    private function logRequestAction(
        int $requestId,
        int $userId,
        string $action,
        ?string $oldStatus,
        string $newStatus,
        ?string $notes = null,
        ?string $ip = null
    ): void {
        try {
            RequestLog::create([
                'request_id'  => $requestId,
                'user_id'     => $userId,
                'action'      => $action,
                'old_status'  => $oldStatus,
                'new_status'  => $newStatus,
                'notes'       => $notes,
                'ip_address'  => $ip ?? request()->ip(),
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to log request action: ' . $e->getMessage(), [
                'request_id' => $requestId,
                'user_id' => $userId,
                'action' => $action,
            ]);
        }
    }

    /**
     * Create notification for user with sanitized data
     */
    private function createNotification(int $userId, string $title, string $body, string $type, array $data = []): void
    {
        try {
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

            Notification::create([
                'user_id' => $userId,
                'title' => $title,
                'body' => $body,
                'type' => $type,
                'data' => $sanitizedData,
                'is_read' => false,
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to create notification: ' . $e->getMessage(), [
                'user_id' => $userId,
                'type' => $type,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Sanitize data for FCM/notification
     */
    private function sanitizeData(array $data): array
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
     * CUSTOMER: Create a new request
     * POST /v4/requests
     */
    public function store(Request $request)
    {
        try {
            $user = $request->user();

            if (!$user || !$user->hasRole('CUSTOMER')) {
                return $this->forbidden('Only customers can create requests.');
            }

            $data = $request->validate([
                'technician_id' => 'required|exists:technicians,id',
                'service_id'    => 'required|exists:services,id',
                'description'   => 'required|string|min:5',
            ]);

            // ✅ FIXED: Allow re-booking after cancellation
            // Check for existing active request (excluding 'cancelled' status)
            $existing = ServiceRequest::where('customer_id', $user->id)
                ->where('technician_id', $data['technician_id'])
                ->whereIn('status', ['pending', 'accepted', 'in_progress'])
                ->first();

            if ($existing) {
                return $this->errorResponse(
                    'You already have an active request with this fundi. Wait for a response or cancel it first.',
                    422
                );
            }

            DB::beginTransaction();

            $serviceRequest = ServiceRequest::create([
                'customer_id'   => $user->id,
                'technician_id' => $data['technician_id'],
                'service_id'    => $data['service_id'],
                'description'   => $data['description'],
                'status'        => 'pending',
            ]);

            $serviceRequest->load(['customer', 'technician.user', 'service']);

            DB::commit();

            // Dispatch event
            try {
                event(new RequestCreated($serviceRequest));
            } catch (\Exception $e) {
                Log::error('Failed to dispatch RequestCreated event: ' . $e->getMessage());
            }

            // Send email notification to technician
            try {
                if ($serviceRequest->technician && 
                    $serviceRequest->technician->user && 
                    $serviceRequest->technician->user->email) {
                    Mail::to($serviceRequest->technician->user->email)
                        ->send(new RequestCreatedMail($serviceRequest));
                }
            } catch (\Exception $e) {
                Log::error('Failed to send request created email: ' . $e->getMessage(), [
                    'request_id' => $serviceRequest->id,
                    'technician_id' => $serviceRequest->technician_id
                ]);
            }

            // Send FCM notification to technician
            try {
                if ($serviceRequest->technician && $serviceRequest->technician->user) {
                    $technicianUser = $serviceRequest->technician->user;
                    
                    $this->fcm->sendToUser(
                        $technicianUser,
                        'New Service Request',
                        "You have a new request for {$serviceRequest->service->name}",
                        $this->sanitizeData([
                            'request_id' => $serviceRequest->id,
                            'type' => 'new_request',
                            'customer_name' => $user->name ?? 'Customer',
                            'service_name' => $serviceRequest->service->name ?? 'Service',
                            'description' => $serviceRequest->description,
                        ])
                    );

                    $this->createNotification(
                        $technicianUser->id,
                        'New Service Request',
                        "You have a new request for {$serviceRequest->service->name} from {$user->name}",
                        'new_request',
                        [
                            'request_id' => $serviceRequest->id,
                            'customer_id' => $user->id,
                            'customer_name' => $user->name,
                            'service_name' => $serviceRequest->service->name,
                            'description' => $serviceRequest->description,
                        ]
                    );
                }
            } catch (\Exception $e) {
                Log::error('Failed to send FCM notification: ' . $e->getMessage(), [
                    'request_id' => $serviceRequest->id,
                    'error' => $e->getMessage()
                ]);
            }

            $this->logRequestAction(
                $serviceRequest->id,
                $user->id,
                'created',
                null,
                'pending',
                "Request created by customer {$user->id}"
            );

            $this->logAudit('create_request', 'request', $serviceRequest->id, "Customer {$user->id} created request");

            return $this->created($serviceRequest, 'Request submitted successfully.');

        } catch (\Illuminate\Validation\ValidationException $e) {
            return $this->validationError($e->errors());
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error creating request: ' . $e->getMessage(), [
                'user_id' => $request->user()->id ?? 'unknown',
                'data' => $request->all()
            ]);
            
            return $this->errorResponse('Failed to create request. Please try again.', 500);
        }
    }

    /**
     * Update request status (FUNDI, CUSTOMER, ADMIN)
     * PATCH /v4/requests/{id}/status
     */
    public function updateStatus(Request $request, $id)
    {
        try {
            $serviceRequest = ServiceRequest::with(['technician.user', 'customer'])->findOrFail($id);
            $user = $request->user();
            $newStatus = $request->status;
            $oldStatus = $serviceRequest->status;

            if (!$user) {
                return $this->forbidden('User not authenticated.');
            }

            $allowed = false;
            
            // Fundi can accept, reject, or complete (if accepted)
            if ($user->hasRole('FUNDI')) {
                if (in_array($newStatus, ['accepted', 'rejected']) && $oldStatus === 'pending') {
                    $allowed = true;
                }
                if ($newStatus === 'completed' && in_array($oldStatus, ['accepted', 'in_progress'])) {
                    $allowed = true;
                }
                if ($newStatus === 'in_progress' && $oldStatus === 'accepted') {
                    $allowed = true;
                }
            } 
            // Customer can cancel only if pending
            elseif ($user->hasRole('CUSTOMER') && $newStatus === 'cancelled' && $oldStatus === 'pending') {
                $allowed = true;
            } 
            // Admin/Manager can change any status (permission-based)
            elseif ($user->can('requests.status.update')) {
                $allowed = true;
            }

            if (!$allowed) {
                return $this->forbidden('Invalid status change. Please check your permissions and the current request status.');
            }

            DB::beginTransaction();

            $serviceRequest->status = $newStatus;
            $serviceRequest->save();

            DB::commit();

            try {
                event(new RequestStatusUpdated($serviceRequest));
            } catch (\Exception $e) {
                Log::error('Failed to dispatch RequestStatusUpdated event: ' . $e->getMessage());
            }

            $this->logRequestAction(
                $serviceRequest->id,
                $user->id,
                $newStatus,
                $oldStatus,
                $newStatus,
                "Status changed from {$oldStatus} to {$newStatus} by " . ($user->hasRole('FUNDI') ? 'fundi' : ($user->hasRole('CUSTOMER') ? 'customer' : 'admin')),
                $request->ip()
            );

            $this->handleStatusChange($serviceRequest, $newStatus);

            $this->logAudit('update_request_status', 'request', $id, "Status changed to {$newStatus}");

            return $this->successResponse($serviceRequest, 'Status updated successfully.');

        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error updating request status: ' . $e->getMessage(), [
                'request_id' => $id,
                'status' => $request->status ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to update status. Please try again.', 500);
        }
    }

    /**
     * Handle status change notifications
     */
    private function handleStatusChange(ServiceRequest $serviceRequest, string $newStatus): void
    {
        try {
            switch ($newStatus) {
                case 'accepted':
                    $this->handleAccepted($serviceRequest);
                    break;
                case 'rejected':
                    $this->handleRejected($serviceRequest);
                    break;
                case 'cancelled':
                    $this->handleCancelled($serviceRequest);
                    break;
                case 'in_progress':
                    $this->handleInProgress($serviceRequest);
                    break;
                case 'completed':
                    $this->handleCompleted($serviceRequest);
                    break;
                default:
                    Log::debug('No notification handler for status: ' . $newStatus);
                    break;
            }
        } catch (\Exception $e) {
            Log::error('Error handling status change: ' . $e->getMessage(), [
                'request_id' => $serviceRequest->id,
                'status' => $newStatus
            ]);
        }
    }

    /**
     * Handle accepted status
     */
    private function handleAccepted(ServiceRequest $serviceRequest): void
    {
        try {
            if ($serviceRequest->customer && $serviceRequest->customer->email) {
                Mail::to($serviceRequest->customer->email)
                    ->send(new RequestAcceptedMail($serviceRequest));
            }
        } catch (\Exception $e) {
            Log::error('Failed to send accepted email: ' . $e->getMessage());
        }

        try {
            if ($serviceRequest->customer) {
                $this->fcm->sendToUser(
                    $serviceRequest->customer,
                    'Request Accepted',
                    "Your request has been accepted by {$serviceRequest->technician->user->name}.",
                    $this->sanitizeData([
                        'request_id' => $serviceRequest->id,
                        'status' => 'accepted',
                        'type' => 'request_accepted',
                        'technician_name' => $serviceRequest->technician->user->name,
                    ])
                );

                $this->createNotification(
                    $serviceRequest->customer_id,
                    'Request Accepted',
                    "Your request has been accepted by {$serviceRequest->technician->user->name}",
                    'request_accepted',
                    [
                        'request_id' => $serviceRequest->id,
                        'technician_id' => $serviceRequest->technician_id,
                        'technician_name' => $serviceRequest->technician->user->name,
                    ]
                );
            }
        } catch (\Exception $e) {
            Log::error('Failed to send accepted notification: ' . $e->getMessage());
        }
    }

    /**
     * Handle rejected status
     */
    private function handleRejected(ServiceRequest $serviceRequest): void
    {
        try {
            if ($serviceRequest->customer) {
                $this->fcm->sendToUser(
                    $serviceRequest->customer,
                    'Request Rejected',
                    "Sorry, your request has been rejected.",
                    $this->sanitizeData([
                        'request_id' => $serviceRequest->id,
                        'status' => 'rejected',
                        'type' => 'request_rejected',
                    ])
                );

                $this->createNotification(
                    $serviceRequest->customer_id,
                    'Request Rejected',
                    "Your request has been rejected",
                    'request_rejected',
                    [
                        'request_id' => $serviceRequest->id,
                    ]
                );
            }
        } catch (\Exception $e) {
            Log::error('Failed to send rejected notification: ' . $e->getMessage());
        }
    }

    /**
     * Handle cancelled status
     */
    private function handleCancelled(ServiceRequest $serviceRequest): void
    {
        try {
            if ($serviceRequest->technician && $serviceRequest->technician->user) {
                $this->fcm->sendToUser(
                    $serviceRequest->technician->user,
                    'Request Cancelled',
                    "Customer cancelled request #{$serviceRequest->id}.",
                    $this->sanitizeData([
                        'request_id' => $serviceRequest->id,
                        'status' => 'cancelled',
                        'type' => 'request_cancelled',
                    ])
                );

                $this->createNotification(
                    $serviceRequest->technician_id,
                    'Request Cancelled',
                    "Customer cancelled request #{$serviceRequest->id}",
                    'request_cancelled',
                    [
                        'request_id' => $serviceRequest->id,
                        'customer_name' => $serviceRequest->customer->name ?? 'Customer',
                    ]
                );
            }
        } catch (\Exception $e) {
            Log::error('Failed to send cancelled notification: ' . $e->getMessage());
        }
    }

    /**
     * Handle in_progress status
     */
    private function handleInProgress(ServiceRequest $serviceRequest): void
    {
        try {
            if ($serviceRequest->customer) {
                $this->fcm->sendToUser(
                    $serviceRequest->customer,
                    'Request In Progress',
                    "Your request is now in progress.",
                    $this->sanitizeData([
                        'request_id' => $serviceRequest->id,
                        'status' => 'in_progress',
                        'type' => 'request_in_progress',
                    ])
                );

                $this->createNotification(
                    $serviceRequest->customer_id,
                    'Request In Progress',
                    "Your request is now in progress",
                    'request_in_progress',
                    [
                        'request_id' => $serviceRequest->id,
                    ]
                );
            }
        } catch (\Exception $e) {
            Log::error('Failed to send in_progress notification: ' . $e->getMessage());
        }
    }

    /**
     * Handle completed status
     */
    private function handleCompleted(ServiceRequest $serviceRequest): void
    {
        try {
            if ($serviceRequest->customer && $serviceRequest->customer->email) {
                Mail::to($serviceRequest->customer->email)
                    ->send(new RequestCompletedMail($serviceRequest));
            }
        } catch (\Exception $e) {
            Log::error('Failed to send completed email: ' . $e->getMessage());
        }

        try {
            if ($serviceRequest->customer) {
                $this->fcm->sendToUser(
                    $serviceRequest->customer,
                    'Request Completed',
                    "Your request has been completed by {$serviceRequest->technician->user->name}.",
                    $this->sanitizeData([
                        'request_id' => $serviceRequest->id,
                        'status' => 'completed',
                        'type' => 'request_completed',
                        'technician_name' => $serviceRequest->technician->user->name,
                    ])
                );

                $this->createNotification(
                    $serviceRequest->customer_id,
                    'Request Completed',
                    "Your request has been completed by {$serviceRequest->technician->user->name}",
                    'request_completed',
                    [
                        'request_id' => $serviceRequest->id,
                        'technician_id' => $serviceRequest->technician_id,
                        'technician_name' => $serviceRequest->technician->user->name,
                    ]
                );
            }
        } catch (\Exception $e) {
            Log::error('Failed to send completed notification: ' . $e->getMessage());
        }
    }

    /**
     * CUSTOMER: Cancel a request
     * DELETE /v4/requests/{id}/cancel
     */
    public function cancel($id, Request $request)
    {
        try {
            $serviceRequest = ServiceRequest::findOrFail($id);
            $user = $request->user();

            if (!$user) {
                return $this->forbidden('User not authenticated.');
            }

            if ($user->id !== $serviceRequest->customer_id || $serviceRequest->status !== 'pending') {
                return $this->forbidden('Cannot cancel this request.');
            }

            DB::beginTransaction();

            $oldStatus = $serviceRequest->status;
            $serviceRequest->status = 'cancelled';
            $serviceRequest->save();

            DB::commit();

            try {
                event(new RequestStatusUpdated($serviceRequest));
            } catch (\Exception $e) {
                Log::error('Failed to dispatch RequestStatusUpdated event: ' . $e->getMessage());
            }

            $this->logRequestAction(
                $serviceRequest->id,
                $user->id,
                'cancelled',
                $oldStatus,
                'cancelled',
                'Customer cancelled request'
            );

            $this->handleCancelled($serviceRequest);

            $this->logAudit('cancel_request', 'request', $id, 'Request cancelled by customer');

            return $this->successResponse($serviceRequest, 'Request cancelled successfully.');

        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error cancelling request: ' . $e->getMessage(), [
                'request_id' => $id,
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to cancel request. Please try again.', 500);
        }
    }

    /**
     * Get my requests (CUSTOMER, FUNDI, ADMIN)
     * GET /v4/my-requests
     */
    public function myRequests(Request $request)
    {
        try {
            $user = $request->user();

            if (!$user) {
                return $this->forbidden('User not authenticated.');
            }

            $perPage = $request->input('per_page', 15);

            if ($user->hasRole('CUSTOMER')) {
                $requests = ServiceRequest::with(['technician.user', 'service'])
                    ->where('customer_id', $user->id)
                    ->latest()
                    ->paginate($perPage);
                    
                $data = $this->formatRequests($requests);
                
            } elseif ($user->hasRole('FUNDI')) {
                $technician = $user->technician;
                if (!$technician) {
                    return $this->successResponse([
                        'data' => [],
                        'pagination' => [
                            'total' => 0,
                            'per_page' => $perPage,
                            'current_page' => 1,
                            'last_page' => 1
                        ]
                    ], 'No requests found');
                }
                
                $requests = ServiceRequest::with(['customer', 'service'])
                    ->where('technician_id', $technician->id)
                    ->latest()
                    ->paginate($perPage);
                    
                $data = $this->formatRequests($requests);
            } else {
                // Admin/Manager with permission to view all requests
                if (!$user->can('requests.view')) {
                    return $this->forbidden('Unauthorized. You need requests.view permission.');
                }
                
                $requests = ServiceRequest::with(['customer', 'technician.user', 'service'])
                    ->latest()
                    ->paginate($perPage);
                    
                $data = $this->formatRequests($requests);
            }

            return $this->successResponse($data, 'Requests retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching my requests: ' . $e->getMessage(), [
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Get all requests with filters (Permission-based)
     * GET /v4/admin/requests
     */
    public function index(Request $request)
    {
        try {
            if (!$request->user()->can('requests.view')) {
                return $this->forbidden('Unauthorized. You need requests.view permission.');
            }

            $query = ServiceRequest::with([
                'customer', 
                'technician.user', 
                'service',
                'logs' => function($q) {
                    $q->latest()->limit(5);
                }
            ]);

            if ($request->filled('status')) {
                $query->where('status', $request->status);
            }

            if ($request->filled('customer_id')) {
                $query->where('customer_id', $request->customer_id);
            }

            if ($request->filled('technician_id')) {
                $query->where('technician_id', $request->technician_id);
            }

            if ($request->filled('service_id')) {
                $query->where('service_id', $request->service_id);
            }

            if ($request->filled('date_from')) {
                $query->whereDate('created_at', '>=', $request->date_from);
            }
            if ($request->filled('date_to')) {
                $query->whereDate('created_at', '<=', $request->date_to);
            }

            if ($request->filled('search')) {
                $search = $request->search;
                $query->where(function($q) use ($search) {
                    $q->where('description', 'like', "%{$search}%")
                      ->orWhereHas('customer', function($cq) use ($search) {
                          $cq->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%");
                      })
                      ->orWhereHas('technician.user', function($tq) use ($search) {
                          $tq->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%");
                      });
                });
            }

            $sortField = $request->input('sort_by', 'created_at');
            $sortOrder = $request->input('sort_order', 'desc');
            
            $allowedSortFields = ['id', 'created_at', 'updated_at', 'status', 'customer_id', 'technician_id'];
            if (!in_array($sortField, $allowedSortFields)) {
                $sortField = 'created_at';
            }
            
            $query->orderBy($sortField, $sortOrder);

            $perPage = $request->input('per_page', 20);
            $requests = $query->paginate($perPage);

            $data = $this->formatRequests($requests);

            return $this->successResponse($data, 'Requests retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching requests: ' . $e->getMessage(), [
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Get single request with full details (Permission-based)
     * GET /v4/admin/requests/{id}
     */
    public function show($id, Request $request)
    {
        try {
            if (!$request->user()->can('requests.view')) {
                return $this->forbidden('Unauthorized. You need requests.view permission.');
            }

            $serviceRequest = ServiceRequest::with([
                'customer', 
                'technician.user', 
                'service',
                'logs.user'
            ])->findOrFail($id);

            $data = $this->formatSingleRequest($serviceRequest);

            return $this->successResponse($data, 'Request retrieved successfully');

        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            Log::error('Error fetching request: ' . $e->getMessage(), [
                'request_id' => $id,
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to fetch request. Please try again.', 500);
        }
    }

    /**
     * Delete request (Permission-based)
     * DELETE /v4/admin/requests/{id}
     */
    public function destroy($id, Request $request)
    {
        try {
            if (!$request->user()->can('requests.delete')) {
                return $this->forbidden('Unauthorized. You need requests.delete permission.');
            }

            $serviceRequest = ServiceRequest::findOrFail($id);
            
            DB::beginTransaction();
            
            RequestLog::where('request_id', $id)->delete();
            
            $serviceRequest->delete();
            
            DB::commit();
            
            $this->logAudit('delete_request', 'request', $id, "Deleted request ID: $id");
            
            return $this->successResponse(null, 'Request deleted successfully.');

        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error deleting request: ' . $e->getMessage(), [
                'request_id' => $id,
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to delete request. Please try again.', 500);
        }
    }

    /**
     * Get request logs (Permission-based)
     * GET /v4/admin/request-logs/{requestId}
     */
    public function logs($requestId, Request $request)
    {
        try {
            if (!$request->user()->can('requests.view')) {
                return $this->forbidden('Unauthorized. You need requests.view permission.');
            }

            $logs = RequestLog::where('request_id', $requestId)
                ->with('user')
                ->orderBy('created_at', 'desc')
                ->get();

            return $this->successResponse($logs, 'Request logs retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching request logs: ' . $e->getMessage(), [
                'request_id' => $requestId,
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to fetch logs. Please try again.', 500);
        }
    }

    /**
     * Get request statistics (Permission-based)
     * GET /v4/admin/requests/stats
     */
    public function stats(Request $request)
    {
        try {
            if (!$request->user()->can('requests.view')) {
                return $this->forbidden('Unauthorized. You need requests.view permission.');
            }

            $stats = [
                'total' => ServiceRequest::count(),
                'pending' => ServiceRequest::where('status', 'pending')->count(),
                'accepted' => ServiceRequest::where('status', 'accepted')->count(),
                'rejected' => ServiceRequest::where('status', 'rejected')->count(),
                'cancelled' => ServiceRequest::where('status', 'cancelled')->count(),
                'in_progress' => ServiceRequest::where('status', 'in_progress')->count(),
                'completed' => ServiceRequest::where('status', 'completed')->count(),
                'today' => ServiceRequest::whereDate('created_at', today())->count(),
                'this_week' => ServiceRequest::whereBetween('created_at', [now()->startOfWeek(), now()->endOfWeek()])->count(),
                'this_month' => ServiceRequest::whereMonth('created_at', now()->month)->count(),
            ];

            return $this->successResponse($stats, 'Request statistics retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching request stats: ' . $e->getMessage(), [
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to fetch statistics. Please try again.', 500);
        }
    }

    /**
     * Get request by customer (for customers to see their requests)
     * GET /v4/customer/requests
     */
    public function customerRequests(Request $request)
    {
        try {
            $user = $request->user();

            if (!$user || !$user->hasRole('CUSTOMER')) {
                return $this->forbidden('Only customers can view their requests.');
            }

            $perPage = $request->input('per_page', 15);
            $status = $request->input('status');

            $query = ServiceRequest::with(['technician.user', 'service'])
                ->where('customer_id', $user->id);

            if ($status) {
                $query->where('status', $status);
            }

            $requests = $query->latest()->paginate($perPage);
            $data = $this->formatRequests($requests);

            return $this->successResponse($data, 'Customer requests retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching customer requests: ' . $e->getMessage(), [
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Get request by technician (for technicians to see their requests)
     * GET /v4/technician/requests
     */
    public function technicianRequests(Request $request)
    {
        try {
            $user = $request->user();

            if (!$user || !$user->hasRole('FUNDI')) {
                return $this->forbidden('Only technicians can view their requests.');
            }

            $technician = $user->technician;
            if (!$technician) {
                return $this->successResponse([
                    'data' => [],
                    'pagination' => [
                        'total' => 0,
                        'per_page' => 15,
                        'current_page' => 1,
                        'last_page' => 1
                    ]
                ], 'No requests found');
            }

            $perPage = $request->input('per_page', 15);
            $status = $request->input('status');

            $query = ServiceRequest::with(['customer', 'service'])
                ->where('technician_id', $technician->id);

            if ($status) {
                $query->where('status', $status);
            }

            $requests = $query->latest()->paginate($perPage);
            $data = $this->formatRequests($requests);

            return $this->successResponse($data, 'Technician requests retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching technician requests: ' . $e->getMessage(), [
                'user_id' => $request->user()->id ?? 'unknown'
            ]);
            
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Format requests for response
     */
    private function formatRequests($requests): array
    {
        $data = $requests->map(function($request) {
            return $this->formatSingleRequest($request);
        });

        return [
            'data' => $data,
            'pagination' => [
                'total' => $requests->total(),
                'per_page' => $requests->perPage(),
                'current_page' => $requests->currentPage(),
                'last_page' => $requests->lastPage(),
            ]
        ];
    }

    /**
     * Format single request
     */
    private function formatSingleRequest($request): array
    {
        return [
            'id' => $request->id,
            'description' => $request->description,
            'status' => $request->status,
            'created_at' => $request->created_at,
            'updated_at' => $request->updated_at,
            'customer' => $request->customer ? [
                'id' => $request->customer->id,
                'name' => $request->customer->name,
                'email' => $request->customer->email,
                'phone' => $request->customer->phone,
            ] : null,
            'technician' => $request->technician ? [
                'id' => $request->technician->id,
                'name' => $request->technician->user->name ?? null,
                'email' => $request->technician->user->email ?? null,
                'phone' => $request->technician->user->phone ?? null,
                'profile_photo' => $request->technician->profile_photo 
                    ? url($request->technician->profile_photo) 
                    : null,
                'area' => $request->technician->area,
                'rating' => (float) ($request->technician->rating ?? 0),
                'is_online' => (bool) ($request->technician->is_online ?? false),
            ] : null,
            'service' => $request->service ? [
                'id' => $request->service->id,
                'name' => $request->service->name,
            ] : null,
            'logs' => $request->logs ? $request->logs->map(function($log) {
                return [
                    'id' => $log->id,
                    'action' => $log->action,
                    'old_status' => $log->old_status,
                    'new_status' => $log->new_status,
                    'notes' => $log->notes,
                    'created_at' => $log->created_at,
                    'user' => $log->user ? [
                        'id' => $log->user->id,
                        'name' => $log->user->name,
                    ] : null,
                ];
            }) : [],
        ];
    }
}