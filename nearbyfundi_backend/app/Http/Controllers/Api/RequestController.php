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
use App\Services\SmsNotificationService;
use App\Traits\Auditable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class RequestController extends BaseApiController
{
    use Auditable;

    protected FcmService $fcm;
    protected SmsNotificationService $smsService;

    public function __construct(FcmService $fcm, SmsNotificationService $smsService)
    {
        $this->fcm = $fcm;
        $this->smsService = $smsService;
    }

    // ============================================================
    // PRIVATE HELPERS
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
            $sanitizedData = $this->sanitizeData($data);

            Notification::create([
                'user_id' => $userId,
                'title'   => $title,
                'body'    => $body,
                'type'    => $type,
                'data'    => $sanitizedData,
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

    /**
     * Send push + DB notification to customer about request status change
     */
    private function notifyCustomer(ServiceRequest $request, string $event, ?string $customTitle = null, ?string $customBody = null): void
    {
        $titles = [
            'on_the_way'   => 'Technician On The Way',
            'arrived'      => 'Technician Arrived',
            'accepted'     => 'Request Accepted',
            'rejected'     => 'Request Rejected',
            'in_progress'  => 'Request In Progress',
            'completed'    => 'Request Completed',
            'cancelled'    => 'Request Cancelled',
        ];

        $bodies = [
            'on_the_way'  => 'Your fundi is on the way to your location.',
            'arrived'     => 'Your fundi has arrived at your location.',
            'accepted'    => 'Your request has been accepted.',
            'rejected'    => 'Sorry, your request has been rejected.',
            'in_progress' => 'Your request is now in progress.',
            'completed'   => 'Your request has been completed.',
            'cancelled'   => 'Your request has been cancelled.',
        ];

        $title = $customTitle ?? ($titles[$event] ?? 'Request Update');
        $body  = $customBody  ?? ($bodies[$event]  ?? "Your request #{$request->id} is now: " . str_replace('_', ' ', $event));
        $data  = [
            'request_id' => $request->id,
            'status'     => $event,
            'type'       => 'request_' . $event,
        ];

        try {
            if ($request->customer) {
                $this->fcm->sendToUser($request->customer, $title, $body, $this->sanitizeData($data));
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
        $a = sin($dLat / 2) * sin($dLat / 2) +
             cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
             sin($dLon / 2) * sin($dLon / 2);
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return $earthRadius * $c;
    }

    /**
     * Check if the authenticated fundi owns this request
     */
    private function isAssignedFundi($user, ServiceRequest $serviceRequest): bool
    {
        return $user
            && $user->hasRole('FUNDI')
            && $user->technician
            && (int) $user->technician->id === (int) $serviceRequest->technician_id;
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
            $services = Service::with(['categories' => function ($query) {
                $query->select('service_categories.service_categoryID', 'category_name', 'slug')
                      ->orderBy('category_name', 'asc');
            }])
            ->select('id', 'name')
            ->orderBy('name', 'asc')
            ->get();

            $data = $services->map(function ($service) {
                return [
                    'id'   => $service->id,
                    'name' => $service->name,
                    'categories' => $service->categories->map(function ($category) {
                        return [
                            'id'   => $category->service_categoryID,
                            'name' => $category->category_name,
                            'slug' => $category->slug,
                        ];
                    }),
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
                'service_id'  => 'required|exists:services,id',
                'category_id' => 'nullable|exists:service_categories,service_categoryID',
            ]);

            $query = \App\Models\Technician::with(['user', 'services'])
                ->whereHas('user', function ($q) {
                    $q->where('is_active', true);
                })
                ->where('verified', true);

            $query->whereHas('services', function ($q) use ($validated) {
                $q->where('service_id', $validated['service_id']);
            });

            if (!empty($validated['category_id'])) {
                $query->whereHas('services.categories', function ($q) use ($validated) {
                    $q->where('service_categoryID', $validated['category_id']);
                });
            }

            $technicians = $query->get();

            $data = $technicians->map(function ($technician) {
                return [
                    'id'            => $technician->id,
                    'name'          => $technician->user->name ?? 'Unknown',
                    'email'         => $technician->user->email ?? null,
                    'phone'         => $technician->user->phone ?? null,
                    'profile_photo' => $technician->profile_photo ? url($technician->profile_photo) : null,
                    'area'          => $technician->area,
                    'rating'        => (float) ($technician->rating ?? 0),
                    'is_online'     => (bool) ($technician->is_online ?? false),
                    'services'      => $technician->services->map(function ($service) {
                        return [
                            'id'   => $service->id,
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
                        'service_id'  => $data['service_id'],
                        'category_id' => $data['category_id'],
                    ]);
                    return $this->errorResponse(
                        'The selected category is not associated with this service.',
                        422
                    );
                }
            }

            $existing = ServiceRequest::where('customer_id', $user->id)
                ->where('technician_id', $data['technician_id'])
                ->whereIn('status', ['pending', 'accepted', 'on_the_way', 'arrived', 'in_progress'])
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

            // ============================================================
            // 🔥 SEND SMS TO TECHNICIAN - NEW REQUEST NOTIFICATION
            // ============================================================
            try {
                $technician = $serviceRequest->technician;
                if ($technician && $technician->user && !empty($technician->user->phone)) {
                    $smsResult = $this->smsService->notifyTechnicianNewRequest($serviceRequest, $technician);
                    
                    Log::info('SMS notification sent to technician', [
                        'request_id'    => $serviceRequest->id,
                        'technician_id' => $technician->id,
                        'phone'         => $technician->user->phone,
                        'sms_success'   => $smsResult['success'] ?? false,
                    ]);
                } else {
                    Log::warning('Technician has no phone number, SMS not sent', [
                        'request_id'    => $serviceRequest->id,
                        'technician_id' => $data['technician_id'],
                    ]);
                }
            } catch (\Exception $e) {
                Log::error('Failed to send SMS to technician: ' . $e->getMessage(), [
                    'request_id'    => $serviceRequest->id,
                    'technician_id' => $data['technician_id'],
                ]);
                // Don't fail the request if SMS fails - just log it
            }

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
                    $serviceName    = $serviceRequest->service->name ?? 'Service';
                    $categoryName   = $serviceRequest->category->category_name ?? '';

                    $this->fcm->sendToUser(
                        $technicianUser,
                        'New Service Request',
                        "You have a new request for {$serviceName}" . ($categoryName ? " ({$categoryName})" : ''),
                        $this->sanitizeData([
                            'request_id'    => $serviceRequest->id,
                            'type'          => 'new_request',
                            'customer_name' => $user->name ?? 'Customer',
                            'service_name'  => $serviceName,
                            'category_name' => $categoryName,
                            'description'   => $serviceRequest->description,
                        ])
                    );

                    $this->createNotification(
                        $technicianUser->id,
                        'New Service Request',
                        "You have a new request for {$serviceName}" . ($categoryName ? " ({$categoryName})" : '') . " from {$user->name}",
                        'new_request',
                        [
                            'request_id'    => $serviceRequest->id,
                            'customer_id'   => $user->id,
                            'customer_name' => $user->name,
                            'service_name'  => $serviceName,
                            'category_name' => $categoryName,
                            'description'   => $serviceRequest->description,
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
                'data'    => $request->all(),
            ]);
            return $this->errorResponse('Failed to create request. Please try again.', 500);
        }
    }

    /**
     * Update request status
     * PATCH /v4/requests/{id}/status
     */
     public function updateStatus(Request $request, $id)
{
    try {
        $serviceRequest = ServiceRequest::with(['technician.user', 'customer', 'service'])->findOrFail($id);
        $user           = $request->user();
        $newStatus      = $request->input('status') ?? $request->status;
        $oldStatus      = $serviceRequest->status;

        if (!$user) {
            return $this->forbidden('User not authenticated.');
        }

        if (empty($newStatus)) {
            return $this->errorResponse('Status is required.', 422);
        }

        $allowed = false;

        // ─── FUNDI ───────────────────────────────────────────────
        if ($user->hasRole('FUNDI')) {
            if (!$this->isAssignedFundi($user, $serviceRequest)) {
                return $this->forbidden(
                    'You are not assigned to this request. This request belongs to another fundi.'
                );
            }

            // Valid transitions
            if (in_array($newStatus, ['accepted', 'rejected']) && $oldStatus === 'pending') {
                $allowed = true;
            }
            if ($newStatus === 'on_the_way' && $oldStatus === 'accepted') {
                $allowed = true;
            }
            if ($newStatus === 'arrived' && $oldStatus === 'on_the_way') {
                $allowed = true;
            }
            if ($newStatus === 'in_progress' && in_array($oldStatus, ['accepted', 'on_the_way', 'arrived'])) {
                $allowed = true;
            }
            if ($newStatus === 'completed' && in_array($oldStatus, ['accepted', 'on_the_way', 'arrived', 'in_progress'])) {
                $allowed = true;
            }
        }
        // ─── CUSTOMER ────────────────────────────────────────────
        elseif ($user->hasRole('CUSTOMER') && $newStatus === 'cancelled' && $oldStatus === 'pending') {
            if ((int) $user->id !== (int) $serviceRequest->customer_id) {
                return $this->forbidden('You can only cancel your own requests.');
            }
            $allowed = true;
        }
        // ─── ADMIN / STAFF ───────────────────────────────────────
        elseif ($user->can('requests.status.update')) {
            $allowed = true;
        }

        if (!$allowed) {
            Log::warning('Invalid status change attempt', [
                'user_id'       => $user->id,
                'roles'         => $user->getRoleNames()->toArray(),
                'request_id'    => $id,
                'old_status'    => $oldStatus,
                'new_status'    => $newStatus,
                'technician_id' => $serviceRequest->technician_id,
            ]);

            return $this->forbidden(
                "Invalid status change. Current status is '{$oldStatus}'. You cannot change it to '{$newStatus}'."
            );
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

        return $this->successResponse(
            $this->formatSingleRequest($serviceRequest->fresh(['customer', 'technician.user', 'service', 'category'])),
            'Status updated successfully.'
        );
    } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
        return $this->notFound('Request not found.');
    } catch (\Exception $e) {
        DB::rollBack();
        Log::error('Error updating request status: ' . $e->getMessage());
        return $this->errorResponse('Failed to update status. Please try again.', 500);
    }
}

    /**
     * Handle status change side-effects
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

    // ----- Individual status handlers -----

    private function handleAccepted(ServiceRequest $serviceRequest): void
    {
        try {
            if ($serviceRequest->customer && $serviceRequest->customer->email) {
                Mail::to($serviceRequest->customer->email)->send(new RequestAcceptedMail($serviceRequest));
            }
        } catch (\Exception $e) {
            Log::error('Failed to send accepted email: ' . $e->getMessage());
        }

        // ============================================================
        // 🔥 SEND SMS TO CUSTOMER - REQUEST ACCEPTED
        // ============================================================
        try {
            $technician = $serviceRequest->technician;
            $customer   = $serviceRequest->customer;
            
            if ($technician && $customer && !empty($customer->phone)) {
                // Ensure service is loaded
                if (!$serviceRequest->relationLoaded('service')) {
                    $serviceRequest->load('service');
                }

                $smsResult = $this->smsService->notifyCustomerRequestAccepted($serviceRequest, $technician);
                
                Log::info('SMS notification sent to customer about acceptance', [
                    'request_id'  => $serviceRequest->id,
                    'customer_id' => $customer->id,
                    'phone'       => $customer->phone,
                    'sms_success' => $smsResult['success'] ?? false,
                ]);
            } else {
                Log::warning('Customer has no phone number, SMS not sent', [
                    'request_id'  => $serviceRequest->id,
                    'customer_id' => $serviceRequest->customer_id,
                ]);
            }
        } catch (\Exception $e) {
            Log::error('Failed to send SMS to customer about acceptance: ' . $e->getMessage(), [
                'request_id'  => $serviceRequest->id,
                'customer_id' => $serviceRequest->customer_id,
            ]);
            // Don't fail the request if SMS fails - just log it
        }

        try {
            $techName = $serviceRequest->technician->user->name ?? 'the fundi';
            if ($serviceRequest->customer) {
                $this->fcm->sendToUser(
                    $serviceRequest->customer,
                    'Request Accepted',
                    "Your request has been accepted by {$techName}.",
                    $this->sanitizeData([
                        'request_id'       => $serviceRequest->id,
                        'status'           => 'accepted',
                        'type'             => 'request_accepted',
                        'technician_name'  => $techName,
                    ])
                );

                $this->createNotification(
                    $serviceRequest->customer_id,
                    'Request Accepted',
                    "Your request has been accepted by {$techName}",
                    'request_accepted',
                    [
                        'request_id'      => $serviceRequest->id,
                        'technician_id'   => $serviceRequest->technician_id,
                        'technician_name' => $techName,
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
                    'Sorry, your request has been rejected.',
                    $this->sanitizeData([
                        'request_id' => $serviceRequest->id,
                        'status'     => 'rejected',
                        'type'       => 'request_rejected',
                    ])
                );

                $this->createNotification(
                    $serviceRequest->customer_id,
                    'Request Rejected',
                    'Your request has been rejected',
                    'request_rejected',
                    ['request_id' => $serviceRequest->id]
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
                $techUser = $serviceRequest->technician->user;

                $this->fcm->sendToUser(
                    $techUser,
                    'Request Cancelled',
                    "Customer cancelled request #{$serviceRequest->id}.",
                    $this->sanitizeData([
                        'request_id' => $serviceRequest->id,
                        'status'     => 'cancelled',
                        'type'       => 'request_cancelled',
                    ])
                );

                // Fixed: notify the user account of the technician, not the technician_id
                $this->createNotification(
                    $techUser->id,
                    'Request Cancelled',
                    "Customer cancelled request #{$serviceRequest->id}",
                    'request_cancelled',
                    [
                        'request_id'    => $serviceRequest->id,
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
                    'Your request is now in progress.',
                    $this->sanitizeData([
                        'request_id' => $serviceRequest->id,
                        'status'     => 'in_progress',
                        'type'       => 'request_in_progress',
                    ])
                );

                $this->createNotification(
                    $serviceRequest->customer_id,
                    'Request In Progress',
                    'Your request is now in progress',
                    'request_in_progress',
                    ['request_id' => $serviceRequest->id]
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
            $techName = $serviceRequest->technician->user->name ?? 'the fundi';
            if ($serviceRequest->customer) {
                $this->fcm->sendToUser(
                    $serviceRequest->customer,
                    'Request Completed',
                    "Your request has been completed by {$techName}.",
                    $this->sanitizeData([
                        'request_id'      => $serviceRequest->id,
                        'status'          => 'completed',
                        'type'            => 'request_completed',
                        'technician_name' => $techName,
                    ])
                );

                $this->createNotification(
                    $serviceRequest->customer_id,
                    'Request Completed',
                    "Your request has been completed by {$techName}",
                    'request_completed',
                    [
                        'request_id'      => $serviceRequest->id,
                        'technician_id'   => $serviceRequest->technician_id,
                        'technician_name' => $techName,
                    ]
                );
            }
        } catch (\Exception $e) {
            Log::error('Failed to send completed notification: ' . $e->getMessage());
        }
    }

    private function handleOnTheWay(ServiceRequest $serviceRequest): void
    {
        $techName = $serviceRequest->technician->user->name ?? 'Your fundi';
        $this->notifyCustomer(
            $serviceRequest,
            'on_the_way',
            'Technician On The Way',
            "{$techName} is on the way to your location."
        );
    }

    private function handleArrived(ServiceRequest $serviceRequest): void
    {
        $techName = $serviceRequest->technician->user->name ?? 'Your fundi';
        $this->notifyCustomer(
            $serviceRequest,
            'arrived',
            'Technician Arrived',
            "{$techName} has arrived at your location."
        );
    }

    /**
     * Cancel a request (customer only, pending only)
     * DELETE /v4/requests/{id}/cancel
     */
    public function cancel($id, Request $request)
    {
        try {
            $serviceRequest = ServiceRequest::with(['technician.user', 'customer'])->findOrFail($id);
            $user           = $request->user();

            if (!$user) {
                return $this->forbidden('User not authenticated.');
            }

            if ($user->id !== $serviceRequest->customer_id || $serviceRequest->status !== 'pending') {
                return $this->forbidden('Cannot cancel this request.');
            }

            DB::beginTransaction();

            $oldStatus              = $serviceRequest->status;
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

            return $this->successResponse(
                $this->formatSingleRequest($serviceRequest),
                'Request cancelled successfully.'
            );
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
     * GET /v4/requests/my
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
                    'review',
                ])
                    ->where('customer_id', $user->id)
                    ->latest()
                    ->paginate($perPage);
                $data = $this->formatRequests($requests, $user->id);
            } elseif ($user->hasRole('FUNDI')) {
                $technician = $user->technician;
                if (!$technician) {
                    return $this->successResponse([
                        'data'       => [],
                        'pagination' => [
                            'total'        => 0,
                            'per_page'     => $perPage,
                            'current_page' => 1,
                            'last_page'    => 1,
                        ],
                    ], 'No requests found');
                }

                // Include customer (with phone) for Fundi app
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
     * GET /v4/requests
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
                'category',
                'logs' => function ($q) {
                    $q->latest()->limit(5);
                },
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
                $query->where(function ($q) use ($search) {
                    $q->where('description', 'like', "%{$search}%")
                      ->orWhereHas('customer', function ($cq) use ($search) {
                          $cq->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%");
                      })
                      ->orWhereHas('technician.user', function ($tq) use ($search) {
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

            $perPage  = $request->input('per_page', 20);
            $requests = $query->paginate($perPage);
            $data     = $this->formatRequests($requests);

            return $this->successResponse($data, 'Requests retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching requests: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Admin: show single request details
     * GET /v4/requests/{id}
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
                'category',
                'logs.user',
            ])->findOrFail($id);

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
     * DELETE /v4/requests/{id}
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
     * GET /v4/requests/{requestId}/logs
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
            Log::error('Error fetching request logs: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch logs. Please try again.', 500);
        }
    }

    /**
     * Get request statistics (admin)
     * GET /v4/requests/stats
     */
    public function stats(Request $request)
    {
        try {
            if (!$request->user()->can('requests.view')) {
                return $this->forbidden('Unauthorized. You need requests.view permission.');
            }

            $stats = [
                'total'       => ServiceRequest::count(),
                'pending'     => ServiceRequest::where('status', 'pending')->count(),
                'accepted'    => ServiceRequest::where('status', 'accepted')->count(),
                'on_the_way'  => ServiceRequest::where('status', 'on_the_way')->count(),
                'arrived'     => ServiceRequest::where('status', 'arrived')->count(),
                'in_progress' => ServiceRequest::where('status', 'in_progress')->count(),
                'completed'   => ServiceRequest::where('status', 'completed')->count(),
                'rejected'    => ServiceRequest::where('status', 'rejected')->count(),
                'cancelled'   => ServiceRequest::where('status', 'cancelled')->count(),
                'today'       => ServiceRequest::whereDate('created_at', today())->count(),
                'this_week'   => ServiceRequest::whereBetween('created_at', [now()->startOfWeek(), now()->endOfWeek()])->count(),
                'this_month'  => ServiceRequest::whereMonth('created_at', now()->month)->count(),
            ];

            return $this->successResponse($stats, 'Request statistics retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching request stats: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch statistics. Please try again.', 500);
        }
    }

    /**
     * Get requests for the authenticated customer
     * GET /v4/requests/customer
     */
    public function customerRequests(Request $request)
    {
        try {
            $user = $request->user();

            if (!$user || !$user->hasRole('CUSTOMER')) {
                return $this->forbidden('Only customers can view their requests.');
            }

            $perPage = $request->input('per_page', 15);
            $status  = $request->input('status');

            $query = ServiceRequest::with(['technician.user', 'service', 'category'])
                ->where('customer_id', $user->id);

            if ($status) {
                $query->where('status', $status);
            }

            $requests = $query->latest()->paginate($perPage);
            $data     = $this->formatRequests($requests, $user->id);

            return $this->successResponse($data, 'Customer requests retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching customer requests: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    /**
     * Get requests for the authenticated technician
     * GET /v4/requests/technician
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
                    'data'       => [],
                    'pagination' => [
                        'total'        => 0,
                        'per_page'     => 15,
                        'current_page' => 1,
                        'last_page'    => 1,
                    ],
                ], 'No requests found');
            }

            $perPage = $request->input('per_page', 15);
            $status  = $request->input('status');

            $query = ServiceRequest::with(['customer', 'service', 'category'])
                ->where('technician_id', $technician->id);

            if ($status) {
                $query->where('status', $status);
            }

            $requests = $query->latest()->paginate($perPage);
            $data     = $this->formatRequests($requests);

            return $this->successResponse($data, 'Technician requests retrieved successfully');
        } catch (\Exception $e) {
            Log::error('Error fetching technician requests: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch requests. Please try again.', 500);
        }
    }

    // ============================================================
    // TRACKING METHODS
    // ============================================================

    /**
     * Technician marks request as "On the Way"
     * PATCH /v4/requests/{id}/on-the-way
     */
    public function markOnTheWay(Request $request, $id)
    {
        try {
            $serviceRequest = ServiceRequest::with(['technician.user', 'customer'])->findOrFail($id);
            $user           = $request->user();

            if (!$this->isAssignedFundi($user, $serviceRequest)) {
                return $this->forbidden('You are not the technician assigned to this request.');
            }

            if ($serviceRequest->status !== 'accepted') {
                return $this->errorResponse('Request must be accepted first.', 422);
            }

            DB::beginTransaction();

            $oldStatus              = $serviceRequest->status;
            $serviceRequest->status = 'on_the_way';
            $serviceRequest->save();

            DB::commit();

            try {
                event(new RequestStatusUpdated($serviceRequest));
            } catch (\Exception $e) {
                Log::error('Failed to dispatch RequestStatusUpdated event: ' . $e->getMessage());
            }

            $this->handleOnTheWay($serviceRequest);

            $this->logRequestAction(
                $serviceRequest->id,
                $user->id,
                'on_the_way',
                $oldStatus,
                'on_the_way',
                'Technician is on the way'
            );
            $this->logAudit('mark_on_the_way', 'request', $serviceRequest->id, 'Technician marked on the way');

            return $this->successResponse(
                $this->formatSingleRequest($serviceRequest->fresh(['customer', 'technician.user', 'service', 'category'])),
                'Now on the way.'
            );
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error marking on the way: ' . $e->getMessage());
            return $this->errorResponse('Failed to update status. Please try again.', 500);
        }
    }

    /**
     * Technician marks request as "Arrived"
     * PATCH /v4/requests/{id}/arrive
     */
    public function markArrived(Request $request, $id)
    {
        try {
            $serviceRequest = ServiceRequest::with(['technician.user', 'customer'])->findOrFail($id);
            $user           = $request->user();

            if (!$this->isAssignedFundi($user, $serviceRequest)) {
                return $this->forbidden('You are not the technician assigned to this request.');
            }

            if ($serviceRequest->status !== 'on_the_way') {
                return $this->errorResponse('Must be on the way first.', 422);
            }

            DB::beginTransaction();

            $oldStatus              = $serviceRequest->status;
            $serviceRequest->status = 'arrived';
            $serviceRequest->save();

            DB::commit();

            try {
                event(new RequestStatusUpdated($serviceRequest));
            } catch (\Exception $e) {
                Log::error('Failed to dispatch RequestStatusUpdated event: ' . $e->getMessage());
            }

            $this->handleArrived($serviceRequest);

            $this->logRequestAction(
                $serviceRequest->id,
                $user->id,
                'arrived',
                $oldStatus,
                'arrived',
                'Technician arrived'
            );
            $this->logAudit('mark_arrived', 'request', $serviceRequest->id, 'Technician marked arrived');

            return $this->successResponse(
                $this->formatSingleRequest($serviceRequest->fresh(['customer', 'technician.user', 'service', 'category'])),
                'Arrived at location.'
            );
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error marking arrived: ' . $e->getMessage());
            return $this->errorResponse('Failed to update status. Please try again.', 500);
        }
    }

    /**
     * Get live tracking data for a request
     * GET /v4/requests/{id}/tracking
     */
    public function trackingData($id)
    {
        try {
            $request = ServiceRequest::with('technician')->findOrFail($id);

            $customerLat = $request->latitude ?? null;
            $customerLng = $request->longitude ?? null;
            $techLat     = $request->technician->latitude ?? null;
            $techLng     = $request->technician->longitude ?? null;

            $distance = null;
            $eta      = null;

            if ($customerLat && $customerLng && $techLat && $techLng) {
                $distance   = $this->haversineDistance($customerLat, $customerLng, $techLat, $techLng);
                $etaMinutes = $distance * 2; // ~30 km/h average
                $eta        = now()->addMinutes($etaMinutes)->toIso8601String();
            }

            return $this->successResponse([
                'technician_location' => [
                    'lat' => $techLat !== null ? (float) $techLat : null,
                    'lng' => $techLng !== null ? (float) $techLng : null,
                ],
                'customer_location' => [
                    'lat' => $customerLat !== null ? (float) $customerLat : null,
                    'lng' => $customerLng !== null ? (float) $customerLng : null,
                ],
                'status'       => $request->status,
                'distance_km'  => $distance !== null ? round($distance, 2) : null,
                'eta'          => $eta,
                'last_updated' => $request->technician->location_updated_at?->toIso8601String(),
            ], 'Tracking data retrieved.');
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Exception $e) {
            Log::error('Error fetching tracking data: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch tracking data.', 500);
        }
    }

    /**
     * Update customer location for a request
     * POST /v4/requests/{id}/location
     */
    public function updateLocation(Request $request, $id)
    {
        try {
            $serviceRequest = ServiceRequest::findOrFail($id);
            $user = $request->user();

            if (!$user || $user->id !== $serviceRequest->customer_id) {
                return $this->forbidden('You can only update location for your own requests.');
            }

            $data = $request->validate([
                'latitude'  => 'required|numeric|between:-90,90',
                'longitude' => 'required|numeric|between:-180,180',
            ]);

            $serviceRequest->latitude = $data['latitude'];
            $serviceRequest->longitude = $data['longitude'];
            $serviceRequest->save();

            Log::info('Customer location updated for request', [
                'request_id'  => $id,
                'customer_id' => $user->id,
                'latitude'    => $data['latitude'],
                'longitude'   => $data['longitude'],
            ]);

            return $this->successResponse([
                'request_id' => $id,
                'latitude'   => (float) $serviceRequest->latitude,
                'longitude'  => (float) $serviceRequest->longitude,
            ], 'Location updated successfully.');
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Request not found.');
        } catch (\Illuminate\Validation\ValidationException $e) {
            return $this->validationError($e->errors());
        } catch (\Exception $e) {
            Log::error('Error updating location: ' . $e->getMessage());
            return $this->errorResponse('Failed to update location. Please try again.', 500);
        }
    }

    // ============================================================
    // PRIVATE FORMATTING HELPERS
    // ============================================================

    private function formatRequests($requests, ?int $userId = null): array
    {
        $data = $requests->map(function ($request) use ($userId) {
            return $this->formatSingleRequest($request, $userId);
        });

        return [
            'data'       => $data,
            'pagination' => [
                'total'        => $requests->total(),
                'per_page'     => $requests->perPage(),
                'current_page' => $requests->currentPage(),
                'last_page'    => $requests->lastPage(),
            ],
        ];
    }

    private function formatSingleRequest($request, ?int $userId = null): array
    {
        $data = [
            'id'          => $request->id,
            'description' => $request->description,
            'status'      => $request->status,
            'created_at'  => $request->created_at,
            'updated_at'  => $request->updated_at,
            'customer'    => $request->customer ? [
                'id'    => $request->customer->id,
                'name'  => $request->customer->name,
                'email' => $request->customer->email,
                'phone' => $request->customer->phone,
            ] : null,
            'technician'  => $request->technician ? [
                'id'            => $request->technician->id,
                'name'          => $request->technician->user->name ?? null,
                'email'         => $request->technician->user->email ?? null,
                'phone'         => $request->technician->user->phone ?? null,
                'profile_photo' => $request->technician->profile_photo
                    ? url($request->technician->profile_photo)
                    : null,
                'area'      => $request->technician->area,
                'rating'    => (float) ($request->technician->rating ?? 0),
                'is_online' => (bool) ($request->technician->is_online ?? false),
            ] : null,
            'service'     => $request->service ? [
                'id'   => $request->service->id,
                'name' => $request->service->name,
            ] : null,
            'category'    => $request->category ? [
                'id'   => $request->category->service_categoryID,
                'name' => $request->category->category_name,
                'slug' => $request->category->slug,
            ] : null,
            'latitude'    => $request->latitude ? (float) $request->latitude : null,
            'longitude'   => $request->longitude ? (float) $request->longitude : null,
            'logs'        => $request->logs ? $request->logs->map(function ($log) {
                return [
                    'id'         => $log->id,
                    'action'     => $log->action,
                    'old_status' => $log->old_status,
                    'new_status' => $log->new_status,
                    'notes'      => $log->notes,
                    'created_at' => $log->created_at,
                    'user'       => $log->user ? [
                        'id'   => $log->user->id,
                        'name' => $log->user->name,
                    ] : null,
                ];
            }) : [],
        ];

        if ($userId !== null) {
            $hasReview = $request->relationLoaded('review')
                ? ($request->review !== null)
                : $request->review()->where('customer_id', $userId)->exists();
        } elseif (auth()->check()) {
            $hasReview = $request->review()->where('customer_id', auth()->id())->exists();
        } else {
            $hasReview = false;
        }

        $data['has_review'] = $hasReview;

        return $data;
    }
}