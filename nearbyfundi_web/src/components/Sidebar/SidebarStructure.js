// src/components/Sidebar/SidebarStructure.js
import {
  Dashboard as DashboardIcon,
  People as UsersIcon,
  Security as RolesIcon,
  VpnKey as PermissionsIcon,
  History as AuditIcon,
  VpnKey as OTPIcon,
  Info as AboutIcon,
  Description as TermsIcon,
  Help as FaqIcon,
  Build as ServicesIcon,
  Engineering as TechniciansIcon,
  PhotoLibrary as PortfoliosIcon,
  Article as PostsIcon,
  RequestPage as RequestsIcon,
  Assessment as ReportIcon,
  Settings as SettingsIcon,
  MonitorHeart as MonitoringIcon,
  AccountBalance as FundIcon,
} from '@mui/icons-material';

const addIf = (condition, item) => (condition ? [item] : []);

export function getSidebarStructure(hasPermission) {
  const structure = [];

  // ----- Dashboard -----
  if (hasPermission('dashboard.view')) {
    structure.push({
      id: 1,
      label: 'Dashboard',
      link: '/app/dashboard',
      icon: <DashboardIcon />,
    });
  }

  // ----- Static Pages -----
  const staticChildren = [
    ...addIf(hasPermission('about.view'), { label: 'About', link: '/app/about' }),
    ...addIf(hasPermission('terms.view'), { label: 'Terms', link: '/app/terms' }),
    ...addIf(hasPermission('faqs.view'), { label: 'FAQs', link: '/app/faqs' }),
  ];
  if (staticChildren.length > 0) {
    structure.push({
      id: 2,
      label: 'Static Pages',
      link: '#',
      icon: <AboutIcon />,
      children: staticChildren,
    });
  }

  // ----- Services -----
  if (hasPermission('services.view')) {
    structure.push({
      id: 3,
      label: 'Services',
      link: '/app/services',
      icon: <ServicesIcon />,
      children: [{ label: 'All Services', link: '/app/services' }],
    });
  }

  // ----- Technicians -----
  if (hasPermission('technicians.view')) {
    structure.push({
      id: 4,
      label: 'Technicians',
      link: '/app/technicians',
      icon: <TechniciansIcon />,
      children: [{ label: 'All Technicians', link: '/app/technicians' }],
    });
  }

  // ----- Portfolios -----
  if (hasPermission('portfolios.view')) {
    structure.push({
      id: 5,
      label: 'Portfolios',
      link: '/app/portfolios',
      icon: <PortfoliosIcon />,
    });
  }

  // ----- Posts -----
  if (hasPermission('posts.view')) {
    structure.push({
      id: 6,
      label: 'Posts',
      link: '/app/posts',
      icon: <PostsIcon />,
      children: [{ label: 'All Posts', link: '/app/posts' }],
    });
  }

  // ----- Service Requests -----
  if (hasPermission('requests.view')) {
    structure.push({
      id: 7,
      label: 'Service Requests',
      link: '/app/requests',
      icon: <RequestsIcon />,
      children: [{ label: 'All Requests', link: '/app/requests' }],
    });
  }

  // ----- Fund -----
  const fundChildren = [
    ...addIf(hasPermission('fund.view'), { label: 'Fund Management', link: '/app/fund' }),
    ...addIf(hasPermission('fund.transactions.view'), { label: 'Fund Transactions', link: '/app/fund/transactions' }),
    ...addIf(hasPermission('fund.reports.view'), { label: 'Fund Reports', link: '/app/fund/reports' }),
  ];
  if (fundChildren.length > 0) {
    structure.push({
      id: 11,
      label: 'Fund',
      link: '/app/fund',
      icon: <FundIcon />,
      children: fundChildren,
    });
  }

  // ----- Monitoring -----
  if (hasPermission('monitoring.view')) {
    structure.push({
      id: 10,
      label: 'Monitoring',
      link: '/app/monitoring',
      icon: <MonitoringIcon />,
      children: [{ label: 'Monitoring Dashboard', link: '/app/monitoring' }],
    });
  }

  // ----- Reports -----
  if (hasPermission('reports.view')) {
    structure.push({
      id: 8,
      label: 'Reports',
      link: '#',
      icon: <ReportIcon />,
      children: [{ label: 'Reports Dashboard', link: '/app/reports' }],
    });
  }

  // ----- Settings -----
  const settingsChildren = [
    ...addIf(hasPermission('users.view'), { label: 'Users', link: '/app/users' }),
    ...addIf(hasPermission('roles.view'), { label: 'Roles', link: '/app/roles' }),
    ...addIf(hasPermission('permissions.view'), { label: 'Permissions', link: '/app/permissions' }),
    ...addIf(hasPermission('audit.view'), { label: 'Audit Logs', link: '/app/audit' }),
    ...addIf(hasPermission('otp.view'), { label: 'OTP Management', link: '/app/otp' }),
    ...addIf(hasPermission('profile.view'), { label: 'Profile', link: '/app/profile' }),
  ];
  if (settingsChildren.length > 0) {
    structure.push({
      id: 9,
      label: 'Settings',
      link: '#',
      icon: <SettingsIcon />,
      children: settingsChildren,
    });
  }

  return structure;
}

// Static structure for breadcrumbs
const staticStructure = [
  { id: 1, label: 'Dashboard', link: '/app/dashboard', icon: <DashboardIcon /> },
  {
    id: 2,
    label: 'Static Pages',
    link: '#',
    icon: <AboutIcon />,
    children: [
      { label: 'About', link: '/app/about' },
      { label: 'Terms', link: '/app/terms' },
      { label: 'FAQs', link: '/app/faqs' },
    ]
  },
  { id: 3, label: 'Services', link: '/app/services', icon: <ServicesIcon />, children: [{ label: 'All Services', link: '/app/services' }] },
  { id: 4, label: 'Technicians', link: '/app/technicians', icon: <TechniciansIcon />, children: [{ label: 'All Technicians', link: '/app/technicians' }] },
  { id: 5, label: 'Portfolios', link: '/app/portfolios', icon: <PortfoliosIcon /> },
  { id: 6, label: 'Posts', link: '/app/posts', icon: <PostsIcon />, children: [{ label: 'All Posts', link: '/app/posts' }] },
  { id: 7, label: 'Service Requests', link: '/app/requests', icon: <RequestsIcon />, children: [{ label: 'All Requests', link: '/app/requests' }] },
  {
    id: 11,
    label: 'Fund',
    link: '/app/fund',
    icon: <FundIcon />,
    children: [
      { label: 'Fund Management', link: '/app/fund' },
      { label: 'Fund Transactions', link: '/app/fund/transactions' },
      { label: 'Fund Reports', link: '/app/fund/reports' },
    ]
  },
  { id: 10, label: 'Monitoring', link: '/app/monitoring', icon: <MonitoringIcon />, children: [{ label: 'Monitoring Dashboard', link: '/app/monitoring' }] },
  { id: 8, label: 'Reports', link: '#', icon: <ReportIcon />, children: [{ label: 'Reports Dashboard', link: '/app/reports' }] },
  {
    id: 9,
    label: 'Settings',
    link: '#',
    icon: <SettingsIcon />,
    children: [
      { label: 'Users', link: '/app/users' },
      { label: 'Roles', link: '/app/roles' },
      { label: 'Permissions', link: '/app/permissions' },
      { label: 'Audit Logs', link: '/app/audit' },
      { label: 'OTP Management', link: '/app/otp' },
      { label: 'Profile', link: '/app/profile' },
    ]
  },
];

export default staticStructure;