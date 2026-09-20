import tinycolor from 'tinycolor2';

const primary = '#075E54';
const secondary = '#F5A623';
const success = '#21AE8C';
const accent = '#00A896';

const lightenRate = 7.5;
const darkenRate = 15;

const defaultTheme = {
  palette: {
    mode: 'light',
    primary: {
      main: primary,
      light: '#0A8A6D',
      dark: '#054A44',
      contrastText: '#FFFFFF',
    },
    secondary: {
      main: secondary,
      light: tinycolor(secondary).lighten(lightenRate).toHexString(),
      dark: tinycolor(secondary).darken(darkenRate).toHexString(),
      contrastText: '#FFFFFF',
    },
    success: {
      main: success,
      light: tinycolor(success).lighten(lightenRate).toHexString(),
      dark: tinycolor(success).darken(darkenRate).toHexString(),
      contrastText: '#FFFFFF',
    },
    info: {
      main: accent,
      light: tinycolor(accent).lighten(lightenRate).toHexString(),
      dark: tinycolor(accent).darken(darkenRate).toHexString(),
      contrastText: '#FFFFFF',
    },
    warning: {
      main: secondary,
      light: tinycolor(secondary).lighten(lightenRate).toHexString(),
      dark: tinycolor(secondary).darken(darkenRate).toHexString(),
      contrastText: '#FFFFFF',
    },
    error: {
      main: '#EF4444',
      light: '#F87171',
      dark: '#B91C1C',
      contrastText: '#FFFFFF',
    },
    text: {
      primary: '#13191D',
      secondary: '#6B7A8A',
      disabled: '#9AA5B1',
      hint: '#6B7A8A',
    },
    background: {
      default: '#F8F9FA',
      paper: '#FFFFFF',
      light: '#F0F2F5',
    },
    divider: '#E8ECF0',
    action: {
      active: '#6B7A8A',
      hover: 'rgba(7, 94, 84, 0.06)',
      selected: 'rgba(7, 94, 84, 0.12)',
      disabled: 'rgba(0, 0, 0, 0.3)',
      disabledBackground: 'rgba(0, 0, 0, 0.08)',
      focus: 'rgba(7, 94, 84, 0.16)',
    },
  },
  customShadows: {
    widget: '0px 2px 8px rgba(0, 0, 0, 0.04)',
  },
};

export default defaultTheme;