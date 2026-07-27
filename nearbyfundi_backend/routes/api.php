<?php
// routes/api.php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\TechnicianController;
use App\Http\Controllers\Api\ServiceController;
use App\Http\Controllers\Api\PortfolioController;
use App\Http\Controllers\Api\RequestController;
use App\Http\Controllers\Api\PostController;
use App\Http\Controllers\Api\CommentController;
use App\Http\Controllers\Api\LikeController;
use App\Http\Controllers\Api\AboutController;
use App\Http\Controllers\Api\FaqController;
use App\Http\Controllers\Api\TermsController;
use App\Http\Controllers\Api\AdminDashboardController;
use App\Http\Controllers\Api\UserManagementController;
use App\Http\Controllers\Api\RolePermissionController;
use App\Http\Controllers\Api\AuditTrailController;
use App\Http\Controllers\Api\OtpController;
use App\Http\Controllers\Api\UserSessionController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\MonitoringController;
use App\Http\Controllers\Api\NotificationController;

// =============================================
// HEALTH CHECK
// =============================================
Route::get('/health', function () { 
    return response()->json(['status' => 'ok', 'timestamp' => now()]); 
});

// =============================================
// V1 – AUTH & PUBLIC
// =============================================
Route::prefix('v1')->group(function () {
    // Auth Routes
    Route::prefix('auth')->group(function () {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('register-fundi', [AuthController::class, 'registerFundi']);
        Route::post('login', [AuthController::class, 'login']);
        Route::post('verify-otp', [AuthController::class, 'verifyOtp']);
        Route::post('resend-otp', [AuthController::class, 'resendOtp']);
        Route::post('forgot-password', [AuthController::class, 'forgotPassword']);
        Route::post('reset-password', [AuthController::class, 'resetPassword']);
        Route::post('logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
        Route::get('me', [AuthController::class, 'me'])->middleware('auth:sanctum');
        Route::get('permissions', [AuthController::class, 'myPermissions'])->middleware('auth:sanctum');
        Route::put('profile', [AuthController::class, 'updateProfile'])->middleware('auth:sanctum');
        Route::post('change-password', [AuthController::class, 'changePassword'])->middleware('auth:sanctum');
        Route::post('locale', [AuthController::class, 'updateLocale'])->middleware('auth:sanctum');
        Route::delete('account', [AuthController::class, 'deleteAccount'])->middleware('auth:sanctum');
    });

    // Verification
    Route::get('verification/verify-token', [AuthController::class, 'verifyToken']);

    // Device Token Management
    Route::post('device-token', [AuthController::class, 'updateDeviceToken'])->middleware('auth:sanctum');
    Route::get('device-token', [AuthController::class, 'getDeviceToken'])->middleware('auth:sanctum');
    Route::delete('device-token', [AuthController::class, 'deleteDeviceToken'])->middleware('auth:sanctum');

    // Public Resources
    Route::get('services', [ServiceController::class, 'index']);
    Route::get('technicians', [TechnicianController::class, 'publicIndex']);
    Route::get('technicians/nearby', [TechnicianController::class, 'nearby']);
    Route::get('technicians/nearby-by-place', [TechnicianController::class, 'nearbyByPlace']);
    Route::get('technicians/{id}', [TechnicianController::class, 'show']);
    Route::get('portfolios/{technicianId}', [PortfolioController::class, 'index']);
    Route::get('posts', [PostController::class, 'index']);
    Route::get('posts/{id}', [PostController::class, 'show']);
    Route::get('about', [AboutController::class, 'show']);
    Route::get('faqs', [FaqController::class, 'index']);
    Route::get('terms', [TermsController::class, 'show']);

    // Authenticated User Sessions
    Route::middleware(['auth:sanctum', 'active.session'])->prefix('sessions')->group(function () {
        Route::get('/', [UserSessionController::class, 'index']);
        Route::delete('/all', [UserSessionController::class, 'destroyAll']);
        Route::delete('/others', [UserSessionController::class, 'destroyOthers']);
        Route::delete('/{id}', [UserSessionController::class, 'destroy']);
    });
});

// =============================================
// V2 – TECHNICIANS (Fundi)
// =============================================
Route::prefix('v2')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::put('technicians/profile', [TechnicianController::class, 'updateProfile']);
    Route::get('technicians/profile', [TechnicianController::class, 'getOwnProfile']);
    Route::post('technicians/services', [TechnicianController::class, 'updateServices']);
    Route::patch('technicians/online-status', [TechnicianController::class, 'toggleOnline']);
    Route::post('technicians/heartbeat', [TechnicianController::class, 'heartbeat']);
    Route::post('technicians/location', [TechnicianController::class, 'updateLocation']);
    Route::post('technicians/profile/photo', [TechnicianController::class, 'uploadProfilePhoto']); 

    // Admin routes
    Route::patch('technicians/{id}/verify', [TechnicianController::class, 'verify']);
    Route::apiResource('technicians', TechnicianController::class)->except(['show', 'nearby', 'updateProfile', 'toggleOnline']);
});

// =============================================
// V3 – PORTFOLIOS
// =============================================
Route::prefix('v3')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::post('portfolios', [PortfolioController::class, 'store']);
    Route::put('portfolios/{id}', [PortfolioController::class, 'update']);
    Route::delete('portfolios/{id}', [PortfolioController::class, 'destroy']);
    Route::get('portfolios', [PortfolioController::class, 'index']);
    Route::get('portfolios/technician/{technicianId}', [PortfolioController::class, 'getByTechnician']);
    Route::get('portfolios/my', [PortfolioController::class, 'myPortfolios']);
    Route::put('portfolios/{id}/social-links', [PortfolioController::class, 'updateSocialLinks']);
    Route::delete('admin/portfolios/{id}', [PortfolioController::class, 'destroyAdmin']);
});

// =============================================
// V4 – SERVICE REQUESTS & MONITORING
// =============================================
Route::prefix('v4')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    // Request Routes
    Route::post('requests', [RequestController::class, 'store']);
    Route::patch('requests/{id}/status', [RequestController::class, 'updateStatus']);
    Route::delete('requests/{id}/cancel', [RequestController::class, 'cancel']);
    Route::get('my-requests', [RequestController::class, 'myRequests']);

    // Admin Request Routes
    Route::get('admin/requests', [RequestController::class, 'index']);
    Route::get('admin/requests/{id}', [RequestController::class, 'show']);
    Route::delete('admin/requests/{id}', [RequestController::class, 'destroy']);
    Route::get('admin/request-logs/{requestId}', [RequestController::class, 'logs']);
    Route::get('admin/requests/stats', [RequestController::class, 'stats']);

    // =============================================
    // MONITORING ROUTES - Complete
    // =============================================
    Route::prefix('monitoring')->group(function () {
        // Map & Dashboard
        Route::get('map', [MonitoringController::class, 'map']);
        Route::get('notifications', [MonitoringController::class, 'getNotifications']);
        Route::get('statuses', [MonitoringController::class, 'getStatuses']);
        Route::get('pending-history', [MonitoringController::class, 'getPendingHistory']);
        
        // Technicians
        Route::get('technicians', [MonitoringController::class, 'getTechnicians']);
        Route::get('technicians/{id}', [MonitoringController::class, 'getTechnician']);
        Route::get('technicians/area/{area}', [MonitoringController::class, 'getTechniciansByArea']);
        Route::get('technicians/{id}/completed-requests', [MonitoringController::class, 'getTechnicianCompletedRequests']);
        Route::post('technicians/{id}/call', [MonitoringController::class, 'callTechnician']);
        
        // Requests
        Route::get('requests/{id}/logs', [MonitoringController::class, 'getRequestLogs']);
        Route::patch('requests/{id}/status', [MonitoringController::class, 'updateStatus']);
        Route::post('requests/{id}/complete', [MonitoringController::class, 'completeRequest']);
    });
});

// =============================================
// V5 – BLOG (Posts, Comments, Likes)
// =============================================
Route::prefix('v5')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::post('posts', [PostController::class, 'store']);
    Route::put('posts/{id}', [PostController::class, 'update']);
    Route::delete('posts/{id}', [PostController::class, 'destroy']);
    Route::get('my-posts', [PostController::class, 'myPosts']);
    Route::post('posts/{postId}/comments', [CommentController::class, 'store']);
    Route::delete('comments/{id}', [CommentController::class, 'destroy']);
    Route::post('posts/{postId}/like', [LikeController::class, 'toggle']);
    Route::get('admin/posts/all', [PostController::class, 'allWithDetails']);
    Route::get('admin/comments', [CommentController::class, 'index']);
});

// =============================================
// V6 – STATIC PAGES (About, Terms, FAQs)
// =============================================
Route::prefix('v6')->group(function () {
    // Public GET endpoints – no auth required
    Route::get('about', [AboutController::class, 'show']);
    Route::get('terms', [TermsController::class, 'show']);
    Route::get('faqs', [FaqController::class, 'index']);
    Route::get('faqs/{id}', [FaqController::class, 'show']);

    // Protected write endpoints – auth + permissions
    Route::middleware(['auth:sanctum'])->group(function () {
        // About – single record (no ID in URL)
        Route::post('about', [AboutController::class, 'store']);
        Route::put('about', [AboutController::class, 'update']);
        Route::delete('about', [AboutController::class, 'destroy']);

        // Terms – single record (no ID in URL)
        Route::post('terms', [TermsController::class, 'store']);
        Route::put('terms', [TermsController::class, 'update']);
        Route::delete('terms', [TermsController::class, 'destroy']);

        // FAQs – collection with ID
        Route::post('faqs', [FaqController::class, 'store']);
        Route::put('faqs/{id}', [FaqController::class, 'update']);
        Route::delete('faqs/{id}', [FaqController::class, 'destroy']);
    });
});

// =============================================
// V7 – ADMIN DASHBOARD
// =============================================
Route::prefix('v7')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::get('dashboard/stats', [AdminDashboardController::class, 'stats']);
});

// =============================================
// V8 – USER MANAGEMENT
// =============================================
Route::prefix('v8')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::get('/users', [UserManagementController::class, 'index']);
    Route::get('/users/{id}', [UserManagementController::class, 'show']);
    Route::post('/users', [UserManagementController::class, 'store']);
    Route::put('/users/{id}', [UserManagementController::class, 'update']);
    Route::delete('/users/{id}', [UserManagementController::class, 'destroy']);
    Route::get('/users/trashed', [UserManagementController::class, 'trashed']);
    Route::post('/users/{id}/restore', [UserManagementController::class, 'restore']);
    Route::delete('/users/{id}/force', [UserManagementController::class, 'forceDelete']);
    Route::patch('/users/{id}/activate', [UserManagementController::class, 'activate']);
    Route::patch('/users/{id}/deactivate', [UserManagementController::class, 'deactivate']);
    Route::patch('/users/{id}/suspend', [UserManagementController::class, 'suspend']);
    Route::post('/users/{id}/reset-password', [UserManagementController::class, 'resetPassword']);
    Route::post('/users/{id}/reset-password-random', [UserManagementController::class, 'resetPasswordRandom']);
    Route::post('/users/{id}/resend-otp', [UserManagementController::class, 'resendOtp']);
    Route::post('/users/{id}/resend-otp-phone', [UserManagementController::class, 'resendOtpPhone']);
    Route::post('/users/{id}/send-password-reset', [UserManagementController::class, 'sendPasswordResetOtp']);
    Route::get('/customers', [UserManagementController::class, 'customers']);
    Route::get('/fundis', [UserManagementController::class, 'fundis']);
    Route::get('/stats', [UserManagementController::class, 'stats']);
    Route::get('/dropdown/users', [UserManagementController::class, 'dropdownUsers']);
    Route::get('/dropdown/customers', [UserManagementController::class, 'dropdownCustomers']);
    Route::get('/dropdown/fundis', [UserManagementController::class, 'dropdownFundis']);
    Route::get('/dropdown/active-users', [UserManagementController::class, 'dropdownActiveUsers']);
});

// =============================================
// V9 – ROLES & PERMISSIONS
// =============================================
Route::prefix('v9')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::get('roles', [RolePermissionController::class, 'rolesIndex']);
    Route::get('roles/dropdown', [RolePermissionController::class, 'rolesDropdown']);
    Route::post('roles', [RolePermissionController::class, 'roleStore']);
    Route::get('roles/{id}', [RolePermissionController::class, 'roleShow']);
    Route::put('roles/{id}', [RolePermissionController::class, 'roleUpdate']);
    Route::delete('roles/{id}', [RolePermissionController::class, 'roleDestroy']);
    Route::get('roles/{id}/permissions', [RolePermissionController::class, 'rolePermissions']);
    Route::post('roles/{id}/permissions', [RolePermissionController::class, 'assignPermissionsToRole']);
    Route::get('permissions', [RolePermissionController::class, 'permissionsIndex']);
    Route::get('permissions/dropdown', [RolePermissionController::class, 'permissionsDropdown']);
    Route::post('permissions', [RolePermissionController::class, 'permissionStore']);
    Route::get('permissions/{id}', [RolePermissionController::class, 'permissionShow']);
    Route::put('permissions/{id}', [RolePermissionController::class, 'permissionUpdate']);
    Route::delete('permissions/{id}', [RolePermissionController::class, 'permissionDestroy']);
    Route::post('users/{userId}/assign-role', [RolePermissionController::class, 'assignRoleToUser']);
    Route::get('users/{userId}/roles', [RolePermissionController::class, 'getUserRoles']);
    Route::delete('users/{userId}/remove-role', [RolePermissionController::class, 'removeRoleFromUser']);
});

// =============================================
// V10 – AUDIT & OTP
// =============================================
Route::prefix('v10')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::get('audit-logs', [AuditTrailController::class, 'index']);
    Route::get('audit-logs/export', [AuditTrailController::class, 'exportCsv']);
    Route::get('otps', [OtpController::class, 'index']);
    Route::delete('otps/cleanup', [OtpController::class, 'cleanup']);
});

// =============================================
// V11 – SERVICES (Admin)
// =============================================
Route::prefix('v11')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::get('services', [ServiceController::class, 'index']);
    Route::post('services', [ServiceController::class, 'store']);
    Route::put('services/{id}', [ServiceController::class, 'update']);
    Route::delete('services/{id}', [ServiceController::class, 'destroy']);
});

// =============================================
// V12 – REPORTS
// =============================================
Route::prefix('v12')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::get('reports/users', [ReportController::class, 'usersReport']);
    Route::get('reports/technicians', [ReportController::class, 'techniciansReport']);
    Route::get('reports/requests', [ReportController::class, 'requestsReport']);
    Route::get('reports/services', [ReportController::class, 'servicesReport']);
    Route::get('reports/blog', [ReportController::class, 'blogReport']);
    Route::get('reports/portfolio', [ReportController::class, 'portfolioReport']);
    Route::get('reports/revenue', [ReportController::class, 'revenueReport']);
});

// =============================================
// V13 – ANALYTICS
// =============================================
Route::prefix('v13')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::get('analytics/dashboard', [AnalyticsController::class, 'getDashboardAnalytics']);
    Route::get('analytics/summary', [AnalyticsController::class, 'getDashboardSummary']);
    Route::get('analytics/top-commented-posts', [AnalyticsController::class, 'topCommentedPosts']);
    Route::get('analytics/top-liked-posts', [AnalyticsController::class, 'topLikedPosts']);
    Route::get('analytics/top-used-services', [AnalyticsController::class, 'topUsedServices']);
});

// =============================================
// V14 – REAL-TIME CHAT SYSTEM
// =============================================
Route::prefix('v14')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::prefix('chat')->group(function () {
        // Conversation routes
        Route::post('conversation', [ChatController::class, 'getOrCreateConversation']);
        Route::get('conversations', [ChatController::class, 'getConversations']);
        Route::get('conversations/{id}/messages', [ChatController::class, 'getMessages']);
        Route::post('conversations/{id}/read', [ChatController::class, 'markConversationAsRead']);
        Route::delete('conversations/{id}', [ChatController::class, 'deleteConversation']);
        
        // Message routes
        Route::post('send', [ChatController::class, 'sendMessage']);
        Route::put('messages/{id}/read', [ChatController::class, 'markMessageAsRead']);
        Route::delete('messages/{id}', [ChatController::class, 'deleteMessage']);
        
        // Reaction routes
        Route::post('messages/{id}/reaction', [ChatController::class, 'addReaction']);
        Route::delete('messages/{id}/reaction', [ChatController::class, 'removeReaction']);
        
        // File routes
        Route::post('upload', [ChatController::class, 'uploadFile']);
        Route::get('files/{id}/download', [ChatController::class, 'downloadFile']);
        Route::get('files/{id}/info', [ChatController::class, 'getFileInfo']);
        Route::delete('files/{id}', [ChatController::class, 'deleteFile']);
        
        // Typing & unread routes
        Route::post('typing', [ChatController::class, 'setTypingStatus']);
        Route::get('unread', [ChatController::class, 'getUnreadCount']);
    });
});

// =============================================
// V15 – NOTIFICATIONS
// =============================================
Route::prefix('v15')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::prefix('notifications')->group(function () {
        Route::get('/', [NotificationController::class, 'index']);
        Route::get('/unread-count', [NotificationController::class, 'unreadCount']);
        Route::put('/{id}/read', [NotificationController::class, 'markAsRead']);
        Route::put('/read-all', [NotificationController::class, 'markAllAsRead']);
        Route::delete('/{id}', [NotificationController::class, 'destroy']);
        Route::delete('/clear', [NotificationController::class, 'clearAll']);
    });
});