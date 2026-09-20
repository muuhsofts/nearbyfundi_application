import { createTheme } from '@mui/material/styles';

import defaultTheme from './default';
import secondaryTheme from './secondary';
import successTheme from './success';
import darkTheme from './dark';

/* -----------------------------------------------------------
 *  Shared typography
 * ----------------------------------------------------------- */
const typography = {
  fontFamily: [
    'Inter',
    '-apple-system',
    'BlinkMacSystemFont',
    '"Segoe UI"',
    'Roboto',
    '"Helvetica Neue"',
    'Arial',
    'sans-serif',
  ].join(','),
  h1: { fontSize: '3rem', fontWeight: 700 },
  h2: { fontSize: '2rem', fontWeight: 700 },
  h3: { fontSize: '1.64rem', fontWeight: 700 },
  h4: { fontSize: '1.5rem', fontWeight: 700 },
  h5: { fontSize: '1.285rem', fontWeight: 700 },
  h6: { fontSize: '1.142rem', fontWeight: 700 },
  button: { textTransform: 'none', fontWeight: 600 },
};

/* -----------------------------------------------------------
 *  Shared component overrides (Light)
 * ----------------------------------------------------------- */
const baseComponents = {
  MuiCssBaseline: {
    styleOverrides: {
      '*::-webkit-scrollbar': { width: '0.4em', height: '0.4em' },
      '*::-webkit-scrollbar-thumb': {
        backgroundColor: 'rgba(0,0,0,0.15)',
        borderRadius: 4,
      },
      '*::-webkit-scrollbar-track': { backgroundColor: 'transparent' },
      body: { margin: 0, padding: 0 },
    },
  },
  MuiCard: {
    styleOverrides: {
      root: {
        borderRadius: 12,
        boxShadow: '0px 2px 8px rgba(0, 0, 0, 0.04)',
        border: '1px solid #E8ECF0',
      },
    },
  },
  MuiPaper: {
    styleOverrides: {
      root: { backgroundImage: 'none' },
    },
  },
  MuiBackdrop: {
    styleOverrides: {
      root: { backgroundColor: 'rgba(74, 74, 74, 0.35)' },
    },
  },
  MuiMenu: {
    styleOverrides: {
      paper: {
        boxShadow: '0px 2px 8px rgba(0, 0, 0, 0.06)',
        border: '1px solid #E8ECF0',
      },
    },
  },
  MuiSelect: {
    styleOverrides: {
      icon: { color: '#B9B9B9' },
    },
  },
  MuiTableCell: {
    styleOverrides: {
      root: {
        borderBottom: '1px solid #E8ECF0',
        padding: '14px 24px',
      },
      head: { fontSize: '0.95rem', fontWeight: 700 },
      body: { fontSize: '0.95rem' },
    },
  },
  MuiTableRow: {
    styleOverrides: {
      root: { height: 56 },
    },
  },
  MuiButton: {
    styleOverrides: {
      root: { boxShadow: 'none' },
    },
  },
};

/* -----------------------------------------------------------
 *  Dark mode specific overrides
 * ----------------------------------------------------------- */
const darkComponents = {
  MuiCssBaseline: {
    styleOverrides: {
      '*::-webkit-scrollbar': { width: '0.4em', height: '0.4em' },
      '*::-webkit-scrollbar-thumb': {
        backgroundColor: '#2A2A3A',
        borderRadius: 4,
      },
      '*::-webkit-scrollbar-track': { backgroundColor: 'transparent' },
      body: {
        margin: 0,
        padding: 0,
        backgroundColor: '#0A0A0F',
        color: '#F0F0F5',
      },
    },
  },
  MuiPaper: {
    styleOverrides: {
      root: {
        backgroundImage: 'none',
        backgroundColor: '#1A1A24',
        boxShadow: 'none',
        border: '1px solid #2A2A3A',
      },
    },
  },
  MuiAppBar: {
    styleOverrides: {
      root: {
        backgroundColor: '#1A1A24',
        backgroundImage: 'none',
        boxShadow: 'none',
        borderBottom: '1px solid #2A2A3A',
      },
    },
  },
  MuiCard: {
    styleOverrides: {
      root: {
        backgroundColor: '#1A1A24',
        backgroundImage: 'none',
        boxShadow: 'none',
        border: '1px solid #2A2A3A',
      },
    },
  },
  MuiTableCell: {
    styleOverrides: {
      root: { borderBottom: '1px solid #2A2A3A' },
      head: { color: '#9A9AAF', fontWeight: 700 },
      body: { color: '#F0F0F5' },
    },
  },
  MuiTableSortLabel: {
    styleOverrides: {
      root: {
        color: '#9A9AAF',
        '&.Mui-active': { color: '#F0F0F5' },
        '&:hover': { color: '#F0F0F5' },
      },
      icon: { color: '#9A9AAF !important' },
    },
  },
  MuiTablePagination: {
    styleOverrides: {
      toolbar: { color: '#9A9AAF' },
      selectIcon: { color: '#9A9AAF' },
    },
  },
  MuiCheckbox: {
    styleOverrides: {
      root: { color: '#76767B' },
    },
  },
  MuiDivider: {
    styleOverrides: {
      root: { borderColor: '#2A2A3A' },
    },
  },
};

/* -----------------------------------------------------------
 *  Theme factory
 * ----------------------------------------------------------- */
const buildTheme = (themeConfig, isDark = false) =>
    createTheme({
      ...themeConfig,
      typography: {
        ...typography,
        ...(themeConfig.typography || {}),
      },
      components: {
        ...baseComponents,
        ...(isDark ? darkComponents : {}),
        MuiCssBaseline: {
          styleOverrides: {
            ...(baseComponents.MuiCssBaseline?.styleOverrides || {}),
            ...(isDark
                ? darkComponents.MuiCssBaseline?.styleOverrides || {}
                : {}),
          },
        },
      },
      shape: { borderRadius: 12 },
    });

/* -----------------------------------------------------------
 *  Export themes
 * ----------------------------------------------------------- */
const themes = {
  default: buildTheme(defaultTheme, false),
  secondary: buildTheme(secondaryTheme, false),
  success: buildTheme(successTheme, false),
  dark: buildTheme(darkTheme, true),
};

export default themes;