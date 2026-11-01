<?php

namespace App\Http\Controllers\Api;

use App\Models\Portfolio;
use App\Models\Technician;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class PortfolioController extends BaseApiController
{
    /** GET /v3/portfolios/technician/{id} */
    public function getByTechnician($technicianId)
    {
        $technician = Technician::find($technicianId);
        if (!$technician) {
            return $this->notFound('Technician not found.');
        }

        $portfolios = Portfolio::with('images')
            ->where('technician_id', $technician->id)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn ($p) => $this->serialize($p))
            ->values();

        return $this->successResponse([
            'portfolios' => $portfolios,
        ], 'Portfolios retrieved successfully');
    }

    /** GET /v3/portfolios/my */
    public function myPortfolios(Request $request)
    {
        $technician = $request->user()->technician;
        if (!$technician) {
            return $this->forbidden('Only technicians can view their own portfolios.');
        }

        $list = Portfolio::with('images')
            ->where('technician_id', $technician->id)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn ($p) => $this->serialize($p))
            ->values();

        return $this->successResponse($list, 'Portfolios retrieved successfully');
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

        return $this->created(
            $this->serialize($portfolio->load('images')),
            'Portfolio post created successfully.'
        );
    }

    /** PUT /v3/portfolios/{id} (multipart + _method=PUT) */
    public function update(Request $request, $id)
    {
        $portfolio  = Portfolio::with('images')->findOrFail($id);
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
            $toDelete = $portfolio->images()
                ->whereIn('id', $request->input('delete_image_ids'))
                ->get();

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

        return $this->successResponse(
            $this->serialize($portfolio->fresh('images')),
            'Portfolio post updated successfully.'
        );
    }

    /** DELETE /v3/portfolios/{id} */
    public function destroy(Request $request, $id)
    {
        $portfolio  = Portfolio::with('images')->findOrFail($id);
        $technician = $request->user()->technician;

        if (!$technician || $technician->id != $portfolio->technician_id) {
            return $this->forbidden('Unauthorized.');
        }

        $this->deleteFiles($portfolio);
        $portfolio->delete();

        return $this->successResponse(null, 'Portfolio post deleted.');
    }

    /* ---------------- private helpers ---------------- */

    private function serialize(Portfolio $p): array
    {
        return [
            'id'          => $p->id,
            'image_count' => $p->images->count(),
            'created_at'  => $p->created_at?->toIso8601String(),
            'images'      => $p->images
                ->filter(fn ($i) => !empty($i->image))
                ->map(fn ($i) => [
                    'id'  => $i->id,
                    'url' => url('storage/' . ltrim($i->image, '/')),
                ])->values(),
        ];
    }

    private function deleteFiles(Portfolio $p): void
    {
        foreach ($p->images as $img) {
            if ($img->image && Storage::disk('public')->exists($img->image)) {
                Storage::disk('public')->delete($img->image);
            }
        }
    }
}