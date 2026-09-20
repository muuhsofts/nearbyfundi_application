import tinycolor from 'tinycolor2';

const primary = '#075E54';
const secondary = '#F5A623';
const success = '#21AE8C';
const accent = '#00A896';

const lightenRate = 7.5;
const darkenRate = 15;

const darkTheme = {
  palette: {
    mode: 'dark',
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
      primary: '#F0F0F5',
      secondary: '#9A9AAF',
      disabled: '#6B6B80',
      hint: '#9A9AAF',
    },
    background: {
      default: '#0A0A0F',
      paper: '#1A1A24',
      light: '#2A2A3A',
    },
    divider: '#2A2A3A',
    action: {
      active: '#9A9AAF',
      hover: 'rgba(255, 255, 255, 0.06)',
      selected: 'rgba(7, 94, 84, 0.18)',
      disabled: 'rgba(255, 255, 255, 0.3)',
      disabledBackground: 'rgba(255, 255, 255, 0.12)',
      focus: 'rgba(7, 94, 84, 0.20)',
    },
  },
  customShadows: {
    widget: '0px 1px 4px rgba(0, 0, 0, 0.25)',
  },
};

export default darkTheme;