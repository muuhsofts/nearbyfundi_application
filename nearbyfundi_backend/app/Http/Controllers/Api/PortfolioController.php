<?php

namespace App\Http\Controllers\Api;

use App\Models\Portfolio;
use App\Models\Technician;
use App\Traits\Auditable;
use Illuminate\Http\Request;

class PortfolioController extends BaseApiController
{
    use Auditable;

    /**
     * Get ALL portfolios with technician details (Paginated)
     * GET /v3/portfolios
     */
    public function index(Request $request)
    {
        $query = Portfolio::with('technician.user', 'technician.services')
            ->orderBy('created_at', 'desc');

        // Optional filters
        if ($request->filled('technician_id')) {
            $query->where('technician_id', $request->technician_id);
        }

        $portfolios = $query->paginate($request->input('per_page', 20));

        $data = $portfolios->map(function($portfolio) {
            return [
                'id' => $portfolio->id,
                'image' => $portfolio->image ? url('storage/' . $portfolio->image) : null,
                'description' => $portfolio->description,
                'created_at' => $portfolio->created_at,
                'technician' => $portfolio->technician ? [
                    'id' => $portfolio->technician->id,
                    'name' => $portfolio->technician->user->name ?? null,
                    'email' => $portfolio->technician->user->email ?? null,
                    'phone' => $portfolio->technician->user->phone ?? null,
                    'profile_photo' => $portfolio->technician->profile_photo 
                        ? url($portfolio->technician->profile_photo) 
                        : null,
                    'area' => $portfolio->technician->area,
                    'rating' => (float) ($portfolio->technician->rating ?? 0),
                    'is_online' => (bool) ($portfolio->technician->is_online ?? false),
                    'verified' => (bool) ($portfolio->technician->verified ?? false),
                    'services' => $portfolio->technician->services->pluck('name')->toArray(),
                ] : null
            ];
        });

        return $this->successResponse([
            'data' => $data,
            'pagination' => [
                'total' => $portfolios->total(),
                'per_page' => $portfolios->perPage(),
                'current_page' => $portfolios->currentPage(),
                'last_page' => $portfolios->lastPage(),
            ]
        ], 'Portfolios retrieved successfully');
    }

    /**
     * Get portfolios by technician ID
     * GET /v3/portfolios/technician/{technicianId}
     */
    public function getByTechnician($technicianId)
    {
        $technician = Technician::with('user', 'services')->findOrFail($technicianId);
        
        $portfolios = Portfolio::where('technician_id', $technicianId)
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(function($portfolio) {
                return [
                    'id' => $portfolio->id,
                    'image' => $portfolio->image ? url('storage/' . $portfolio->image) : null,
                    'description' => $portfolio->description,
                    'created_at' => $portfolio->created_at,
                ];
            });

        return $this->successResponse([
            'technician' => [
                'id' => $technician->id,
                'name' => $technician->user->name ?? null,
                'profile_photo' => $technician->profile_photo ? url($technician->profile_photo) : null,
                'area' => $technician->area,
                'rating' => (float) ($technician->rating ?? 0),
                'is_online' => (bool) ($technician->is_online ?? false),
                'verified' => (bool) ($technician->verified ?? false),
                'services' => $technician->services->pluck('name')->toArray(),
            ],
            'portfolios' => $portfolios,
        ], 'Portfolios retrieved successfully');
    }

    /**
     * Create portfolio (Technician only)
     * POST /v3/portfolios
     */
    public function store(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can add portfolio items.');
        }

        $data = $request->validate([
            'image'       => 'required|image|mimes:jpg,jpeg,png,webp|max:2048',
            'description' => 'nullable|string|max:255',
        ]);

        $path = $request->file('image')->store('portfolios', 'public');
        $portfolio = Portfolio::create([
            'technician_id' => $technician->id,
            'image'         => $path,
            'description'   => $data['description'] ?? null,
        ]);

        $this->logAudit('create_portfolio', 'portfolio', $portfolio->id, 'Added portfolio item');

        return $this->created($portfolio, 'Portfolio item added.');
    }

    /**
     * Update portfolio (Owner only)
     * PUT /v3/portfolios/{id}
     */
    public function update(Request $request, $id)
    {
        $portfolio = Portfolio::findOrFail($id);
        $technician = $request->user()->technician;
        
        if (!$technician || $technician->id != $portfolio->technician_id) {
            return $this->forbidden('Unauthorized.');
        }

        $data = $request->validate([
            'description' => 'nullable|string|max:255',
            'image'       => 'nullable|image|mimes:jpg,jpeg,png,webp|max:2048',
        ]);

        if ($request->hasFile('image')) {
            if ($portfolio->image && file_exists(public_path($portfolio->image))) {
                unlink(public_path($portfolio->image));
            }
            $data['image'] = $request->file('image')->store('portfolios', 'public');
        }

        $old = $portfolio->toArray();
        $portfolio->update($data);
        $new = $portfolio->fresh()->toArray();

        $this->logAudit('update_portfolio', 'portfolio', $id, 'Updated portfolio item', $old, $new);

        return $this->successResponse($portfolio, 'Portfolio updated.');
    }

    /**
     * Delete portfolio (Owner only)
     * DELETE /v3/portfolios/{id}
     */
    public function destroy(Request $request, $id)
    {
        $portfolio = Portfolio::findOrFail($id);
        $technician = $request->user()->technician;
        
        if (!$technician || $technician->id != $portfolio->technician_id) {
            return $this->forbidden('Unauthorized.');
        }

        if ($portfolio->image && file_exists(public_path($portfolio->image))) {
            unlink(public_path($portfolio->image));
        }
        $portfolio->delete();

        $this->logAudit('delete_portfolio', 'portfolio', $id, 'Deleted portfolio item');

        return $this->successResponse(null, 'Portfolio item deleted.');
    }

    /**
     * Admin delete any portfolio
     * DELETE /v3/admin/portfolios/{id}
     */
    public function destroyAdmin($id)
    {
        $portfolio = Portfolio::findOrFail($id);
        
        if ($portfolio->image && file_exists(public_path($portfolio->image))) {
            unlink(public_path($portfolio->image));
        }
        $portfolio->delete();

        $this->logAudit('delete_portfolio_admin', 'portfolio', $id, 'Admin deleted portfolio item');

        return $this->successResponse(null, 'Portfolio item deleted by admin.');
    }

    /**
 * Get portfolios for the authenticated technician
 * GET /v3/portfolios/my
 */
public function myPortfolios(Request $request)
{
    $technician = $request->user()->technician;
    if (!$technician) {
        return $this->forbidden('Only technicians can view their own portfolios.');
    }

    $portfolios = Portfolio::where('technician_id', $technician->id)
        ->orderBy('created_at', 'desc')
        ->get()
        ->map(function($portfolio) {
            return [
                'id' => $portfolio->id,
                'image' => $portfolio->image ? url('storage/' . $portfolio->image) : null,
                'description' => $portfolio->description,
                'created_at' => $portfolio->created_at,
            ];
        });

    return $this->successResponse($portfolios, 'Portfolios retrieved successfully');
}
}