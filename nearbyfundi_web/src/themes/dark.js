import tinycolor from 'tinycolor2';

const primary = '#818CF8';
const secondary = '#F472B6';
const warning = '#FBBF24';
const success = '#34D399';
const info = '#A78BFA';

const lightenRate = 7.5;
const darkenRate = 15;

const darkTheme = {
  palette: {
    contrastText: '#fff',
    mode: 'dark',
    primary: {
      main: primary,
      light: tinycolor(primary).lighten(lightenRate).toHexString(),
      dark: tinycolor(primary).darken(darkenRate).toHexString(),
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
    },
    success: {
      main: success,
      light: tinycolor(success).lighten(lightenRate).toHexString(),
      dark: tinycolor(success).darken(darkenRate).toHexString(),
    },
    info: {
      main: info,
      light: tinycolor(info).lighten(lightenRate).toHexString(),
      dark: tinycolor(info).darken(darkenRate).toHexString(),
    },
    text: {
      primary: '#F1F1F9',
      secondary: '#B8B8D0',
      hint: '#7A7A9E',
    },
    background: {
      default: '#0F0F1A',
      light: '#1A1A2E',
    },
  },
  customShadows: {
    widget: '0px 1px 8px rgba(0, 0, 0, 0.103475), 0px 3px 3px rgba(0, 0, 0, 0.0988309), 0px 3px 4px rgba(0, 0, 0, 0.10301)',
  },
};

export default darkTheme;