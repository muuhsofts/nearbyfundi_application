<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Otp;
use App\Models\FailedLoginAttempt;
use App\Models\UserSession;
use App\Mail\OtpMail;
use App\Traits\Auditable;
use App\Models\Technician;
use App\Models\Service;
use Carbon\Carbon;
use App\Services\GeocodingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Spatie\Permission\Models\Role;

class TechnicianController extends BaseApiController
{
    use Auditable;

    // ------------------ CUSTOMER REGISTRATION ------------------
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

    // ------------------ FUNDI REGISTRATION (WITH OSM VALIDATION) ------------------
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

        \Log::info('TechnicianController - service_ids received:', [
            'service_ids' => $data['service_ids'],
            'count' => count($data['service_ids']),
        ]);

        // ✅ Validate area with OpenStreetMap ONLY - no hardcoded lists
        $coords = $this->validateAndGeocodeArea(
            $data['area'], 
            $data['latitude'] ?? null, 
            $data['longitude'] ?? null, 
            $geocoder
        );
        
        // Store the validated coordinates
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

    // ------------------ SEARCH TECHNICIANS BY PLACE (OSM ONLY) ------------------
    public function nearbyByPlace(Request $request, GeocodingService $geocoder)
    {
        $request->validate([
            'place'      => 'required|string|max:255',
            'service_id' => 'nullable|exists:services,id',
            'radius'     => 'nullable|integer|min:1|max:100',
        ]);

        $place     = trim($request->input('place'));
        $radius    = $request->input('radius', 10);
        $serviceId = $request->input('service_id');

        // Try geocoding, but don't fail the whole search if it doesn't resolve
        $coords = $geocoder->geocode($place);

        $query = Technician::with(['user', 'services'])
            ->where('verified', true)
            ->whereHas('user', fn($q) => $q->where('is_active', true));

        if ($serviceId) {
            $query->whereHas('services', fn($q) => $q->where('services.id', $serviceId));
        }

        if ($coords) {
            // Always compute distance for sorting/display
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

            // Match EITHER: area text contains the search term
            //           OR: technician is within radius km of the geocoded point
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
            // Geocoding failed entirely — fall back to plain text match on area
            $query->where('area', 'like', "%{$place}%");
        }

        $technicians = $query->get();

        if ($technicians->isEmpty()) {
            return $this->errorResponse(
                "No technicians found near '{$place}'. Please check the spelling or try a nearby area like 'Sinza' or 'Ubungo'.",
                404
            );
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
                'services'      => $tech->services->pluck('name')->toArray(),
            ];
        });

        // 👇 Wrap technicians + the geocoded search origin together so the
        // frontend can draw a pin at the searched place and lines to each
        // technician found, without guessing coordinates itself.
        return $this->successResponse([
            'technicians' => $formatted,
            'search' => [
                'place'     => $place,
                'latitude'  => $coords['lat'] ?? null,
                'longitude' => $coords['lng'] ?? null,
            ],
        ], 'Technicians found near ' . $place);
    }

    // ------------------ GET TECHNICIAN DETAIL ------------------
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

    // ------------------ GET OWN PROFILE ------------------
    public function getOwnProfile(Request $request)
    {
        $technician = $request->user()->technician()->with('services')->first();
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }
        $technician->makeVisible('nida');
        return $this->successResponse($technician);
    }

    // ------------------ UPDATE PROFILE ------------------
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

        // ✅ If area is being updated, validate with OpenStreetMap
        if ($request->has('area') && !$request->has('latitude') && !$request->has('longitude')) {
            $coords = $this->validateAndGeocodeArea(
                $request->area,
                null,
                null,
                $geocoder
            );
            $updateData['latitude'] = $coords['lat'];
            $updateData['longitude'] = $coords['lng'];
        }

        $technician->update($updateData);
        $this->logAudit('update_technician_profile', 'technician', $technician->id, 'Profile updated');

        $technician->makeVisible('nida');
        return $this->successResponse($technician, 'Profile updated.');
    }

    // ------------------ UPDATE SERVICES ------------------
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

    // ------------------ TOGGLE ONLINE STATUS ------------------
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

    // ------------------ HEARTBEAT (KEEP ALIVE) ------------------
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

    // ------------------ UPDATE LOCATION ------------------
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

    // ------------------ UPLOAD PROFILE PHOTO ------------------
    public function uploadProfilePhoto(Request $request)
    {
        $request->validate([
            'profile_photo' => 'required|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->notFound('Technician profile not found.');
        }

        // Delete old photo if exists
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

    // ------------------ PRIVATE HELPERS ------------------

    /**
     * Upload profile photo using Laravel's storage system.
     * Stores in storage/app/public/technicians/ and returns relative path.
     */
    private function uploadImage($file): string
    {
        $path = $file->store('technicians', 'public');
        return $path;
    }

    /**
     * ✅ Validate and geocode area using OpenStreetMap ONLY
     * No hardcoded lists - everything comes from OpenStreetMap
     * Returns coordinates or throws validation error
     */
    private function validateAndGeocodeArea(
        string $area, 
        ?float $lat, 
        ?float $lng, 
        GeocodingService $geocoder
    ): array {
        // If coordinates are provided directly, use them
        if ($lat !== null && $lng !== null) {
            // Verify the coordinates are valid
            if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
                abort(422, 'Invalid coordinates provided.');
            }
            return ['lat' => $lat, 'lng' => $lng];
        }

        // ✅ Try to geocode the area using OpenStreetMap ONLY
        $coords = $geocoder->geocode($area);
        
        if (!$coords) {
            // OpenStreetMap couldn't find the place - return error
            $message = "We couldn't locate '{$area}' in OpenStreetMap. ";
            $message .= "Please check the spelling or enter a more specific location. ";
            $message .= "Examples: 'Dar es Salaam', 'Mwanza', 'Kariakoo', 'Sinza', or a specific street address.";
            
            abort(422, $message);
        }

        // ✅ Successfully geocoded by OpenStreetMap
        return $coords;
    }

     // =============================================
    // PUBLIC - List all technicians (with filters)
    // =============================================
    /**
     * Public index - list all verified technicians with filters
     * GET /v1/technicians
     */
    public function publicIndex(Request $request)
    {
        $query = Technician::with(['user', 'services'])
            ->where('verified', true)
            ->whereHas('user', function($q) {
                $q->where('is_active', true);
            });

        // Search by name or area
        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->whereHas('user', function($u) use ($search) {
                    $u->where('name', 'like', "%{$search}%");
                })->orWhere('area', 'like', "%{$search}%");
            });
        }

        // Filter by service
        if ($request->filled('service_id')) {
            $query->whereHas('services', function($q) use ($request) {
                $q->where('services.id', $request->service_id);
            });
        }

        // Filter by service name (string)
        if ($request->filled('service')) {
            $query->whereHas('services', function($q) use ($request) {
                $q->where('name', 'like', "%{$request->service}%");
            });
        }

        // Online only
        if ($request->filled('online_only') && $request->online_only) {
            $query->where('is_online', true);
        }

        // Sort
        $sortField = $request->input('sort_by', 'created_at');
        $sortOrder = $request->input('sort_order', 'desc');
        
        // Map sort fields to actual columns
        $sortMap = [
            'name' => 'user_id',
            'area' => 'area',
            'rating' => 'rating',
            'experience' => 'experience',
            'created_at' => 'created_at',
        ];
        
        $sortColumn = $sortMap[$sortField] ?? 'created_at';
        
        // For sorting by name, we need to join with users
        if ($sortField === 'name') {
            $query->join('users', 'technicians.user_id', '=', 'users.id')
                  ->orderBy('users.name', $sortOrder)
                  ->select('technicians.*');
        } else {
            $query->orderBy($sortColumn, $sortOrder);
        }

        // Pagination
        $perPage = $request->input('per_page', 10);
        $technicians = $query->paginate($perPage);

        // Format response
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
}