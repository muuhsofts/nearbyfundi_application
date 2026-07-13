<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Technician;
use App\Models\ServiceRequest;
use App\Models\Post;
use App\Models\Comment;
use App\Models\Portfolio;
use App\Models\Service;
use App\Models\Like;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ReportController extends BaseApiController
{
    /**
     * Users report – paginated with stats and trend.
     */
    public function usersReport(Request $request)
    {
        $this->checkPermission('reports.view');

        $query = User::with('roles');

        // Filters
        if ($request->filled('role')) {
            $query->role($request->role);
        }
        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }
        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        // Date range from period filters
        list($start, $end) = $this->parseDateRange($request);
        if ($start) {
            $query->whereDate('created_at', '>=', $start);
        }
        if ($end) {
            $query->whereDate('created_at', '<=', $end);
        }

        $users = $query->paginate($request->input('per_page', 20));

        $stats = $this->getUserStats($start, $end);
        $trend = $this->getUserTrend($start, $end);

        return $this->successResponse([
            'data'   => $users,
            'stats'  => $stats,
            'trend'  => $trend,
        ]);
    }

    /**
     * Technicians report – includes area filter, no online/offline.
     */
    public function techniciansReport(Request $request)
    {
        $this->checkPermission('reports.view');

        $query = Technician::with('user');

        // Filters
        if ($request->filled('verified')) {
            $query->where('verified', $request->verified === 'true');
        }
        if ($request->filled('area')) {
            $query->where('area', 'like', "%{$request->area}%");
        }
        if ($request->filled('search')) {
            $search = $request->search;
            $query->whereHas('user', function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        list($start, $end) = $this->parseDateRange($request);
        if ($start) {
            $query->whereDate('created_at', '>=', $start);
        }
        if ($end) {
            $query->whereDate('created_at', '<=', $end);
        }

        $technicians = $query->paginate($request->input('per_page', 20));

        $stats = $this->getTechnicianStats($start, $end);
        $trend = $this->getTechnicianTrend($start, $end);

        return $this->successResponse([
            'data'   => $technicians,
            'stats'  => $stats,
            'trend'  => $trend,
        ]);
    }

    /**
     * Service requests report – with status filter.
     */
    public function requestsReport(Request $request)
    {
        $this->checkPermission('reports.view');

        $query = ServiceRequest::with('customer', 'technician.user', 'service');

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }
        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('description', 'like', "%{$search}%")
                    ->orWhereHas('customer', fn($cq) => $cq->where('name', 'like', "%{$search}%"))
                    ->orWhereHas('technician.user', fn($tq) => $tq->where('name', 'like', "%{$search}%"));
            });
        }

        list($start, $end) = $this->parseDateRange($request);
        if ($start) {
            $query->whereDate('created_at', '>=', $start);
        }
        if ($end) {
            $query->whereDate('created_at', '<=', $end);
        }

        $requests = $query->orderBy('created_at', 'desc')
            ->paginate($request->input('per_page', 20));

        $stats = $this->getRequestStats($start, $end);
        $trend = $this->getRequestTrend($start, $end);

        return $this->successResponse([
            'data'   => $requests,
            'stats'  => $stats,
            'trend'  => $trend,
        ]);
    }

    /**
     * Services report – top services by request count.
     */
    public function servicesReport(Request $request)
    {
        $this->checkPermission('reports.view');

        list($start, $end) = $this->parseDateRange($request);

        $query = Service::withCount(['requests' => function ($q) use ($start, $end) {
            if ($start) $q->whereDate('created_at', '>=', $start);
            if ($end)   $q->whereDate('created_at', '<=', $end);
        }]);

        $services = $query->orderBy('requests_count', 'desc')->get();

        return $this->successResponse([
            'data'  => $services,
            'stats' => [
                'total'            => $services->count(),
                'total_requests'   => $services->sum('requests_count'),
                'avg_per_service'  => $services->avg('requests_count'),
            ],
        ]);
    }

    /**
     * Blog report – posts, comments, likes, and trends.
     */
    public function blogReport(Request $request)
    {
        $this->checkPermission('reports.view');

        list($start, $end) = $this->parseDateRange($request);

        // Base queries with date filters
        $postsQuery    = Post::query();
        $commentsQuery = Comment::query();
        $likesQuery    = Like::query();

        if ($start) {
            $postsQuery->whereDate('created_at', '>=', $start);
            $commentsQuery->whereDate('created_at', '>=', $start);
            $likesQuery->whereDate('created_at', '>=', $start);
        }
        if ($end) {
            $postsQuery->whereDate('created_at', '<=', $end);
            $commentsQuery->whereDate('created_at', '<=', $end);
            $likesQuery->whereDate('created_at', '<=', $end);
        }

        $totalPosts = $postsQuery->count();

        $stats = [
            'total_posts'             => $totalPosts,
            'total_comments'          => $commentsQuery->count(),
            'total_likes'             => $likesQuery->count(),
            'avg_comments_per_post'   => $totalPosts > 0 ? $commentsQuery->count() / $totalPosts : 0,

            'posts_with_most_comments' => Post::withCount(['comments' => function ($q) use ($start, $end) {
                if ($start) $q->whereDate('created_at', '>=', $start);
                if ($end)   $q->whereDate('created_at', '<=', $end);
            }])->orderBy('comments_count', 'desc')->limit(5)->get(['id', 'title', 'comments_count']),

            'posts_with_most_likes' => Post::withCount(['likes' => function ($q) use ($start, $end) {
                if ($start) $q->whereDate('created_at', '>=', $start);
                if ($end)   $q->whereDate('created_at', '<=', $end);
            }])->orderBy('likes_count', 'desc')->limit(5)->get(['id', 'title', 'likes_count']),

            'comments_by_user' => Comment::selectRaw('user_id, count(*) as count')
                ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
                ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
                ->groupBy('user_id')
                ->orderBy('count', 'desc')
                ->limit(5)
                ->with('user:id,name')
                ->get(),
        ];

        // Blog post trend (daily)
        $trend = Post::select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('COUNT(*) as posts')
            )
            ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
            ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
            ->groupBy('date')
            ->orderBy('date', 'asc')
            ->get();

        return $this->successResponse([
            'stats' => $stats,
            'trend' => $trend,
        ]);
    }

    /**
     * Portfolio report – total items and technicians with most items.
     */
    public function portfolioReport(Request $request)
    {
        $this->checkPermission('reports.view');

        list($start, $end) = $this->parseDateRange($request);

        $query = Portfolio::query();
        if ($start) $query->whereDate('created_at', '>=', $start);
        if ($end)   $query->whereDate('created_at', '<=', $end);

        $total = $query->count();

        $techPortfolios = Portfolio::selectRaw('technician_id, count(*) as count')
            ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
            ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
            ->groupBy('technician_id')
            ->orderBy('count', 'desc')
            ->limit(10)
            ->with('technician.user:id,name')
            ->get();

        return $this->successResponse([
            'total_portfolio_items'           => $total,
            'technicians_with_most_portfolios' => $techPortfolios,
        ]);
    }

    // ---------- Aggregation Helpers ----------

    private function getUserStats($start, $end)
    {
        $query = User::query();
        if ($start) $query->whereDate('created_at', '>=', $start);
        if ($end)   $query->whereDate('created_at', '<=', $end);

        $total    = $query->count();
        $active   = (clone $query)->where('is_active', true)->count();
        $inactive = (clone $query)->where('is_active', false)->count();

        return ['total' => $total, 'active' => $active, 'inactive' => $inactive];
    }

    private function getTechnicianStats($start, $end)
    {
        $query = Technician::query();
        if ($start) $query->whereDate('created_at', '>=', $start);
        if ($end)   $query->whereDate('created_at', '<=', $end);

        $total    = $query->count();
        $verified = (clone $query)->where('verified', true)->count();

        return ['total' => $total, 'verified' => $verified];
    }

    private function getRequestStats($start, $end)
    {
        $query = ServiceRequest::query();
        if ($start) $query->whereDate('created_at', '>=', $start);
        if ($end)   $query->whereDate('created_at', '<=', $end);

        $total    = $query->count();
        $statuses = (clone $query)->select('status', DB::raw('count(*) as count'))
            ->groupBy('status')
            ->get();

        return ['total' => $total, 'by_status' => $statuses];
    }

    private function getUserTrend($start, $end)
    {
        return User::select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('COUNT(*) as total')
            )
            ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
            ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
            ->groupBy('date')
            ->orderBy('date', 'asc')
            ->get();
    }

    private function getTechnicianTrend($start, $end)
    {
        return Technician::select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('COUNT(*) as total')
            )
            ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
            ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
            ->groupBy('date')
            ->orderBy('date', 'asc')
            ->get();
    }

    private function getRequestTrend($start, $end)
    {
        return ServiceRequest::select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('COUNT(*) as total')
            )
            ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
            ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
            ->groupBy('date')
            ->orderBy('date', 'asc')
            ->get();
    }

    /**
     * Parse period and date from request, return Carbon instances in EAT.
     *
     * @param Request $request
     * @return array [start, end] (Carbon|null)
     */
    private function parseDateRange(Request $request)
    {
        $period = $request->get('period');
        $date   = $request->get('date');

        if (!$period || !$date) {
            return [null, null];
        }

        $tz = 'Africa/Dar_es_Salaam';
        $start = null;
        $end   = null;

        if ($period === 'daily') {
            $start = Carbon::parse($date, $tz)->startOfDay();
            $end   = Carbon::parse($date, $tz)->endOfDay();
        } elseif ($period === 'monthly') {
            $start = Carbon::parse($date . '-01', $tz)->startOfDay();
            $end   = Carbon::parse($date . '-01', $tz)->endOfMonth()->endOfDay();
        } elseif ($period === 'yearly') {
            $start = Carbon::parse($date . '-01-01', $tz)->startOfDay();
            $end   = Carbon::parse($date . '-12-31', $tz)->endOfDay();
        }

        return [$start, $end];
    }
}