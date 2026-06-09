'use client'
import { useEffect } from 'react'

// Registrerer service worker app-bredt så appen blir installerbar (PWA).
export function RegistrerSW() {
  useEffect(() => {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => {})
    }
  }, [])
  return null
}
