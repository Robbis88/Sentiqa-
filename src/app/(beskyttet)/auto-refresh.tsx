'use client'
import { useRouter } from 'next/navigation'
import { useEffect } from 'react'

// Henter ferske data jevnlig + når fanen blir aktiv igjen — ingen refresh-knapp.
export function AutoRefresh({ sekunder = 30 }: { sekunder?: number }) {
  const router = useRouter()
  useEffect(() => {
    const id = setInterval(() => router.refresh(), sekunder * 1000)
    const naarSynlig = () => {
      if (document.visibilityState === 'visible') router.refresh()
    }
    document.addEventListener('visibilitychange', naarSynlig)
    return () => {
      clearInterval(id)
      document.removeEventListener('visibilitychange', naarSynlig)
    }
  }, [router, sekunder])
  return null
}
