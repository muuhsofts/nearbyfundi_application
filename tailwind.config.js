/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        nf: {
          dark: "#002B49",
          primary: "#006B5E",
          primaryDark: "#004D3A",
          secondary: "#F5A623",
          accent: "#00A896",
          sea: "#004472",
          salat: "#21AE8C",
          black: "#13191D",
          border: "#E2E8F0",
          muted: "#8A8A8A"
        }
      },
      fontFamily: {
        nunito: ["Nunito", "ui-sans-serif", "system-ui", "sans-serif"]
      },
      boxShadow: {
        soft: "0 8px 30px rgba(19, 25, 29, 0.08)",
        card: "0 4px 12px rgba(19, 25, 29, 0.08)"
      },
      borderRadius: {
        nf: "16px"
      }
    }
  },
  plugins: []
};