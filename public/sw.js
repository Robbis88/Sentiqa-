// Sentiqa service worker — tar imot web-push og viser varsler.
self.addEventListener('push', (event) => {
  let data = {}
  try {
    data = event.data.json()
  } catch {
    data = { tittel: 'Sentiqa', tekst: event.data ? event.data.text() : '' }
  }
  const tittel = data.tittel || 'Sentiqa'
  event.waitUntil(
    self.registration.showNotification(tittel, {
      body: data.tekst || '',
      icon: '/logo.png',
      badge: '/logo.png',
      data: { lenke: data.lenke || '/varsler' },
    }),
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const lenke = (event.notification.data && event.notification.data.lenke) || '/varsler'
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((wins) => {
      for (const w of wins) {
        if ('focus' in w) {
          w.navigate(lenke)
          return w.focus()
        }
      }
      if (clients.openWindow) return clients.openWindow(lenke)
    }),
  )
})
