import React from 'react';
import { BrowserRouter, Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { ToastContainer } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import { setNavigator } from "router/navigation";
import { AuthProvider, useAuth } from "context/AuthContext";
import Documentation from "components/Documentation";
import Layout from "components/Layout";
import Login from "pages/login/Login";
import VerifyOTP from "pages/verify_otp/VerifyOTP";
import ResetPassword from "pages/reset_password/ResetPassword";
import ForgotPassword from "pages/forgot_password/ForgotPassword";
import Error from "pages/error/Error";

// All Pages
import Profile from "pages/profile";
import Dashboard from "pages/dashboard/Dashboard";
import UsersList from "pages/user";
import PermissionsList from "pages/permissions/PermissionList";
import RoleList from "pages/roles/RoleList";
import AuditList from "pages/audit/AuditList";
import OtpList from "pages/otp/OtpList";
import AboutPage from "pages/about/AboutPage";
import TermsPage from "pages/terms/TermsPage";
import FaqList from "pages/faqs/FaqList";
import TechniciansList from "pages/technicians/TechniciansList";
import TechnicianDetails from "pages/technicians/TechnicianDetails";
import PortfoliosList from "pages/portfolios/PortfoliosList";
import PostsList from "pages/posts/PostsList";
import RequestsList from "pages/requests/RequestsList";
import ReportsDashboard from "pages/reports/ReportsDashboard";
import ServicesList from "pages/services/ServicesList";
import MonitoringMap from "pages/monitoring/MonitoringMap";
import PrivacyPolicyPage from "pages/privacy-policy/PrivacyPolicyPage";

// Subscription pages
import SubscriptionList from "pages/subscriptions/SubscriptionList";
import RateCardManagement from "pages/subscriptions/RateCardManagement";
import PaymentMethodManagement from "pages/subscriptions/PaymentMethodManagement";

// Contexts
import { UserProvider } from "context/UserContext";
import { RoleProvider } from "context/RoleContext";
import { PermissionProvider } from "context/PermissionContext";
import { AuditProvider } from "context/AuditContext";
import { OtpProvider } from "context/OtpContext";
import { DashboardProvider } from "context/DashboardContext";
import { AboutProvider } from "context/AboutContext";
import { TermsProvider } from "context/TermsContext";
import { FaqProvider } from "context/FaqContext";
import { ServiceProvider } from "context/ServiceContext";
import { TechnicianProvider } from "context/TechnicianContext";
import { AdminTechnicianProvider } from "context/AdminTechnicianContext"; // 🆕
import { PortfolioProvider } from "context/PortfolioContext";
import { PostProvider } from "context/PostContext";
import { CommentProvider } from "context/CommentContext";
import { LikeProvider } from "context/LikeContext";
import { RequestProvider } from "context/RequestContext";
import { ReportProvider } from "context/ReportContext";
import {
    RateCardProvider,
    PaymentMethodProvider,
    SubscriptionProvider,
} from "context/SubscriptionContext";
import { PrivacyPolicyProvider } from "context/PrivacyPolicyContext";

function RouterNavigatorSync() {
    const navigate = useNavigate();
    React.useEffect(() => {
        setNavigator(navigate);
        return () => setNavigator(null);
    }, [navigate]);
    return null;
}

function AppContent() {
    const { isAuthenticated, isLoading } = useAuth();

    if (isLoading) {
        return (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
                Loading...
            </div>
        );
    }

    return (
        <Routes>
            {/* Public Routes */}
            <Route path="/login" element={<PublicRoute><Login /></PublicRoute>} />
            <Route path="/verify-otp" element={<PublicRoute><VerifyOTP /></PublicRoute>} />
            <Route path="/reset-password" element={<PublicRoute><ResetPassword /></PublicRoute>} />
            <Route path="/forgot-password" element={<PublicRoute><ForgotPassword /></PublicRoute>} />

            {/* Error Pages */}
            <Route path="/403" element={<Error code={403} />} />
            <Route path="/500" element={<Error code={500} />} />

            {/* Documentation */}
            <Route path="/documentation/*" element={<Documentation />} />

            {/* Protected Routes – all /app/* handled by Layout */}
            <Route path="/app/*" element={<PrivateRoute><Layout /></PrivateRoute>}>
                <Route path="profile" element={<Profile />} />
                <Route path="dashboard" element={<Dashboard />} />
                <Route path="users" element={<UsersList />} />
                <Route path="users/create" element={<UsersList />} />
                <Route path="users/:id/edit" element={<UsersList />} />
                <Route path="users/:id/view" element={<UsersList />} />
                <Route path="roles" element={<RoleList />} />
                <Route path="roles/create" element={<RoleList />} />
                <Route path="roles/:id/edit" element={<RoleList />} />
                <Route path="roles/:id/view" element={<RoleList />} />
                <Route path="permissions" element={<PermissionsList />} />
                <Route path="permissions/create" element={<PermissionsList />} />
                <Route path="permissions/:id/edit" element={<PermissionsList />} />
                <Route path="permissions/:id/view" element={<PermissionsList />} />
                <Route path="audit" element={<AuditList />} />
                <Route path="otp" element={<OtpList />} />
                <Route path="about" element={<AboutPage />} />
                <Route path="terms" element={<TermsPage />} />
                <Route path="faqs" element={<FaqList />} />
                <Route path="faqs/create" element={<FaqList />} />
                <Route path="faqs/:id/edit" element={<FaqList />} />
                <Route path="services" element={<ServicesList />} />
                <Route path="services/create" element={<ServicesList />} />
                <Route path="services/:id/edit" element={<ServicesList />} />
                <Route path="technicians" element={<TechniciansList />} />
                <Route path="technicians/:id" element={<TechnicianDetails />} />
                <Route path="portfolios" element={<PortfoliosList />} />
                <Route path="posts" element={<PostsList />} />
                <Route path="requests" element={<RequestsList />} />
                <Route path="monitoring" element={<MonitoringMap />} />
                <Route path="reports" element={<ReportsDashboard />} />
                <Route path="subscriptions" element={<SubscriptionList />} />
                <Route path="rate-cards" element={<RateCardManagement />} />
                <Route path="payment-methods" element={<PaymentMethodManagement />} />
                <Route path="privacy-policy" element={<PrivacyPolicyPage />} />
                <Route index element={<Navigate to="/app/dashboard" replace />} />
                <Route path="*" element={<Navigate to="/app/dashboard" replace />} />
            </Route>

            <Route path="/" element={<Navigate to="/app/dashboard" replace />} />
            <Route path="/app" element={<Navigate to="/app/dashboard" replace />} />
            <Route path="*" element={<Error />} />
        </Routes>
    );

    function PrivateRoute({ children }) {
        if (!isAuthenticated) return <Navigate to="/login" replace />;
        return children;
    }

    function PublicRoute({ children }) {
        if (isAuthenticated) return <Navigate to="/app/dashboard" replace />;
        return children;
    }
}

export default function App() {
    return (
        <BrowserRouter>
            <AuthProvider>
                <DashboardProvider>
                    <UserProvider>
                        <RoleProvider>
                            <PermissionProvider>
                                <AuditProvider>
                                    <OtpProvider>
                                        <AboutProvider>
                                            <TermsProvider>
                                                <FaqProvider>
                                                    <PrivacyPolicyProvider>
                                                        <ServiceProvider>
                                                            <TechnicianProvider>
                                                                <AdminTechnicianProvider>   {/* 🆕 */}
                                                                    <PortfolioProvider>
                                                                        <PostProvider>
                                                                            <CommentProvider>
                                                                                <LikeProvider>
                                                                                    <RequestProvider>
                                                                                        <ReportProvider>
                                                                                            <RateCardProvider>
                                                                                                <PaymentMethodProvider>
                                                                                                    <SubscriptionProvider>
                                                                                                        <ToastContainer
                                                                                                            position="top-right"
                                                                                                            autoClose={3000}
                                                                                                            hideProgressBar={false}
                                                                                                        />
                                                                                                        <RouterNavigatorSync />
                                                                                                        <AppContent />
                                                                                                    </SubscriptionProvider>
                                                                                                </PaymentMethodProvider>
                                                                                            </RateCardProvider>
                                                                                        </ReportProvider>
                                                                                    </RequestProvider>
                                                                                </LikeProvider>
                                                                            </CommentProvider>
                                                                        </PostProvider>
                                                                    </PortfolioProvider>
                                                                </AdminTechnicianProvider>   {/* 🆕 */}
                                                            </TechnicianProvider>
                                                        </ServiceProvider>
                                                    </PrivacyPolicyProvider>
                                                </FaqProvider>
                                            </TermsProvider>
                                        </AboutProvider>
                                    </OtpProvider>
                                </AuditProvider>
                            </PermissionProvider>
                        </RoleProvider>
                    </UserProvider>
                </DashboardProvider>
            </AuthProvider>
        </BrowserRouter>
    );
}