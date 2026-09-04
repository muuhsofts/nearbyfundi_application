<?php

namespace App\Http\Controllers\Api\Finance;

use App\Http\Controllers\Api\BaseApiController;
use App\Models\Subscription;
use App\Traits\FinanceRangeTrait;
use Carbon\CarbonPeriod;
use Illuminate\Http\Request;

class FinanceSubscriptionController extends BaseApiController
{
    use FinanceRangeTrait;

   public function summary(Request $request)
{
    [$start, $end, $range] = $this->resolveRange($request);
    $status = $request->input('status');

    $baseQuery = Subscription::whereBetween('created_at', [$start, $end]);
    if ($status && $status !== 'all') {
        $baseQuery->where('status', $status);
    }

    // Total count and revenue
    $totalCount = (clone $baseQuery)->count();
    $totalRevenue = (float) (clone $baseQuery)->sum('amount_paid');

    // Active subscriptions: status='active' AND (expiry_date IS NULL OR expiry_date > now)
    $activeCount = (clone $baseQuery)
        ->where('status', 'active')
        ->where(function($q) {
            $q->whereNull('expiry_date')
              ->orWhere('expiry_date', '>', now());
        })
        ->count();

    // Expired subscriptions: status='expired' OR (status='active' AND expiry_date <= now)
    $expiredCount = (clone $baseQuery)
        ->where(function($q) {
            $q->where('status', 'expired')
              ->orWhere(function($sub) {
                  $sub->where('status', 'active')
                      ->whereNotNull('expiry_date')
                      ->where('expiry_date', '<=', now());
              });
        })
        ->count();

    // Status breakdown
    $breakdown = (clone $baseQuery)
        ->selectRaw('status, count(*) as total, sum(amount_paid) as revenue')
        ->groupBy('status')
        ->get()
        ->map(fn ($r) => [
            'status' => $r->status, 
            'total' => (int) $r->total, 
            'revenue' => (float) $r->revenue
        ]);

    return $this->successResponse([
        'range' => ['start' => $start->toDateString(), 'end' => $end->toDateString(), 'label' => $range],
        'totals' => [
            'count'   => $totalCount,
            'revenue' => $totalRevenue,
            'active'  => $activeCount,
            'expired' => $expiredCount,
        ],
        'status_breakdown' => $breakdown,
    ]);
}

    public function table(Request $request)
    {
        [$start, $end] = $this->resolveRange($request);
        $status = $request->input('status');
        $search = $request->input('search');

        $query = Subscription::with(['user', 'rateCard'])->whereBetween('created_at', [$start, $end]);
        if ($status && $status !== 'all') $query->where('status', $status);
        if ($search) {
            $query->whereHas('user', fn ($q) => $q->where('name', 'LIKE', "%{$search}%")->orWhere('email', 'LIKE', "%{$search}%"));
        }

        return $this->successResponse($query->orderBy('created_at', 'desc')->paginate($request->input('per_page', 10)));
    }

    public function export(Request $request)
    {
        [$start, $end] = $this->resolveRange($request);
        $status = $request->input('status');
        $format = $request->input('format', 'csv');

        $query = Subscription::with(['user', 'rateCard'])->whereBetween('created_at', [$start, $end]);
        if ($status && $status !== 'all') $query->where('status', $status);

        $rows = $query->orderBy('created_at', 'desc')->get();
        $headers = ['ID', 'User', 'Email', 'Plan', 'Amount', 'Currency', 'Status', 'Payment Method', 'Created At', 'Expiry'];
        $filename = 'finance_subscriptions_' . now()->format('Y-m-d_His');

        $mapRow = fn ($row) => [
            $row->id, $row->user->name ?? '-', $row->user->email ?? '-', $row->rateCard->name ?? '-',
            $row->amount_paid, $row->currency, $row->status, $row->payment_method,
            optional($row->created_at)->format('Y-m-d H:i'), optional($row->expiry_date)->format('Y-m-d H:i'),
        ];

        return $format === 'xlsx'
            ? $this->exportExcel($rows, $headers, $filename, $mapRow)
            : $this->exportCsv($rows, $headers, $filename, $mapRow);
    }
}