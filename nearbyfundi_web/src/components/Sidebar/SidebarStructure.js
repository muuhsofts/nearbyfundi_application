// src/components/Sidebar/SidebarStructure.js
import {
  Dashboard as DashboardIcon,
  Info as AboutIcon,
  Build as ServicesIcon,
  Engineering as TechniciansIcon,
  PhotoLibrary as PortfoliosIcon,
  Article as PostsIcon,
  RequestPage as RequestsIcon,
  Settings as SettingsIcon,
  MonitorHeart as MonitoringIcon,
  Subscriptions as SubscriptionsIcon,
  Category as CategoryIcon,
  AttachMoney as FinanceIcon,
  Sms as SmsIcon,
} from '@mui/icons-material';

import { identityT } from './components/Sidebar/sidebarTranslations';

const addIf = (condition, item) => (condition ? [item] : []);

/**
 * Shared theme tokens — MUI palette keys for consistent dark mode support.
 * Used by the sidebar renderer to apply theme-aware colors.
 */
const THEME_TOKENS = {
  activeColor: 'primary.main',
  hoverBg: 'action.hover',
  activeBg: 'action.selected',
  textColor: 'text.primary',
  subTextColor: 'text.secondary',
  borderColor: 'divider',
  iconColor: 'text.secondary',
  activeIconColor: 'primary.main',
};

/**
 * Production sidebar structure
 * Only contains items that exist in the real application.
 * All items carry theme-aware color tokens for full dark mode compatibility.
 */
export function getSidebarStructure(hasPermission, t = identityT) {
  const structure = [];

  // ----- Dashboard -----
  if (hasPermission('dashboard.view')) {
    structure.push({
      id: 1,
      label: t('sidebar.dashboard'),
      link: '/app/dashboard',
      icon: <DashboardIcon />,
      ...THEME_TOKENS,
    });
  }

  // ----- Static Pages -----
  const staticChildren = [
    ...addIf(hasPermission('about.view'), {
      label: t('sidebar.about'),
      link: '/app/about',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('terms.view'), {
      label: t('sidebar.terms'),
      link: '/app/terms',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('faqs.view'), {
      label: t('sidebar.faqs'),
      link: '/app/faqs',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('privacy.view'), {
      label: t('sidebar.privacy'),
      link: '/app/privacy-policy',
      ...THEME_TOKENS,
    }),
  ];

  if (staticChildren.length > 0) {
    structure.push({
      id: 2,
      label: t('sidebar.staticPages'),
      link: '#',
      icon: <AboutIcon />,
      children: staticChildren,
      ...THEME_TOKENS,
    });
  }

  // ----- Services -----
  if (hasPermission('services.view')) {
    const servicesChildren = [
      { label: t('sidebar.allServices'), link: '/app/services', ...THEME_TOKENS },
    ];

    if (hasPermission('service-categories.view')) {
      servicesChildren.push({
        label: t('sidebar.categories'),
        link: '/app/services/categories',
        icon: <CategoryIcon />,
        ...THEME_TOKENS,
      });
    }

    structure.push({
      id: 3,
      label: t('sidebar.services'),
      link: '/app/services',
      icon: <ServicesIcon />,
      children: servicesChildren,
      ...THEME_TOKENS,
    });
  }

  // ----- Technicians -----
  if (hasPermission('technicians.view')) {
    structure.push({
      id: 4,
      label: t('sidebar.technicians'),
      link: '/app/technicians',
      icon: <TechniciansIcon />,
      children: [
        { label: t('sidebar.allTechnicians'), link: '/app/technicians', ...THEME_TOKENS },
      ],
      ...THEME_TOKENS,
    });
  }

  // ----- Portfolios -----
  if (hasPermission('portfolios.view')) {
    structure.push({
      id: 5,
      label: t('sidebar.portfolios'),
      link: '/app/portfolios',
      icon: <PortfoliosIcon />,
      ...THEME_TOKENS,
    });
  }

  // ----- Posts -----
  if (hasPermission('posts.view')) {
    structure.push({
      id: 6,
      label: t('sidebar.posts'),
      link: '/app/posts',
      icon: <PostsIcon />,
      children: [{ label: t('sidebar.allPosts'), link: '/app/posts', ...THEME_TOKENS }],
      ...THEME_TOKENS,
    });
  }

  // ----- Service Requests -----
  if (hasPermission('requests.view')) {
    structure.push({
      id: 7,
      label: t('sidebar.serviceRequests'),
      link: '/app/requests',
      icon: <RequestsIcon />,
      children: [{ label: t('sidebar.allRequests'), link: '/app/requests', ...THEME_TOKENS }],
      ...THEME_TOKENS,
    });
  }

  // ----- SMS Logs -----
  if (hasPermission('sms.view')) {
    structure.push({
      id: 14,
      label: t('sidebar.smsLogs'),
      link: '/app/sms-logs',
      icon: <SmsIcon />,
      children: [{ label: t('sidebar.allSmsLogs'), link: '/app/sms-logs', ...THEME_TOKENS }],
      ...THEME_TOKENS,
    });
  }

  // ----- Finance -----
  if (hasPermission('finance.view')) {
    structure.push({
      id: 13,
      label: t('sidebar.finance'),
      link: '/app/finance',
      icon: <FinanceIcon />,
      children: [
        { label: t('sidebar.subscriptions'), link: '/app/finance/subscriptions', ...THEME_TOKENS },
        { label: t('sidebar.technicians'), link: '/app/finance/technicians', ...THEME_TOKENS },
        { label: t('sidebar.customers'), link: '/app/finance/customers', ...THEME_TOKENS },
        { label: t('sidebar.requests'), link: '/app/finance/requests', ...THEME_TOKENS },
      ],
      ...THEME_TOKENS,
    });
  }

  // ----- Monitoring -----
  if (hasPermission('monitoring.view')) {
    structure.push({
      id: 10,
      label: t('sidebar.monitoring'),
      link: '/app/monitoring',
      icon: <MonitoringIcon />,
      children: [
        { label: t('sidebar.monitoringDashboard'), link: '/app/monitoring', ...THEME_TOKENS },
      ],
      ...THEME_TOKENS,
    });
  }

  // ----- Subscriptions -----
  const subscriptionChildren = [
    ...addIf(hasPermission('subscriptions.view'), {
      label: t('sidebar.allSubscriptions'),
      link: '/app/subscriptions',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('subscriptions.manage'), {
      label: t('sidebar.rateCards'),
      link: '/app/rate-cards',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('subscriptions.manage'), {
      label: t('sidebar.paymentMethods'),
      link: '/app/payment-methods',
      ...THEME_TOKENS,
    }),
  ];

  if (subscriptionChildren.length > 0) {
    structure.push({
      id: 12,
      label: t('sidebar.subscriptions'),
      link: '#',
      icon: <SubscriptionsIcon />,
      children: subscriptionChildren,
      ...THEME_TOKENS,
    });
  }

  // ----- Settings -----
  const settingsChildren = [
    ...addIf(hasPermission('users.view'), {
      label: t('sidebar.users'),
      link: '/app/users',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('roles.view'), {
      label: t('sidebar.roles'),
      link: '/app/roles',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('permissions.view'), {
      label: t('sidebar.permissions'),
      link: '/app/permissions',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('audit.view'), {
      label: t('sidebar.auditLogs'),
      link: '/app/audit',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('otp.view'), {
      label: t('sidebar.otpManagement'),
      link: '/app/otp',
      ...THEME_TOKENS,
    }),
    ...addIf(hasPermission('profile.view'), {
      label: t('sidebar.profile'),
      link: '/app/profile',
      ...THEME_TOKENS,
    }),
  ];

  if (settingsChildren.length > 0) {
    structure.push({
      id: 9,
      label: t('sidebar.settings'),
      link: '#',
      icon: <SettingsIcon />,
      children: settingsChildren,
      ...THEME_TOKENS,
    });
  }

  return structure;
}

export default getSidebarStructure;