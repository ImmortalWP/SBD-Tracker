/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        sl: {
          bg: '#0a0a0a',
          surface: '#141414',
          card: '#1a1a1a',
          cardHover: '#1f1f1f',
          border: '#2a2a2a',
          borderLight: '#333333',
          text: '#ffffff',
          textSecondary: '#a0a0a0',
          textMuted: '#666666',
          green: '#4CAF50',
          greenDark: '#388E3C',
          greenLight: '#66BB6A',
          greenGlow: '#4CAF5033',
          red: '#EF5350',
          redGlow: '#EF535022',
          amber: '#FFB74D',
          blue: '#42A5F5',
          purple: '#AB47BC',
          cyan: '#26C6DA',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['JetBrains Mono', 'Fira Code', 'monospace'],
      },
      boxShadow: {
        'card': '0 1px 3px rgba(0,0,0,0.4)',
        'cardHover': '0 8px 25px rgba(0,0,0,0.5)',
        'glow': '0 0 20px rgba(76, 175, 80, 0.15)',
        'glowStrong': '0 0 30px rgba(76, 175, 80, 0.25)',
      },
      animation: {
        'fade-in': 'fadeIn 0.25s ease-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'slide-down': 'slideDown 0.3s ease-out',
        'scale-in': 'scaleIn 0.2s ease-out',
        'pulse-green': 'pulseGreen 2s infinite',
        'bounce-in': 'bounceIn 0.4s cubic-bezier(0.68, -0.55, 0.27, 1.55)',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(16px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        slideDown: {
          '0%': { opacity: '0', transform: 'translateY(-16px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.9)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
        pulseGreen: {
          '0%, 100%': { boxShadow: '0 0 0 0 rgba(76, 175, 80, 0.4)' },
          '50%': { boxShadow: '0 0 0 8px rgba(76, 175, 80, 0)' },
        },
        bounceIn: {
          '0%': { transform: 'scale(0)', opacity: '0' },
          '50%': { transform: 'scale(1.1)' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
      },
    },
  },
  plugins: [],
}
