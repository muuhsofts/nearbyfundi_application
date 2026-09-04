// src/config.js
const baseURLApi = "http://192.168.43.116:8000/api";
const redirectUrl = typeof window !== "undefined"
    ? window.location.origin
    : "https://yourdomain.com";

const appConfig = {
  baseURLApi,
  redirectUrl,
  remote: "https://sing-generator-node.flatlogic.com",
  auth: {
    email: 'admin@example.com',
    password: 'password',
  },
  app: {
    colors: {
      dark: '#002B49',      // Dark navy - for headers, footers, dark elements
      light: '#FFFFFF',     // White - for backgrounds, cards
      sea: '#004472',       // Deep blue - for primary buttons, links
      sky: '#E9EBEF',       // Light gray - for page backgrounds
      wave: '#D1E7F6',      // Light blue - for highlights, badges
      rain: '#CCDDE9',      // Muted blue - for borders, dividers
      middle: '#D7DFE6',    // Medium gray - for secondary backgrounds
      black: '#13191D',     // Almost black - for text
      salat: '#21AE8C',     // Green - for success, accepted, verified
    },
  },
};

export default appConfig;