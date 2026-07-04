// See the Tailwind default theme values here:
// https://github.com/tailwindcss/tailwindcss/blob/master/stubs/defaultConfig.stub.js
//TEST
const colors = require('tailwindcss/colors')
const defaultTheme = require('tailwindcss/defaultTheme')

// ─────────────────────────────────────────────────────────────────────────────
// Design-Token Single-Source — Richtung A (helle SaaS-Ästhetik, ruhiger Teal-
// Akzent, warmes Neutralgrau). Alle UI-Farben werden hier abgeleitet; hart
// kodierte Hex-Codes in Views/CSS werden schrittweise auf diese Token gezogen.
// Anker-Werte aus den Redesign-Mockups (2026-07-01):
//   Accent/Primary #0f5f56  ·  Text primary #26251f  ·  Border default #e2ded4
// ─────────────────────────────────────────────────────────────────────────────

// Primary/Accent — ruhiger Teal-Grün-Ton. Ramp so verankert, dass 600 = #0f5f56
// (Button-Grundfläche); 50/100 sind die Accent-Tint-Backgrounds aus den Mockups.
const primary = {
  50: '#eef6f4',
  100: '#e7f0ee',
  200: '#c5ddd8',
  300: '#9bc4bc',
  400: '#5b9b8f',
  500: '#1f7a6d',
  600: '#0f5f56', // Anker: Accent
  700: '#0c4d45',
  800: '#0a3e38',
  900: '#08322e',
  950: '#041d1a',
}

// Warmes Neutralgrau — ersetzt das kühle Tailwind-neutral als App-weites `gray`.
// Deckt zugleich Text- und Border-Token ab (Single-Source statt Extra-Aliase):
//   Text  primary #26251f=900 · secondary #57534e=600 · muted #8a857a=500 · faint #b0aba0=400
//   Border default #e2ded4=200 · content #faf9f6=50 · sidebar #f3f1ea=100
const warmGray = {
  50: '#faf9f6',
  100: '#f3f1ea',
  200: '#e2ded4',
  300: '#cdc7b9',
  400: '#b0aba0',
  500: '#8a857a',
  600: '#57534e',
  700: '#423f39',
  800: '#302e28',
  900: '#26251f',
  950: '#17160f',
}

/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  mode: 'jit',
  plugins: [require('@tailwindcss/typography')],

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
        primary,
        secondary: colors.emerald,
        tertiary: colors.gray,
        danger: colors.red,
        // Semantische Status-Tokens (Phase 7) — volle Ramps für alle Shades
        success: colors.emerald, // Anker #10b981 = emerald-500
        warning: colors.amber,   // Anker #f59e0b = amber-500, #fbbf24 = amber-400
        info: colors.blue,       // info/brand-Blau-Fälle
        colors: {
          'neon-yellow': '#FFFF09',
        },
        // App-weites Grau = warmes Neutral (Surfaces, Text, Borders leiten hieraus ab)
        gray: warmGray,
        "code-400": "#fefcf9",
        "code-600": "#3c455b",

        // Semantische Surface-Backgrounds, die nicht exakt auf der Grau-Ramp sitzen
        surface: {
          page: '#eceae5',
          content: '#faf9f6',
          card: '#ffffff',
          sidebar: '#f3f1ea',
          panel: '#faf9f6',
        },

        // Disziplin-Chips (Hintergrund/Vordergrund je Familie)
        discipline: {
          'dreiband-bg': '#eaf2ff', 'dreiband-fg': '#1e498c',
          'snooker-bg': '#e9f7ee', 'snooker-fg': '#1c6b3f',
          'pool-bg': '#fdeede', 'pool-fg': '#8a5a12',
          'karambol-bg': '#efeafd', 'karambol-fg': '#4b3a8c',
        },
      },
      borderRadius: {
        control: '8px', // Buttons, Inputs, Controls
        card: '12px',   // Karten/Panels
        pill: '20px',   // Chips/Pills
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
