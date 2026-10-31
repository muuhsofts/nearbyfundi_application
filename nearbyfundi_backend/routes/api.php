<?php

use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\TechnicianController;
use App\Http\Controllers\Api\SearchNearbyFundiController;
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
use App\Http\Controllers\Api\WebOtpLoginController;
use App\Http\Controllers\Api\OtpController;
use App\Http\Controllers\Api\UserSessionController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\MonitoringController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\SubscriptionController;
use App\Http\Controllers\Api\RateCardController;
use App\Http\Controllers\Api\PaymentMethodController;
use App\Http\Controllers\Api\ServiceCategoryController;
use App\Http\Controllers\Api\ReviewController;
use App\Http\Controllers\Api\PrivacyPolicyController;
use App\Http\Controllers\Api\Finance\FinanceSubscriptionController;
use App\Http\Controllers\Api\Finance\FinanceTechnicianController;
use App\Http\Controllers\Api\Finance\FinanceCustomerController;
use App\Http\Controllers\Api\Finance\FinanceRequestController;
use App\Http\Controllers\Api\FeedbackController;
use App\Http\Controllers\Api\SmsLogController;
use App\Http\Controllers\Api\MiniAppController;
use App\Http\Controllers\Api\MiniAppQrController;
use App\Http\Controllers\Api\BannerController;

// Health check
Route::get('/health', fn () => response()->json(['status' => 'ok', 'timestamp' => now()]));

// =============================================
// V1 – AUTH & PUBLIC
// =============================================
Route::prefix('v1')->group(function () {

    // Auth
    Route::prefix('auth')->group(function () {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('register-fundi', [AuthController::class, 'registerFundi']);
        Route::post('google', [AuthController::class, 'googleLogin']);
        Route::get('google/redirect', [AuthController::class, 'redirectToGoogle']);
        Route::match(['get', 'post'], 'google/callback', [AuthController::class, 'handleGoogleCallback']);
        Route::post('login', [AuthController::class, 'login']);
        Route::post('verify-otp', [AuthController::class, 'verifyOtp']);
        Route::post('resend-otp', [AuthController::class, 'resendOtp']);
        Route::post('forgot-password', [AuthController::class, 'forgotPassword']);
        Route::post('reset-password', [AuthController::class, 'resetPassword']);

        // Web OTP Login
        Route::post('web-otp/request', [WebOtpLoginController::class, 'requestOtp']);
        Route::post('web-otp/verify', [WebOtpLoginController::class, 'verifyOtp']);
        Route::post('web-otp/resend', [WebOtpLoginController::class, 'resendOtp']);

        // Authenticated auth routes
        Route::middleware('auth:sanctum')->group(function () {
            Route::post('logout', [AuthController::class, 'logout']);
            Route::post('logout-all', [AuthController::class, 'logoutAll']);
            Route::get('me', [AuthController::class, 'me']);
            Route::get('permissions', [AuthController::class, 'myPermissions']);
            Route::put('profile', [AuthController::class, 'updateProfile']);
            Route::post('change-password', [AuthController::class, 'changePassword']);
            Route::post('locale', [AuthController::class, 'updateLocale']);
            Route::delete('account', [AuthController::class, 'deleteAccount']);
        });
    });

    Route::get('verification/verify-token', [AuthController::class, 'verifyToken']);

    // Device Token
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('device-token', [AuthController::class, 'updateDeviceToken']);
        Route::get('device-token', [AuthController::class, 'getDeviceToken']);
        Route::delete('device-token', [AuthController::class, 'deleteDeviceToken']);

        // FCM-specific endpoint (uses `fcm_device_token` field)
        Route::post('device/fcm-token', [TechnicianController::class, 'updateFcmToken']);
    });

    // Public
    Route::get('services', [ServiceController::class, 'index']);
    Route::get('technicians', [TechnicianController::class, 'publicIndex']);
    Route::get('technicians/{id}', [TechnicianController::class, 'show']);
    Route::get('portfolios/{technicianId}', [PortfolioController::class, 'index']);
    Route::get('posts', [PostController::class, 'index']);
    Route::get('posts/{id}', [PostController::class, 'show']);
    Route::get('about', [AboutController::class, 'show']);
    Route::get('faqs', [FaqController::class, 'index']);
    Route::get('terms', [TermsController::class, 'show']);

    // Sessions
    Route::middleware(['auth:sanctum', 'active.session'])->prefix('sessions')->group(function () {
        Route::get('/', [UserSessionController::class, 'index']);
        Route::delete('/all', [UserSessionController::class, 'destroyAll']);
        Route::delete('/others', [UserSessionController::class, 'destroyOthers']);
        Route::delete('/{id}', [UserSessionController::class, 'destroy']);
    });
});

// =============================================
// NEARBY SEARCH
// =============================================
Route::prefix('fundis')->group(function () {
    Route::get('nearby', [SearchNearbyFundiController::class, 'nearby']);
    Route::get('nearby-by-place', [SearchNearbyFundiController::class, 'nearbyByPlace']);
});

// =============================================
// V2 – TECHNICIAN PROFILE (Authenticated + Subscription)
// =============================================
Route::prefix('v2')->middleware(['auth:sanctum', 'active.session', 'subscription'])->group(function () {
    Route::get('technicians/profile', [TechnicianController::class, 'getOwnProfile']);
    Route::put('technicians/profile', [TechnicianController::class, 'updateProfile']);
    Route::post('technicians/profile/photo', [TechnicianController::class, 'uploadProfilePhoto']);
    Route::post('technicians/services', [TechnicianController::class, 'updateServices']);
    Route::post('technicians/location', [TechnicianController::class, 'updateLocation']);
    Route::post('technicians/heartbeat', [TechnicianController::class, 'heartbeat']);
});

// Verification (no subscription required)
Route::prefix('v2')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::patch('technicians/{id}/verify', [TechnicianController::class, 'verify'])
        ->middleware('permission:technicians.verify');
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
// V4 – REQUESTS & MONITORING
// =============================================
Route::prefix('v4')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::get('request-services', [RequestController::class, 'getServicesWithCategories']);
    Route::get('technicians/by-service-category', [RequestController::class, 'getTechniciansByServiceCategory']);

    Route::post('requests', [RequestController::class, 'store']);
    Route::patch('requests/{id}/status', [RequestController::class, 'updateStatus']);
    Route::delete('requests/{id}/cancel', [RequestController::class, 'cancel']);
    Route::get('my-requests', [RequestController::class, 'myRequests']);

    // Admin
    Route::get('admin/requests', [RequestController::class, 'index']);
    Route::get('admin/requests/{id}', [RequestController::class, 'show']);
    Route::delete('admin/requests/{id}', [RequestController::class, 'destroy']);
    Route::get('admin/request-logs/{requestId}', [RequestController::class, 'logs']);
    Route::get('admin/requests/stats', [RequestController::class, 'stats']);

    Route::get('customer/requests', [RequestController::class, 'customerRequests']);
    Route::get('technician/requests', [RequestController::class, 'technicianRequests']);

    // Tracking
    Route::patch('requests/{id}/on-the-way', [RequestController::class, 'markOnTheWay']);
    Route::patch('requests/{id}/arrive', [RequestController::class, 'markArrived']);
    Route::get('requests/{id}/tracking', [RequestController::class, 'trackingData']);

    // Monitoring
    Route::prefix('monitoring')->group(function () {
        Route::get('map', [MonitoringController::class, 'map']);
        Route::get('notifications', [MonitoringController::class, 'getNotifications']);
        Route::get('statuses', [MonitoringController::class, 'getStatuses']);
        Route::get('pending-history', [MonitoringController::class, 'getPendingHistory']);
        Route::get('technicians', [MonitoringController::class, 'getTechnicians']);
        Route::get('technicians/{id}', [MonitoringController::class, 'getTechnician']);
        Route::get('technicians/area/{area}', [MonitoringController::class, 'getTechniciansByArea']);
        Route::get('technicians/{id}/completed-requests', [MonitoringController::class, 'getTechnicianCompletedRequests']);
        Route::post('technicians/{id}/call', [MonitoringController::class, 'callTechnician']);
        Route::get('requests/{id}/logs', [MonitoringController::class, 'getRequestLogs']);
        Route::patch('requests/{id}/status', [MonitoringController::class, 'updateStatus']);
        Route::post('requests/{id}/complete', [MonitoringController::class, 'completeRequest']);
        Route::post('requests/{id}/check-arrival', [MonitoringController::class, 'checkArrival']);
        Route::get('requests/{id}/tracking', [MonitoringController::class, 'getRequestTracking']);
    });
});

// =============================================
// V5 – BLOG
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
// V6 – STATIC PAGES
// =============================================
Route::prefix('v6')->group(function () {
    Route::get('about', [AboutController::class, 'show']);
    Route::get('terms', [TermsController::class, 'show']);
    Route::get('faqs', [FaqController::class, 'index']);
    Route::get('faqs/{id}', [FaqController::class, 'show']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('about', [AboutController::class, 'store']);
        Route::put('about', [AboutController::class, 'update']);
        Route::delete('about', [AboutController::class, 'destroy']);
        Route::post('terms', [TermsController::class, 'store']);
        Route::put('terms', [TermsController::class, 'update']);
        Route::delete('terms', [TermsController::class, 'destroy']);
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
    Route::post('/users/{id}/verify-otp', [UserManagementController::class, 'verifyOtp']);
    Route::post('/users/{id}/verify-token', [UserManagementController::class, 'verifyUserToken']);
    Route::post('/users/{id}/mark-verified', [UserManagementController::class, 'markVerified']);

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
// V11 – SERVICES
// =============================================
Route::prefix('v11')->group(function () {
    // Static paths FIRST (before {id})
    Route::get('services/dropdown', [ServiceController::class, 'getServicesDropdown']);
    Route::get('services/grouped-by-category', [ServiceController::class, 'getServicesGroupedByCategory']);
    Route::get('services/by-category/{categoryId}', [ServiceController::class, 'getServicesByCategory']);
    Route::get('services/by-category-slug/{slug}', [ServiceController::class, 'getServicesByCategorySlug']);
    Route::get('categories/with-service-count', [ServiceController::class, 'getCategoriesWithServiceCount']);

    Route::get('services', [ServiceController::class, 'index']);
    Route::get('services/{id}', [ServiceController::class, 'show'])->whereNumber('id');

    Route::middleware(['auth:sanctum', 'active.session'])->group(function () {
        Route::post('services', [ServiceController::class, 'store']);
        Route::put('services/{id}', [ServiceController::class, 'update'])->whereNumber('id');
        Route::delete('services/{id}', [ServiceController::class, 'destroy'])->whereNumber('id');
        Route::post('services/{id}/attach-categories', [ServiceController::class, 'attachCategories'])->whereNumber('id');
        Route::delete('services/{id}/detach-categories', [ServiceController::class, 'detachCategories'])->whereNumber('id');
        Route::put('services/{id}/sync-categories', [ServiceController::class, 'syncCategories'])->whereNumber('id');
    });
});

// =============================================
// V12 – REPORTS
// =============================================
Route::prefix('v12')
    ->middleware(['auth:sanctum', 'active.session', 'permission:finance.view'])
    ->group(function () {
        Route::prefix('reports')->group(function () {
            Route::get('summary', [ReportController::class, 'summary']);
            Route::get('trends', [ReportController::class, 'trends']);
            Route::get('detailed', [ReportController::class, 'detailed']);
            Route::get('overview', [ReportController::class, 'overview']);
            Route::get('export', [ReportController::class, 'export']);
        });
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
// V14 – CHAT
// =============================================
Route::prefix('v14')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::prefix('chat')->group(function () {
        Route::post('conversation', [ChatController::class, 'getOrCreateConversation']);
        Route::get('conversations', [ChatController::class, 'getConversations']);
        Route::get('conversations/{id}/messages', [ChatController::class, 'getMessages']);
        Route::post('conversations/{id}/read', [ChatController::class, 'markConversationAsRead']);
        Route::delete('conversations/{id}', [ChatController::class, 'deleteConversation']);
        Route::post('send', [ChatController::class, 'sendMessage']);
        Route::put('messages/{id}/read', [ChatController::class, 'markMessageAsRead']);
        Route::delete('messages/{id}', [ChatController::class, 'deleteMessage']);
        Route::post('messages/{id}/reaction', [ChatController::class, 'addReaction']);
        Route::delete('messages/{id}/reaction', [ChatController::class, 'removeReaction']);
        Route::post('upload', [ChatController::class, 'uploadFile']);
        Route::get('files/{id}/download', [ChatController::class, 'downloadFile']);
        Route::get('files/{id}/info', [ChatController::class, 'getFileInfo']);
        Route::delete('files/{id}', [ChatController::class, 'deleteFile']);
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

// =============================================
// V16 – SUBSCRIPTIONS & RATE CARDS
// =============================================
Route::prefix('v16')->group(function () {
    Route::get('rate-cards', [SubscriptionController::class, 'getRateCards']);
    Route::get('payment-methods', [SubscriptionController::class, 'getPaymentMethods']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('check-subscription', [SubscriptionController::class, 'checkStatus']);
        Route::post('subscriptions', [SubscriptionController::class, 'store']);
        Route::get('my-subscriptions', [SubscriptionController::class, 'mySubscriptions']);
        Route::get('my-invoices', [SubscriptionController::class, 'myInvoices']);
        Route::get('invoices/{id}/download', [SubscriptionController::class, 'downloadInvoicePdf']);
    });

    Route::middleware('auth:sanctum')->prefix('admin')->group(function () {
        Route::get('rate-cards', [RateCardController::class, 'index']);
        Route::post('rate-cards', [RateCardController::class, 'store']);
        Route::put('rate-cards/{id}', [RateCardController::class, 'update']);
        Route::delete('rate-cards/{id}', [RateCardController::class, 'destroy']);

        Route::get('payment-methods', [PaymentMethodController::class, 'index']);
        Route::post('payment-methods', [PaymentMethodController::class, 'store']);
        Route::get('payment-methods/{id}', [PaymentMethodController::class, 'show']);
        Route::put('payment-methods/{id}', [PaymentMethodController::class, 'update']);
        Route::delete('payment-methods/{id}', [PaymentMethodController::class, 'destroy']);
        Route::get('payment-methods/dropdown', [PaymentMethodController::class, 'dropdown']);
        Route::patch('payment-methods/{id}/toggle', [PaymentMethodController::class, 'toggle']);

        Route::get('subscriptions', [SubscriptionController::class, 'adminIndex']);
        Route::get('subscriptions/stats', [SubscriptionController::class, 'stats']);
        Route::post('subscriptions/{id}/approve', [SubscriptionController::class, 'approve']);
        Route::post('subscriptions/{id}/reject', [SubscriptionController::class, 'reject']);
        Route::get('invoices/{id}/download', [SubscriptionController::class, 'downloadInvoicePdf']);
    });
});

// =============================================
// V17 – SERVICE CATEGORIES
// =============================================
Route::prefix('v17')->group(function () {
    Route::get('service-categories', [ServiceCategoryController::class, 'index']);
    Route::get('service-categories/{id}', [ServiceCategoryController::class, 'show']);
    Route::get('service-categories/slug/{slug}', [ServiceCategoryController::class, 'showBySlug']);
    Route::get('service-categories/dropdown/by-id', [ServiceCategoryController::class, 'dropdownById']);
    Route::get('service-categories/dropdown/active', [ServiceCategoryController::class, 'dropdownActive']);
    Route::get('service-categories/dropdown/paginated', [ServiceCategoryController::class, 'dropdownPaginated']);

    Route::middleware(['auth:sanctum', 'active.session'])->group(function () {
        Route::post('service-categories', [ServiceCategoryController::class, 'store']);
        Route::put('service-categories/{id}', [ServiceCategoryController::class, 'update']);
        Route::delete('service-categories/{id}', [ServiceCategoryController::class, 'destroy']);
        Route::delete('service-categories/bulk-delete', [ServiceCategoryController::class, 'bulkDelete']);
        Route::get('service-categories/stats', [ServiceCategoryController::class, 'stats']);
    });
});

// =============================================
// V18 – PRIVACY POLICY
// =============================================
Route::prefix('v18')->group(function () {
    Route::get('privacy-policy', [PrivacyPolicyController::class, 'show']);
    Route::get('privacy-policies', [PrivacyPolicyController::class, 'index']);

    Route::middleware(['auth:sanctum', 'active.session', 'permission:privacy.edit'])->group(function () {
        Route::post('privacy-policies', [PrivacyPolicyController::class, 'store']);
        Route::get('privacy-policies/{id}', [PrivacyPolicyController::class, 'showById']);
        Route::get('privacy-policies/{id}/edit', [PrivacyPolicyController::class, 'edit']);
        Route::put('privacy-policies/{id}', [PrivacyPolicyController::class, 'update']);
        Route::delete('privacy-policies/{id}', [PrivacyPolicyController::class, 'destroy']);
        Route::put('privacy-policy', [PrivacyPolicyController::class, 'update']);
    });
});


// =============================================
// V19 – TECHNICIAN 6-STEP REGISTRATION (draft-based)
//  • step1 / verify-otp / resend-otp / status — PUBLIC (throttled)
//  • steps 2–6 — draft token (auth:sanctum only; draft tokens have no User,
//    so `active.session` must NOT be applied here)
// =============================================
Route::prefix('v19')->group(function () {

    // ── Public ──
    Route::post('technicians/register/step1', [TechnicianController::class, 'registerStep1'])
        ->middleware('throttle:6,1');
    Route::post('technicians/register/verify-otp', [TechnicianController::class, 'verifyDraftOtp'])
        ->middleware('throttle:10,1');
    Route::post('technicians/register/resend-otp', [TechnicianController::class, 'resendDraftOtp'])
        ->middleware('throttle:3,1');
    Route::get('technicians/register/status/{id}', [TechnicianController::class, 'registrationStatus'])
        ->whereNumber('id');

    // ── Draft-authenticated: steps 2–6 ──
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('technicians/register/step2', [TechnicianController::class, 'registerStep2']);
        Route::post('technicians/register/step3', [TechnicianController::class, 'registerStep3']);
        Route::post('technicians/register/step4', [TechnicianController::class, 'registerStep4']);
        Route::post('technicians/register/step5', [TechnicianController::class, 'registerStep5']);
        Route::post('technicians/register/step6', [TechnicianController::class, 'registerStep6']);
    });

    // ── Admin approve ──
    Route::post('admin/technicians/{id}/approve', [TechnicianController::class, 'approve'])
        ->middleware(['auth:sanctum', 'active.session', 'permission:technicians.approve']);

    // ── Authenticated technician (no subscription check) ──
    Route::middleware(['auth:sanctum', 'active.session'])->group(function () {
        Route::get('technicians/my-registration-status', [TechnicianController::class, 'myRegistrationStatus']);
        Route::get('technicians/profile', [TechnicianController::class, 'getOwnProfile']);
        Route::put('technicians/profile', [TechnicianController::class, 'updateProfile']);
        Route::post('technicians/profile/photo', [TechnicianController::class, 'uploadProfilePhoto']);
        Route::post('technicians/services', [TechnicianController::class, 'updateServices']);
        Route::post('technicians/heartbeat', [TechnicianController::class, 'heartbeat']);
        Route::post('technicians/location', [TechnicianController::class, 'updateLocation']);
    });
});


// =============================================
// V20 – ADMIN TECHNICIANS
// =============================================
Route::prefix('v20')->middleware(['auth:sanctum', 'active.session'])->group(function () {

    // Split lists (define static paths BEFORE {id} to avoid capture)
    Route::get('admin/technicians/pending',  [TechnicianController::class, 'adminPendingIndex'])
        ->middleware('permission:technicians.view');
    Route::get('admin/technicians/approved', [TechnicianController::class, 'adminApprovedIndex'])
        ->middleware('permission:technicians.view');

    Route::get('admin/technicians', [TechnicianController::class, 'adminIndex'])
        ->middleware('permission:technicians.view');

    // Biometrics — only for admin
    Route::get('admin/technicians/{id}/biometrics', [TechnicianController::class, 'adminBiometrics'])
        ->whereNumber('id')
        ->middleware('permission:technicians.view');
});

// =============================================
// V21 – FINANCE
// =============================================
Route::prefix('v21')
    ->middleware(['auth:sanctum', 'active.session', 'permission:finance.view'])
    ->group(function () {
        Route::prefix('finance/subscriptions')->group(function () {
            Route::get('summary', [FinanceSubscriptionController::class, 'summary']);
            Route::get('trends', [FinanceSubscriptionController::class, 'trends']);
            Route::get('table', [FinanceSubscriptionController::class, 'table']);
            Route::get('export', [FinanceSubscriptionController::class, 'export']);
        });

        Route::prefix('finance/technicians')->group(function () {
            Route::get('summary', [FinanceTechnicianController::class, 'summary']);
            Route::get('trends', [FinanceTechnicianController::class, 'trends']);
            Route::get('table', [FinanceTechnicianController::class, 'table']);
            Route::get('export', [FinanceTechnicianController::class, 'export']);
        });

        Route::prefix('finance/customers')->group(function () {
            Route::get('summary', [FinanceCustomerController::class, 'summary']);
            Route::get('trends', [FinanceCustomerController::class, 'trends']);
            Route::get('table', [FinanceCustomerController::class, 'table']);
            Route::get('export', [FinanceCustomerController::class, 'export']);
        });

        Route::prefix('finance/requests')->group(function () {
            Route::get('summary', [FinanceRequestController::class, 'summary']);
            Route::get('trends', [FinanceRequestController::class, 'trends']);
            Route::get('table', [FinanceRequestController::class, 'table']);
            Route::get('export', [FinanceRequestController::class, 'export']);
        });
    });

// =============================================
// V22 – SMS LOGS
// =============================================
Route::prefix('v22')->middleware(['auth:sanctum', 'active.session'])->group(function () {
    Route::middleware('permission:sms.view')->group(function () {
        Route::get('sms-logs', [SmsLogController::class, 'index']);
        Route::get('users/{userId}/sms-logs', [SmsLogController::class, 'getUserSmsLogs']);
        Route::get('sms-balance', [SmsLogController::class, 'balance']);
        Route::get('sms-stats', [SmsLogController::class, 'stats']);
    });

    Route::middleware('permission:sms.send')->group(function () {
        Route::post('send-sms', [SmsLogController::class, 'sendSms']);
    });

    Route::middleware('permission:sms.resend')->group(function () {
        Route::post('sms-logs/{id}/resend', [SmsLogController::class, 'resendSms']);
    });

    Route::middleware('permission:sms.delete')->group(function () {
        Route::delete('sms-logs/{id}', [SmsLogController::class, 'deleteSmsLog']);
    });
});

// =============================================
// V23 – FEEDBACK
// =============================================
Route::prefix('v23')->group(function () {
    Route::post('feedback', [FeedbackController::class, 'store'])->middleware('throttle:5,1');

    Route::middleware(['auth:sanctum', 'active.session'])->prefix('admin')->group(function () {
        Route::middleware('permission:feedback.view')->group(function () {
            Route::get('feedback', [FeedbackController::class, 'index']);
            Route::get('feedback/stats', [FeedbackController::class, 'stats']);
            Route::get('feedback/{id}', [FeedbackController::class, 'show']);
        });

        Route::middleware('permission:feedback.edit')->group(function () {
            Route::put('feedback/{id}', [FeedbackController::class, 'update']);
        });

        Route::middleware('permission:feedback.delete')->group(function () {
            Route::delete('feedback/{id}', [FeedbackController::class, 'destroy']);
        });
    });
});

// =============================================
// V24 – MINI APPS
// =============================================
Route::prefix('v24')->group(function () {
    Route::get('mini-apps', [MiniAppController::class, 'index']);
    Route::get('mini-apps-print', [MiniAppController::class, 'printSheet']);
    Route::post('mini-apps/qr/verify', [MiniAppQrController::class, 'verify'])->middleware('throttle:60,1');
    Route::get('mini-apps/qr/{token}/image', [MiniAppQrController::class, 'image']);
    Route::get('mini-apps/{slug}', [MiniAppController::class, 'show']);
    Route::get('mini-apps/{slug}/qr', [MiniAppController::class, 'qr']);

    Route::middleware(['auth:sanctum', 'active.session'])->prefix('admin')->group(function () {
        Route::middleware('permission:miniapps.manage')->group(function () {
            Route::post('mini-apps', [MiniAppController::class, 'store']);
            Route::put('mini-apps/{id}', [MiniAppController::class, 'update']);
            Route::delete('mini-apps/{id}', [MiniAppController::class, 'destroy']);
        });

        Route::get('mini-app-qrs/stats', [MiniAppQrController::class, 'stats'])->middleware('permission:miniapp-qrs.view');
        Route::get('mini-app-qrs', [MiniAppQrController::class, 'index'])->middleware('permission:miniapp-qrs.view');
        Route::get('mini-app-qrs/{id}', [MiniAppQrController::class, 'show'])->middleware('permission:miniapp-qrs.view');
        Route::post('mini-app-qrs', [MiniAppQrController::class, 'store'])->middleware('permission:miniapp-qrs.create');
        Route::put('mini-app-qrs/{id}', [MiniAppQrController::class, 'update'])->middleware('permission:miniapp-qrs.update');
        Route::delete('mini-app-qrs/{id}', [MiniAppQrController::class, 'destroy'])->middleware('permission:miniapp-qrs.delete');
    });
});

// =============================================
// V25 – BANNERS
// =============================================
Route::prefix('v25')->group(function () {
    Route::get('banners', [BannerController::class, 'publicIndex']);

    Route::middleware(['auth:sanctum', 'active.session'])->prefix('admin')->group(function () {
        Route::get('banners', [BannerController::class, 'index']);
        Route::get('banners/{id}', [BannerController::class, 'show']);
        Route::post('banners', [BannerController::class, 'store']);
        Route::put('banners/{id}', [BannerController::class, 'update']);
        Route::post('banners/{id}', [BannerController::class, 'update']);
        Route::delete('banners/{id}', [BannerController::class, 'destroy']);
        Route::patch('banners/{id}/status', [BannerController::class, 'updateStatus']);
    });
});

// =============================================
// PUBLIC TRACKING & REGISTRATION STATUS (backward-compatible legacy aliases)
// =============================================
Route::get('tracking/{requestId}', [TechnicianController::class, 'getTrackingData']);
Route::get('technicians/registration-status/{id}', [TechnicianController::class, 'registrationStatus']);
