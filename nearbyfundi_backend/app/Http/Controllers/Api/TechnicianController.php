<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Otp;
use App\Models\Technician;
use App\Models\Service;
use App\Models\ServiceCategory;
use Carbon\Carbon;
use App\Services\GeocodingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use App\Traits\Auditable;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Spatie\Permission\Models\Role;

class TechnicianController extends BaseApiController
{
    use Auditable;

    // =============================================
    // CUSTOMER REGISTRATION
    // =============================================
    public function register(Request $request)
    {
        $data = $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users',
            'password' => 'required|string|min:8|confirmed',
            'phone'    => 'nullable|string|max:20',
        ]);

        DB::beginTransaction();
        try {
            $role = Role::where('name', 'CUSTOMER')->firstOrFail();

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
            $this->logAudit('register', 'auth', 'user', "Customer registered: {$user->email}");
            return $this->created(['email' => $user->email], 'Registration successful. Please verify email.');
        } catch (\Exception $e) {
            DB::rollBack();
            return $this->serverError('Registration failed: ' . $e->getMessage());
        }
    }

    // =============================================
    // FUNDI REGISTRATION (WITH OSM VALIDATION)
    // =============================================
    public function registerFundi(Request $request, GeocodingService $geocoder)
    {
        $data = $request->validate([
            'name'          => 'required|string|max:255',
            'email'         => 'required|email|unique:users',
            'password'      => 'required|string|min:8|confirmed',
            'phone'         => 'nullable|string|max:20',
            'bio'           => 'nullable|string',
            'nida'          => 'required|string|size:20|unique:technicians,nida',
            'experience'    => 'nullable|integer|min:0',
            'hourly_rate'   => 'nullable|numeric|min:0|max:999999.99',
            'area'          => 'required|string|max:255',
            'latitude'      => 'nullable|numeric|between:-90,90',
            'longitude'     => 'nullable|numeric|between:-180,180',
            'service_ids'   => 'required|array|min:1',
            'service_ids.*' => 'exists:services,id',
            'profile_photo' => 'required|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        $coords = $this->validateAndGeocodeArea(
            $data['area'], 
            $data['latitude'] ?? null, 
            $data['longitude'] ?? null, 
            $geocoder
        );
        $data['latitude']  = $coords['lat'];
        $data['longitude'] = $coords['lng'];

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
                'user_id'             => $user->id,
                'bio'                 => $data['bio'] ?? null,
                'nida'                => $data['nida'],
                'experience'          => $data['experience'] ?? 0,
                'hourly_rate'         => $data['hourly_rate'] ?? null,
                'area'                => $data['area'],
                'latitude'            => $data['latitude'],
                'longitude'           => $data['longitude'],
                'location_updated_at' => now(),
                'verified'            => false,
                'is_online'           => false,
            ];

            $technicianData['profile_photo'] = $this->uploadImage($request->file('profile_photo'));

            $technician = Technician::create($technicianData);
            $technician->services()->sync($data['service_ids']);

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
            $this->logAudit('register_fundi', 'auth', 'user', "Fundi registered: {$user->email}");
            return $this->created(['email' => $user->email], 'Fundi registered. Verify email and wait for admin approval.');
        } catch (\Exception $e) {
            DB::rollBack();
            return $this->serverError('Registration failed: ' . $e->getMessage());
        }
    }

       /**
     * SEARCH TECHNICIANS BY PLACE WITH SERVICE AND CATEGORY FILTERS
     * GET /v1/technicians/nearby-by-place
     * Supports Swahili search
     */
    public function nearbyByPlace(Request $request, GeocodingService $geocoder)
    {
        $request->validate([
            'place'       => 'required|string|max:255',
            'service_id'  => 'nullable|exists:services,id',
            'category_id' => 'nullable|exists:service_categories,service_categoryID',
            'radius'      => 'nullable|integer|min:1|max:100',
            'search'      => 'nullable|string|max:255', // For text search
        ]);

        $place      = trim($request->input('place'));
        $radius     = $request->input('radius', 20);
        $serviceId  = $request->input('service_id');
        $categoryId = $request->input('category_id');
        $searchText = $request->input('search');
        $locale = $request->header('Accept-Language', 'en');

        $coords = $geocoder->geocode($place);

        $query = Technician::with(['user', 'services', 'services.categories'])
            ->where('verified', true)
            ->whereHas('user', fn($q) => $q->where('is_active', true));

        // Search in both English and Swahili service names
        if ($searchText) {
            $query->whereHas('services', function($q) use ($searchText) {
                $q->where('name', 'LIKE', "%{$searchText}%")
                  ->orWhere('swahili_name', 'LIKE', "%{$searchText}%");
            });
        }

        if ($serviceId) {
            $query->whereHas('services', function($q) use ($serviceId) {
                $q->where('services.id', $serviceId);
            });
        }

        if ($categoryId) {
            $query->whereHas('services.categories', function($q) use ($categoryId) {
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

        $serviceName = null;
        $categoryName = null;
        
        if ($serviceId) {
            $service = Service::find($serviceId);
            $serviceName = $service ? $service->getNameForLocale($locale) : null;
        }

        if ($categoryId) {
            $category = ServiceCategory::find($categoryId);
            $categoryName = $category ? $category->getNameForLocale($locale) : null;
        }

        if ($technicians->isEmpty()) {
            $totalQuery = Technician::with(['user', 'services'])
                ->where('verified', true)
                ->whereHas('user', fn($q) => $q->where('is_active', true));

            if ($coords) {
                $totalQuery->selectRaw("
                    technicians.*,
                    (
                        6371 * acos(
                            cos(radians(?)) * cos(radians(latitude)) *
                            cos(radians(longitude) - radians(?)) +
                            sin(radians(?)) * sin(radians(latitude))
                        )
                    ) AS distance
                ", [$coords['lat'], $coords['lng'], $coords['lat']]);

                $totalQuery->where(function ($q) use ($place, $radius, $coords) {
                    $q->where('area', 'like', "%{$place}%")
                      ->orWhereRaw("
                            (6371 * acos(
                                cos(radians(?)) * cos(radians(latitude)) *
                                cos(radians(longitude) - radians(?)) +
                                sin(radians(?)) * sin(radians(latitude))
                            )) <= ?
                        ", [$coords['lat'], $coords['lng'], $coords['lat'], $radius]);
                });
            } else {
                $totalQuery->where('area', 'like', "%{$place}%");
            }

            $totalTechnicians = $totalQuery->count();

            $message = $locale === 'sw' 
                ? "Hakuna mafundi waliopatikana karibu na '{$place}'"
                : "No technicians found near '{$place}'";
            
            $suggestions = $locale === 'sw'
                ? ['Jaribu kuondoa vichujio', 'Jaribu eneo lingine', 'Jaribu huduma nyingine']
                : ['Try removing filters', 'Try a different location', 'Try a different service'];

            return $this->successResponse([
                'technicians' => [],
                'search' => [
                    'place'     => $place,
                    'latitude'  => $coords['lat'] ?? null,
                    'longitude' => $coords['lng'] ?? null,
                ],
                'filters' => [
                    'service_id' => $serviceId,
                    'service_name' => $serviceName,
                    'category_id' => $categoryId,
                    'category_name' => $categoryName,
                ],
                'meta' => [
                    'total_technicians_nearby' => $totalTechnicians,
                    'has_filters' => ($serviceId || $categoryId),
                    'suggestions' => $suggestions,
                ]
            ], $message, 200);
        }

        $formatted = $technicians->map(function ($tech) use ($locale) {
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
                'experience'    => $tech->experience ? (int) $tech->experience : 0,
                'rating'        => (float) ($tech->rating ?? 0),
                'is_online'     => (bool) $tech->is_online,
                'verified'      => (bool) $tech->verified,
                'distance'      => isset($tech->distance) ? (float) round($tech->distance, 2) : null,
                'services'      => $tech->services->map(function($service) use ($locale) {
                    return [
                        'id' => $service->id,
                        'name' => $service->getNameForLocale($locale),
                        'name_en' => $service->name,
                        'name_sw' => $service->swahili_name,
                        'categories' => $service->categories->map(function($category) use ($locale) {
                            return [
                                'id' => $category->service_categoryID,
                                'name' => $category->getNameForLocale($locale),
                                'name_en' => $category->category_name,
                                'name_sw' => $category->swahili_name,
                                'slug' => $category->slug,
                            ];
                        }),
                    ];
                }),
                'service_names' => $tech->services->pluck('name')->toArray(),
            ];
        });

        $message = $locale === 'sw'
            ? "Mafundi waliopatikana karibu na {$place}"
            : "Technicians found near {$place}";

        return $this->successResponse([
            'technicians' => $formatted,
            'search' => [
                'place'     => $place,
                'latitude'  => $coords['lat'] ?? null,
                'longitude' => $coords['lng'] ?? null,
            ],
            'filters' => [
                'service_id' => $serviceId,
                'category_id' => $categoryId,
            ],
            'meta' => [
                'total_found' => $technicians->count(),
                'has_filters' => ($serviceId || $categoryId),
            ]
        ], $message);
    }

    /**
     * NEARBY TECHNICIANS WITH COORDINATES, SERVICE AND CATEGORY FILTERS
     * GET /v1/technicians/nearby
     */
    public function nearby(Request $request)
    {
        $request->validate([
            'lat'         => 'required|numeric|between:-90,90',
            'lng'         => 'required|numeric|between:-180,180',
            'radius'      => 'nullable|integer|min:1|max:100',
            'service_id'  => 'nullable|exists:services,id',
            'category_id' => 'nullable|exists:service_categories,service_categoryID',
        ]);

        $lat       = $request->input('lat');
        $lng       = $request->input('lng');
        $radius    = $request->input('radius', 10);
        $serviceId = $request->input('service_id');
        $categoryId = $request->input('category_id');

        $query = Technician::with(['user', 'services', 'services.categories'])
            ->where('verified', true)
            ->whereHas('user', fn($q) => $q->where('is_active', true));

        if ($serviceId) {
            $query->whereHas('services', fn($q) => $q->where('services.id', $serviceId));
        }

        if ($categoryId) {
            $query->whereHas('services.categories', function($q) use ($categoryId) {
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

        if ($technicians->isEmpty()) {
            // Get total technicians nearby for reference
            $totalQuery = Technician::with(['user', 'services'])
                ->where('verified', true)
                ->whereHas('user', fn($q) => $q->where('is_active', true));

            $totalQuery->selectRaw("
                technicians.*,
                (
                    6371 * acos(
                        cos(radians(?)) * cos(radians(latitude)) *
                        cos(radians(longitude) - radians(?)) +
                        sin(radians(?)) * sin(radians(latitude))
                    )
                ) AS distance
            ", [$lat, $lng, $lat]);

            $totalQuery->having('distance', '<=', $radius);
            $totalTechnicians = $totalQuery->count();

            $message = "No technicians found within {$radius}km radius";
            $suggestions = [];

            if ($serviceId || $categoryId) {
                $suggestions[] = "Try removing service/category filters";
                $suggestions[] = "Try increasing the search radius";
            } else {
                $suggestions[] = "Try increasing the search radius";
                $suggestions[] = "Try a different location";
            }

            if ($totalTechnicians > 0) {
                $message .= ". There are {$totalTechnicians} other technicians nearby.";
            }

            return $this->successResponse([
                'technicians' => [],
                'search' => [
                    'latitude'  => (float) $lat,
                    'longitude' => (float) $lng,
                    'radius' => (int) $radius,
                ],
                'filters' => [
                    'service_id' => $serviceId,
                    'category_id' => $categoryId,
                ],
                'meta' => [
                    'total_technicians_nearby' => $totalTechnicians,
                    'has_filters' => ($serviceId || $categoryId),
                    'suggestions' => $suggestions,
                ]
            ], $message, 200);
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
                'experience'    => $tech->experience ? (int) $tech->experience : 0,
                'rating'        => (float) ($tech->rating ?? 0),
                'is_online'     => (bool) $tech->is_online,
                'verified'      => (bool) $tech->verified,
                'distance'      => isset($tech->distance) ? (float) round($tech->distance, 2) : null,
                'services'      => $tech->services->map(function($service) {
                    return [
                        'id' => $service->id,
                        'name' => $service->name,
                        'categories' => $service->categories->map(function($category) {
                            return [
                                'id' => $category->service_categoryID,
                                'name' => $category->category_name,
                                'slug' => $category->slug,
                            ];
                        }),
                    ];
                }),
                'service_names' => $tech->services->pluck('name')->toArray(),
            ];
        });

        return $this->successResponse([
            'technicians' => $formatted,
            'search' => [
                'latitude'  => (float) $lat,
                'longitude' => (float) $lng,
            ],
            'filters' => [
                'service_id' => $serviceId,
                'category_id' => $categoryId,
            ],
            'meta' => [
                'total_found' => $technicians->count(),
                'has_filters' => ($serviceId || $categoryId),
            ]
        ], 'Technicians found within radius.');
    }


    // =============================================
    // GET TECHNICIAN DETAIL
    // =============================================
    public function show($id)
    {
        $tech = Technician::with(['user', 'services', 'portfolios'])->find($id);

        if (!$tech) {
            return $this->notFound('Technician profile not found.');
        }

        $formatted = [
            'id' => $tech->id,
            'user_id' => $tech->user_id,
            'name' => $tech->user->name ?? 'Unknown',
            'email' => $tech->user->email ?? '',
            'phone' => $tech->user->phone ?? '',
            'profile_photo' => $tech->profile_photo ? url('storage/' . $tech->profile_photo) : null,
            'bio' => $tech->bio,
            'area' => $tech->area,
            'latitude' => $tech->latitude ? (float) $tech->latitude : null,
            'longitude' => $tech->longitude ? (float) $tech->longitude : null,
            'hourly_rate' => $tech->hourly_rate ? (float) $tech->hourly_rate : null,
            'experience' => $tech->experience ? (int) $tech->experience : 0,
            'rating' => (float) ($tech->rating ?? 0),
            'is_online' => (bool) $tech->is_online,
            'verified' => (bool) $tech->verified,
            'distance_km' => 0.0,
            'services' => $tech->services->pluck('name')->toArray(),
            'portfolios' => $tech->portfolios->map(function($portfolio) {
                return [
                    'id' => $portfolio->id,
                    'image' => $portfolio->image ? url('storage/' . $portfolio->image) : '',
                    'description' => $portfolio->description,
                    'created_at' => $portfolio->created_at ? $portfolio->created_at->toIso8601String() : null,
                ];
            })->toArray()
        ];

        return $this->successResponse($formatted, 'Technician detail profile retrieved successfully.');
    }

    // =============================================
    // GET OWN PROFILE
    // =============================================
    public function getOwnProfile(Request $request)
    {
        $technician = $request->user()->technician()->with('services')->first();
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }
        $technician->makeVisible('nida');
        return $this->successResponse($technician);
    }

    // =============================================
    // UPDATE PROFILE
    // =============================================
    public function updateProfile(Request $request, GeocodingService $geocoder)
    {
        $request->validate([
            'bio'         => 'nullable|string',
            'hourly_rate' => 'nullable|numeric|min:0|max:999999.99',
            'area'        => 'nullable|string|max:255',
            'latitude'    => 'nullable|numeric|between:-90,90',
            'longitude'   => 'nullable|numeric|between:-180,180',
            'nida'        => 'nullable|string|size:20|unique:technicians,nida,' . $request->user()->technician->id,
        ]);

        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        $updateData = $request->only(['bio', 'hourly_rate', 'area', 'latitude', 'longitude', 'nida']);

        if ($request->has('area') && !$request->has('latitude') && !$request->has('longitude')) {
            $coords = $this->validateAndGeocodeArea($request->area, null, null, $geocoder);
            $updateData['latitude'] = $coords['lat'];
            $updateData['longitude'] = $coords['lng'];
        }

        $technician->update($updateData);
        $this->logAudit('update_technician_profile', 'technician', $technician->id, 'Profile updated');

        $technician->makeVisible('nida');
        return $this->successResponse($technician, 'Profile updated.');
    }

    // =============================================
    // UPDATE SERVICES
    // =============================================
    public function updateServices(Request $request)
    {
        $request->validate([
            'service_ids'   => 'required|array|min:1',
            'service_ids.*' => 'exists:services,id',
        ]);

        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        $technician->services()->sync($request->service_ids);
        $this->logAudit('update_technician_services', 'technician', $technician->id, 'Services updated');

        return $this->successResponse($technician->load('services'), 'Services updated.');
    }

    // =============================================
    // TOGGLE ONLINE STATUS
    // =============================================
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

        $this->logAudit('toggle_online', 'technician', $technician->id, 'Online status changed');
        return $this->successResponse($technician, 'Online status updated.');
    }

    // =============================================
    // HEARTBEAT (KEEP ALIVE)
    // =============================================
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

    // =============================================
    // UPDATE LOCATION
    // =============================================
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

        $technician->latitude = $request->latitude;
        $technician->longitude = $request->longitude;
        $technician->location_updated_at = now();
        $technician->save();

        return $this->successResponse(null, 'Location updated.');
    }

    // =============================================
    // UPLOAD PROFILE PHOTO
    // =============================================
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

        $technician->profile_photo = $this->uploadImage($request->file('profile_photo'));
        $technician->save();

        $this->logAudit('upload_profile_photo', 'technician', $technician->id, 'Profile photo updated');

        return $this->successResponse([
            'profile_photo' => $technician->profile_photo,
        ], 'Profile photo updated successfully.');
    }

    // =============================================
    // VERIFY TECHNICIAN
    // =============================================
    public function verify($id)
    {
        $technician = Technician::findOrFail($id);
        $technician->verified = true;
        $technician->save();

        $this->logAudit('verify_technician', 'technician', $technician->id, "Verified technician #{$id}");

        return $this->successResponse($technician, 'Technician verified successfully.');
    }

    // =============================================
    // PUBLIC - List all technicians (with filters)
    // GET /v1/technicians
    // =============================================
    public function publicIndex(Request $request)
    {
        $query = Technician::with(['user', 'services'])
            ->where('verified', true)
            ->whereHas('user', function($q) {
                $q->where('is_active', true);
            });

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->whereHas('user', function($u) use ($search) {
                    $u->where('name', 'like', "%{$search}%");
                })->orWhere('area', 'like', "%{$search}%");
            });
        }

        if ($request->filled('service_id')) {
            $query->whereHas('services', function($q) use ($request) {
                $q->where('services.id', $request->service_id);
            });
        }

        if ($request->filled('category_id')) {
            $query->whereHas('services.categories', function($q) use ($request) {
                $q->where('service_categories.service_categoryID', $request->category_id);
            });
        }

        if ($request->filled('service')) {
            $query->whereHas('services', function($q) use ($request) {
                $q->where('name', 'like', "%{$request->service}%");
            });
        }

        if ($request->filled('online_only') && $request->online_only) {
            $query->where('is_online', true);
        }

        $sortField = $request->input('sort_by', 'created_at');
        $sortOrder = $request->input('sort_order', 'desc');
        
        $sortMap = [
            'name' => 'user_id',
            'area' => 'area',
            'rating' => 'rating',
            'experience' => 'experience',
            'created_at' => 'created_at',
        ];
        
        $sortColumn = $sortMap[$sortField] ?? 'created_at';
        
        if ($sortField === 'name') {
            $query->join('users', 'technicians.user_id', '=', 'users.id')
                  ->orderBy('users.name', $sortOrder)
                  ->select('technicians.*');
        } else {
            $query->orderBy($sortColumn, $sortOrder);
        }

        $perPage = $request->input('per_page', 10);
        $technicians = $query->paginate($perPage);

        $formatted = $technicians->map(function($tech) {
            return [
                'id' => $tech->id,
                'user_id' => $tech->user_id,
                'name' => $tech->user->name ?? 'Unknown',
                'email' => $tech->user->email ?? '',
                'phone' => $tech->user->phone ?? '',
                'profile_photo' => $tech->profile_photo ? url('storage/' . $tech->profile_photo) : null,
                'bio' => $tech->bio,
                'area' => $tech->area,
                'latitude' => $tech->latitude ? (float) $tech->latitude : null,
                'longitude' => $tech->longitude ? (float) $tech->longitude : null,
                'hourly_rate' => $tech->hourly_rate ? (float) $tech->hourly_rate : null,
                'experience' => $tech->experience ? (int) $tech->experience : 0,
                'rating' => (float) ($tech->rating ?? 0),
                'is_online' => (bool) $tech->is_online,
                'verified' => (bool) $tech->verified,
                'services' => $tech->services->pluck('name')->toArray(),
                'created_at' => $tech->created_at ? $tech->created_at->toIso8601String() : null,
            ];
        });

        return $this->successResponse([
            'data' => $formatted,
            'total' => $technicians->total(),
            'per_page' => $technicians->perPage(),
            'current_page' => $technicians->currentPage(),
            'last_page' => $technicians->lastPage(),
        ], 'Technicians retrieved successfully');
    }

    // =============================================
    // PRIVATE HELPERS
    // =============================================
    private function uploadImage($file): string
    {
        return $file->store('technicians', 'public');
    }

    private function validateAndGeocodeArea(
        string $area, 
        ?float $lat, 
        ?float $lng, 
        GeocodingService $geocoder
    ): array {
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
}