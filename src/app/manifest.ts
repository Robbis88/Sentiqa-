import type { MetadataRoute } from 'next'

// PWA-manifest (§ App & distribusjon). Gjør Sentiqa installerbar på hjem-skjerm
// — riktig løsning for nettbrettet i butikken (ingen App Store-kø).
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Sentiqa',
    short_name: 'Sentiqa',
    description: 'AI-drevet drift, analyse og assistanse for servicehandelen.',
    start_url: '/oversikt',
    display: 'standalone',
    background_color: '#0a0f1f',
    theme_color: '#0a0f1f',
    lang: 'nb',
    icons: [
      { src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  }
}
