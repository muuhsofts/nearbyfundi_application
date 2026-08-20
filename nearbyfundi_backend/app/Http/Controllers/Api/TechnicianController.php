<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Technician;
use App\Models\Notification;
use App\Models\Subscription;
use App\Models\RateCard;
use Carbon\Carbon;
use App\Services\GeocodingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use App\Traits\Auditable;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\DB;
use App\Models\Otp;
use App\Mail\OtpMail;
use Illuminate\Support\Facades\Storage;
use Spatie\Permission\Models\Role;
use App\Models\ServiceRequest;

class TechnicianController extends BaseApiController
{
    use Auditable;

    // ──────────────────────────────────────────────
    // 4-STEP REGISTRATION
    // ──────────────────────────────────────────────

    /**
     * Step 1: Personal Information
     */
    public function registerStep1(Request $request)
    {
        $data = $request->validate([
            'name'          => 'required|string|max:255',
            'email'         => 'required|email|unique:users',
            'password'      => 'required|string|min:8|confirmed',
            'phone'         => 'nullable|string|max:20',
            'profile_photo' => 'nullable|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        DB::beginTransaction();
        try {
            $role = Role::where('name', 'FUNDI')->firstOrFail();

            $user = User::create([
                'name'       => $data['name'],
                'email'      => $data['email'],
                'password'   => Hash::make($data['password']),
                'phone'      => $data['phone'] ?? null,
                'status'     => 'pending',
                'is_active'  => false,
                'locale'     => 'en',
            ]);

            $user->assignRole($role);

            $technicianData = [
                'user_id'               => $user->id,
                'registration_step'     => 1,
                'registration_completed'=> false,
                'verified'              => false,
                'verification_status'   => 'pending',
                'is_online'             => false,
            ];

            if ($request->hasFile('profile_photo')) {
                $path = $request->file('profile_photo')->store('technicians', 'public');
                $technicianData['profile_photo'] = $path;
            }

            $technician = Technician::create($technicianData);

            // Generate OTP and send email
            $otp = Otp::create([
                'email'      => $user->email,
                'otp'        => Otp::generateOtp(),
                'token'      => Otp::generateToken(),
                'type'       => Otp::TYPE_EMAIL_VERIFICATION,
                'name'       => $user->name,
                'expires_at' => Carbon::now()->addMinutes(10),
                'is_used'    => false,
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);

            Mail::to($user->email)->send(
                new OtpMail(
                    $otp->otp,
                    $user->email,
                    $user->name,
                    Otp::TYPE_EMAIL_VERIFICATION,
                    $otp->getVerificationUrl()
                )
            );

            DB::commit();

            $this->logAudit('register_step1', 'technician', $technician->id, "Technician Step 1 completed for {$user->email}");

            return $this->successResponse([
                'technician_id' => $technician->id,
                'user'          => $user->only(['id', 'name', 'email', 'phone']),
                'step'          => 1,
            ], 'Step 1 completed. Proceed to identification.');
        } catch (\Exception $e) {
            DB::rollBack();
            return $this->serverError('Step 1 failed: ' . $e->getMessage());
        }
    }

    /**
     * Step 2: Identification Information (NIDA / Driver's License / Voter ID)
     */
    public function registerStep2(Request $request)
    {
        $request->validate([
            'technician_id'     => 'required|exists:technicians,id',
            'id_document_type'  => 'required|in:nida,drivers_license,voter_id',
            'id_document_image' => 'required|image|mimes:jpg,jpeg,png,webp|max:5120',
        ]);

        $technician = Technician::findOrFail($request->technician_id);

        if ($technician->registration_completed) {
            return $this->errorResponse('Registration already completed.', 422);
        }

        // Dynamic validation based on document type
        $nidaValue = $request->input('nida');
        switch ($request->id_document_type) {
            case 'nida':
                $request->validate(['nida' => 'required|string|size:20|unique:technicians,nida']);
                break;
            case 'voter_id':
                $request->validate(['nida' => 'required|string|size:12|unique:technicians,nida']);
                break;
            case 'drivers_license':
                $request->validate(['nida' => 'required|string|min:10|unique:technicians,nida']);
                break;
        }

        $path = $request->file('id_document_image')->store('technician_ids', 'public');

        $technician->update([
            'nida'                => $request->nida,
            'id_document_type'    => $request->id_document_type,
            'id_document_image'   => $path,
            'registration_step'   => 2,
        ]);

        $this->logAudit('register_step2', 'technician', $technician->id, "Technician Step 2 completed");

        return $this->successResponse(['step' => 2], 'Step 2 completed. Proceed to working area.');
    }

    /**
     * Step 3: Working Area (Place name or Lat/Lng)
     */
    public function registerStep3(Request $request, GeocodingService $geocoder)
    {
        $request->validate([
            'technician_id' => 'required|exists:technicians,id',
            'area'          => 'required|string|max:255',
            'latitude'      => 'nullable|numeric|between:-90,90',
            'longitude'     => 'nullable|numeric|between:-180,180',
        ]);

        $technician = Technician::findOrFail($request->technician_id);

        if ($technician->registration_completed) {
            return $this->errorResponse('Registration already completed.', 422);
        }

        $lat = $request->latitude;
        $lng = $request->longitude;

        if ($lat === null || $lng === null) {
            $coords = $geocoder->geocode($request->area);
            if (!$coords) {
                return $this->errorResponse("We couldn't locate '{$request->area}'. Please check spelling or use the map picker.", 422);
            }
            $lat = $coords['lat'];
            $lng = $coords['lng'];
        }

        $technician->update([
            'area'                => $request->area,
            'latitude'            => $lat,
            'longitude'           => $lng,
            'location_updated_at' => now(),
            'registration_step'   => 3,
        ]);

        $this->logAudit('register_step3', 'technician', $technician->id, "Technician Step 3 completed. Area: {$request->area}");

        return $this->successResponse(['step' => 3], 'Step 3 completed. Proceed to services & pricing.');
    }

    /**
     * Step 4: Services & Pricing
     */
    public function registerStep4(Request $request)
    {
        $request->validate([
            'technician_id' => 'required|exists:technicians,id',
            'services'      => 'required|array|min:1',
            'services.*.service_id' => 'required|exists:services,id',
            'services.*.min_price'  => 'required|numeric|min:0',
            'services.*.max_price'  => 'required|numeric|min:0|gte:services.*.min_price',
        ]);

        $technician = Technician::findOrFail($request->technician_id);

        if ($technician->registration_completed) {
            return $this->errorResponse('Registration already completed.', 422);
        }

        DB::beginTransaction();
        try {
            $syncData = [];
            foreach ($request->services as $service) {
                $syncData[$service['service_id']] = [
                    'min_price' => $service['min_price'],
                    'max_price' => $service['max_price'],
                ];
            }

            $technician->servicePrices()->sync($syncData);
            $technician->update(['registration_step' => 4]);

            DB::commit();

            $this->logAudit('register_step4', 'technician', $technician->id, "Technician Step 4 completed. Services synced.");

            return $this->successResponse(['step' => 4], 'Step 4 completed. You may now submit your registration.');
        } catch (\Exception $e) {
            DB::rollBack();
            return $this->serverError('Step 4 failed: ' . $e->getMessage());
        }
    }

    /**
 * Get the registration step for a technician (public endpoint)
 */
public function registrationStatus($id)
{
    $technician = Technician::find($id);
    if (!$technician) {
        return $this->notFound('Technician not found.');
    }

    return $this->successResponse([
        'registration_step'        => $technician->registration_step,
        'registration_completed'   => $technician->registration_completed,
        'technician_id'            => $technician->id,
    ]);
}

    /**
     * Final Submit Registration
     */
    public function submitRegistration(Request $request)
    {
        $request->validate([
            'technician_id' => 'required|exists:technicians,id',
        ]);

        $technician = Technician::with('servicePrices')->findOrFail($request->technician_id);

        if ($technician->registration_step < 4) {
            return $this->errorResponse('Please complete all 4 registration steps first.', 422);
        }

        if ($technician->registration_completed) {
            return $this->errorResponse('Registration already submitted.', 422);
        }

        if ($technician->servicePrices->isEmpty()) {
            return $this->errorResponse('You must select at least one service with a price range.', 422);
        }

        $technician->update([
            'registration_completed' => true,
            'verification_status'    => 'pending',
            'verified'               => false,
        ]);

        $technician->user->update(['status' => 'pending']);

        $this->logAudit('submit_registration', 'technician', $technician->id, "Technician submitted registration for approval.");

        return $this->successResponse([
            'message' => 'Registration submitted. Please wait for admin verification.',
            'status'  => 'pending_verification',
        ], 'Registration submitted successfully.');
    }

    // ──────────────────────────────────────────────
    // ADMIN: APPROVE TECHNICIAN (with 1-day free trial)
    // ──────────────────────────────────────────────

    public function approve($id)
    {
        $technician = Technician::findOrFail($id);

        if (!$technician->registration_completed) {
            return $this->errorResponse('Technician has not completed registration.', 422);
        }

        DB::beginTransaction();
        try {
            $technician->verification_status = 'approved';
            $technician->verified = true;
            $technician->save();

            $user = $technician->user;
            $user->update([
                'status'    => 'active',
                'is_active' => true,
            ]);

            $freeTrialRate = RateCard::where('slug', 'free-trial')->first();
            if (!$freeTrialRate) {
                $freeTrialRate = RateCard::create([
                    'name'          => 'Free Trial',
                    'slug'          => 'free-trial',
                    'price'         => 0,
                    'duration_days' => 1,
                    'currency'      => 'TZS',
                    'description'   => '1-day free trial after verification',
                    'is_active'     => true,
                    'display_order' => 0,
                ]);
            }

            $subscription = Subscription::create([
                'user_id'        => $user->id,
                'rate_card_id'   => $freeTrialRate->id,
                'status'         => Subscription::STATUS_ACTIVE,
                'start_date'     => now(),
                'expiry_date'    => now()->addDay(),
                'amount_paid'    => 0,
                'currency'       => 'TZS',
                'payment_method' => 'Free Trial',
                'approved_at'    => now(),
                'approved_by'    => auth()->id(),
            ]);

            $user->activateSubscription($subscription);

            $this->createNotification(
                $user->id,
                'Account Approved 🎉',
                'Your fundi account has been approved! You now have a 1-day free trial.',
                'technician_approved',
                [
                    'technician_id' => $technician->id,
                    'trial_expires' => $subscription->expiry_date->toIso8601String(),
                ]
            );

            DB::commit();

            $this->logAudit('approve_technician', 'technician', $technician->id, "Technician #{$id} approved and free trial activated");

            return $this->successResponse($technician, 'Technician approved and free trial activated.');
        } catch (\Exception $e) {
            DB::rollBack();
            return $this->serverError('Approval failed: ' . $e->getMessage());
        }
    }

    // ──────────────────────────────────────────────
    // PROFILE MANAGEMENT (Technician)
    // ──────────────────────────────────────────────

    public function getOwnProfile(Request $request)
    {
        $technician = $request->user()->technician()->with('servicePrices', 'portfolios', 'user')->first();
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        $technician->makeVisible('nida');

        return $this->successResponse($technician);
    }

    public function updateProfile(Request $request, GeocodingService $geocoder)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        $data = $request->validate([
            'bio'         => 'nullable|string',
            'hourly_rate' => 'nullable|numeric|min:0|max:999999.99',
            'area'        => 'nullable|string|max:255',
            'latitude'    => 'nullable|numeric|between:-90,90',
            'longitude'   => 'nullable|numeric|between:-180,180',
        ]);

        $updateData = $request->only(['bio', 'hourly_rate', 'area', 'latitude', 'longitude']);

        if ($request->has('area') && !$request->has('latitude') && !$request->has('longitude')) {
            $coords = $this->validateAndGeocodeArea($request->area, null, null, $geocoder);
            $updateData['latitude'] = $coords['lat'];
            $updateData['longitude'] = $coords['lng'];
        }

        $technician->update($updateData);
        $this->logAudit('update_technician_profile', 'technician', $technician->id, 'Profile updated');

        return $this->successResponse($technician->load('servicePrices'), 'Profile updated.');
    }

    public function uploadProfilePhoto(Request $request)
    {
        $request->validate([
            'profile_photo' => 'required|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        if ($technician->profile_photo && Storage::disk('public')->exists($technician->profile_photo)) {
            Storage::disk('public')->delete($technician->profile_photo);
        }

        $path = $request->file('profile_photo')->store('technicians', 'public');
        $technician->update(['profile_photo' => $path]);

        $this->logAudit('upload_profile_photo', 'technician', $technician->id, 'Profile photo updated');

        return $this->successResponse([
            'profile_photo' => url('storage/' . $path),
        ], 'Profile photo updated successfully.');
    }

    public function updateServicePrices(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician not found.');
        }

        $data = $request->validate([
            'prices' => 'required|array',
            'prices.*.service_id' => 'required|exists:services,id',
            'prices.*.min_price' => 'required|numeric|min:0',
            'prices.*.max_price' => 'required|numeric|min:0|gte:prices.*.min_price',
        ]);

        $syncData = [];
        foreach ($data['prices'] as $price) {
            $syncData[$price['service_id']] = [
                'min_price' => $price['min_price'],
                'max_price' => $price['max_price'],
            ];
        }

        $technician->servicePrices()->sync($syncData);

        $this->logAudit('update_service_prices', 'technician', $technician->id, 'Updated service prices');

        return $this->successResponse(
            $technician->load('servicePrices'),
            'Prices updated successfully.'
        );
    }

    // ──────────────────────────────────────────────
    // LOCATION & ONLINE STATUS HELPERS
    // ──────────────────────────────────────────────

    public function updateLocation(Request $request)
    {
        $request->validate([
            'latitude'  => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
        ]);

        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        $technician->update([
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
            'location_updated_at' => now(),
        ]);

        return $this->successResponse(null, 'Location updated.');
    }

    public function toggleOnline(Request $request)
    {
        $request->validate(['is_online' => 'required|boolean']);

        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        $technician->is_online = $request->is_online;
        if ($request->is_online) {
            $technician->last_activity_at = now();
        }
        $technician->save();

        return $this->successResponse(['is_online' => $technician->is_online], 'Online status updated.');
    }

    public function heartbeat(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        $technician->recordHeartbeat(
            $request->input('latitude'),
            $request->input('longitude')
        );

        return $this->successResponse(null, 'Heartbeat recorded.');
    }

    // ──────────────────────────────────────────────
    // PUBLIC ENDPOINTS
    // ──────────────────────────────────────────────

    public function publicIndex(Request $request)
    {
        $query = Technician::with([
            'user',
            'services',
            'servicePrices',
            'portfolios',
        ])
        ->where('verified', true)
        ->whereHas('user', function ($q) {
            $q->where('is_active', true);
        });

        if ($request->filled('service_id')) {
            $query->whereHas('services', function ($q) use ($request) {
                $q->where('services.id', $request->service_id);
            });
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('area', 'LIKE', "%{$search}%")
                  ->orWhereHas('user', function ($userQuery) use ($search) {
                      $userQuery->where('name', 'LIKE', "%{$search}%");
                  })
                  ->orWhereHas('services', function ($serviceQuery) use ($search) {
                      $serviceQuery->where('name', 'LIKE', "%{$search}%")
                                   ->orWhere('swahili_name', 'LIKE', "%{$search}%");
                  });
            });
        }

        $technicians = $query->paginate($request->input('per_page', 15));

        return $this->successResponse($technicians);
    }

  
    public function show($id)
{
    $technician = Technician::with([
        'user',
        'services',
        'servicePrices',
        'portfolios',
        'user.subscriptions.rateCard' 
    ])->find($id);

    if (!$technician) {
        return $this->notFound('Technician not found.');
    }

    // If the user has permission, expose sensitive fields
    if (auth()->user() && auth()->user()->can('technicians.view')) {
        $technician->makeVisible([
            'nida',
            'id_document_type',
            'id_document_image',
            'registration_step',
            'registration_completed',
            'verification_status',
            'verified',
            'is_online',
            'last_activity_at',
            'location_updated_at',
        ]);
    }

    return $this->successResponse($technician);
}

    // ──────────────────────────────────────────────
    // NEARBY & SEARCH
    // ──────────────────────────────────────────────

    public function nearby(Request $request)
    {
        $request->validate([
            'lat'         => 'required|numeric|between:-90,90',
            'lng'         => 'required|numeric|between:-180,180',
            'radius'      => 'nullable|integer|min:1|max:100',
            'service_id'  => 'nullable|exists:services,id',
            'category_id' => 'nullable|exists:service_categories,service_categoryID',
            'search'      => 'nullable|string|max:255',
        ]);

        $lat       = (float) $request->input('lat');
        $lng       = (float) $request->input('lng');
        $radius    = (int) $request->input('radius', 10);
        $serviceId = $request->input('service_id');
        $categoryId = $request->input('category_id');
        $searchText = $request->input('search');

        $query = Technician::with(['user', 'services.categories'])
            ->where('verified', true)
            ->whereHas('user', fn($q) => $q->where('is_active', true));

        if ($searchText) {
            $query->whereHas('services', function ($q) use ($searchText) {
                $q->where('name', 'LIKE', "%{$searchText}%")
                  ->orWhere('swahili_name', 'LIKE', "%{$searchText}%");
            });
        }

        if ($serviceId) {
            $query->whereHas('services', fn($q) => $q->where('services.id', $serviceId));
        }

        if ($categoryId) {
            $query->whereHas('services.categories', function ($q) use ($categoryId) {
                $q->where('service_categories.service_categoryID', $categoryId);
            });
        }

        $query->selectRaw("
            technicians.*,
            (
                6371 * acos(
                    cos(radians(?)) * cos(radians(latitude)) *
                    cos(radians(longitude) - radians(?)) +
                    sin(radians(?)) * sin(radians(latitude))
                )
            ) AS distance
        ", [$lat, $lng, $lat]);

        $query->having('distance', '<=', $radius);
        $query->orderBy('distance', 'asc');

        $technicians = $query->get();

        $formatted = $technicians->map(function ($tech) {
            return [
                'id'            => $tech->id,
                'user_id'       => $tech->user_id,
                'name'          => $tech->user->name ?? 'Unknown',
                'email'         => $tech->user->email ?? '',
                'phone'         => $tech->user->phone ?? '',
                'profile_photo' => $tech->profile_photo ? url('storage/' . $tech->profile_photo) : null,
                'bio'           => $tech->bio,
                'area'          => $tech->area,
                'latitude'      => $tech->latitude ? (float) $tech->latitude : null,
                'longitude'     => $tech->longitude ? (float) $tech->longitude : null,
                'hourly_rate'   => $tech->hourly_rate ? (float) $tech->hourly_rate : null,
                'experience'    => (int) ($tech->experience ?? 0),
                'rating'        => (float) ($tech->rating ?? 0),
                'is_online'     => (bool) $tech->is_online,
                'verified'      => (bool) $tech->verified,
                'distance'      => isset($tech->distance) ? (float) round($tech->distance, 2) : null,
                'services'      => $tech->services->pluck('name')->toArray(),
                'service_prices'=> $tech->servicePrices->map(function ($service) {
                    return [
                        'id'        => $service->id,
                        'name'      => $service->name,
                        'min_price' => (float) $service->pivot->min_price,
                        'max_price' => (float) $service->pivot->max_price,
                    ];
                })->values()->toArray(),
            ];
        });

        if ($formatted->isEmpty()) {
            return $this->successResponse([
                'technicians' => [],
                'search' => [
                    'latitude'  => $lat,
                    'longitude' => $lng,
                    'radius'    => $radius,
                ],
                'filters' => [
                    'service_id'  => $serviceId,
                    'category_id' => $categoryId,
                ],
                'meta' => [
                    'total_found' => 0,
                    'has_filters' => !empty($serviceId) || !empty($categoryId),
                ]
            ], 'No technicians found within radius.');
        }

        return $this->successResponse([
            'technicians' => $formatted,
            'search' => [
                'latitude'  => $lat,
                'longitude' => $lng,
                'radius'    => $radius,
            ],
            'filters' => [
                'service_id'  => $serviceId,
                'category_id' => $categoryId,
            ],
            'meta' => [
                'total_found' => $formatted->count(),
                'has_filters' => !empty($serviceId) || !empty($categoryId),
            ]
        ], 'Technicians found within radius.');
    }

    public function nearbyByPlace(Request $request, GeocodingService $geocoder)
    {
        $request->validate([
            'place'       => 'required|string|max:255',
            'service_id'  => 'nullable|exists:services,id',
            'category_id' => 'nullable|exists:service_categories,service_categoryID',
            'radius'      => 'nullable|integer|min:1|max:100',
            'search'      => 'nullable|string|max:255',
        ]);

        $place      = trim($request->input('place'));
        $radius     = $request->input('radius', 20);
        $serviceId  = $request->input('service_id');
        $categoryId = $request->input('category_id');
        $searchText = $request->input('search');

        $coords = $geocoder->geocode($place);

        $query = Technician::with(['user', 'services.categories'])
            ->where('verified', true)
            ->whereHas('user', fn($q) => $q->where('is_active', true));

        if ($searchText) {
            $query->whereHas('services', function ($q) use ($searchText) {
                $q->where('name', 'LIKE', "%{$searchText}%")
                  ->orWhere('swahili_name', 'LIKE', "%{$searchText}%");
            });
        }

        if ($serviceId) {
            $query->whereHas('services', fn($q) => $q->where('services.id', $serviceId));
        }

        if ($categoryId) {
            $query->whereHas('services.categories', function ($q) use ($categoryId) {
                $q->where('service_categories.service_categoryID', $categoryId);
            });
        }

        if ($coords) {
            $query->selectRaw("
                technicians.*,
                (
                    6371 * acos(
                        cos(radians(?)) * cos(radians(latitude)) *
                        cos(radians(longitude) - radians(?)) +
                        sin(radians(?)) * sin(radians(latitude))
                    )
                ) AS distance
            ", [$coords['lat'], $coords['lng'], $coords['lat']]);

            $query->where(function ($q) use ($place, $radius, $coords) {
                $q->where('area', 'like', "%{$place}%")
                  ->orWhereRaw("
                        (6371 * acos(
                            cos(radians(?)) * cos(radians(latitude)) *
                            cos(radians(longitude) - radians(?)) +
                            sin(radians(?)) * sin(radians(latitude))
                        )) <= ?
                    ", [$coords['lat'], $coords['lng'], $coords['lat'], $radius]);
            });

            $query->orderBy('distance', 'asc');
        } else {
            $query->where('area', 'like', "%{$place}%");
        }

        $technicians = $query->get();

        if ($technicians->isEmpty()) {
            return $this->successResponse([
                'technicians' => [],
                'search' => [
                    'place'     => $place,
                    'latitude'  => $coords['lat'] ?? null,
                    'longitude' => $coords['lng'] ?? null,
                ],
                'filters' => [
                    'service_id'  => $serviceId,
                    'category_id' => $categoryId,
                ],
                'meta' => [
                    'total_found' => 0,
                    'has_filters' => !empty($serviceId) || !empty($categoryId),
                ]
            ], 'No technicians found.');
        }

        $formatted = $technicians->map(function ($tech) {
            return [
                'id'            => $tech->id,
                'user_id'       => $tech->user_id,
                'name'          => $tech->user->name ?? 'Unknown',
                'email'         => $tech->user->email ?? '',
                'phone'         => $tech->user->phone ?? '',
                'profile_photo' => $tech->profile_photo ? url('storage/' . $tech->profile_photo) : null,
                'bio'           => $tech->bio,
                'area'          => $tech->area,
                'latitude'      => $tech->latitude ? (float) $tech->latitude : null,
                'longitude'     => $tech->longitude ? (float) $tech->longitude : null,
                'hourly_rate'   => $tech->hourly_rate ? (float) $tech->hourly_rate : null,
                'experience'    => (int) ($tech->experience ?? 0),
                'rating'        => (float) ($tech->rating ?? 0),
                'is_online'     => (bool) $tech->is_online,
                'verified'      => (bool) $tech->verified,
                'distance'      => isset($tech->distance) ? (float) round($tech->distance, 2) : null,
                'services'      => $tech->services->pluck('name')->toArray(),
                'service_prices'=> $tech->servicePrices->map(function ($service) {
                    return [
                        'id'        => $service->id,
                        'name'      => $service->name,
                        'min_price' => (float) $service->pivot->min_price,
                        'max_price' => (float) $service->pivot->max_price,
                    ];
                })->values()->toArray(),
            ];
        });

        return $this->successResponse([
            'technicians' => $formatted,
            'search' => [
                'place'     => $place,
                'latitude'  => $coords['lat'] ?? null,
                'longitude' => $coords['lng'] ?? null,
            ],
            'filters' => [
                'service_id'  => $serviceId,
                'category_id' => $categoryId,
            ],
            'meta' => [
                'total_found' => $formatted->count(),
                'has_filters' => !empty($serviceId) || !empty($categoryId),
            ]
        ], 'Technicians found.');
    }

    // ──────────────────────────────────────────────
    // TRACKING DATA
    // ──────────────────────────────────────────────

    public function getTrackingData(Request $request, $requestId)
    {
        $requestModel = ServiceRequest::with(['technician', 'customer'])->findOrFail($requestId);

        $technician = $requestModel->technician;
        $customer = $requestModel->customer;

        if (!$technician || !$customer) {
            return $this->notFound('Technician or Customer not found.');
        }

        $techLat = $technician->latitude;
        $techLng = $technician->longitude;
        $custLat = $requestModel->latitude ?? $customer->latitude;
        $custLng = $requestModel->longitude ?? $customer->longitude;

        if (is_null($techLat) || is_null($techLng)) {
            return $this->successResponse([
                'technician_location' => null,
                'customer_location' => ['lat' => $custLat, 'lng' => $custLng],
                'distance_km' => null,
                'eta' => null,
            ], 'Technician location not available yet.');
        }

        $distance = $this->haversineGreatCircleDistance($techLat, $techLng, $custLat, $custLng);
        $etaMinutes = $distance > 0 ? ($distance / 30) * 60 : 0;
        $etaTime = now()->addMinutes($etaMinutes);

        return $this->successResponse([
            'technician_location' => [
                'lat' => (float) $techLat,
                'lng' => (float) $techLng,
            ],
            'customer_location' => [
                'lat' => (float) $custLat,
                'lng' => (float) $custLng,
            ],
            'distance_km' => round($distance, 2),
            'eta' => $etaTime->toIso8601String(),
        ], 'Tracking data retrieved.');
    }

    // ──────────────────────────────────────────────
    // ADMIN: VERIFY TECHNICIAN
    // ──────────────────────────────────────────────

    // ──────────────────────────────────────────────
// ADMIN: VERIFY TECHNICIAN (with free trial)
// ──────────────────────────────────────────────

public function verify($id)
{
    $technician = Technician::with('user')->find($id);

    if (!$technician) {
        return $this->notFound('Technician not found.');
    }

    DB::beginTransaction();
    try {
        // Mark technician as verified
        $technician->update([
            'verified'            => true,
            'verification_status' => 'approved',
        ]);

        $user = $technician->user;
        if ($user) {
            $user->update([
                'status'    => 'active',
                'is_active' => true,
            ]);
        }

        // Create or fetch the free trial rate card
        $freeTrialRate = RateCard::where('slug', 'free-trial')->first();
        if (!$freeTrialRate) {
            $freeTrialRate = RateCard::create([
                'name'          => 'Free Trial',
                'slug'          => 'free-trial',
                'price'         => 0,
                'duration_days' => 1,
                'currency'      => 'TZS',
                'description'   => '1-day free trial after verification',
                'is_active'     => true,
                'display_order' => 0,
            ]);
        }

        // Create the free trial subscription
        $subscription = Subscription::create([
            'user_id'        => $user->id,
            'rate_card_id'   => $freeTrialRate->id,
            'status'         => Subscription::STATUS_ACTIVE,
            'start_date'     => now(),
            'expiry_date'    => now()->addDay(),
            'amount_paid'    => 0,
            'currency'       => 'TZS',
            'payment_method' => 'Free Trial',
            'approved_at'    => now(),
            'approved_by'    => auth()->id(),
        ]);

        // Activate the subscription on the user
        $user->activateSubscription($subscription);

        // Send notification
        $this->createNotification(
            $user->id,
            'Account Verified 🎉',
            'Your fundi account has been verified! You now have a 1-day free trial.',
            'technician_verified',
            [
                'technician_id' => $technician->id,
                'trial_expires' => $subscription->expiry_date->toIso8601String(),
            ]
        );

        DB::commit();

        $this->logAudit('verify_technician', 'technician', $technician->id, "Technician #{$technician->id} verified and free trial activated");

        return $this->successResponse(
            $technician->fresh()->load('user'),
            'Technician verified successfully and free trial activated.'
        );
    } catch (\Exception $e) {
        DB::rollBack();
        return $this->serverError('Verification failed: ' . $e->getMessage());
    }
}

    
    // ──────────────────────────────────────────────
    // ADMIN: UPDATE SERVICES (legacy)
    // ──────────────────────────────────────────────

    public function updateServices(Request $request)
    {
        $technician = $request->user()->technician;

        if (!$technician) {
            return $this->notFound('Technician not found.');
        }

        $data = $request->validate([
            'services'   => 'required|array|min:1',
            'services.*' => 'exists:services,id',
        ]);

        $technician->services()->sync($data['services']);

        $this->logAudit('update_technician_services', 'technician', $technician->id, 'Technician services updated');

        return $this->successResponse(
            $technician->load('services'),
            'Services updated successfully.'
        );
    }

    // ──────────────────────────────────────────────
    // PRIVATE HELPERS
    // ──────────────────────────────────────────────

    private function validateAndGeocodeArea(string $area, ?float $lat, ?float $lng, GeocodingService $geocoder): array
    {
        if ($lat !== null && $lng !== null) {
            if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
                abort(422, 'Invalid coordinates provided.');
            }
            return ['lat' => $lat, 'lng' => $lng];
        }

        $coords = $geocoder->geocode($area);
        if (!$coords) {
            $message = "We couldn't locate '{$area}' in OpenStreetMap. ";
            $message .= "Please check the spelling or enter a more specific location.";
            abort(422, $message);
        }
        return $coords;
    }

    private function createNotification(int $userId, string $title, string $body, string $type, array $data = []): void
    {
        try {
            Notification::create([
                'user_id' => $userId,
                'title'   => $title,
                'body'    => $body,
                'type'    => $type,
                'data'    => json_encode($data),
                'is_read' => false,
            ]);
        } catch (\Exception $e) {
            \Log::error('Failed to create notification: ' . $e->getMessage());
        }
    }

    private function haversineGreatCircleDistance($latitudeFrom, $longitudeFrom, $latitudeTo, $longitudeTo, $earthRadius = 6371)
    {
        $latFrom = deg2rad($latitudeFrom);
        $lonFrom = deg2rad($longitudeFrom);
        $latTo = deg2rad($latitudeTo);
        $lonTo = deg2rad($longitudeTo);

        $latDelta = $latTo - $latFrom;
        $lonDelta = $lonTo - $lonFrom;

        $angle = 2 * asin(sqrt(pow(sin($latDelta / 2), 2) +
            cos($latFrom) * cos($latTo) * pow(sin($lonDelta / 2), 2)));
        return $angle * $earthRadius;
    }

    // This method is used internally, kept for completeness
    public function uploadImage($file)
    {
        if (!$file || !$file->isValid()) {
            return null;
        }

        return $file->store('technicians', 'public');
    }

    /**
 * Admin: List all technicians (no filters)
 */
public function adminIndex(Request $request)
{
    $this->checkPermission('technicians.view'); // reuse existing permission

    $query = Technician::with([
        'user',
        'services',
        'servicePrices',
        'portfolios'
    ]);

    // Optional search
    if ($request->filled('search')) {
        $search = $request->search;
        $query->where(function ($q) use ($search) {
            $q->where('area', 'LIKE', "%{$search}%")
              ->orWhereHas('user', function ($uq) use ($search) {
                  $uq->where('name', 'LIKE', "%{$search}%")
                     ->orWhere('email', 'LIKE', "%{$search}%");
              });
        });
    }

    $technicians = $query->paginate($request->input('per_page', 15));

    return $this->successResponse($technicians);
}
}