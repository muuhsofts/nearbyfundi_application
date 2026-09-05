<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\BaseApiController;
use App\Models\ServiceRequest;
use App\Models\Subscription;
use App\Models\Technician;
use App\Models\User;
use App\Traits\FinanceRangeTrait;
use Carbon\Carbon;
use Carbon\CarbonPeriod;
use Illuminate\Http\Request;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

/**
 * Consolidates FinanceCustomerController, FinanceRequestController,
 * FinanceSubscriptionController and FinanceTechnicianController behind a
 * single set of endpoints:
 *
 *   GET /v12/reports/summary    ?type=&status=&(range params)
 *   GET /v12/reports/trends     ?type=&status=&granularity=&(range params)
 *   GET /v12/reports/detailed   ?type=(required)&status=&search=&per_page=&(range params)
 *   GET /v12/reports/overview   ?(range params)
 *   GET /v12/reports/export     ?type=&format=csv|xlsx&status=&(range params)
 *
 * `type` is one of: customers | requests | subscriptions | technicians | all
 * (all is the default for summary/trends, and means "every domain combined";
 * detailed always needs one specific type since the tables don't share columns).
 */
class ReportController extends BaseApiController
{
    use FinanceRangeTrait;

    private const DOMAINS = ['customers', 'requests', 'subscriptions', 'technicians'];

    // =====================================================================
    //  GET /v12/reports/summary
    // =====================================================================
    public function summary(Request $request)
    {
        [$start, $end, $range] = $this->resolveRange($request);
        $type = $request->input('type', 'all');

        if ($type !== 'all') {
            if (!$this->isValidType($type)) {
                return $this->invalidTypeResponse($type);
            }

            return $this->successResponse(array_merge(
                ['range' => $this->rangePayload($start, $end, $range), 'type' => $type],
                $this->buildSummary($type, $request, $start, $end)
            ));
        }

        $customers     = $this->buildSummary('customers', $request, $start, $end);
        $requests      = $this->buildSummary('requests', $request, $start, $end);
        $subscriptions = $this->buildSummary('subscriptions', $request, $start, $end);
        $technicians   = $this->buildSummary('technicians', $request, $start, $end);

        return $this->successResponse([
            'range' => $this->rangePayload($start, $end, $range),
            'combined_totals' => [
                'customers'          => $customers['totals']['count'],
                'requests'           => $requests['totals']['count'],
                'subscriptions'      => $subscriptions['totals']['count'],
                'subscriptions_revenue' => $subscriptions['totals']['revenue'],
                'technicians'        => $technicians['totals']['count'],
            ],
            'customers'     => $customers,
            'requests'      => $requests,
            'subscriptions' => $subscriptions,
            'technicians'   => $technicians,
        ]);
    }

    // =====================================================================
    //  GET /v12/reports/trends
    // =====================================================================
    public function trends(Request $request)
    {
        [$start, $end, $range] = $this->resolveRange($request);
        $granularity = $this->resolveGranularity($request, $range);
        $unit = $this->bucketUnit($granularity);
        $type = $request->input('type', 'all');
        $status = $request->input('status');

        if ($type !== 'all') {
            if (!$this->isValidType($type)) {
                return $this->invalidTypeResponse($type);
            }

            $buckets = [];
            foreach (CarbonPeriod::create($start, "1 {$unit}", $end) as $date) {
                $bStart = $date->copy()->startOf($unit);
                $bEnd   = $date->copy()->endOf($unit);
                $point  = $this->bucketPoint($type, $bStart, $bEnd, $status);

                $buckets[] = array_merge([
                    'label' => $this->bucketLabel($bStart, $unit),
                    'date'  => $bStart->toDateString(),
                ], $point);
            }

            return $this->successResponse([
                'type'        => $type,
                'granularity' => $granularity,
                'buckets'     => $buckets,
            ]);
        }

        // Combined: one bucket loop, one series per domain (status filter is
        // ignored here since it means something different per domain).
        $buckets = [];
        foreach (CarbonPeriod::create($start, "1 {$unit}", $end) as $date) {
            $bStart = $date->copy()->startOf($unit);
            $bEnd   = $date->copy()->endOf($unit);

            $buckets[] = [
                'label' => $this->bucketLabel($bStart, $unit),
                'date'  => $bStart->toDateString(),
                'customers'             => $this->bucketPoint('customers', $bStart, $bEnd, null)['count'],
                'requests'              => $this->bucketPoint('requests', $bStart, $bEnd, null)['count'],
                'subscriptions'         => $this->bucketPoint('subscriptions', $bStart, $bEnd, null)['count'],
                'subscriptions_revenue' => $this->bucketPoint('subscriptions', $bStart, $bEnd, null)['revenue'],
                'technicians'           => $this->bucketPoint('technicians', $bStart, $bEnd, null)['count'],
            ];
        }

        return $this->successResponse([
            'granularity' => $granularity,
            'buckets'     => $buckets,
        ]);
    }

    // =====================================================================
    //  GET /v12/reports/detailed
    //  A single-domain paginated table (equivalent to the old `table()`
    //  endpoints). `type` is required since schemas differ per domain.
    // =====================================================================
    public function detailed(Request $request)
    {
        $type = $request->input('type');

        if (!$type || !$this->isValidType($type)) {
            return $this->invalidTypeResponse($type, true);
        }

        [$start, $end] = $this->resolveRange($request);
        $status = $request->input('status');
        $search = $request->input('search');
        $perPage = $request->input('per_page', 10);

        $query = match ($type) {
            'customers' => User::role('CUSTOMER')->whereBetween('created_at', [$start, $end]),
            'requests'  => ServiceRequest::with(['customer', 'technician.user', 'service'])
                ->whereBetween('created_at', [$start, $end]),
            'subscriptions' => Subscription::with(['user', 'rateCard'])
                ->whereBetween('created_at', [$start, $end]),
            'technicians' => Technician::with('user')->whereBetween('created_at', [$start, $end]),
        };

        if ($status && $status !== 'all') {
            $statusColumn = $type === 'technicians' ? 'verification_status' : 'status';
            $query->where($statusColumn, $status);
        }

        if ($search) {
            $this->applySearch($query, $type, $search);
        }

        return $this->successResponse(
            $query->orderBy('created_at', 'desc')->paginate($perPage)
        );
    }

    // =====================================================================
    //  GET /v12/reports/overview
    //  Dashboard snapshot: headline totals + growth vs. the previous period
    //  of equal length, plus a compact combined trend.
    // =====================================================================
    public function overview(Request $request)
    {
        [$start, $end, $range] = $this->resolveRange($request);
        [$prevStart, $prevEnd] = $this->previousPeriod($start, $end);

        $current = [
            'customers'     => $this->buildSummary('customers', $request, $start, $end),
            'requests'      => $this->buildSummary('requests', $request, $start, $end),
            'subscriptions' => $this->buildSummary('subscriptions', $request, $start, $end),
            'technicians'   => $this->buildSummary('technicians', $request, $start, $end),
        ];

        $previous = [
            'customers'     => $this->buildSummary('customers', $request, $prevStart, $prevEnd),
            'requests'      => $this->buildSummary('requests', $request, $prevStart, $prevEnd),
            'subscriptions' => $this->buildSummary('subscriptions', $request, $prevStart, $prevEnd),
            'technicians'   => $this->buildSummary('technicians', $request, $prevStart, $prevEnd),
        ];

        $headline = [];
        foreach (self::DOMAINS as $domain) {
            $headline[$domain] = [
                'count'  => $current[$domain]['totals']['count'],
                'growth' => $this->growth(
                    $current[$domain]['totals']['count'],
                    $previous[$domain]['totals']['count']
                ),
            ];
        }
        $headline['subscriptions']['revenue'] = $current['subscriptions']['totals']['revenue'];
        $headline['subscriptions']['revenue_growth'] = $this->growth(
            $current['subscriptions']['totals']['revenue'],
            $previous['subscriptions']['totals']['revenue']
        );

        // Compact combined trend for a quick chart on the same screen.
        $granularity = $this->resolveGranularity($request, $range);
        $unit = $this->bucketUnit($granularity);
        $buckets = [];
        foreach (CarbonPeriod::create($start, "1 {$unit}", $end) as $date) {
            $bStart = $date->copy()->startOf($unit);
            $bEnd   = $date->copy()->endOf($unit);

            $buckets[] = [
                'label'         => $this->bucketLabel($bStart, $unit),
                'date'          => $bStart->toDateString(),
                'customers'     => $this->bucketPoint('customers', $bStart, $bEnd, null)['count'],
                'requests'      => $this->bucketPoint('requests', $bStart, $bEnd, null)['count'],
                'subscriptions' => $this->bucketPoint('subscriptions', $bStart, $bEnd, null)['count'],
                'technicians'   => $this->bucketPoint('technicians', $bStart, $bEnd, null)['count'],
            ];
        }

        return $this->successResponse([
            'range' => $this->rangePayload($start, $end, $range),
            'previous_range' => $this->rangePayload($prevStart, $prevEnd, null),
            'headline' => $headline,
            'trend' => [
                'granularity' => $granularity,
                'buckets'     => $buckets,
            ],
        ]);
    }

    // =====================================================================
    //  GET /v12/reports/export
    //  Single domain -> csv/xlsx (same output as the old export() methods).
    //  type=all -> combined multi-sheet xlsx only.
    // =====================================================================
    public function export(Request $request)
    {
        [$start, $end] = $this->resolveRange($request);
        $status = $request->input('status');
        $format = $request->input('format', 'csv');
        $type = $request->input('type', 'all');

        if ($type === 'all') {
            if ($format !== 'xlsx') {
                return $this->errorResponse(
                    "Combined export only supports format=xlsx (each domain has different columns). Pass a specific ?type= for csv.",
                    422
                );
            }

            return $this->exportCombined($start, $end, $status);
        }

        if (!$this->isValidType($type)) {
            return $this->invalidTypeResponse($type);
        }

        [$headers, $rows, $mapRow, $filename] = $this->exportDataFor($type, $start, $end, $status);

        return $format === 'xlsx'
            ? $this->exportExcel($rows, $headers, $filename, $mapRow)
            : $this->exportCsv($rows, $headers, $filename, $mapRow);
    }

    // =====================================================================
    //  Internal helpers
    // =====================================================================

    private function isValidType(?string $type): bool
    {
        return in_array($type, self::DOMAINS, true);
    }

    private function invalidTypeResponse(?string $type, bool $required = false)
    {
        $message = $required
            ? "A ?type= is required. Expected one of: " . implode(', ', self::DOMAINS)
            : "Invalid type '{$type}'. Expected one of: " . implode(', ', self::DOMAINS) . ', or all';

        return $this->errorResponse($message, 422);
    }

    private function rangePayload(Carbon $start, Carbon $end, ?string $range): array
    {
        return array_filter([
            'start' => $start->toDateString(),
            'end'   => $end->toDateString(),
            'label' => $range,
        ], fn ($v) => $v !== null);
    }

    private function previousPeriod(Carbon $start, Carbon $end): array
    {
        $seconds = max($start->diffInSeconds($end), 1);
        $prevEnd = $start->copy()->subSecond();
        $prevStart = $prevEnd->copy()->subSeconds($seconds);

        return [$prevStart, $prevEnd];
    }

    private function growth($current, $previous): float
    {
        if ((float) $previous == 0.0) {
            return $current > 0 ? 100.0 : 0.0;
        }

        return round((($current - $previous) / $previous) * 100, 2);
    }

    /**
     * Builds the same {totals, status_breakdown} shape the original
     * Finance*Controllers::summary() returned, for one domain.
     */
    private function buildSummary(string $type, Request $request, Carbon $start, Carbon $end): array
    {
        $status = $request->input('status');

        return match ($type) {
            'customers' => $this->summaryCustomers($start, $end, $status),
            'requests' => $this->summaryRequests($start, $end, $status),
            'subscriptions' => $this->summarySubscriptions($start, $end, $status),
            'technicians' => $this->summaryTechnicians($start, $end, $status),
        };
    }

    private function summaryCustomers(Carbon $start, Carbon $end, ?string $status): array
    {
        $query = User::role('CUSTOMER')->whereBetween('created_at', [$start, $end]);
        if ($status && $status !== 'all') {
            $query->where('status', $status);
        }

        $breakdown = (clone $query)
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->get()
            ->map(fn ($r) => ['status' => $r->status, 'total' => (int) $r->total]);

        return [
            'totals' => [
                'count'     => (clone $query)->count(),
                'active'    => (clone $query)->where('status', 'active')->count(),
                'pending'   => (clone $query)->where('status', 'pending')->count(),
                'suspended' => (clone $query)->where('status', 'suspended')->count(),
            ],
            'status_breakdown' => $breakdown,
        ];
    }

    private function summaryRequests(Carbon $start, Carbon $end, ?string $status): array
    {
        $query = ServiceRequest::whereBetween('created_at', [$start, $end]);
        if ($status && $status !== 'all') {
            $query->where('status', $status);
        }

        $breakdown = (clone $query)
            ->selectRaw('status, count(*) as total')
            ->groupBy('status')
            ->get()
            ->map(fn ($r) => ['status' => $r->status, 'total' => (int) $r->total]);

        return [
            'totals' => [
                'count'      => (clone $query)->count(),
                'pending'    => (clone $query)->where('status', 'pending')->count(),
                'accepted'   => (clone $query)->where('status', 'accepted')->count(),
                'completed'  => (clone $query)->where('status', 'completed')->count(),
                'on_the_way' => (clone $query)->where('status', 'on_the_way')->count(),
                'rejected'   => (clone $query)->where('status', 'rejected')->count(),
                'cancelled'  => (clone $query)->where('status', 'cancelled')->count(),
            ],
            'status_breakdown' => $breakdown,
        ];
    }

    private function summarySubscriptions(Carbon $start, Carbon $end, ?string $status): array
    {
        $query = Subscription::whereBetween('created_at', [$start, $end]);
        if ($status && $status !== 'all') {
            $query->where('status', $status);
        }

        $activeCount = (clone $query)
            ->where('status', 'active')
            ->where(fn ($q) => $q->whereNull('expiry_date')->orWhere('expiry_date', '>', now()))
            ->count();

        $expiredCount = (clone $query)
            ->where(function ($q) {
                $q->where('status', 'expired')
                  ->orWhere(function ($sub) {
                      $sub->where('status', 'active')
                          ->whereNotNull('expiry_date')
                          ->where('expiry_date', '<=', now());
                  });
            })
            ->count();

        $breakdown = (clone $query)
            ->selectRaw('status, count(*) as total, sum(amount_paid) as revenue')
            ->groupBy('status')
            ->get()
            ->map(fn ($r) => [
                'status'  => $r->status,
                'total'   => (int) $r->total,
                'revenue' => (float) $r->revenue,
            ]);

        return [
            'totals' => [
                'count'   => (clone $query)->count(),
                'revenue' => (float) (clone $query)->sum('amount_paid'),
                'active'  => $activeCount,
                'expired' => $expiredCount,
            ],
            'status_breakdown' => $breakdown,
        ];
    }

    private function summaryTechnicians(Carbon $start, Carbon $end, ?string $status): array
    {
        $query = Technician::whereBetween('created_at', [$start, $end]);
        if ($status && $status !== 'all') {
            $query->where('verification_status', $status);
        }

        $breakdown = (clone $query)
            ->selectRaw('verification_status as status, count(*) as total')
            ->groupBy('verification_status')
            ->get()
            ->map(fn ($r) => ['status' => $r->status, 'total' => (int) $r->total]);

        return [
            'totals' => [
                'count'    => (clone $query)->count(),
                'approved' => (clone $query)->where('verification_status', 'approved')->count(),
                'pending'  => (clone $query)->where('verification_status', 'pending')->count(),
                'online'   => (clone $query)->where('is_online', true)->count(),
            ],
            'status_breakdown' => $breakdown,
        ];
    }

    /**
     * Count (+ revenue, for subscriptions) for one domain within one bucket window.
     */
    private function bucketPoint(string $type, Carbon $bStart, Carbon $bEnd, ?string $status): array
    {
        return match ($type) {
            'customers' => (function () use ($bStart, $bEnd, $status) {
                $q = User::role('CUSTOMER')->whereBetween('created_at', [$bStart, $bEnd]);
                if ($status && $status !== 'all') $q->where('status', $status);
                return ['count' => $q->count()];
            })(),
            'requests' => (function () use ($bStart, $bEnd, $status) {
                $q = ServiceRequest::whereBetween('created_at', [$bStart, $bEnd]);
                if ($status && $status !== 'all') $q->where('status', $status);
                return ['count' => $q->count()];
            })(),
            'subscriptions' => (function () use ($bStart, $bEnd, $status) {
                $q = Subscription::whereBetween('created_at', [$bStart, $bEnd]);
                if ($status && $status !== 'all') $q->where('status', $status);
                return [
                    'count'   => (clone $q)->count(),
                    'revenue' => (float) (clone $q)->sum('amount_paid'),
                ];
            })(),
            'technicians' => (function () use ($bStart, $bEnd, $status) {
                $q = Technician::whereBetween('created_at', [$bStart, $bEnd]);
                if ($status && $status !== 'all') $q->where('verification_status', $status);
                return ['count' => $q->count()];
            })(),
        };
    }

    private function applySearch($query, string $type, string $search): void
    {
        match ($type) {
            'customers' => $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%")
                  ->orWhere('phone', 'LIKE', "%{$search}%");
            }),
            'requests' => $query->where(function ($q) use ($search) {
                $q->where('description', 'LIKE', "%{$search}%")
                  ->orWhereHas('customer', fn ($u) => $u->where('name', 'LIKE', "%{$search}%")
                      ->orWhere('email', 'LIKE', "%{$search}%")
                      ->orWhere('phone', 'LIKE', "%{$search}%"))
                  ->orWhereHas('technician.user', fn ($u) => $u->where('name', 'LIKE', "%{$search}%"))
                  ->orWhereHas('service', fn ($s) => $s->where('name', 'LIKE', "%{$search}%"));
            }),
            'subscriptions' => $query->whereHas('user', fn ($q) => $q->where('name', 'LIKE', "%{$search}%")
                ->orWhere('email', 'LIKE', "%{$search}%")),
            'technicians' => $query->where(function ($q) use ($search) {
                $q->where('area', 'LIKE', "%{$search}%")
                  ->orWhereHas('user', fn ($u) => $u->where('name', 'LIKE', "%{$search}%")
                      ->orWhere('email', 'LIKE', "%{$search}%"));
            }),
            default => null,
        };
    }

    /**
     * Returns [headers, rows, mapRow, filename] for a single-domain export,
     * matching the original Finance*Controllers::export() column sets.
     */
    private function exportDataFor(string $type, Carbon $start, Carbon $end, ?string $status): array
    {
        $timestamp = now()->format('Y-m-d_His');

        return match ($type) {
            'customers' => (function () use ($start, $end, $status, $timestamp) {
                $query = User::role('CUSTOMER')->whereBetween('created_at', [$start, $end]);
                if ($status && $status !== 'all') $query->where('status', $status);

                return [
                    ['ID', 'Name', 'Email', 'Phone', 'Status', 'Active', 'Created At'],
                    $query->orderBy('created_at', 'desc')->get(),
                    fn ($row) => [
                        $row->id, $row->name, $row->email, $row->phone ?? '-',
                        $row->status, $row->is_active ? 'Yes' : 'No',
                        optional($row->created_at)->format('Y-m-d H:i'),
                    ],
                    "finance_customers_{$timestamp}",
                ];
            })(),
            'requests' => (function () use ($start, $end, $status, $timestamp) {
                $query = ServiceRequest::with(['customer', 'technician.user', 'service'])
                    ->whereBetween('created_at', [$start, $end]);
                if ($status && $status !== 'all') $query->where('status', $status);

                return [
                    ['ID', 'Customer', 'Technician', 'Service', 'Status', 'Description', 'Created At'],
                    $query->orderBy('created_at', 'desc')->get(),
                    fn ($row) => [
                        $row->id, $row->customer->name ?? '-', $row->technician->user->name ?? '-',
                        $row->service->name ?? '-', $row->status, $row->description,
                        optional($row->created_at)->format('Y-m-d H:i'),
                    ],
                    "finance_requests_{$timestamp}",
                ];
            })(),
            'subscriptions' => (function () use ($start, $end, $status, $timestamp) {
                $query = Subscription::with(['user', 'rateCard'])->whereBetween('created_at', [$start, $end]);
                if ($status && $status !== 'all') $query->where('status', $status);

                return [
                    ['ID', 'User', 'Email', 'Plan', 'Amount', 'Currency', 'Status', 'Payment Method', 'Created At', 'Expiry'],
                    $query->orderBy('created_at', 'desc')->get(),
                    fn ($row) => [
                        $row->id, $row->user->name ?? '-', $row->user->email ?? '-', $row->rateCard->name ?? '-',
                        $row->amount_paid, $row->currency, $row->status, $row->payment_method,
                        optional($row->created_at)->format('Y-m-d H:i'), optional($row->expiry_date)->format('Y-m-d H:i'),
                    ],
                    "finance_subscriptions_{$timestamp}",
                ];
            })(),
            'technicians' => (function () use ($start, $end, $status, $timestamp) {
                $query = Technician::with('user')->whereBetween('created_at', [$start, $end]);
                if ($status && $status !== 'all') $query->where('verification_status', $status);

                return [
                    ['ID', 'Name', 'Email', 'Area', 'Rating', 'Verification Status', 'Online', 'Created At'],
                    $query->orderBy('created_at', 'desc')->get(),
                    fn ($row) => [
                        $row->id, $row->user->name ?? '-', $row->user->email ?? '-', $row->area,
                        $row->rating, $row->verification_status, $row->is_online ? 'Yes' : 'No',
                        optional($row->created_at)->format('Y-m-d H:i'),
                    ],
                    "finance_technicians_{$timestamp}",
                ];
            })(),
        };
    }

    /**
     * Combined multi-sheet xlsx export (one sheet per domain), built directly
     * with PhpSpreadsheet so it doesn't depend on BaseApiController::exportExcel()
     * being single-sheet only. Adjust namespace/imports above if your project
     * uses a different Excel package.
     */
    private function exportCombined(Carbon $start, Carbon $end, ?string $status)
    {
        $spreadsheet = new Spreadsheet();
        $spreadsheet->removeSheetByIndex(0);

        $sheetTitles = [
            'customers'     => 'Customers',
            'requests'      => 'Requests',
            'subscriptions' => 'Subscriptions',
            'technicians'   => 'Technicians',
        ];

        foreach (self::DOMAINS as $type) {
            [$headers, $rows, $mapRow] = $this->exportDataFor($type, $start, $end, $status);

            $sheet = $spreadsheet->createSheet();
            $sheet->setTitle($sheetTitles[$type]);
            $sheet->fromArray($headers, null, 'A1');

            $rowIndex = 2;
            foreach ($rows as $row) {
                $sheet->fromArray($mapRow($row), null, "A{$rowIndex}");
                $rowIndex++;
            }

            foreach (range('A', $sheet->getHighestColumn()) as $col) {
                $sheet->getColumnDimension($col)->setAutoSize(true);
            }
        }

        $filename = 'finance_report_' . now()->format('Y-m-d_His') . '.xlsx';
        $writer = new Xlsx($spreadsheet);

        return response()->streamDownload(function () use ($writer) {
            $writer->save('php://output');
        }, $filename, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }
}