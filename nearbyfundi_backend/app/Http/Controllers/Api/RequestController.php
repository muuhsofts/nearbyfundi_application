<?php

namespace App\Http\Controllers\Api;

use App\Models\ServiceRequest;
use App\Models\RequestLog;
use App\Models\Notification;
use App\Models\Service;
use App\Models\ServiceCategory;
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

    // ============================================================
    // PRIVATE HELPERS (existing)
    // ============================================================

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
            Log::error('Failed to log request action: ' . $e->getMessage());
        }
    }

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
            Log::error('Failed to create notification: ' . $e->getMessage());
        }
    }

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

    // ============================================================
    // NEW PRIVATE HELPERS (Phase 2)
    // ============================================================

    /**
     * Send push and database notification to customer about request status change
     */
    private function notifyCustomer(ServiceRequest $request, string $event): void
    {
        $title = 'Request Update';
        $body = "Your request #{$request->id} is now: " . str_replace('_', ' ', $event);
        $data = ['request_id' => $request->id, 'status' => $event];

        try {
            if ($request->customer) {
                $this->fcm->sendToUser($request->customer, $title, $body, $data);
                $this->createNotification(
                    $request->customer_id,
                    $title,
                    $body,
                    'request_' . $event,
                    $data
                );
            }
        } catch (\Exception $e) {
            Log::error('Failed to notify customer: ' . $e->getMessage());
        }
    }

    /**
     * Haversine distance in km
     */
    private function haversineDistance($lat1, $lon1, $lat2, $lon2): float
    {
        $earthRadius = 6371; // km
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);
        $a = sin($dLat/2) * sin($dLat/2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon/2) * sin($dLon/2);
        $c = 2 * atan2(sqrt($a), sqrt(1-$a));
        return $earthRadius * $c;
    }

    // ============================================================
    // PUBLIC METHODS
    // ============================================================

    /**
     * Get services with their categories for request creation
     * GET /v4/request-services
     */
    public function getServicesWithCategories(Request $request)
    {
        try {
            $services = Service::with(['categories' => function($query) {
                $query->select('service_categories.service_categoryID', 'category_name', 'slug')
                      ->orderBy('category_name', 'asc');
            }])
            ->select('id', 'name')
            ->orderBy('name', 'asc')
            ->get();

            $data = $services->map(function($service) {
                return [
                    'id' => $service->id,
                    'name' => $service->name,
                    'categories' => $service->categories->map(function($category) {
                        return [
                            'id' => $category->service_categoryID,
                            'name' => $category->category_name,
                            'slug' => $category->slug,
                        ];
                    })
                ];
            });

            return $this->successResponse($data, 'Services with categories retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching services with categories: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch services. Please try again.', 500);
        }
    }

    /**
     * Get technicians by service and category
     * GET /v4/technicians/by-service-category
     */
    public function getTechniciansByServiceCategory(Request $request)
    {
        try {
            $validated = $request->validate([
                'service_id' => 'required|exists:services,id',
                'category_id' => 'nullable|exists:service_categories,service_categoryID',
            ]);

            $query = \App\Models\Technician::with(['user', 'services'])
                ->whereHas('user', function($q) {
                    $q->where('is_active', true);
                })
                ->where('verified', true);

            $query->whereHas('services', function($q) use ($validated) {
                $q->where('service_id', $validated['service_id']);
            });

            if (!empty($validated['category_id'])) {
                $query->whereHas('services.categories', function($q) use ($validated) {
                    $q->where('service_categoryID', $validated['category_id']);
                });
            }

            $technicians = $query->get();

            $data = $technicians->map(function($technician) {
                return [
                    'id' => $technician->id,
                    'name' => $technician->user->name ?? 'Unknown',
                    'email' => $technician->user->email ?? null,
                    'phone' => $technician->user->phone ?? null,
                    'profile_photo' => $technician->profile_photo ? url($technician->profile_photo) : null,
                    'area' => $technician->area,
                    'rating' => (float) ($technician->rating ?? 0),
                    'is_online' => (bool) ($technician->is_online ?? false),
                    'services' => $technician->services->map(function($service) {
                        return [
                            'id' => $service->id,
                            'name' => $service->name,
                        ];
                    }),
                ];
            });

            return $this->successResponse($data, 'Technicians retrieved successfully');
        } catch (\Illuminate\Validation\ValidationException $e) {
            return $this->validationError($e->errors());
        } catch (\Exception $e) {
            Log::error('Error fetching technicians by service/category: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch technicians. Please try again.', 500);
        }
    }

    /**
     * CUSTOMER: Create a new request with service and category
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
                'category_id'   => 'nullable|exists:service_categories,service_categoryID',
                'description'   => 'required|string|min:5',
            ]);

            Log::info('Request creation data received:', $data);

            if (!empty($data['category_id'])) {
                $service = Service::find($data['service_id']);
                if (!$service) {
                    return $this->errorResponse('Service not found.', 404);
                }
                if (!$service->hasCategory($data['category_id'])) {
                    Log::warning('Category not associated with service', [
                        'service_id' => $data['service_id'],
                        'category_id' => $data['category_id']
                    ]);
                    return $this->errorResponse(
                        'The selected category is not associated with this service.',
                        422
                    );
                }
            }

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
                'category_id'   => $data['category_id'] ?? null,
                'description'   => $data['description'],
                'status'        => 'pending',
            ]);

            Log::info('Request created successfully:', ['request_id' => $serviceRequest->id]);

            $serviceRequest->load(['customer', 'technician.user', 'service', 'category']);

            DB::commit();

            try {
                event(new RequestCreated($serviceRequest));
            } catch (\Exception $e) {
                Log::error('Failed to dispatch RequestCreated event: ' . $e->getMessage());
            }

            try {
                if ($serviceRequest->technician && 
                    $serviceRequest->technician->user && 
                    $serviceRequest->technician->user->email) {
                    Mail::to($serviceRequest->technician->user->email)
                        ->send(new RequestCreatedMail($serviceRequest));
                }
            } catch (\Exception $e) {
                Log::error('Failed to send request created email: ' . $e->getMessage());
            }

            try {
                if ($serviceRequest->technician && $serviceRequest->technician->user) {
                    $technicianUser = $serviceRequest->technician->user;
                    $serviceName = $serviceRequest->service->name ?? 'Service';
                    $categoryName = $serviceRequest->category->category_name ?? '';

                    $this->fcm->sendToUser(
                        $technicianUser,
                        'New Service Request',
                        "You have a new request for {$serviceName}" . ($categoryName ? " ({$categoryName})" : ""),
                        $this->sanitizeData([
                            'request_id' => $serviceRequest->id,
                            'type' => 'new_request',
                            'customer_name' => $user->name ?? 'Customer',
                            'service_name' => $serviceName,
                            'category_name' => $categoryName,
                            'description' => $serviceRequest->description,
                        ])
                    );

                    $this->createNotification(
                        $technicianUser->id,
                        'New Service Request',
                        "You have a new request for {$serviceName}" . ($categoryName ? " ({$categoryName})" : "") . " from {$user->name}",
                        'new_request',
                        [
                            'request_id' => $serviceRequest->id,
                            'customer_id' => $user->id,
                            'customer_name' => $user->name,
                            'service_name' => $serviceName,
                            'category_name' => $categoryName,
                            'description' => $serviceRequest->description,
                        ]
                    );
                }
            } catch (\Exception $e) {
                Log::error('Failed to send FCM notification: ' . $e->getMessage());
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

            return $this->created($this->formatSingleRequest($serviceRequest), 'Request submitted successfully.');
            
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
     * Update request status (UPDATED to allow on_the_way & arrived)
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
                // NEW: allow technician to set on_the_way and arrived
                if ($newStatus === 'on_the_way' && $oldStatus === 'accepted') {
                    $allowed = true;
                }
                if ($newStatus === 'arrived' && $oldStatus === 'on_the_way') {
                    $allowed = true;
                }
            } elseif ($user->hasRole('CUSTOMER') && $newStatus === 'cancelled' && $oldStatus === 'pending') {
                $allowed = true;
            } elseif ($user->can('requests.status.update')) {
                $allowed = true;
            }

            if (!$allowed) {
                return $this->forbidden('Invalid status change.');
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
                "Status changed from {$oldStatus} to {$newStatus}",
                $request->ip()
            );

            $this->handleStatusChange($serviceRequest, $newStatus);
            $this->logAudit('update_request_status', 'request', $id, "Status changed to {$newStatus}");

            return $this->successResponse($serviceRequest, 'Status updated successfully.');
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error updating request status: ' . $e->getMessage());
            return $this->errorResponse('Failed to update status. Please try again.', 500);
        }
    }

    /**
     * Handle status change – updated to include on_the_way and arrived
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
                case 'on_the_way':
                    $this->handleOnTheWay($serviceRequest);
                    break;
                case 'arrived':
                    $this->handleArrived($serviceRequest);
                    break;
                default:
                    break;
            }
        } catch (\Exception $e) {
            Log::error('Error handling status change: ' . $e->getMessage());
        }
    }

    // ----- Individual status handlers (existing + new) -----

    private function handleAccepted(ServiceRequest $serviceRequest): void
    {
        try {
            if ($serviceRequest->customer && $serviceRequest->customer->email) {
                Mail::to($serviceRequest->customer->email)->send(new RequestAcceptedMail($serviceRequest));
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

    private function handleCompleted(ServiceRequest $serviceRequest): void
    {
        try {
            if ($serviceRequest->customer && $serviceRequest->customer->email) {
                Mail::to($serviceRequest->customer->email)->send(new RequestCompletedMail($serviceRequest));
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

    // NEW handlers for on_the_way and arrived
    private function handleOnTheWay(ServiceRequest $serviceRequest): void
    {
        $this->notifyCustomer($serviceRequest, 'on_the_way');
    }

    private function handleArrived(ServiceRequest $serviceRequest): void
    {
        $this->notifyCustomer($serviceRequest, 'arrived');
    }

    /**
     * Cancel a request (customer only)
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
            Log::error('Error cancelling request: ' . $e->getMessage());
            return $this->errorResponse('Failed to cancel request. Please try again.', 500);
        }
    }

    /**
     * Get authenticated user's requests (customer or technician)
     * 
     * UPDATED: eager loads 'review' relationship for the current user.
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
                $requests = ServiceRequest::with([
                    'technician.user',
                    'service',
                    'category',
                    'review'                   // ← eager load the review
                ])
                    ->where('customer_id', $user->id)
                    ->latest()
                    ->paginate($perPage);
                $data = $this->formatRequests($requests, $user->id);
            } elseif ($user->hasRole('FUNDI')) {
                $technician = $user->technician;
                if (!$technician) {
                    return $this->successResponse(['data' => [], 'pagination' => ['total' => 0, 'per_page' => $perPage, 'current_page' => 1, 'last_page' => 1]], 'No requests found');
                }
                $requests = ServiceRequest::with(['customer', 'service', 'category'])
                    ->where('technician_id', $technician->id)
                    ->latest()
                    ->paginate($perPage);
                $data = $this->formatRequests($requests);
            } else {
                if (!$user->can('requests.view')) {
                    return $this->forbidden('Unauthorized. You need requests.view permission.');
                }
                $requests = ServiceRequest::with(['customer', 'technician.user', 'service', 'category'])
                    ->latest()
                    ->paginate($perPage);
                $data = $this->formatRequests($requests);
            }

            return $this->successResponse($data, 'Requests retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching my requests: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Admin: list all requests with filters
     */
    public function index(Request $request)
    {
        try {
            if (!$request->user()->can('requests.view')) {
                return $this->forbidden('Unauthorized. You need requests.view permission.');
            }

            $query = ServiceRequest::with(['customer', 'technician.user', 'service', 'category', 'logs' => function($q) {
                $q->latest()->limit(5);
            }]);

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
            if ($request->filled('category_id')) {
                $query->where('category_id', $request->category_id);
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
            Log::error('Error fetching requests: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Admin: show single request details
     */
    public function show($id, Request $request)
    {
        try {
            if (!$request->user()->can('requests.view')) {
                return $this->forbidden('Unauthorized. You need requests.view permission.');
            }

            $serviceRequest = ServiceRequest::with(['customer', 'technician.user', 'service', 'category', 'logs.user'])->findOrFail($id);
            $data = $this->formatSingleRequest($serviceRequest);

            return $this->successResponse($data, 'Request retrieved successfully');
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            Log::error('Error fetching request: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch request. Please try again.', 500);
        }
    }

    /**
     * Admin: delete a request
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
            Log::error('Error deleting request: ' . $e->getMessage());
            return $this->errorResponse('Failed to delete request. Please try again.', 500);
        }
    }

    /**
     * Get logs for a specific request (admin)
     */
    public function logs($requestId, Request $request)
    {
        try {
            if (!$request->user()->can('requests.view')) {
                return $this->forbidden('Unauthorized. You need requests.view permission.');
            }

            $logs = RequestLog::where('request_id', $requestId)->with('user')->orderBy('created_at', 'desc')->get();
            return $this->successResponse($logs, 'Request logs retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching request logs: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch logs. Please try again.', 500);
        }
    }

    /**
     * Get request statistics (admin)
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
            Log::error('Error fetching request stats: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch statistics. Please try again.', 500);
        }
    }

    /**
     * Get requests for the authenticated customer
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

            $query = ServiceRequest::with(['technician.user', 'service', 'category'])->where('customer_id', $user->id);

            if ($status) {
                $query->where('status', $status);
            }

            $requests = $query->latest()->paginate($perPage);
            $data = $this->formatRequests($requests);

            return $this->successResponse($data, 'Customer requests retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching customer requests: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Get requests for the authenticated technician
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
                return $this->successResponse(['data' => [], 'pagination' => ['total' => 0, 'per_page' => 15, 'current_page' => 1, 'last_page' => 1]], 'No requests found');
            }

            $perPage = $request->input('per_page', 15);
            $status = $request->input('status');

            $query = ServiceRequest::with(['customer', 'service', 'category'])->where('technician_id', $technician->id);

            if ($status) {
                $query->where('status', $status);
            }

            $requests = $query->latest()->paginate($perPage);
            $data = $this->formatRequests($requests);

            return $this->successResponse($data, 'Technician requests retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching technician requests: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    // ============================================================
    // NEW: TRACKING METHODS (Phase 2)
    // ============================================================

    /**
     * Technician marks request as "On the Way"
     * PATCH /v4/requests/{id}/on-the-way
     */
    public function markOnTheWay(Request $request, $id)
    {
        $serviceRequest = ServiceRequest::findOrFail($id);
        $user = $request->user();

        if (!$user->technician || $user->technician->id !== $serviceRequest->technician_id) {
            return $this->forbidden('You are not the technician assigned to this request.');
        }

        if ($serviceRequest->status !== ServiceRequest::STATUS_ACCEPTED) {
            return $this->errorResponse('Request must be accepted first.', 422);
        }

        $serviceRequest->status = ServiceRequest::STATUS_ON_THE_WAY;
        $serviceRequest->save();

        $this->handleOnTheWay($serviceRequest);
        $this->logRequestAction(
            $serviceRequest->id,
            $user->id,
            'on_the_way',
            ServiceRequest::STATUS_ACCEPTED,
            ServiceRequest::STATUS_ON_THE_WAY,
            'Technician is on the way'
        );
        $this->logAudit('mark_on_the_way', 'request', $serviceRequest->id, 'Technician marked on the way');

        return $this->successResponse($serviceRequest, 'Now on the way.');
    }

    /**
     * Technician marks request as "Arrived" (manual)
     * PATCH /v4/requests/{id}/arrive
     */
    public function markArrived(Request $request, $id)
    {
        $serviceRequest = ServiceRequest::findOrFail($id);
        $user = $request->user();

        if (!$user->technician || $user->technician->id !== $serviceRequest->technician_id) {
            return $this->forbidden('You are not the technician assigned to this request.');
        }

        if ($serviceRequest->status !== ServiceRequest::STATUS_ON_THE_WAY) {
            return $this->errorResponse('Must be on the way first.', 422);
        }

        $serviceRequest->status = ServiceRequest::STATUS_ARRIVED;
        $serviceRequest->save();

        $this->handleArrived($serviceRequest);
        $this->logRequestAction(
            $serviceRequest->id,
            $user->id,
            'arrived',
            ServiceRequest::STATUS_ON_THE_WAY,
            ServiceRequest::STATUS_ARRIVED,
            'Technician arrived'
        );
        $this->logAudit('mark_arrived', 'request', $serviceRequest->id, 'Technician marked arrived');

        return $this->successResponse($serviceRequest, 'Arrived at location.');
    }

    /**
     * Get live tracking data for a request
     * GET /v4/requests/{id}/tracking
     */
    public function trackingData($id)
    {
        $request = ServiceRequest::with('technician')->findOrFail($id);

        $customerLat = $request->latitude;
        $customerLng = $request->longitude;
        $techLat = $request->technician->latitude;
        $techLng = $request->technician->longitude;

        $distance = null;
        $eta = null;
        if ($customerLat && $customerLng && $techLat && $techLng) {
            $distance = $this->haversineDistance($customerLat, $customerLng, $techLat, $techLng);
            // Estimate ETA: assume average speed 30 km/h => 2 min per km
            $etaMinutes = $distance * 2;
            $eta = now()->addMinutes($etaMinutes)->toIso8601String();
        }

        return $this->successResponse([
            'technician_location' => [
                'lat' => $techLat ? (float) $techLat : null,
                'lng' => $techLng ? (float) $techLng : null,
            ],
            'customer_location' => [
                'lat' => $customerLat ? (float) $customerLat : null,
                'lng' => $customerLng ? (float) $customerLng : null,
            ],
            'status' => $request->status,
            'distance_km' => $distance ? round($distance, 2) : null,
            'eta' => $eta,
            'last_updated' => $request->technician->location_updated_at?->toIso8601String(),
        ], 'Tracking data retrieved.');
    }

    // ============================================================
    // PRIVATE FORMATTING HELPERS
    // ============================================================

    /**
     * Format a paginated request collection.
     *
     * @param mixed $requests
     * @param int|null $userId Optional user ID for 'has_review' flag.
     * @return array
     */
    private function formatRequests($requests, ?int $userId = null): array
    {
        $data = $requests->map(function($request) use ($userId) {
            return $this->formatSingleRequest($request, $userId);
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
     * Format a single request.
     *
     * @param mixed $request
     * @param int|null $userId Optional user ID to check for existing review.
     * @return array
     */
    private function formatSingleRequest($request, ?int $userId = null): array
    {
        $data = [
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
            'category' => $request->category ? [
                'id' => $request->category->service_categoryID,
                'name' => $request->category->category_name,
                'slug' => $request->category->slug,
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

        // --- Add has_review flag ---
        // If a user ID is provided, check if a review exists for that customer.
        // Otherwise, fallback to the authenticated user (if any) or false.
        if ($userId !== null) {
            $hasReview = $request->review()->where('customer_id', $userId)->exists();
        } elseif (auth()->check()) {
            $hasReview = $request->review()->where('customer_id', auth()->id())->exists();
        } else {
            $hasReview = false;
        }
        $data['has_review'] = $hasReview;

        return $data;
    }
}