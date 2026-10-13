import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        blue: {
          950: '#0A1540',
          900: '#13225A',
          800: '#1B3180',
          pole: '#2448B8',
          pressed: '#2A45A3',
          300: '#93A2D3',
          100: '#E7ECFA',
        },
        red: {
          700: '#B3141C',
          600: '#C81E26',
          pole: '#D62828',
          400: '#FF5C62',
          300: '#FF8A8F',
          100: '#FBE0E1',
          50: '#FEF1F1',
        },
        ink: { DEFAULT: '#13225A', 2: '#4B5565', 3: '#5E6878' },
        line: { DEFAULT: '#DCE1EC', soft: '#E8ECF4' },
        bg: '#F4F6FB',
        surface: '#FFFFFF',
        switchOff: '#D4D8DF',
        onDark: { DEFAULT: '#CBD3EC', muted: '#A8B5DF' },
        vip: '#8A1016',
        info: { fg: '#1E4FB8', bg: '#E5EDFC' },
        success: { fg: '#16794A', bg: '#E3F4EA' },
        warning: { fg: '#A4520B', bg: '#FCEEDC' },
        danger: { fg: '#B42318', bg: '#FDE8E7' },
      },
      fontFamily: { sans: ['Cairo', 'system-ui', 'sans-serif'] },
      borderRadius: { badge: '8px', small: '10px', ctl: '12px', card: '16px', panel: '20px' },
      boxShadow: {
        card: '0 6px 20px rgba(19,34,90,0.08)',
        ring: '0 0 0 4px #FEF1F1',
      },
      fontSize: {
        display: ['32px', { lineHeight: '44px', fontWeight: '800' }],
        h1: ['24px', { lineHeight: '36px', fontWeight: '700' }],
        h2: ['20px', { lineHeight: '30px', fontWeight: '700' }],
        h3: ['17px', { lineHeight: '26px', fontWeight: '600' }],
        body: ['15px', { lineHeight: '24px' }],
        caption: ['13px', { lineHeight: '20px', fontWeight: '500' }],
        label: ['12px', { lineHeight: '18px', fontWeight: '700' }],
      },
    },
  },
  plugins: [],
};

export default config;
