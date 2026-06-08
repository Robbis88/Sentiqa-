'use client'
import { useEffect, useState } from 'react'
import { lagrePushAbonnement, fjernPushAbonnement } from './push-handlinger'

const VAPID = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY

function urlBase64ToUint8Array(base64: string): Uint8Array {
  const padding = '='.repeat((4 - (base64.length % 4)) % 4)
  const b64 = (base64 + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = atob(b64)
  const arr = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i)
  return arr
}

export function PushTilmelding() {
  const [stotte, setStotte] = useState(false)
  const [pa, setPa] = useState(false)
  const [jobber, setJobber] = useState(false)

  useEffect(() => {
    if (!('serviceWorker' in navigator) || !('PushManager' in window) || !VAPID) return
    let avbrutt = false
    navigator.serviceWorker
      .register('/sw.js')
      .then((reg) => reg.pushManager.getSubscription())
      .then((sub) => {
        if (avbrutt) return
        setStotte(true)
        setPa(Boolean(sub))
      })
      .catch(() => {
        if (!avbrutt) setStotte(true)
      })
    return () => {
      avbrutt = true
    }
  }, [])

  if (!stotte) return null

  async function slaaPaa() {
    setJobber(true)
    try {
      const perm = await Notification.requestPermission()
      if (perm === 'granted') {
        const reg = await navigator.serviceWorker.ready
        const sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(VAPID as string) as BufferSource,
        })
        const json = sub.toJSON()
        await lagrePushAbonnement({ endpoint: sub.endpoint, p256dh: json.keys!.p256dh, auth: json.keys!.auth })
        setPa(true)
      }
    } catch {
      // ignorer
    }
    setJobber(false)
  }

  async function slaaAv() {
    setJobber(true)
    try {
      const reg = await navigator.serviceWorker.ready
      const sub = await reg.pushManager.getSubscription()
      if (sub) {
        await fjernPushAbonnement(sub.endpoint)
        await sub.unsubscribe()
      }
      setPa(false)
    } catch {
      // ignorer
    }
    setJobber(false)
  }

  return (
    <div className="push-til">
      {pa ? (
        <button type="button" className="liten" onClick={slaaAv} disabled={jobber}>Skru av push på denne enheten</button>
      ) : (
        <button type="button" className="liten" onClick={slaaPaa} disabled={jobber}>🔔 Slå på push-varsler her</button>
      )}
    </div>
  )
}
