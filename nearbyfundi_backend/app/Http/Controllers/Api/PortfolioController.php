<?php

namespace App\Http\Controllers\Api;

use App\Models\Portfolio;
use App\Models\Technician;
use App\Traits\Auditable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class PortfolioController extends BaseApiController
{
    use Auditable;

    /** GET /v1/portfolios  |  GET /v3/portfolios */
    public function index(Request $request)
    {
        $query = Portfolio::with('images', 'technician.user')
            ->orderByDesc('created_at');

        if ($request->filled('technician_id')) {
            $query->where('technician_id', $request->integer('technician_id'));
        }

        if ($request->filled('search')) {
            $s = trim($request->input('search'));
            $query->where(function ($q) use ($s) {
                $q->whereHas('technician.user', fn ($u) => $u->where('name', 'like', "%{$s}%"));
                if (is_numeric($s)) {
                    $q->orWhere('portfolios.id', (int) $s);
                }
            });
        }

        $perPage = min(100, max(1, $request->integer('per_page', 10)));
        $page = $query->paginate($perPage);

        return $this->successResponse([
            'data'       => $page->getCollection()->map(fn ($p) => $this->serialize($p))->values(),
            'pagination' => [
                'total'        => $page->total(),
                'per_page'     => $page->perPage(),
                'current_page' => $page->currentPage(),
                'last_page'    => $page->lastPage(),
            ],
        ], 'Portfolios retrieved successfully');
    }

    /** GET /v1/portfolios/{technicianId}  |  GET /v3/portfolios/technician/{id} */
    public function getByTechnician($technicianId)
    {
        $technician = Technician::with('user', 'services')->find($technicianId);
        if (!$technician) {
            return $this->notFound('Technician not found.');
        }

        $portfolios = Portfolio::with('images')
            ->where('technician_id', $technician->id)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn ($p) => [
                'id'         => $p->id,
                'images'     => $this->serializeImages($p),
                'created_at' => $p->created_at,
            ]);

        return $this->successResponse([
            'technician' => [
                'id'            => $technician->id,
                'name'          => $technician->user->name ?? null,
                'profile_photo' => $this->fileUrl($technician->profile_photo),
                'area'          => $technician->area,
                'rating'        => (float) ($technician->rating ?? 0),
                'is_online'     => (bool) $technician->is_online,
                'verified'      => (bool) $technician->verified,
                'services'      => $technician->services->pluck('name'),
            ],
            'portfolios' => $portfolios,
        ], 'Portfolios retrieved successfully');
    }

    /** POST /v3/portfolios */
    public function store(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can add portfolio items.');
        }

        $request->validate([
            'images'   => 'required|array|min:1|max:10',
            'images.*' => 'image|mimes:jpg,jpeg,png,webp|max:5120',
        ]);

        $portfolio = Portfolio::create(['technician_id' => $technician->id]);

        foreach ($request->file('images') as $file) {
            $path = $file->store('portfolios', 'public');
            $portfolio->images()->create(['image' => $path]);
        }

        $this->logAudit(
            'create_portfolio', 'portfolio', $portfolio->id,
            'Added portfolio with ' . count($request->file('images')) . ' images'
        );

        return $this->created(
            $this->serialize($portfolio->load('images', 'technician.user')),
            'Portfolio post created successfully.'
        );
    }

    /**
     * PUT /v3/portfolios/{id}
     * NOTE: PHP does not parse multipart bodies on real PUT requests, so the client
     * must send POST + `_method=PUT` (Laravel method spoofing) when uploading files.
     */
    public function update(Request $request, $id)
    {
        $portfolio = Portfolio::with('images')->findOrFail($id);
        $technician = $request->user()->technician;

        if (!$technician || $technician->id != $portfolio->technician_id) {
            return $this->forbidden('Unauthorized.');
        }

        $request->validate([
            'images'             => 'nullable|array|max:10',
            'images.*'           => 'image|mimes:jpg,jpeg,png,webp|max:5120',
            'delete_image_ids'   => 'nullable|array',
            'delete_image_ids.*' => 'integer',
        ]);

        if ($request->filled('delete_image_ids')) {
            $toDelete = $portfolio->images()->whereIn('id', $request->input('delete_image_ids'))->get();
            foreach ($toDelete as $img) {
                if (Storage::disk('public')->exists($img->image)) {
                    Storage::disk('public')->delete($img->image);
                }
                $img->delete();
            }
        }

        if ($request->hasFile('images')) {
            foreach ($request->file('images') as $file) {
                $path = $file->store('portfolios', 'public');
                $portfolio->images()->create(['image' => $path]);
            }
        }

        $this->logAudit('update_portfolio', 'portfolio', $portfolio->id, 'Updated portfolio');

        return $this->successResponse(
            $this->serialize($portfolio->fresh(['images', 'technician.user'])),
            'Portfolio post updated successfully.'
        );
    }

    /** DELETE /v3/portfolios/{id} */
    public function destroy(Request $request, $id)
    {
        $portfolio = Portfolio::with('images')->findOrFail($id);
        $technician = $request->user()->technician;

        if (!$technician || $technician->id != $portfolio->technician_id) {
            return $this->forbidden('Unauthorized.');
        }

        $this->deleteFiles($portfolio);
        $portfolio->delete();

        $this->logAudit('delete_portfolio', 'portfolio', $id, 'Deleted portfolio');

        return $this->successResponse(null, 'Portfolio post deleted.');
    }

    /** DELETE /v3/admin/portfolios/{id} */
    public function destroyAdmin($id)
    {
        $portfolio = Portfolio::with('images')->findOrFail($id);
        $this->deleteFiles($portfolio);
        $portfolio->delete();

        $this->logAudit('delete_portfolio_admin', 'portfolio', $id, 'Deleted portfolio (admin)');

        return $this->successResponse(null, 'Portfolio post deleted by admin.');
    }

    /** GET /v3/portfolios/my */
    public function myPortfolios(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can view their own portfolios.');
        }

        $list = Portfolio::with('images', 'technician.user')
            ->where('technician_id', $technician->id)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn ($p) => $this->serialize($p))
            ->values();

        return $this->successResponse($list, 'Portfolios retrieved successfully');
    }

    /** PUT /v3/portfolios/{id}/social-links */
    public function updateSocialLinks(Request $request, $id)
    {
        $portfolio = Portfolio::findOrFail($id);
        $technician = $request->user()->technician;

        if (!$technician || $technician->id != $portfolio->technician_id) {
            return $this->forbidden('Unauthorized.');
        }

        $request->validate(['social_links' => 'nullable|array']);
        $portfolio->update(['social_links' => $request->input('social_links', [])]);

        return $this->successResponse($portfolio, 'Social links updated.');
    }

    /* ---------------- private helpers ---------------- */

    /**
     * Build a URL from the *current request host* instead of APP_URL.
     * Storage::url() uses APP_URL, which is often "http://localhost" in .env and
     * makes every image URL point to the wrong host (browser can't load them).
     * Requires: php artisan storage:link
     */
    private function fileUrl(?string $path): ?string
    {
        if (!$path) {
            return null;
        }
        if (preg_match('#^https?://#i', $path)) {
            return $path;
        }
        return url('storage/' . ltrim($path, '/'));
    }

    private function serializeImages(Portfolio $p)
    {
        return $p->images->map(fn ($i) => [
            'id'  => $i->id,
            'url' => $this->fileUrl($i->image),
        ])->values();
    }

    private function serialize(Portfolio $p): array
    {
        return [
            'id'          => $p->id,
            'images'      => $this->serializeImages($p),
            'image_count' => $p->images->count(),
            'created_at'  => $p->created_at,
            'technician'  => $p->technician ? [
                'id'            => $p->technician->id,
                'name'          => $p->technician->user->name ?? null,
                'profile_photo' => $this->fileUrl($p->technician->profile_photo),
                'area'          => $p->technician->area,
                'rating'        => (float) ($p->technician->rating ?? 0),
                'is_online'     => (bool) $p->technician->is_online,
                'verified'      => (bool) $p->technician->verified,
            ] : null,
        ];
    }

    private function deleteFiles(Portfolio $p): void
    {
        foreach ($p->images as $img) {
            if (Storage::disk('public')->exists($img->image)) {
                Storage::disk('public')->delete($img->image);
            }
        }
    }
}