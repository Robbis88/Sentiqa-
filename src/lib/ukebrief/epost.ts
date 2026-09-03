import type { Rangert, Ukebrief } from './type'

// =====================================================================
// Ukebriefen som e-post.
//
// HEX-FARGER OG INLINE-STILER ER MED VILJE HER, og fila staar derfor i
// UNNTAK i `farger.ts`. E-postklienter stoetter ikke CSS-variabler,
// eksterne stilark eller `<style>` i noen paalitelig form — Outlook
// stripper det siste. Alt maa staa paa elementet.
//
// Fargene er kopiert fra `globals.css` og skal foelge den. Endres
// `--primaer` der, skal den endres her — det er den prisen e-post
// koster, og den betales bevisst i én fil framfor aa spres.
//
// MOBIL FOERST. En butikksjef leser dette paa telefonen mandag morgen,
// mellom to andre ting. Én spalte, ingen tabelloppsett med kolonner,
// store nok trykkflater, og det viktigste over folden: hva gjoer jeg i dag.
//
// Ren funksjon. Ingen nettverk, ingen klokke — samme brief gir samme
// e-post, og innholdet kan derfor sammenlignes i en test.
// =====================================================================

const F = {
  bg: '#f8fafc',
  kort: '#ffffff',
  tekst: '#0f1720',
  svak: '#64748b',
  kant: '#e2e8f0',
  primaer: '#2e7d6b',
  primaerSvak: '#e6f2ef',
  gronn: '#1f6152',
  gul: '#7a5321',
} as const

const SKRIFT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"

/** Ordene er de samme som paa skjermen. Et brev som kaller det noe annet
    enn siden gjoer, laerer leseren to vokabular for samme sak. */
const GRUNNLAG: Record<Rangert['grunnlag'], { navn: string; farge: string }> = {
  fakta: { navn: 'Fakta', farge: F.gronn },
  indikasjon: { navn: 'Sterk indikasjon', farge: F.primaer },
  hypotese: { navn: 'Mulig forklaring', farge: F.gul },
  mangler_data: { navn: 'Ikke nok data', farge: F.svak },
}

/**
 * HTML-escaping.
 *
 * Varenavn og avdelingsnavn kommer fra kjedens egne filer og har
 * allerede inneholdt `&` og `<`. Uten dette blir brevet oedelagt av en
 * vare som heter «Pepsi & Max» — og i verste fall av noe verre.
 */
function e(s: string): string {
  return s
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;')
}

function funnHtml(s: Rangert, basisUrl: string): string {
  const g = GRUNNLAG[s.grunnlag]
  return `
    <tr><td style="padding:16px 0;border-top:1px solid ${F.kant};">
      <div style="font-size:16px;font-weight:600;color:${F.tekst};">${e(s.tittel)}${
        s.endring ? `<span style="float:right;font-weight:400;color:${F.svak};">${e(s.endring)}</span>` : ''
      }</div>
      <div style="font-size:15px;line-height:1.55;color:${F.svak};margin-top:6px;">${e(s.detalj)}</div>
      <div style="margin-top:10px;font-size:12px;">
        <span style="border:1px solid ${g.farge};color:${g.farge};border-radius:4px;padding:2px 7px;">${g.navn}</span>
        <a href="${basisUrl}${e(s.lenke)}" style="color:${F.primaer};text-decoration:none;margin-left:10px;">Se tallene &rarr;</a>
      </div>
    </td></tr>`
}

function seksjon(tittel: string, innhold: string): string {
  if (!innhold) return ''
  return `
    <tr><td style="padding:26px 0 0;">
      <div style="font-size:12px;letter-spacing:0.06em;text-transform:uppercase;color:${F.svak};">${e(tittel)}</div>
    </td></tr>
    ${innhold}`
}

export type Epost = { emne: string; html: string; tekst: string }

export function tilEpost(brief: Ukebrief, basisUrl: string): Epost {
  const emne = `Uke ${brief.ukenummer} — ${brief.overskrift}`

  const handlinger = brief.handlinger.length === 0 ? '' : `
    <tr><td style="padding:22px 0 0;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
             style="background:${F.primaerSvak};border-radius:10px;">
        <tr><td style="padding:16px 18px;">
          <div style="font-size:12px;letter-spacing:0.06em;text-transform:uppercase;color:${F.primaer};">Dette ville jeg tatt tak i</div>
          <ol style="margin:10px 0 0;padding-left:20px;color:${F.tekst};font-size:15px;line-height:1.6;">
            ${brief.handlinger.map((h) => `<li style="margin-bottom:8px;">${e(h.tekst)}</li>`).join('')}
          </ol>
        </td></tr>
      </table>
    </td></tr>`

  const ikkeVet = brief.viIkkeVet.length === 0 ? '' : `
    <tr><td style="padding:26px 0 0;border-top:1px solid ${F.kant};">
      <div style="font-size:12px;letter-spacing:0.06em;text-transform:uppercase;color:${F.svak};">Dette vet vi ikke</div>
      <ul style="margin:8px 0 0;padding-left:20px;color:${F.svak};font-size:13px;line-height:1.55;">
        ${brief.viIkkeVet.map((t) => `<li style="margin-bottom:4px;">${e(t)}</li>`).join('')}
      </ul>
    </td></tr>`

  const html = `<!doctype html>
<html lang="nb"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${e(emne)}</title>
</head>
<body style="margin:0;padding:0;background:${F.bg};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${e(brief.ingress)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${F.bg};">
<tr><td align="center" style="padding:24px 12px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
         style="max-width:560px;background:${F.kort};border:1px solid ${F.kant};border-radius:14px;font-family:${SKRIFT};">
    <tr><td style="padding:26px 22px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr><td>
          <div style="font-size:13px;color:${F.svak};">Uke ${brief.ukenummer} &middot; ${e(brief.stasjonNavn)}</div>
          <h1 style="margin:6px 0 10px;font-size:22px;line-height:1.25;color:${F.tekst};font-weight:700;">${e(brief.overskrift)}</h1>
          <div style="font-size:16px;line-height:1.6;color:${F.tekst};">${e(brief.ingress)}</div>
        </td></tr>
        ${handlinger}
        ${seksjon('Trenger oppmerksomhet', brief.oppmerksomhet.map((s) => funnHtml(s, basisUrl)).join(''))}
        ${seksjon('Dette gikk bra', brief.bra.map((s) => funnHtml(s, basisUrl)).join(''))}
        ${ikkeVet}
        <tr><td style="padding:26px 0 0;">
          <a href="${basisUrl}/oversikt"
             style="display:block;text-align:center;background:${F.primaer};color:#ffffff;text-decoration:none;
                    padding:13px 20px;border-radius:9px;font-size:15px;font-weight:600;">Åpne Sentiqa</a>
        </td></tr>
      </table>
    </td></tr>
  </table>
  <div style="max-width:560px;margin:14px auto 0;font-family:${SKRIFT};font-size:12px;color:${F.svak};text-align:center;">
    Sendt automatisk av Sentiqa. Tallene er hentet fra din egen stasjon.
  </div>
</td></tr>
</table>
</body></html>`

  // Ren tekst er ikke en formalitet: den leses av skjermlesere, av
  // klienter satt til aa foretrekke tekst, og av spamfilteret som ser en
  // e-post uten tekstdel som mer mistenkelig.
  const linje = (s: Rangert) =>
    `- ${s.tittel}${s.endring ? ` (${s.endring})` : ''}\n  ${s.detalj}\n  [${GRUNNLAG[s.grunnlag].navn}]`
  const tekst = [
    `Uke ${brief.ukenummer} - ${brief.stasjonNavn}`,
    brief.overskrift,
    '',
    brief.ingress,
    brief.handlinger.length ? '\nDETTE VILLE JEG TATT TAK I\n' + brief.handlinger.map((h, i) => `${i + 1}. ${h.tekst}`).join('\n') : '',
    brief.oppmerksomhet.length ? '\nTRENGER OPPMERKSOMHET\n' + brief.oppmerksomhet.map(linje).join('\n') : '',
    brief.bra.length ? '\nDETTE GIKK BRA\n' + brief.bra.map(linje).join('\n') : '',
    brief.viIkkeVet.length ? '\nDETTE VET VI IKKE\n' + brief.viIkkeVet.map((t) => `- ${t}`).join('\n') : '',
    `\n${basisUrl}/oversikt`,
  ].filter(Boolean).join('\n')

  return { emne, html, tekst }
}
