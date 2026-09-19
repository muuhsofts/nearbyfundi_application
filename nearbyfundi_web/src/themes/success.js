// src/themes/success.js
import tinycolor from 'tinycolor2';

const primary = '#10B981';       // Emerald
const secondary = '#4ADE80';     // Mint
const warning = '#F59E0B';       // Amber
const success = '#10B981';       // Emerald
const info = '#8B5CF6';          // Violet

const lightenRate = 7.5;
const darkenRate = 15;

const successTheme = {
  palette: {
    mode: 'light',
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
      contrastText: '#FFFFFF',
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
      primary: '#1A1A2E',
      secondary: '#4A4A6A',
      disabled: '#8A8AA8',
      hint: '#8A8AA8',
    },
    background: {
      default: '#F8F9FF',
      paper: '#FFFFFF',
      light: '#F0F1FF',
    },
    divider: 'rgba(0, 0, 0, 0.08)',
    action: {
      active: '#4A4A6A',
      hover: 'rgba(16, 185, 129, 0.06)',
      selected: 'rgba(16, 185, 129, 0.12)',
      disabled: 'rgba(0, 0, 0, 0.3)',
      disabledBackground: 'rgba(0, 0, 0, 0.08)',
      focus: 'rgba(16, 185, 129, 0.16)',
    },
  },
  customShadows: {
    widget: '0px 3px 11px 0px #E8EAFC, 0 3px 3px -2px #B2B2B21A, 0 1px 8px 0 #9A9A9A1A',
    widgetDark: '0px 3px 18px 0px #4558A3B3, 0 3px 3px -2px #B2B2B21A, 0 1px 8px 0 #9A9A9A1A',
    widgetWide: '0px 12px 33px 0px #E8EAFC, 0 3px 3px -2px #B2B2B21A, 0 1px 8px 0 #9A9A9A1A',
  },
};

export default successTheme;