/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./index.html", "./src/**/*.{js,jsx,gleam}"],
  theme: {
    extend: {
      colors: {
        faff: {
          50: "#FFECFC",
          100: "#FFD8F9",
          200: "#FFAFF3",
          300: "#FF77EB",
          400: "#FF3FE2",
          500: "#FF07DA",
          600: "#CE00AF",
          700: "#96007F",
          800: "#5D004F",
          900: "#250020",
        },
        charcoal: {
          50: "#C8C8C8",
          100: "#BEBEBE",
          200: "#A9A9A9",
          300: "#959595",
          400: "#818181",
          500: "#6C6C6C",
          600: "#585858",
          700: "#434343",
          800: "#2F2F2F",
          900: "#131313",
        },
        "unnamed-blue": {
          DEFAULT: "#A6F0FC",
          50: "#E1FAFE",
          100: "#CDF7FD",
          200: "#A6F0FC",
          300: "#70E7FA",
          400: "#39DEF8",
          500: "#08D1F2",
          600: "#06A2BB",
          700: "#047385",
          800: "#03444F",
          900: "#011518",
        },
        "gleam-white": "#fefefc",
        "gleam-black": "#1e1e1e",
        "gleam-blacker": "#151515",
      },
      keyframes: {
        bloop: {
          "0%": { transform: "scale(1)", background: "#FF77EB" },
          "50%": { transform: "scale(0.75)", background: "#FFAFF3" },
          "100%": { transform: "scale(1)", background: "#FF77EB" },
        },
      },
      animation: {
        bloop: "bloop 0.25s ease-in-out",
        bleep: "bloop 0.26s ease-in-out",
      },
    },
  },
  plugins: [],
};
