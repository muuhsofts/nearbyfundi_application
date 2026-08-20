<?php

namespace App\Http\Controllers\Api;

use App\Models\User;
use App\Models\Technician;
use App\Models\ServiceRequest;
use App\Models\Post;
use App\Models\Review;
use App\Models\Comment;
use App\Models\Portfolio;
use App\Models\Service;
use App\Models\Like;
use App\Models\Subscription;
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

    /**
 * Reviews report – paginated list with filters.
 */
public function reviewsReport(Request $request)
{
    $this->checkPermission('reports.view');

    $query = Review::with(['customer', 'technician.user']);

    // Filters
    if ($request->filled('rating')) {
        $query->where('rating', $request->rating);
    }
    if ($request->filled('search')) {
        $search = $request->search;
        $query->where(function ($q) use ($search) {
            $q->where('comment', 'like', "%{$search}%")
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

    $reviews = $query->orderBy('created_at', 'desc')
        ->paginate($request->input('per_page', 20));

    return $this->successResponse($reviews);
}

    /**
 * Get all dashboard stats and trends in one request.
 */
public function allStats(Request $request)
{
    $this->checkPermission('reports.view');

    $tz = 'Africa/Dar_es_Salaam';
    $now = Carbon::now($tz);
    list($start, $end) = $this->parseDateRange($request);

    // Default to last 30 days if no period given
    if (!$start) {
        $start = $now->copy()->subDays(30)->startOfDay();
    }
    if (!$end) {
        $end = $now->copy()->endOfDay();
    }

    // ─── Users ──────────────────────────────────────────────
    $usersQuery = User::query();
    if ($start) $usersQuery->whereDate('created_at', '>=', $start);
    if ($end)   $usersQuery->whereDate('created_at', '<=', $end);
    $usersTotal   = $usersQuery->count();
    $usersActive  = (clone $usersQuery)->where('is_active', true)->count();
    $usersInactive = (clone $usersQuery)->where('is_active', false)->count();
    $usersTrend = User::select(DB::raw('DATE(created_at) as date'), DB::raw('COUNT(*) as total'))
        ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
        ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
        ->groupBy('date')->orderBy('date')->get();

    // ─── Technicians ────────────────────────────────────────
    $techQuery = Technician::query();
    if ($start) $techQuery->whereDate('created_at', '>=', $start);
    if ($end)   $techQuery->whereDate('created_at', '<=', $end);
    $techTotal   = $techQuery->count();
    $techVerified = (clone $techQuery)->where('verified', true)->count();
    $techTrend = Technician::select(DB::raw('DATE(created_at) as date'), DB::raw('COUNT(*) as total'))
        ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
        ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
        ->groupBy('date')->orderBy('date')->get();

    // ─── Service Requests ──────────────────────────────────
    $reqQuery = ServiceRequest::query();
    if ($start) $reqQuery->whereDate('created_at', '>=', $start);
    if ($end)   $reqQuery->whereDate('created_at', '<=', $end);
    $reqTotal    = $reqQuery->count();
    $reqByStatus = (clone $reqQuery)->select('status', DB::raw('count(*) as count'))
        ->groupBy('status')->get();
    $reqTrend = ServiceRequest::select(DB::raw('DATE(created_at) as date'), DB::raw('COUNT(*) as total'))
        ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
        ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
        ->groupBy('date')->orderBy('date')->get();

    // ─── Services ───────────────────────────────────────────
    $serviceQuery = Service::withCount(['requests' => function($q) use ($start, $end) {
        if ($start) $q->whereDate('created_at', '>=', $start);
        if ($end)   $q->whereDate('created_at', '<=', $end);
    }]);
    $topServices = $serviceQuery->orderBy('requests_count', 'desc')->limit(10)->get();
    $totalServices = Service::count();
    $totalRequestsAll = ServiceRequest::whereBetween('created_at', [$start, $end])->count();

    // ─── Blog ────────────────────────────────────────────────
    $blogPostsQuery = Post::query();
    if ($start) $blogPostsQuery->whereDate('created_at', '>=', $start);
    if ($end)   $blogPostsQuery->whereDate('created_at', '<=', $end);
    $totalPosts = $blogPostsQuery->count();

    $blogCommentsQuery = Comment::query();
    if ($start) $blogCommentsQuery->whereDate('created_at', '>=', $start);
    if ($end)   $blogCommentsQuery->whereDate('created_at', '<=', $end);
    $totalComments = $blogCommentsQuery->count();

    $blogLikesQuery = Like::query();
    if ($start) $blogLikesQuery->whereDate('created_at', '>=', $start);
    if ($end)   $blogLikesQuery->whereDate('created_at', '<=', $end);
    $totalLikes = $blogLikesQuery->count();

    $avgComments = $totalPosts > 0 ? $totalComments / $totalPosts : 0;

    $postsWithMostComments = Post::withCount(['comments' => function($q) use ($start, $end) {
        if ($start) $q->whereDate('created_at', '>=', $start);
        if ($end)   $q->whereDate('created_at', '<=', $end);
    }])->orderBy('comments_count', 'desc')->limit(5)->get(['id', 'title', 'comments_count']);

    $postsWithMostLikes = Post::withCount(['likes' => function($q) use ($start, $end) {
        if ($start) $q->whereDate('created_at', '>=', $start);
        if ($end)   $q->whereDate('created_at', '<=', $end);
    }])->orderBy('likes_count', 'desc')->limit(5)->get(['id', 'title', 'likes_count']);

    $commentsByUser = Comment::select('user_id', DB::raw('count(*) as count'))
        ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
        ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
        ->groupBy('user_id')->orderBy('count', 'desc')->limit(5)
        ->with('user:id,name')->get();

    $blogTrend = Post::select(DB::raw('DATE(created_at) as date'), DB::raw('COUNT(*) as posts'))
        ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
        ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
        ->groupBy('date')->orderBy('date')->get();

    // ─── Portfolio ───────────────────────────────────────────
    $portfolioQuery = Portfolio::query();
    if ($start) $portfolioQuery->whereDate('created_at', '>=', $start);
    if ($end)   $portfolioQuery->whereDate('created_at', '<=', $end);
    $totalPortfolioItems = $portfolioQuery->count();
    $techWithMostPortfolio = Portfolio::select('technician_id', DB::raw('count(*) as count'))
        ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
        ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
        ->groupBy('technician_id')->orderBy('count', 'desc')->limit(10)
        ->with('technician.user:id,name')->get();

    // ─── Subscriptions ───────────────────────────────────────
    $subQuery = Subscription::query();
    if ($start) $subQuery->whereDate('created_at', '>=', $start);
    if ($end)   $subQuery->whereDate('created_at', '<=', $end);
    $subTotal    = $subQuery->count();
    $subActive   = (clone $subQuery)->where('status', 'active')
        ->where(function($q) { $q->whereNull('expiry_date')->orWhere('expiry_date', '>', now()); })->count();
    $subPending  = (clone $subQuery)->where('status', 'pending')->count();
    $subExpired  = (clone $subQuery)->where(function($q) {
        $q->where('status', 'expired')->orWhere(function($sq) {
            $sq->where('status', 'active')->where('expiry_date', '<', now());
        });
    })->count();
    $subCancelled = (clone $subQuery)->where('status', 'cancelled')->count();
    $subRevenue  = (clone $subQuery)->sum('amount_paid');
    $revenueByMethod = (clone $subQuery)->select('payment_method', DB::raw('sum(amount_paid) as total'))
        ->groupBy('payment_method')->get();
    $subTrend = Subscription::select(DB::raw('DATE(created_at) as date'), DB::raw('COUNT(*) as total'))
        ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
        ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
        ->groupBy('date')->orderBy('date')->get();

    // ─── Reviews ─────────────────────────────────────────────
    $reviewQuery = Review::query();
    if ($start) $reviewQuery->whereDate('created_at', '>=', $start);
    if ($end)   $reviewQuery->whereDate('created_at', '<=', $end);
    $totalReviews = $reviewQuery->count();
    $avgRating    = (clone $reviewQuery)->avg('rating') ?? 0;
    $ratingsDistribution = (clone $reviewQuery)->select('rating', DB::raw('count(*) as count'))
        ->groupBy('rating')->orderBy('rating')->get();
    $recentReviews = (clone $reviewQuery)->orderBy('created_at', 'desc')->limit(5)
        ->with(['customer:id,name', 'technician.user:id,name'])->get();

    // ─── Response ────────────────────────────────────────────
    return $this->successResponse([
        'users' => [
            'total'    => $usersTotal,
            'active'   => $usersActive,
            'inactive' => $usersInactive,
            'trend'    => $usersTrend,
        ],
        'technicians' => [
            'total'    => $techTotal,
            'verified' => $techVerified,
            'trend'    => $techTrend,
        ],
        'requests' => [
            'total'     => $reqTotal,
            'by_status' => $reqByStatus,
            'trend'     => $reqTrend,
        ],
        'services' => [
            'total'          => $totalServices,
            'total_requests' => $reqTotal,
            'avg_per_service'=> $totalServices > 0 ? $reqTotal / $totalServices : 0,
            'top_services'   => $topServices,
        ],
        'blog' => [
            'total_posts'   => $totalPosts,
            'total_comments'=> $totalComments,
            'total_likes'   => $totalLikes,
            'avg_comments_per_post' => $avgComments,
            'posts_with_most_comments' => $postsWithMostComments,
            'posts_with_most_likes'    => $postsWithMostLikes,
            'comments_by_user' => $commentsByUser,
            'trend' => $blogTrend,
        ],
        'portfolio' => [
            'total_portfolio_items' => $totalPortfolioItems,
            'technicians_with_most_portfolios' => $techWithMostPortfolio,
        ],
        'subscriptions' => [
            'total'       => $subTotal,
            'active'      => $subActive,
            'pending'     => $subPending,
            'expired'     => $subExpired,
            'cancelled'   => $subCancelled,
            'total_revenue' => $subRevenue,
            'revenue_by_method' => $revenueByMethod,
            'trend'       => $subTrend,
        ],
        'reviews' => [
            'total' => $totalReviews,
            'average_rating' => round($avgRating, 1),
            'ratings_distribution' => $ratingsDistribution,
            'recent_reviews' => $recentReviews,
        ],
    ]);
}

    /**
     * Subscriptions report – with stats, trends, and filters.
     */
    public function subscriptionsReport(Request $request)
    {
        $this->checkPermission('reports.view');

        $query = Subscription::with(['user', 'rateCard', 'invoice']);

        // Filters
        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }
        if ($request->filled('payment_method')) {
            $query->where('payment_method', 'like', "%{$request->payment_method}%");
        }
        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('payment_reference', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search) {
                        $uq->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%");
                    });
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

        $subscriptions = $query->orderBy('created_at', 'desc')
            ->paginate($request->input('per_page', 20));

        // ✅ Auto-mark expired subscriptions
        $expiredSubscriptions = Subscription::where('status', 'active')
            ->where('expiry_date', '<', now())
            ->get();

        foreach ($expiredSubscriptions as $expiredSub) {
            $expiredSub->update(['status' => 'expired']);
            if ($expiredSub->user) {
                $expiredSub->user->update([
                    'subscription_status' => 'expired',
                ]);
            }
        }

        // Stats
        $stats = $this->getSubscriptionStats($start, $end);
        $trend = $this->getSubscriptionTrend($start, $end);

        // Format subscription data for frontend
        $formattedData = $subscriptions->map(function ($sub) {
            // Check if expired based on expiry date
            $isExpired = $sub->expiry_date && Carbon::parse($sub->expiry_date)->isPast();
            $status = $isExpired && $sub->status === 'active' ? 'expired' : $sub->status;

            return [
                'id' => $sub->id,
                'user' => $sub->user ? [
                    'id' => $sub->user->id,
                    'name' => $sub->user->name,
                    'email' => $sub->user->email,
                ] : null,
                'rate_card' => $sub->rateCard ? [
                    'id' => $sub->rateCard->id,
                    'name' => $sub->rateCard->name,
                    'duration' => $sub->rateCard->duration_days . ' days',
                ] : null,
                'status' => $status,
                'status_label' => $this->getStatusLabel($status),
                'amount' => number_format($sub->amount_paid, 0) . ' ' . ($sub->currency ?? 'TZS'),
                'payment_method' => $sub->payment_method,
                'payment_reference' => $sub->payment_reference,
                'payment_proof' => $sub->payment_proof ? url('storage/' . $sub->payment_proof) : null,
                'start_date' => $sub->start_date,
                'expiry_date' => $sub->expiry_date,
                'days_remaining' => $sub->expiry_date ? now()->diffInDays($sub->expiry_date, false) : null,
                'approved_at' => $sub->approved_at,
                'created_at' => $sub->created_at,
                'invoice' => $sub->invoice ? [
                    'id' => $sub->invoice->id,
                    'number' => $sub->invoice->invoice_number,
                    'amount' => $sub->invoice->formatted_amount,
                    'status' => $sub->invoice->status,
                    'status_label' => $sub->invoice->status_label,
                    'pdf_url' => $sub->invoice->pdf_path ? url('storage/' . $sub->invoice->pdf_path) : null,
                ] : null,
            ];
        });

        return $this->successResponse([
            'data' => [
                'data' => $formattedData,
                'total' => $subscriptions->total(),
                'per_page' => $subscriptions->perPage(),
                'current_page' => $subscriptions->currentPage(),
                'last_page' => $subscriptions->lastPage(),
            ],
            'stats' => $stats,
            'trend' => $trend,
        ]);
    }

    /**
     * Revenue report – combined with subscription data.
     */
    public function revenueReport(Request $request)
    {
        $this->checkPermission('reports.view');

        list($start, $end) = $this->parseDateRange($request);

        $query = Subscription::query();
        if ($start) $query->whereDate('created_at', '>=', $start);
        if ($end)   $query->whereDate('created_at', '<=', $end);

        // ✅ FIX: Sum ALL subscriptions amount_paid for total revenue
        $totalRevenue = $query->sum('amount_paid');

        // Revenue by payment method - all subscriptions
        $revenueByMethod = (clone $query)->select('payment_method', DB::raw('sum(amount_paid) as total'))
            ->groupBy('payment_method')
            ->get();

        // Revenue by plan - all subscriptions
        $revenueByPlan = (clone $query)->select('rate_card_id', DB::raw('sum(amount_paid) as total'))
            ->groupBy('rate_card_id')
            ->with('rateCard:id,name')
            ->get();

        // Monthly revenue trend - all subscriptions
        $monthlyTrend = Subscription::select(
                DB::raw('DATE_FORMAT(created_at, "%Y-%m") as month'),
                DB::raw('SUM(amount_paid) as total')
            )
            ->when($start, fn($q) => $q->whereDate('created_at', '>=', $start))
            ->when($end,   fn($q) => $q->whereDate('created_at', '<=', $end))
            ->groupBy('month')
            ->orderBy('month', 'asc')
            ->get();

        return $this->successResponse([
            'total_revenue' => number_format($totalRevenue, 0) . ' TZS',
            'by_payment_method' => $revenueByMethod,
            'by_plan' => $revenueByPlan,
            'monthly_trend' => $monthlyTrend,
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

    /**
     * Get subscription statistics.
     * ✅ FIX: total_revenue sums ALL subscriptions amount_paid
     */
    private function getSubscriptionStats($start, $end)
    {
        $query = Subscription::query();
        if ($start) $query->whereDate('created_at', '>=', $start);
        if ($end)   $query->whereDate('created_at', '<=', $end);

        $total = $query->count();
        
        // Active subscriptions (not expired)
        $active = (clone $query)->where('status', 'active')
            ->where(function($q) {
                $q->whereNull('expiry_date')
                    ->orWhere('expiry_date', '>', now());
            })
            ->count();

        // Pending
        $pending = (clone $query)->where('status', 'pending')->count();

        // Expired (by status OR expiry date)
        $expired = (clone $query)->where(function($q) {
            $q->where('status', 'expired')
                ->orWhere(function($sq) {
                    $sq->where('status', 'active')
                        ->where('expiry_date', '<', now());
                });
        })->count();

        // Cancelled
        $cancelled = (clone $query)->where('status', 'cancelled')->count();

        // ✅ FIX: Total Revenue - sum ALL subscriptions amount_paid
        // This includes all statuses since all have been paid
        $totalRevenue = (clone $query)->sum('amount_paid');

        // Revenue by payment method - all subscriptions
        $revenueByMethod = (clone $query)->select('payment_method', DB::raw('sum(amount_paid) as total'))
            ->groupBy('payment_method')
            ->get();

        return [
            'total' => $total,
            'active' => $active,
            'pending' => $pending,
            'expired' => $expired,
            'cancelled' => $cancelled,
            'total_revenue' => $totalRevenue,
            'revenue_by_method' => $revenueByMethod,
        ];
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
     * Get subscription trend (daily new subscriptions).
     */
    private function getSubscriptionTrend($start, $end)
    {
        return Subscription::select(
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
     * Get status label.
     */
    private function getStatusLabel($status)
    {
        $map = [
            'pending' => 'Pending',
            'active' => 'Active',
            'expired' => 'Expired',
            'cancelled' => 'Cancelled',
        ];
        return $map[$status] ?? $status;
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