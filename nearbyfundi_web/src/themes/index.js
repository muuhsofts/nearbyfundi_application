// src/themes/index.js
import { createTheme } from '@mui/material/styles';

import defaultTheme from './default';
import secondaryTheme from './secondary';
import successTheme from './success';
import darkTheme from './dark';

/* -----------------------------------------------------------
 *  Shared typography tokens
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
 *  Shared component overrides (MUI v5 styleOverrides)
 * ----------------------------------------------------------- */
const baseComponents = {
  MuiCssBaseline: {
    styleOverrides: {
      '*::-webkit-scrollbar': { width: '0.4em', height: '0.4em' },
      '*::-webkit-scrollbar-thumb': { backgroundColor: 'rgba(0,0,0,0.2)', borderRadius: 4 },
      '*::-webkit-scrollbar-track': { backgroundColor: 'transparent' },
      body: { margin: 0, padding: 0 },
    },
  },
  MuiCard: {
    styleOverrides: {
      root: {
        borderRadius: 12,
        boxShadow:
            '0px 3px 11px 0px #E8EAFC, 0 3px 3px -2px #B2B2B21A, 0 1px 8px 0 #9A9A9A1A',
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
        boxShadow:
            '0px 3px 11px 0px #E8EAFC, 0 3px 3px -2px #B2B2B21A, 0 1px 8px 0 #9A9A9A1A',
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
        borderBottom: '1px solid rgba(224, 224, 224, .5)',
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
        backgroundColor: '#12121A',
        borderRadius: 4,
      },
      '*::-webkit-scrollbar-track': { backgroundColor: 'transparent' },
      body: {
        margin: 0,
        padding: 0,
        backgroundColor: '#0F172A',
        color: '#F1F1F9',
      },
    },
  },
  MuiPaper: {
    styleOverrides: {
      root: {
        backgroundImage: 'none',
        backgroundColor: '#1A1A2E',
        boxShadow:
            '0px 1px 8px rgba(0, 0, 0, 0.103475), 0px 3px 3px rgba(0, 0, 0, 0.0988309), 0px 3px 4px rgba(0, 0, 0, 0.10301)',
      },
    },
  },
  MuiAppBar: {
    styleOverrides: {
      root: {
        backgroundColor: '#1A1A2E',
        backgroundImage: 'none',
        boxShadow: 'none',
      },
    },
  },
  MuiCard: {
    styleOverrides: {
      root: {
        backgroundColor: '#1A1A2E',
        backgroundImage: 'none',
        boxShadow:
            '0px 1px 8px rgba(0, 0, 0, 0.103475), 0px 3px 3px rgba(0, 0, 0, 0.0988309), 0px 3px 4px rgba(0, 0, 0, 0.10301)',
      },
    },
  },
  MuiTableCell: {
    styleOverrides: {
      root: { borderBottom: '1px solid rgba(255, 255, 255, 0.08)' },
      head: { color: '#B8B8D0', fontWeight: 700 },
      body: { color: '#F1F1F9' },
    },
  },
  MuiTableSortLabel: {
    styleOverrides: {
      root: {
        color: '#B8B8D0',
        '&.Mui-active': { color: '#F1F1F9' },
        '&:hover': { color: '#F1F1F9' },
      },
      icon: { color: '#B8B8D0 !important' },
    },
  },
  MuiTablePagination: {
    styleOverrides: {
      toolbar: { color: '#B8B8D0' },
      selectIcon: { color: '#B8B8D0' },
    },
  },
  MuiCheckbox: {
    styleOverrides: {
      root: { color: '#76767B' },
    },
  },
  MuiDivider: {
    styleOverrides: {
      root: { borderColor: 'rgba(255, 255, 255, 0.08)' },
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
        // Merge MuiCssBaseline styleOverrides (base + dark)
        MuiCssBaseline: {
          styleOverrides: {
            ...(baseComponents.MuiCssBaseline?.styleOverrides || {}),
            ...(isDark
                ? darkComponents.MuiCssBaseline?.styleOverrides || {}
                : {}),
          },
        },
      },
      shape: { borderRadius: 8 },
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