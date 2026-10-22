<?php

namespace App\Http\Controllers\Api;

use App\Models\MiniApp;
use Illuminate\Http\Request;
use SimpleSoftwareIO\QrCode\Facades\QrCode;

class MiniAppController extends BaseApiController
{
    // ──────────────────────────────────────────────
    // PUBLIC
    // ──────────────────────────────────────────────

    /** GET /api/v24/mini-apps */
    public function index()
    {
        $apps = MiniApp::active()->ordered()->get()
            ->map(fn (MiniApp $a) => $this->format($a));

        return $this->successResponse($apps);
    }

    /** GET /api/v24/mini-apps/{slug} */
    public function show(string $slug)
    {
        $app = MiniApp::active()->where('slug', $slug)->first();

        if (!$app) {
            return $this->notFound('Mini app not found.');
        }

        return $this->successResponse($this->format($app));
    }

    /**
     * GET /api/v24/mini-apps/{slug}/qr?format=svg|png&size=512
     * SVG needs no PHP extension; PNG needs imagick.
     */
    public function qr(Request $request, string $slug)
    {
        $app = MiniApp::active()->where('slug', $slug)->first();

        if (!$app) {
            return $this->notFound('Mini app not found.');
        }

        $format = $request->query('format', 'svg') === 'png' ? 'png' : 'svg';
        $size   = max(128, min((int) $request->query('size', 512), 1024));

        $image = QrCode::format($format)
            ->size($size)
            ->margin(2)
            ->errorCorrection('H')
            ->generate($app->qr_payload);

        return response($image, 200, [
            'Content-Type'  => $format === 'png' ? 'image/png' : 'image/svg+xml',
            'Cache-Control' => 'public, max-age=86400',
        ]);
    }

    /** GET /api/v24/mini-apps-print  (printable sheet of every QR) */
    public function printSheet()
    {
        $apps = MiniApp::active()->ordered()->get();

        return view('mini-apps.print', ['apps' => $apps]);
    }

    // ──────────────────────────────────────────────
    // ADMIN (permission: miniapps.manage)
    // ──────────────────────────────────────────────

    /** POST /api/v24/admin/mini-apps */
    public function store(Request $request)
    {
        $data = $request->validate([
            'slug'           => ['required', 'string', 'max:60', 'regex:/^[a-z0-9_]+$/', 'unique:mini_apps,slug'],
            'name'           => 'required|string|max:120',
            'subtitle'       => 'nullable|string|max:190',
            'is_coming_soon' => 'sometimes|boolean',
            'is_active'      => 'sometimes|boolean',
            'sort_order'     => 'sometimes|integer|min:0',
        ]);

        $app = MiniApp::create($data);

        return $this->created($this->format($app), 'Mini app created.');
    }

    /** PUT /api/v24/admin/mini-apps/{id} */
    public function update(Request $request, int $id)
    {
        $app = MiniApp::findOrFail($id);

        // slug is the QR identity; changing it would break printed codes.
        $data = $request->validate([
            'name'           => 'sometimes|string|max:120',
            'subtitle'       => 'nullable|string|max:190',
            'is_coming_soon' => 'sometimes|boolean',
            'is_active'      => 'sometimes|boolean',
            'sort_order'     => 'sometimes|integer|min:0',
        ]);

        $app->update($data);

        return $this->successResponse($this->format($app->fresh()), 'Mini app updated.');
    }

    /** DELETE /api/v24/admin/mini-apps/{id} */
    public function destroy(int $id)
    {
        MiniApp::findOrFail($id)->delete();

        return $this->successResponse(null, 'Mini app deleted.');
    }

    // ──────────────────────────────────────────────

    private function format(MiniApp $a): array
    {
        return [
            'id'             => $a->id,
            'slug'           => $a->slug,
            'name'           => $a->name,
            'subtitle'       => $a->subtitle,
            'is_coming_soon' => $a->is_coming_soon,
            'is_active'      => $a->is_active,
            'sort_order'     => $a->sort_order,
            'qr_payload'     => $a->qr_payload,
            'qr_url'         => url("/api/v24/mini-apps/{$a->slug}/qr"),
        ];
    }
}