<?php

namespace App\Http\Controllers\Api;

use App\Models\Technician;
use App\Services\GeocodingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class SearchNearbyFundiController extends BaseApiController
{
    /**
     * Search verified technicians near given coordinates.
     * Supports filtering by service, category and keyword.
     * Optimized with bounding-box index pre-filtering and normalized caching.
     */
    public function nearby(Request $request)
    {
        $data = $request->validate([
            'lat'         => 'required|numeric|between:-90,90',
            'lng'         => 'required|numeric|between:-180,180',
            'radius'      => 'nullable|integer|min:1|max:50',
            'service_id'  => 'nullable|exists:services,id',
            'category_id' => 'nullable|exists:service_categories,service_categoryID',
            'search'      => 'nullable|string|max:100',
            'per_page'    => 'nullable|integer|min:5|max:30',
        ]);

        $lat     = (float) $data['lat'];
        $lng     = (float) $data['lng'];
        $radius  = (int) ($data['radius'] ?? 12);
        $perPage = (int) ($data['per_page'] ?? 15);

        // Round coordinates to 4 decimal places (~11m precision) to avoid cache key explosion
        $cacheData = $data;
        $cacheData['lat'] = round($lat, 4);
        $cacheData['lng'] = round($lng, 4);
        $cacheKey = 'nearby:' . md5(json_encode($cacheData));

        $result = Cache::remember($cacheKey, 60, function () use ($lat, $lng, $radius, $data, $perPage) {

            // Approximate lat/lng bounds for index pre-filtering (1 degree ~ 111 km)
            $latRange = $radius / 111.0;
            $lngRange = $radius / (111.0 * max(cos(deg2rad($lat)), 0.01));

            $query = Technician::query()
                ->select([
                    'technicians.id',
                    'technicians.user_id',
                    'technicians.profile_photo',
                    'technicians.area',
                    'technicians.latitude',
                    'technicians.longitude',
                    'technicians.hourly_rate',
                    'technicians.experience',
                    'technicians.rating',
                    'technicians.verified',
                ])
                // Bounding box pre-filter to leverage database indexes
                ->whereBetween('latitude', [$lat - $latRange, $lat + $latRange])
                ->whereBetween('longitude', [$lng - $lngRange, $lng + $lngRange])
                ->selectRaw("
                    (6371 * acos(
                        cos(radians(?)) * cos(radians(latitude)) *
                        cos(radians(longitude) - radians(?)) +
                        sin(radians(?)) * sin(radians(latitude))
                    )) AS distance
                ", [$lat, $lng, $lat])
                ->where('verified', true)
                ->whereHas('user', fn ($q) => $q->where('is_active', true))
                ->whereNotNull('latitude')
                ->whereNotNull('longitude');

            // Filter by specific service
            if (!empty($data['service_id'])) {
                $query->whereHas('services', fn ($q) => 
                    $q->where('services.id', $data['service_id'])
                );
            }

            // Filter by service category
            if (!empty($data['category_id'])) {
                $query->whereHas('services.categories', fn ($q) => 
                    $q->where('service_categories.service_categoryID', $data['category_id'])
                );
            }

            // Keyword search on service names
            if (!empty($data['search'])) {
                $search = $data['search'];
                $query->whereHas('services', function ($q) use ($search) {
                    $q->where('name', 'LIKE', "%{$search}%")
                      ->orWhere('swahili_name', 'LIKE', "%{$search}%");
                });
            }

            return $query
                ->having('distance', '<=', $radius)
                ->orderBy('distance')
                ->with([
                    'user:id,name,phone',
                    'services:id,name',
                ])
                ->paginate($perPage);
        });

        $items = collect($result->items())->map(fn ($tech) => $this->format($tech));

        return $this->successResponse([
            'data' => $items,
            'meta' => [
                'current_page' => $result->currentPage(),
                'last_page'    => $result->lastPage(),
                'per_page'     => $result->perPage(),
                'total'        => $result->total(),
            ],
            'search' => [
                'lat'    => $lat,
                'lng'    => $lng,
                'radius' => $radius,
            ],
        ]);
    }

    /**
     * Search technicians by place name (uses geocoding internally).
     */
    public function nearbyByPlace(Request $request, GeocodingService $geocoder)
    {
        $data = $request->validate([
            'place'       => 'required|string|max:255',
            'radius'      => 'nullable|integer|min:1|max:50',
            'service_id'  => 'nullable|exists:services,id',
            'category_id' => 'nullable|exists:service_categories,service_categoryID',
            'search'      => 'nullable|string|max:100',
            'per_page'    => 'nullable|integer|min:5|max:30',
        ]);

        $coords = $geocoder->geocode($data['place']);

        if (!$coords) {
            return $this->errorResponse("Could not locate place: {$data['place']}", 422);
        }

        // Convert place search into coordinate search
        $request->merge([
            'lat' => $coords['lat'],
            'lng' => $coords['lng'],
        ]);

        return $this->nearby($request);
    }

    /**
     * Format technician data for API response.
     */
    private function format(Technician $tech): array
    {
        return [
            'id'            => $tech->id,
            'name'          => $tech->user->name ?? 'Unknown',
            'phone'         => $tech->user->phone ?? null,
            'profile_photo' => $tech->profile_photo 
                                ? url('storage/' . $tech->profile_photo) 
                                : null,
            'area'          => $tech->area,
            'latitude'      => $tech->latitude ? (float) $tech->latitude : null,
            'longitude'     => $tech->longitude ? (float) $tech->longitude : null,
            'hourly_rate'   => $tech->hourly_rate ? (float) $tech->hourly_rate : null,
            'experience'    => (int) $tech->experience,
            'rating'        => (float) $tech->rating,
            'distance_km'   => isset($tech->distance) ? round($tech->distance, 2) : null,
            'services'      => $tech->services->pluck('name'),
        ];
    }
}