<?php

namespace App\Http\Controllers\Api;

use App\Models\Review;
use App\Models\ServiceRequest;
use App\Traits\Auditable;              // ← add this
use Illuminate\Http\Request;

class ReviewController extends BaseApiController
{
    use Auditable;                      // ← add this

    public function store(Request $request)
    {
        $data = $request->validate([
            'request_id' => 'required|exists:requests,id',
            'rating'     => 'required|integer|min:1|max:5',
            'comment'    => 'nullable|string|max:1000',
        ]);

        $serviceRequest = ServiceRequest::findOrFail($data['request_id']);
        if ($serviceRequest->status !== ServiceRequest::STATUS_COMPLETED) {
            return $this->errorResponse('Only completed requests can be reviewed.', 422);
        }

        if ($request->user()->id !== $serviceRequest->customer_id) {
            return $this->forbidden('You are not authorized to review this request.');
        }

        $existing = Review::where('request_id', $data['request_id'])->first();
        if ($existing) {
            return $this->errorResponse('This request has already been reviewed.', 422);
        }

        $review = Review::create([
            'request_id'    => $data['request_id'],
            'customer_id'   => $request->user()->id,
            'technician_id' => $serviceRequest->technician_id,
            'rating'        => $data['rating'],
            'comment'       => $data['comment'] ?? null,
        ]);

        $serviceRequest->technician->incrementCompletedJobs();

        // Rating recalculated automatically via model event

        // 🔍 Audit log – matches the style used in RequestController
        $this->logAudit('create_review', 'review', $review->id, "Customer reviewed request #{$data['request_id']}");

        return $this->created($review, 'Review submitted successfully.');
    }

    public function technicianReviews($technicianId)
    {
        $reviews = Review::with('customer')
            ->where('technician_id', $technicianId)
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(function ($review) {
                return [
                    'id'          => $review->id,
                    'rating'      => $review->rating,
                    'comment'     => $review->comment,
                    'created_at'  => $review->created_at->toIso8601String(),
                    'customer'    => $review->customer ? [
                        'id'    => $review->customer->id,
                        'name'  => $review->customer->name,
                    ] : null,
                ];
            });

        return $this->successResponse($reviews, 'Technician reviews retrieved.');
    }
}