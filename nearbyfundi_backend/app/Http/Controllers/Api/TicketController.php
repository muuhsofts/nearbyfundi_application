<?php
// app/Http/Controllers/Api/TicketController.php

namespace App\Http\Controllers\Api;

use App\Models\Ticket;
use Illuminate\Http\Request;

/**
 * Read-only ticket listing for the logged-in FUNDI (their jobs' tickets)
 * or CUSTOMER (tickets of their own jobs).
 */
class TicketController extends BaseApiController
{
    private const WITH = ['job.request.service', 'job.customer'];

    public function index(Request $request)
    {
        $user  = $request->user();
        $query = Ticket::with(self::WITH)->latest();

        if ($user->hasRole('CUSTOMER')) {
            $query->whereHas('job', fn ($q) => $q->where('customer_id', $user->id));
        } elseif ($user->hasRole('FUNDI') && $user->technician) {
            $query->whereHas('job', fn ($q) => $q->where('technician_id', $user->technician->id));
        } else {
            return $this->forbidden('You are not allowed to view tickets.');
        }

        if ($request->filled('status') && in_array($request->status, Ticket::STATUSES, true)) {
            $query->where('status', $request->status);
        }

        return $this->successResponse(
            $query->get()->map(fn (Ticket $t) => $this->format($t)),
            'Tickets retrieved successfully'
        );
    }

    public function show(Request $request, $id)
    {
        $user   = $request->user();
        $ticket = Ticket::with(self::WITH)->find($id);

        if (!$ticket || !$ticket->job) {
            return $this->notFound('Ticket not found.');
        }

        $job        = $ticket->job;
        $isCustomer = (int) $job->customer_id === (int) $user->id;
        $isFundi    = $user->hasRole('FUNDI') && $user->technician
            && (int) $user->technician->id === (int) $job->technician_id;

        if (!$isCustomer && !$isFundi) {
            return $this->notFound('Ticket not found.');
        }

        return $this->successResponse($this->format($ticket));
    }

    private function format(Ticket $t): array
    {
        $job     = $t->job;
        $service = $job?->request?->service;

        return [
            'id'            => $t->id,
            'ticket_number' => $t->ticket_number,
            'status'        => $t->status,
            'title'         => $t->title,
            'description'   => $t->description,
            'completed_at'  => $t->completed_at,
            'created_at'    => $t->created_at,
            'job'           => $job ? [
                'id'         => $job->id,
                'job_number' => $job->job_number,
                'status'     => $job->status,
            ] : null,
            'customer'      => $job?->customer
                ? ['id' => $job->customer->id, 'name' => $job->customer->name]
                : null,
            'service'       => $service
                ? ['id' => $service->id, 'name' => $service->name]
                : null,
        ];
    }
}