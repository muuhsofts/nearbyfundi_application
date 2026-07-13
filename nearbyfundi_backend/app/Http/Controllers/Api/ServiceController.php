<?php

namespace App\Http\Controllers\Api;

use App\Models\Service;
use App\Traits\Auditable;
use Illuminate\Http\Request;

class ServiceController extends BaseApiController
{
    use Auditable;

    public function index()
    {
        return $this->successResponse(Service::with('technicians.user')->get());
    }

    public function store(Request $request)
    {
        $this->checkPermission('services.create');
        $request->validate(['name' => 'required|string|unique:services,name']);

        $service = Service::create(['name' => $request->name]);
        $this->logAudit('create_service', 'service', $service->id, "Service created: {$service->name}");

        return $this->created($service, 'Service created.');
    }

    public function update(Request $request, $id)
    {
        $this->checkPermission('services.edit');
        $service = Service::findOrFail($id);
        $request->validate(['name' => 'sometimes|string|unique:services,name,' . $id]);

        $old = $service->toArray();
        $service->update($request->only('name'));
        $new = $service->fresh()->toArray();

        $this->logAudit('update_service', 'service', $id, "Service #{$id} updated", $old, $new);

        return $this->successResponse($service, 'Service updated.');
    }

    public function destroy($id)
    {
        $this->checkPermission('services.delete');
        $service = Service::findOrFail($id);
        $service->delete();
        $this->logAudit('delete_service', 'service', $id, "Service #{$id} deleted");
        return $this->successResponse(null, 'Service deleted.');
    }
}