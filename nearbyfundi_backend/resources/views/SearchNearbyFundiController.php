<?php

namespace App\Http\Controllers\Api;

use App\Models\Technician;
use App\Services\GeocodingService;
use Illuminate\Http\Request;

class SearchNearbyFundiController extends BaseApiController
{
    /**
     * Search nearby verified technicians by coordinates
     */
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

        $lat        = (float) $request->input('lat');
        $lng        = (float) $request->input('lng');
        $radius     = (int) $request->input('radius', 10);
        $serviceId  = $request->input('service_id');
        $categoryId = $request->input('category_id');
        $searchText = $request->input('search');

        $query = Technician::with(['user', 'services.categories', 'servicePrices'])
            ->where('verified', true)
            ->whereHas('user', fn ($q) => $q->where('is_active', true));

        if ($searchText) {
            $query->whereHas('services', function ($q) use ($searchText) {
                $q->where('name', 'LIKE', "%{$searchText}%")
                  ->orWhere('swahili_name', 'LIKE', "%{$searchText}%");
            });
        }

        if ($serviceId) {
            $query->whereHas('services', fn ($q) => $q->where('services.id', $serviceId));
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

        $query->having('distance', '<=', $radius)
              ->orderBy('distance', 'asc');

        $formatted = $query->get()->map(fn ($tech) => $this->formatTechnician($tech));

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
            ],
        ], $formatted->isEmpty() ? 'No technicians found within radius.' : 'Technicians found within radius.');
    }

    /**
     * Search nearby by place name
     */
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

        $query = Technician::with(['user', 'services.categories', 'servicePrices'])
            ->where('verified', true)
            ->whereHas('user', fn ($q) => $q->where('is_active', true));

        if ($searchText) {
            $query->whereHas('services', function ($q) use ($searchText) {
                $q->where('name', 'LIKE', "%{$searchText}%")
                  ->orWhere('swahili_name', 'LIKE', "%{$searchText}%");
            });
        }

        if ($serviceId) {
            $query->whereHas('services', fn ($q) => $q->where('services.id', $serviceId));
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

        $formatted = $query->get()->map(fn ($tech) => $this->formatTechnician($tech));

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
            ],
        ], $formatted->isEmpty() ? 'No technicians found.' : 'Technicians found.');
    }

    /**
     * Clean formatter – bio and is_online removed
     */
    private function formatTechnician(Technician $tech): array
    {
        return [
            'id'             => $tech->id,
            'user_id'        => $tech->user_id,
            'name'           => $tech->user->name ?? 'Unknown',
            'email'          => $tech->user->email ?? '',
            'phone'          => $tech->user->phone ?? '',
            'profile_photo'  => $tech->profile_photo ? url('storage/' . $tech->profile_photo) : null,
            'area'           => $tech->area,
            'latitude'       => $tech->latitude ? (float) $tech->latitude : null,
            'longitude'      => $tech->longitude ? (float) $tech->longitude : null,
            'hourly_rate'    => $tech->hourly_rate ? (float) $tech->hourly_rate : null,
            'experience'     => (int) ($tech->experience ?? 0),
            'rating'         => (float) ($tech->rating ?? 0),
            'verified'       => (bool) $tech->verified,
            'distance'       => isset($tech->distance) ? (float) round($tech->distance, 2) : null,
            'services'       => $tech->services->pluck('name')->toArray(),
            'service_prices' => $tech->servicePrices->map(function ($service) {
                return [
                    'id'        => $service->id,
                    'name'      => $service->name,
                    'min_price' => (float) $service->pivot->min_price,
                    'max_price' => (float) $service->pivot->max_price,
                ];
            })->values()->toArray(),
        ];
    }
}