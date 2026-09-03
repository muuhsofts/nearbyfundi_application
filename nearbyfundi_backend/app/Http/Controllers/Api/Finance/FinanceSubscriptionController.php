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

        $query = Subscription::whereBetween('created_at', [$start, $end]);
        if ($status && $status !== 'all') $query->where('status', $status);

        $breakdown = (clone $query)
            ->selectRaw('status, count(*) as total, sum(amount_paid) as revenue')
            ->groupBy('status')
            ->get()
            ->map(fn ($r) => ['status' => $r->status, 'total' => (int) $r->total, 'revenue' => (float) $r->revenue]);

        return $this->successResponse([
            'range' => ['start' => $start->toDateString(), 'end' => $end->toDateString(), 'label' => $range],
            'totals' => [
                'count'   => (clone $query)->count(),
                'revenue' => (float) (clone $query)->sum('amount_paid'),
            ],
            'status_breakdown' => $breakdown,
        ]);
    }

    public function trends(Request $request)
    {
        [$start, $end, $range] = $this->resolveRange($request);
        $granularity = $this->resolveGranularity($request, $range);
        $unit = $this->bucketUnit($granularity);
        $status = $request->input('status');

        $buckets = [];
        foreach (CarbonPeriod::create($start, "1 {$unit}", $end) as $date) {
            $bStart = $date->copy()->startOf($unit);
            $bEnd = $date->copy()->endOf($unit);
            $q = Subscription::whereBetween('created_at', [$bStart, $bEnd]);
            if ($status && $status !== 'all') $q->where('status', $status);

            $buckets[] = [
                'label'   => $this->bucketLabel($bStart, $unit),
                'date'    => $bStart->toDateString(),
                'count'   => (clone $q)->count(),
                'revenue' => (float) (clone $q)->sum('amount_paid'),
            ];
        }

        return $this->successResponse(['granularity' => $granularity, 'buckets' => $buckets]);
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