// src/components/Layout.js
import React from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import classnames from 'classnames';

import SettingsIcon from '@mui/icons-material/Settings';
import GithubIcon from '@mui/icons-material/GitHub';
import FacebookIcon from '@mui/icons-material/Facebook';
import TwitterIcon from '@mui/icons-material/Twitter';

import { Fab, IconButton } from '@mui/material';
import useStyles from './styles';

import Header from '../Header';
import Sidebar from '../Sidebar';
import Footer from '../Footer';
import { Link } from '../Wrappers';
import ColorChangeThemePopper from './components/ColorChangeThemePopper';
import BreadCrumbs from '../../components/BreadCrumbs';

// Pages
import Profile from '../../pages/profile';
import Dashboard from '../../pages/dashboard/Dashboard';

// Admin/Manager Management Pages
import UsersList from "../../pages/user";
import PermissionsList from "pages/permissions/PermissionList";
import RoleList from "pages/roles/RoleList";
import AuditList from "pages/audit/AuditList";
import OtpList from "pages/otp/OtpList";
import AboutPage from "pages/about/AboutPage";
import TermsPage from "pages/terms/TermsPage";
import FaqList from "pages/faqs/FaqList";
import TechniciansList from "pages/technicians/TechniciansList";
import PortfoliosList from "pages/portfolios/PortfoliosList";
import PostsList from "pages/posts/PostsList";
import RequestsList from "pages/requests/RequestsList";
import ReportsDashboard from "pages/reports/ReportsDashboard";
import ServicesList from "pages/services/ServicesList";

// Monitoring
import MonitoringMap from "pages/monitoring/MonitoringMap";

import { useLayoutState } from "context/LayoutContext";
import { getSidebarStructure } from '../Sidebar/SidebarStructure';
import { usePermissions } from 'hooks/usePermissions';

function Layout() {
  const classes = useStyles();
  const [anchorEl, setAnchorEl] = React.useState(null);
  const open = Boolean(anchorEl);
  const id = open ? 'add-section-popover' : undefined;

  const handleClick = (event) => {
    setAnchorEl(open ? null : event.currentTarget);
  };

  const layoutState = useLayoutState();

  // Permission-based sidebar
  const { can, permissions } = usePermissions();

  const permissionsReady = Array.isArray(permissions);
  const dynamicStructure = permissionsReady ? getSidebarStructure(can) : [];

  return (
      <div className={classes.root}>
        <Header />
        <Sidebar structure={dynamicStructure} />
        <div
            className={classnames(classes.content, {
              [classes.contentShift]: layoutState.isSidebarOpened,
            })}
        >
          <div className={classes.fakeToolbar} />
          <BreadCrumbs />

          <Routes>
            {/* Profile */}
            <Route path="profile" element={<Profile />} />

            {/* Dashboard */}
            <Route path="dashboard" element={<Dashboard />} />

            {/* User Management */}
            <Route path="users" element={<UsersList />} />
            <Route path="users/create" element={<UsersList />} />
            <Route path="users/:id/edit" element={<UsersList />} />
            <Route path="users/:id/view" element={<UsersList />} />

            {/* Role Management */}
            <Route path="roles" element={<RoleList />} />
            <Route path="roles/create" element={<RoleList />} />
            <Route path="roles/:id/edit" element={<RoleList />} />
            <Route path="roles/:id/view" element={<RoleList />} />

            {/* Permission Management */}
            <Route path="permissions" element={<PermissionsList />} />
            <Route path="permissions/create" element={<PermissionsList />} />
            <Route path="permissions/:id/edit" element={<PermissionsList />} />
            <Route path="permissions/:id/view" element={<PermissionsList />} />

            {/* Audit & OTP */}
            <Route path="audit" element={<AuditList />} />
            <Route path="otp" element={<OtpList />} />

            {/* Static Pages - About, Terms, FAQs */}
            <Route path="about" element={<AboutPage />} />
            <Route path="terms" element={<TermsPage />} />
            <Route path="faqs" element={<FaqList />} />
            <Route path="faqs/create" element={<FaqList />} />
            <Route path="faqs/:id/edit" element={<FaqList />} />

            {/* Services */}
            <Route path="services" element={<ServicesList />} />
            <Route path="services/create" element={<ServicesList />} />
            <Route path="services/:id/edit" element={<ServicesList />} />

            {/* Technicians */}
            <Route path="technicians" element={<TechniciansList />} />

            {/* Portfolios */}
            <Route path="portfolios" element={<PortfoliosList />} />

            {/* Posts */}
            <Route path="posts" element={<PostsList />} />

            {/* Service Requests */}
            <Route path="requests" element={<RequestsList />} />

            {/* Monitoring */}
            <Route path="monitoring" element={<MonitoringMap />} />

            {/* Reports */}
            <Route path="reports" element={<ReportsDashboard />} />

            {/* Default redirect */}
            <Route path="*" element={<Navigate to="/app/dashboard" replace />} />
          </Routes>

          <Fab
              color="primary"
              aria-label="settings"
              onClick={handleClick}
              className={classes.changeThemeFab}
              style={{ zIndex: 2000 }}
          >
            <SettingsIcon style={{ color: '#fff' }} />
          </Fab>
          <ColorChangeThemePopper id={id} open={open} anchorEl={anchorEl} />

          <Footer>
            <div>
              <Link color="primary" href="https://imaratech.co.tz/" target="_blank" className={classes.link}>
                imaratech
              </Link>
            </div>
            <div>
              <Link href="https://www.facebook.com/flatlogic" target="_blank">
                <IconButton aria-label="facebook">
                  <FacebookIcon style={{ color: '#6E6E6E99' }} />
                </IconButton>
              </Link>
              <Link href="https://twitter.com/flatlogic" target="_blank">
                <IconButton aria-label="twitter">
                  <TwitterIcon style={{ color: '#6E6E6E99' }} />
                </IconButton>
              </Link>
              <Link href="https://github.com/flatlogic" target="_blank">
                <IconButton aria-label="github" style={{ padding: '12px 0 12px 12px' }}>
                  <GithubIcon style={{ color: '#6E6E6E99' }} />
                </IconButton>
              </Link>
            </div>
          </Footer>
        </div>
      </div>
  );
}

export default Layout;