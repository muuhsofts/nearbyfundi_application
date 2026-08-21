/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        bolt: {
          50: "#ecfdf5",
          100: "#d1fae5",
          400: "#34d399",
          500: "#20c997",
          600: "#12b886",
          700: "#0f9f73",
          900: "#064e3b"
        }
      },
      boxShadow: {
        soft: "0 18px 60px rgba(15, 23, 42, 0.10)",
        "soft-dark": "0 18px 60px rgba(0, 0, 0, 0.35)"
      }
    }
  },
  plugins: []
};
