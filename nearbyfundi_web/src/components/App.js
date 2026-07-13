// src/App.js
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

// Import Error component (if not defined, you may need to create it)
import Error from "pages/error/Error"; // ✅ Ensure this exists

// Admin/Manager Contexts
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
import { PortfolioProvider } from "context/PortfolioContext";
import { PostProvider } from "context/PostContext";
import { CommentProvider } from "context/CommentContext";
import { LikeProvider } from "context/LikeContext";
import { RequestProvider } from "context/RequestContext";
import { ReportProvider } from "context/ReportContext";

// ✅ If you have a ChatProvider or NotificationProvider, add them here
// import { ChatProvider } from "context/ChatContext";
// import { NotificationProvider } from "context/NotificationContext";

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

            {/* Protected Routes */}
            <Route path="/app/*" element={<PrivateRoute><Layout /></PrivateRoute>} />

            {/* Default redirects */}
            <Route path="/" element={<Navigate to="/app/dashboard" replace />} />
            <Route path="/app" element={<Navigate to="/app/dashboard" replace />} />

            {/* 404 */}
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
                                        <AboutProvider>      {/* ✅ About page context */}
                                            <TermsProvider>   {/* ✅ Terms page context */}
                                                <FaqProvider> {/* ✅ FAQ page context */}
                                                    <ServiceProvider>
                                                        <TechnicianProvider>
                                                            <PortfolioProvider>
                                                                <PostProvider>
                                                                    <CommentProvider>
                                                                        <LikeProvider>
                                                                            <RequestProvider>
                                                                                <ReportProvider>
                                                                                    <ToastContainer
                                                                                        position="top-right"
                                                                                        autoClose={3000}
                                                                                        hideProgressBar={false}
                                                                                    />
                                                                                    <RouterNavigatorSync />
                                                                                    <AppContent />
                                                                                </ReportProvider>
                                                                            </RequestProvider>
                                                                        </LikeProvider>
                                                                    </CommentProvider>
                                                                </PostProvider>
                                                            </PortfolioProvider>
                                                        </TechnicianProvider>
                                                    </ServiceProvider>
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