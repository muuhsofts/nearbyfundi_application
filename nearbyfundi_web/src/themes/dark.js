// src/themes/dark.js
import tinycolor from 'tinycolor2';

// Brand palette
const primary = '#0d7377';       // Deep Teal / Forest Green
const secondary = '#1E4D4F';     // Mint / Vibrant Green
const success = '#10B981';       // Emerald
const info = '#8B5CF6';          // Violet
const warning = '#F59E0B';       // Amber (warning is actually warning)

const lightenRate = 7.5;
const darkenRate = 15;

const darkTheme = {
  palette: {
    mode: 'dark', // ✅ Proper MUI v5 mode
    contrastText: '#fff',
    primary: {
      main: primary,
      light: tinycolor(primary).lighten(lightenRate).toHexString(),
      dark: tinycolor(primary).darken(darkenRate).toHexString(),
      contrastText: '#fff',
    },
    secondary: {
      main: secondary,
      light: tinycolor(secondary).lighten(lightenRate).toHexString(),
      dark: tinycolor(secondary).darken(darkenRate).toHexString(),
      contrastText: '#fff',
    },
    warning: {
      main: warning,
      light: tinycolor(warning).lighten(lightenRate).toHexString(),
      dark: tinycolor(warning).darken(darkenRate).toHexString(),
      contrastText: '#fff',
    },
    success: {
      main: success,
      light: tinycolor(success).lighten(lightenRate).toHexString(),
      dark: tinycolor(success).darken(darkenRate).toHexString(),
      contrastText: '#fff',
    },
    info: {
      main: info,
      light: tinycolor(info).lighten(lightenRate).toHexString(),
      dark: tinycolor(info).darken(darkenRate).toHexString(),
      contrastText: '#fff',
    },
    error: {
      main: '#EF4444',
      light: '#F87171',
      dark: '#B91C1C',
      contrastText: '#fff',
    },
    text: {
      primary: '#F1F1F9',
      secondary: '#B8B8D0',
      disabled: '#7A7A9E',
      hint: '#7A7A9E',
    },
    background: {
      default: '#0F172A', // ✅ Your desired clean dark navy
      paper: '#1A1A2E',    // ✅ Card/Paper background
      light: '#1A1A2E',    // Legacy alias
    },
    divider: 'rgba(255, 255, 255, 0.08)',
    action: {
      active: '#B8B8D0',
      hover: 'rgba(255, 255, 255, 0.06)',
      selected: 'rgba(13, 115, 119, 0.18)', // Tint of primary
      disabled: 'rgba(255, 255, 255, 0.3)',
      disabledBackground: 'rgba(255, 255, 255, 0.12)',
      focus: 'rgba(13, 115, 119, 0.20)',
    },
  },
  customShadows: {
    widget:
        '0px 1px 8px rgba(0, 0, 0, 0.103475), 0px 3px 3px rgba(0, 0, 0, 0.0988309), 0px 3px 4px rgba(0, 0, 0, 0.10301)',
  },
};

export default darkTheme;