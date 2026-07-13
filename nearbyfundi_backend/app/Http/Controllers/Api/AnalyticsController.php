<?php

namespace App\Http\Controllers\Api;

use App\Models\Post;
use App\Models\Comment;
use App\Models\Like;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\User;
use App\Models\Technician;
use App\Models\Role;
use App\Models\Permission;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class AnalyticsController extends BaseApiController
{
    /**
     * Get comprehensive dashboard analytics with all trends and breakdowns.
     * All date aggregations are done in East Africa Time (EAT, UTC+3).
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function getDashboardAnalytics(Request $request)
    {
        $this->checkPermission('dashboard.view');

        // ---------- Core Counts ----------
        $totalUsers = User::count();
        $activeUsers = User::where('is_active', true)->count();
        $inactiveUsers = User::where('is_active', false)->count();

        $usersByRole = DB::table('roles')
            ->leftJoin('model_has_roles', 'roles.id', '=', 'model_has_roles.role_id')
            ->select('roles.id', 'roles.name', 'roles.display_name', DB::raw('COUNT(model_has_roles.model_id) as users_count'))
            ->groupBy('roles.id', 'roles.name', 'roles.display_name')
            ->get();

        $totalRoles = Role::count();
        $totalPermissions = Permission::count();

        // ---------- Technicians ----------
        $totalTechnicians = Technician::count();
        $verifiedTechnicians = Technician::where('verified', true)->count();
        $unverifiedTechnicians = Technician::where('verified', false)->count();
        $onlineTechnicians = Technician::where('is_online', true)->count();
        $technicianRatingStats = Technician::select(
            DB::raw('AVG(rating) as average_rating'),
            DB::raw('MIN(rating) as min_rating'),
            DB::raw('MAX(rating) as max_rating')
        )->first();

        // ---------- Customers ----------
        $customerIds = User::whereDoesntHave('technician')->pluck('id');
        $totalCustomers = $customerIds->count();
        $activeCustomers = User::whereHas('customerRequests')->count();

        // ---------- Likes & Comments ----------
        $totalLikes = Like::count();
        $likesPerPost = Post::withCount('likes')
            ->orderBy('likes_count', 'desc')
            ->limit(10)
            ->get(['id', 'title', 'likes_count']);

        $totalComments = Comment::count();
        $commentsPerPost = Post::withCount('comments')
            ->orderBy('comments_count', 'desc')
            ->limit(10)
            ->get(['id', 'title', 'comments_count']);

        // ---------- Services ----------
        $totalServices = Service::count();
        $servicesWithRequests = Service::has('requests')->count();
        $servicesWithoutRequests = Service::doesntHave('requests')->count();
        $topServices = Service::withCount('requests')
            ->orderBy('requests_count', 'desc')
            ->limit(10)
            ->get(['id', 'name', 'requests_count']);

        // ---------- Service Requests ----------
        $totalRequests = ServiceRequest::count();
        $requestsByStatus = ServiceRequest::select('status', DB::raw('count(*) as total'))
            ->groupBy('status')
            ->get();

        $pendingRequests = ServiceRequest::where('status', 'pending')->count();
        $acceptedRequests = ServiceRequest::where('status', 'accepted')->count();
        $inProgressRequests = ServiceRequest::where('status', 'in_progress')->count();
        $completedRequests = ServiceRequest::where('status', 'completed')->count();
        $cancelledRequests = ServiceRequest::where('status', 'cancelled')->count();
        $rejectedRequests = ServiceRequest::where('status', 'rejected')->count();

        // Recent requests (last 10) with related data and EAT time
        $recentRequests = ServiceRequest::with(['customer', 'technician.user', 'service'])
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get()
            ->map(function ($req) {
                $req->area = $req->technician?->area ?? 'N/A';
                $req->created_at_eat = $req->created_at->setTimezone('Africa/Dar_es_Salaam');
                return $req;
            });

        // Requests trend for the last 30 days (grouped by EAT date)
        $requestsLast30Days = ServiceRequest::select(
                DB::raw("DATE(CONVERT_TZ(created_at, '+00:00', '+03:00')) as date"),
                DB::raw('count(*) as total')
            )
            ->where('created_at', '>=', now()->subDays(30))
            ->groupBy('date')
            ->orderBy('date', 'asc')
            ->get();

        // ---------- EAT-aware Analytics ----------
        $weeklyRequests = $this->getWeeklyRequests($request);
        $userTrend = $this->getUserTrend($request);
        $topTechnicians = $this->getTopTechnicians($request);
        $technicianEngagement = $this->getTechnicianEngagement($request);
        $postsTrend = $this->getPostsTrend($request);
        $technicianBreakdown = $this->getTechnicianBreakdown($request);
        $requestsByArea = $this->getRequestsByArea($request);

        // ---------- Engagement Metrics ----------
        $engagementMetrics = [
            'total_posts' => Post::count(),
            'total_comments' => $totalComments,
            'total_likes' => $totalLikes,
            'avg_comments_per_post' => Post::withCount('comments')->get()->avg('comments_count') ?? 0,
            'avg_likes_per_post' => Post::withCount('likes')->get()->avg('likes_count') ?? 0,
        ];

        // ---------- Build Response ----------
        $data = [
            'users' => [
                'total' => $totalUsers,
                'active' => $activeUsers,
                'inactive' => $inactiveUsers,
                'by_role' => $usersByRole,
            ],
            'roles' => ['total' => $totalRoles],
            'permissions' => ['total' => $totalPermissions],
            'technicians' => [
                'total' => $totalTechnicians,
                'verified' => $verifiedTechnicians,
                'unverified' => $unverifiedTechnicians,
                'online' => $onlineTechnicians,
                'rating_stats' => $technicianRatingStats,
            ],
            'customers' => [
                'total' => $totalCustomers,
                'active' => $activeCustomers,
            ],
            'likes' => [
                'total' => $totalLikes,
                'top_posts' => $likesPerPost,
            ],
            'comments' => [
                'total' => $totalComments,
                'top_posts' => $commentsPerPost,
            ],
            'services' => [
                'total' => $totalServices,
                'with_requests' => $servicesWithRequests,
                'without_requests' => $servicesWithoutRequests,
                'top_services' => $topServices,
            ],
            'service_requests' => [
                'total' => $totalRequests,
                'by_status' => $requestsByStatus,
                'status_breakdown' => [
                    'pending' => $pendingRequests,
                    'accepted' => $acceptedRequests,
                    'in_progress' => $inProgressRequests,
                    'completed' => $completedRequests,
                    'cancelled' => $cancelledRequests,
                    'rejected' => $rejectedRequests,
                ],
                'recent' => $recentRequests,
                'last_30_days' => $requestsLast30Days,
            ],
            'engagement_metrics' => $engagementMetrics,
            // Custom analytics (EAT-aware)
            'weekly_requests' => $weeklyRequests,
            'user_trend' => $userTrend,
            'top_technicians' => $topTechnicians,
            'technician_engagement' => $technicianEngagement,
            'posts_trend' => $postsTrend,
            'technician_breakdown' => $technicianBreakdown,
            'requests_by_area' => $requestsByArea,
        ];

        return $this->successResponse($data);
    }

    /**
     * Get simplified dashboard summary (for quick stats).
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function getDashboardSummary(Request $request)
    {
        $this->checkPermission('dashboard.view');

        $data = [
            'total_users' => User::count(),
            'total_roles' => Role::count(),
            'total_permissions' => Permission::count(),
            'total_technicians' => Technician::count(),
            'total_customers' => User::whereDoesntHave('technician')->count(),
            'total_likes' => Like::count(),
            'total_comments' => Comment::count(),
            'total_services' => Service::count(),
            'total_requests' => ServiceRequest::count(),
            'requests_by_status' => ServiceRequest::select('status', DB::raw('count(*) as total'))
                ->groupBy('status')
                ->get(),
        ];

        return $this->successResponse($data);
    }

    // ---------- PRIVATE HELPER METHODS (EAT-aware) ----------

    /**
     * Get number of service requests per day of the week (Monday–Sunday) in EAT.
     */
    private function getWeeklyRequests(Request $request)
    {
        list($startEat, $endEat) = $this->parseDateRangeEat($request);
        $startUtc = $startEat ? $startEat->setTimezone('UTC') : null;
        $endUtc = $endEat ? $endEat->setTimezone('UTC') : null;

        return ServiceRequest::select(
                DB::raw("DAYNAME(CONVERT_TZ(created_at, '+00:00', '+03:00')) as day"),
                DB::raw('COUNT(*) as total')
            )
            ->when($startUtc, fn($q) => $q->where('created_at', '>=', $startUtc))
            ->when($endUtc, fn($q) => $q->where('created_at', '<=', $endUtc))
            ->groupBy('day')
            ->orderByRaw("FIELD(day, 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')")
            ->get();
    }

    /**
     * Get daily user registration trend, split into technicians and customers (EAT dates).
     */
    private function getUserTrend(Request $request)
    {
        list($startEat, $endEat) = $this->parseDateRangeEat($request);
        $startUtc = $startEat ? $startEat->setTimezone('UTC') : null;
        $endUtc = $endEat ? $endEat->setTimezone('UTC') : null;

        return User::select(
                DB::raw("DATE(CONVERT_TZ(created_at, '+00:00', '+03:00')) as date"),
                DB::raw('COUNT(*) as total'),
                DB::raw('SUM(CASE WHEN EXISTS (SELECT 1 FROM technicians WHERE technicians.user_id = users.id) THEN 1 ELSE 0 END) as technicians'),
                DB::raw('SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM technicians WHERE technicians.user_id = users.id) THEN 1 ELSE 0 END) as customers')
            )
            ->when($startUtc, fn($q) => $q->where('created_at', '>=', $startUtc))
            ->when($endUtc, fn($q) => $q->where('created_at', '<=', $endUtc))
            ->groupBy('date')
            ->orderBy('date', 'asc')
            ->get();
    }

    /**
     * Get top technicians by total number of requests.
     */
    private function getTopTechnicians(Request $request)
    {
        $limit = $request->get('limit', 10);
        return Technician::select('technicians.id', 'technicians.user_id', 'users.name')
            ->join('users', 'users.id', '=', 'technicians.user_id')
            ->withCount('requests')
            ->orderBy('requests_count', 'desc')
            ->limit($limit)
            ->get();
    }

    /**
     * Get engagement metrics (likes + comments) per technician via their blog posts.
     */
    private function getTechnicianEngagement(Request $request)
    {
        $limit = $request->get('limit', 10);
        return Technician::select(
                'technicians.id',
                'users.name as technician_name',
                DB::raw('SUM(COALESCE(l.likes_count, 0)) as total_likes'),
                DB::raw('SUM(COALESCE(c.comments_count, 0)) as total_comments')
            )
            ->join('users', 'users.id', '=', 'technicians.user_id')
            ->leftJoin('posts', 'posts.technician_id', '=', 'technicians.id')
            ->leftJoin(
                DB::raw('(SELECT post_id, COUNT(*) as likes_count FROM likes GROUP BY post_id) as l'),
                'l.post_id', '=', 'posts.id'
            )
            ->leftJoin(
                DB::raw('(SELECT post_id, COUNT(*) as comments_count FROM comments GROUP BY post_id) as c'),
                'c.post_id', '=', 'posts.id'
            )
            ->groupBy('technicians.id', 'users.name')
            ->orderBy('total_likes', 'desc')
            ->limit($limit)
            ->get();
    }

    /**
     * Get blog posts trend (number of posts per day) in EAT.
     */
    private function getPostsTrend(Request $request)
    {
        list($startEat, $endEat) = $this->parseDateRangeEat($request);
        $startUtc = $startEat ? $startEat->setTimezone('UTC') : null;
        $endUtc = $endEat ? $endEat->setTimezone('UTC') : null;

        return Post::select(
                DB::raw("DATE(CONVERT_TZ(created_at, '+00:00', '+03:00')) as date"),
                DB::raw('COUNT(*) as posts')
            )
            ->when($startUtc, fn($q) => $q->where('created_at', '>=', $startUtc))
            ->when($endUtc, fn($q) => $q->where('created_at', '<=', $endUtc))
            ->groupBy('date')
            ->orderBy('date', 'asc')
            ->get();
    }

    /**
     * Get detailed breakdown per technician: total requests, counts by status,
     * unique customers, and area(s) served. (EAT-aware)
     */
    private function getTechnicianBreakdown(Request $request)
    {
        list($startEat, $endEat) = $this->parseDateRangeEat($request);
        $startUtc = $startEat ? $startEat->setTimezone('UTC') : null;
        $endUtc = $endEat ? $endEat->setTimezone('UTC') : null;

        // Subquery: count unique customers per technician (within the date range)
        $uniqueCustomers = ServiceRequest::select('technician_id', DB::raw('COUNT(DISTINCT customer_id) as unique_customers'))
            ->when($startUtc, fn($q) => $q->where('created_at', '>=', $startUtc))
            ->when($endUtc, fn($q) => $q->where('created_at', '<=', $endUtc))
            ->groupBy('technician_id');

        // Main query
        $breakdown = Technician::select(
                'technicians.id',
                'users.name as technician_name',
                'technicians.area',
                DB::raw('COUNT(requests.id) as total_requests'),
                DB::raw('SUM(CASE WHEN requests.status = "pending" THEN 1 ELSE 0 END) as pending'),
                DB::raw('SUM(CASE WHEN requests.status = "accepted" THEN 1 ELSE 0 END) as accepted'),
                DB::raw('SUM(CASE WHEN requests.status = "in_progress" THEN 1 ELSE 0 END) as in_progress'),
                DB::raw('SUM(CASE WHEN requests.status = "completed" THEN 1 ELSE 0 END) as completed'),
                DB::raw('SUM(CASE WHEN requests.status = "cancelled" THEN 1 ELSE 0 END) as cancelled'),
                DB::raw('SUM(CASE WHEN requests.status = "rejected" THEN 1 ELSE 0 END) as rejected'),
                DB::raw('COALESCE(uc.unique_customers, 0) as unique_customers')
            )
            ->join('users', 'users.id', '=', 'technicians.user_id')
            ->leftJoin('requests', 'requests.technician_id', '=', 'technicians.id')
            ->leftJoinSub($uniqueCustomers, 'uc', 'uc.technician_id', '=', 'technicians.id')
            ->when($startUtc, function($q) use ($startUtc, $endUtc) {
                $q->where(function($q2) use ($startUtc, $endUtc) {
                    $q2->whereNull('requests.created_at')
                       ->orWhereBetween('requests.created_at', [$startUtc, $endUtc]);
                });
            })
            ->groupBy('technicians.id', 'users.name', 'technicians.area', 'uc.unique_customers')
            ->orderBy('total_requests', 'desc')
            ->limit(10)
            ->get();

        return $breakdown;
    }

    /**
     * Get request counts grouped by technician area (EAT-aware).
     */
    private function getRequestsByArea(Request $request)
    {
        list($startEat, $endEat) = $this->parseDateRangeEat($request);
        $startUtc = $startEat ? $startEat->setTimezone('UTC') : null;
        $endUtc = $endEat ? $endEat->setTimezone('UTC') : null;

        return ServiceRequest::select(
                'technicians.area',
                DB::raw('COUNT(*) as total_requests')
            )
            ->join('technicians', 'technicians.id', '=', 'requests.technician_id')
            ->whereNotNull('technicians.area')
            ->when($startUtc, fn($q) => $q->where('requests.created_at', '>=', $startUtc))
            ->when($endUtc, fn($q) => $q->where('requests.created_at', '<=', $endUtc))
            ->groupBy('technicians.area')
            ->orderBy('total_requests', 'desc')
            ->get();
    }

    /**
     * Parse date range from request filters, returning Carbon instances in EAT.
     *
     * Expected parameters:
     * - period: 'daily'   -> date format: YYYY-MM-DD
     * - period: 'monthly' -> date format: YYYY-MM
     * - period: 'yearly'  -> date format: YYYY
     *
     * Returns an array [startEat, endEat] or [null, null] if no period set.
     */
    private function parseDateRangeEat(Request $request)
    {
        $period = $request->get('period');
        $date = $request->get('date');

        if (!$period || !$date) {
            return [null, null];
        }

        $tz = 'Africa/Dar_es_Salaam';
        $start = null;
        $end = null;

        if ($period === 'daily') {
            $start = Carbon::parse($date, $tz)->startOfDay();
            $end = Carbon::parse($date, $tz)->endOfDay();
        } elseif ($period === 'monthly') {
            $start = Carbon::parse($date . '-01', $tz)->startOfDay();
            $end = Carbon::parse($date . '-01', $tz)->endOfMonth()->endOfDay();
        } elseif ($period === 'yearly') {
            $start = Carbon::parse($date . '-01-01', $tz)->startOfDay();
            $end = Carbon::parse($date . '-12-31', $tz)->endOfDay();
        }

        return [$start, $end];
    }
}