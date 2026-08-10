<?php

namespace App\Http\Controllers\Api;

use App\Models\Service;
use App\Models\ServiceCategory;
use App\Traits\Auditable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

class ServiceController extends BaseApiController
{
    use Auditable;

    /**
     * Get all services with their categories
     * GET /v11/services
     */
    public function index(Request $request)
    {
        try {
            $locale = $request->header('Accept-Language', 'en');

            $query = Service::with(['categories' => function($q) use ($locale) {
                $q->select('service_categories.service_categoryID', 'category_name', 'swahili_name', 'slug')
                  ->orderBy('category_name', 'asc');
            }]);

            // Filter by category
            if ($request->filled('category_id')) {
                $query->whereHas('categories', function($q) use ($request) {
                    $q->where('service_categoryID', $request->category_id);
                });
            }

            // Filter by category slug
            if ($request->filled('category_slug')) {
                $query->whereHas('categories', function($q) use ($request) {
                    $q->where('slug', $request->category_slug);
                });
            }

            // Search by name in both languages
            if ($request->filled('search')) {
                $search = $request->search;
                $query->where(function($q) use ($search) {
                    $q->where('name', 'LIKE', "%{$search}%")
                      ->orWhere('swahili_name', 'LIKE', "%{$search}%");
                });
            }

            // Order by name
            $query->orderBy('name', 'asc');

            $services = $query->get();

            $data = $services->map(function($service) use ($locale) {
                return $this->formatService($service, $locale);
            });

            return $this->successResponse($data, 'Services retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching services: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch services. Please try again.', 500);
        }
    }

    /**
     * Get single service with categories
     * GET /v11/services/{id}
     */
    public function show($id, Request $request)
    {
        try {
            $locale = $request->header('Accept-Language', 'en');
            $service = Service::with(['categories'])->findOrFail($id);
            $data = $this->formatService($service, $locale);
            return $this->successResponse($data, 'Service retrieved successfully');

        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Service not found.');
        } catch (\Exception $e) {
            Log::error('Error fetching service: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch service. Please try again.', 500);
        }
    }

    /**
     * Get services grouped by category
     * GET /v11/services/grouped-by-category
     */
    public function getServicesGroupedByCategory(Request $request)
    {
        try {
            $locale = $request->header('Accept-Language', 'en');

            $categories = ServiceCategory::with(['services' => function($q) use ($locale) {
                $q->select('services.id', 'services.name', 'services.swahili_name')
                  ->orderBy('services.name', 'asc');
            }])
            ->select('service_categoryID', 'category_name', 'swahili_name', 'slug', 'description')
            ->orderBy('category_name', 'asc')
            ->get();

            $data = $categories->map(function($category) use ($locale) {
                return [
                    'category_id' => $category->service_categoryID,
                    'category_name' => $category->getNameForLocale($locale),
                    'category_name_en' => $category->category_name,
                    'category_name_sw' => $category->swahili_name,
                    'category_slug' => $category->slug,
                    'description' => $category->description,
                    'services' => $category->services->map(function($service) use ($locale) {
                        return [
                            'id' => $service->id,
                            'name' => $service->getNameForLocale($locale),
                            'name_en' => $service->name,
                            'name_sw' => $service->swahili_name,
                        ];
                    }),
                    'service_count' => $category->services->count(),
                ];
            });

            return $this->successResponse($data, 'Services grouped by category retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching services grouped by category: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch services. Please try again.', 500);
        }
    }

    /**
     * Get services for dropdown (id => name)
     * GET /v11/services/dropdown
     */
    public function getServicesDropdown(Request $request)
    {
        try {
            $locale = $request->header('Accept-Language', 'en');
            $services = Service::orderBy('name', 'asc')->get(['id', 'name', 'swahili_name']);

            $dropdown = $services->mapWithKeys(function($service) use ($locale) {
                return [$service->id => $service->getNameForLocale($locale)];
            });

            return $this->successResponse([
                'dropdown' => $dropdown,
                'count' => $services->count()
            ], 'Services dropdown retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching services dropdown: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch services dropdown. Please try again.', 500);
        }
    }

    /**
     * Get services by category ID
     * GET /v11/services/by-category/{categoryId}
     */
    public function getServicesByCategory($categoryId, Request $request)
    {
        try {
            $locale = $request->header('Accept-Language', 'en');
            $category = ServiceCategory::findOrFail($categoryId);

            $services = Service::with(['categories'])
                ->whereHas('categories', function($q) use ($categoryId) {
                    $q->where('service_categoryID', $categoryId);
                })
                ->orderBy('name', 'asc')
                ->get();

            $data = [
                'category' => [
                    'id' => $category->service_categoryID,
                    'name' => $category->getNameForLocale($locale),
                    'name_en' => $category->category_name,
                    'name_sw' => $category->swahili_name,
                    'slug' => $category->slug,
                    'description' => $category->description,
                ],
                'services' => $services->map(function($service) use ($locale) {
                    return [
                        'id' => $service->id,
                        'name' => $service->getNameForLocale($locale),
                        'name_en' => $service->name,
                        'name_sw' => $service->swahili_name,
                    ];
                }),
                'count' => $services->count(),
            ];

            return $this->successResponse($data, 'Services by category retrieved successfully');

        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Category not found.');
        } catch (\Exception $e) {
            Log::error('Error fetching services by category: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch services. Please try again.', 500);
        }
    }

    /**
     * Get services by category slug
     * GET /v11/services/by-category-slug/{slug}
     */
    public function getServicesByCategorySlug($slug, Request $request)
    {
        try {
            $locale = $request->header('Accept-Language', 'en');
            $category = ServiceCategory::where('slug', $slug)->firstOrFail();

            $services = Service::with(['categories'])
                ->whereHas('categories', function($q) use ($category) {
                    $q->where('service_categoryID', $category->service_categoryID);
                })
                ->orderBy('name', 'asc')
                ->get();

            $data = [
                'category' => [
                    'id' => $category->service_categoryID,
                    'name' => $category->getNameForLocale($locale),
                    'name_en' => $category->category_name,
                    'name_sw' => $category->swahili_name,
                    'slug' => $category->slug,
                    'description' => $category->description,
                ],
                'services' => $services->map(function($service) use ($locale) {
                    return [
                        'id' => $service->id,
                        'name' => $service->getNameForLocale($locale),
                        'name_en' => $service->name,
                        'name_sw' => $service->swahili_name,
                    ];
                }),
                'count' => $services->count(),
            ];

            return $this->successResponse($data, 'Services by category retrieved successfully');

        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return $this->notFound('Category not found.');
        } catch (\Exception $e) {
            Log::error('Error fetching services by category slug: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch services. Please try again.', 500);
        }
    }

    /**
     * Get all categories with service count
     * GET /v11/categories/with-service-count
     */
    public function getCategoriesWithServiceCount(Request $request)
    {
        try {
            $locale = $request->header('Accept-Language', 'en');
            $categories = ServiceCategory::withCount('services')
                ->orderBy('category_name', 'asc')
                ->get();

            $data = $categories->map(function($category) use ($locale) {
                return [
                    'id' => $category->service_categoryID,
                    'name' => $category->getNameForLocale($locale),
                    'name_en' => $category->category_name,
                    'name_sw' => $category->swahili_name,
                    'slug' => $category->slug,
                    'description' => $category->description,
                    'service_count' => $category->services_count,
                ];
            });

            return $this->successResponse($data, 'Categories with service count retrieved successfully');

        } catch (\Exception $e) {
            Log::error('Error fetching categories with service count: ' . $e->getMessage());
            return $this->errorResponse('Failed to fetch categories. Please try again.', 500);
        }
    }

    /**
     * Format service for response
     */
    private function formatService($service, string $locale): array
    {
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
            'category_ids' => $service->categories->pluck('service_categoryID')->toArray(),
            'created_at' => $service->created_at,
            'updated_at' => $service->updated_at,
        ];
    }
}