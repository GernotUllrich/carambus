// See the Tailwind default theme values here:
// https://github.com/tailwindcss/tailwindcss/blob/master/stubs/defaultConfig.stub.js
//TEST
const colors = require('tailwindcss/colors')
const defaultTheme = require('tailwindcss/defaultTheme')

/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  mode: 'jit',
  plugins: [],

  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],

  // All the default values will be compiled unless they are overridden below
  theme: {
    // Extend (add to) the default theme in the `extend` key
    extend: {
      // Create your own at: https://javisperez.github.io/tailwindcolorshades
      colors: {
        primary: colors.blue,
        secondary: colors.emerald,
        tertiary: colors.gray,
        danger: colors.red,
        colors: {
          'neon-yellow': '#FFFF09',
        },
        gray: colors.neutral,
        "code-400": "#fefcf9",
        "code-600": "#3c455b",
      },
      fontFamily: {
        // Use system fonts for instant loading (0ms) instead of external Inter font (40+ seconds)
        sans: [
          'system-ui',
          '-apple-system',
          'BlinkMacSystemFont',
          'Segoe UI',
          'Roboto',
          'Helvetica Neue',
          'Arial',
          'sans-serif',
        ],
      },
    },
  },

  // Opt-in to TailwindCSS future changes
  future: {
  },
}
