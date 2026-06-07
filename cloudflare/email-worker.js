// Cloudflare Email Worker for Sentiqa e-post-inntak (§6).
// Tar imot e-post sendt til *@sentiqa.ai, henter ut vedleggene, og POSTer dem
// som JSON til webhooken /api/epost-inntak (samme format som Postmark inbound).
//
// Oppsett i Cloudflare-dashbordet:
//   Email → Email Routing → Email Workers → Create → lim inn denne koden.
//   postal-mime legges til automatisk når du lagrer (import nedenfor).
//   Variabler (Settings → Variables):
//     WEBHOOK_URL    = https://sentiqa.ai/api/epost-inntak
//     INNTAK_SECRET  = <samme som EPOST_INNTAK_SECRET i appen> (marker som Secret)
//   Til slutt: Email Routing → Routing rules → Catch-all → Send to a Worker → denne.

import PostalMime from 'postal-mime'

export default {
  async email(message, env) {
    const epost = await PostalMime.parse(message.raw)

    const vedlegg = (epost.attachments || []).map((a) => ({
      Name: a.filename || 'vedlegg',
      ContentType: a.mimeType || 'application/octet-stream',
      Content: tilBase64(a.content),
    }))

    const res = await fetch(env.WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-inntak-secret': env.INNTAK_SECRET,
      },
      body: JSON.stringify({
        To: message.to,
        From: message.from,
        Attachments: vedlegg,
      }),
    })

    // Kast ved feil så Cloudflare prøver igjen / varsler.
    if (!res.ok) throw new Error(`Webhook svarte ${res.status}`)
  },
}

function tilBase64(data) {
  if (typeof data === 'string') return btoa(unescape(encodeURIComponent(data)))
  const bytes = new Uint8Array(data)
  let bin = ''
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i])
  return btoa(bin)
}
