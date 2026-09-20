import tinycolor from 'tinycolor2';

const primary = '#21AE8C';
const secondary = '#00A896';
const warning = '#F5A623';
const success = '#21AE8C';
const info = '#00A896';

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
      hover: 'rgba(33, 174, 140, 0.06)',
      selected: 'rgba(33, 174, 140, 0.12)',
      disabled: 'rgba(0, 0, 0, 0.3)',
      disabledBackground: 'rgba(0, 0, 0, 0.08)',
      focus: 'rgba(33, 174, 140, 0.16)',
    },
  },
  customShadows: {
    widget: '0px 2px 8px rgba(0, 0, 0, 0.04)',
  },
};

export default successTheme;