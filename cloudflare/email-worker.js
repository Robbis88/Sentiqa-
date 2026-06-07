// Cloudflare Email Worker for Sentiqa e-post-inntak (§6).
// Helt avhengighetsfri — videresender den rå e-posten til webhooken, som
// tolker MIME/vedlegg på serversiden. Trygt å lime rett inn i dashbordet.
//
// Variabler (Worker → Settings → Variables and Secrets):
//   WEBHOOK_URL    = https://sentiqa.ai/api/epost-inntak
//   INNTAK_SECRET  = <samme som EPOST_INNTAK_SECRET i appen>  (type: Secret)
//
// Til slutt: Email Routing → Routing rules → Catch-all → Send to a Worker → denne.

export default {
  async email(message, env) {
    const raw = await new Response(message.raw).arrayBuffer()

    const res = await fetch(env.WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'content-type': 'message/rfc822',
        'x-inntak-secret': env.INNTAK_SECRET,
        'x-mail-to': message.to,
        'x-mail-from': message.from,
      },
      body: raw,
    })

    // Kast ved feil så Cloudflare prøver igjen / varsler.
    if (!res.ok) throw new Error(`Webhook svarte ${res.status}`)
  },
}
