import type { Maanedsplan } from './plan'
import { maanedsnavn } from './plan'

// =====================================================================
// Månedsplanen som e-post.
//
// HEX-FARGER OG INLINE-STILER ER MED VILJE, av samme grunn som i
// `ukebrief/epost.ts`: e-postklienter støtter ikke CSS-variabler eller
// eksterne stilark, og Outlook stripper `<style>`. Fargene er kopiert
// fra `globals.css` og skal følge den.
//
// MOBIL FØRST. En butikksjef leser dette på telefonen, mellom to andre
// ting. Én spalte, og det viktigste over folden.
//
// ---------------------------------------------------------------------
// HVA SOM ER ØVERST, OG HVORFOR
//
// Ukebriefen åpner med et tall. Denne åpner med en RETNING, fordi det er
// hele poenget: «Dale går riktig vei» er en annen beskjed enn «Dale har
// klusterets dårligste resultat», og på Kelsars tall er begge sanne.
//
// I motvind står det ÉN ting under. Ikke fem. En liste med fem tiltak
// til noen som holder på å miste grepet er ikke en plan, det er en
// anklage — og den blir lest som en.
//
// ---------------------------------------------------------------------
// REN FUNKSJON
//
// Ingen nettverk, ingen klokke. Samme plan gir samme e-post, og
// innholdet kan derfor sammenlignes i en test. Teksten kommer fra
// `plan.ts`, som skriver den ut av tallene — ikke fra en modell som kan
// finne på å tolke dem.
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
  rod: '#9b2c2c',
  rodSvak: '#fbeceb',
  gul: '#7a5321',
  gulSvak: '#fbf1dd',
} as const

const SKRIFT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"

const e = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')

const kr = (n: number) =>
  Math.round(Math.abs(n)).toLocaleString('nb-NO').replace(/\s/g, ' ')

/** Ordene er de samme som på skjermen. Et brev som kaller det noe annet
    enn siden gjør, lærer leseren to vokabular for samme sak. */
const DOMORD = {
  medvind: { ord: 'Medvind', farge: F.gronn, bakgrunn: F.primaerSvak },
  motvind: { ord: 'Motvind', farge: F.rod, bakgrunn: F.rodSvak },
  flat: { ord: 'Stø kurs', farge: F.gul, bakgrunn: F.gulSvak },
} as const

export type Epost = { emne: string; html: string; tekst: string }

export function tilEpost(plan: Maanedsplan, basisUrl: string): Epost {
  const mnd = maanedsnavn(plan.maaned)
  const d = DOMORD[plan.dom]

  // EMNET SIER RETNINGEN, IKKE «Månedsplan». Et emne som er likt hver
  // måned blir et emne ingen leser.
  const emne = plan.dom === 'medvind'
    ? `${plan.stasjonNavn} går riktig vei — ${mnd}`
    : plan.dom === 'motvind'
      ? `${plan.stasjonNavn}, én ting i ${mnd}`
      : `${plan.stasjonNavn} — ${mnd}`

  const punkter = plan.punkter.map((p) => {
    const erTiltak = p.slag === 'tiltak'
    const kant = erTiltak ? F.rod : F.gronn
    const merke = erTiltak
      ? (plan.dom === 'medvind' ? 'NESTE' : 'DETTE')
      : 'GÅR BRA'
    const kroner = p.kronerIAret === null ? '' : `
          <div style="margin-top:8px;font-size:14px;font-weight:600;color:${kant};">
            ${erTiltak ? 'Står på spill' : 'Verdt'}: ${kr(p.kronerIAret)} kroner i året
          </div>`
    return `
      <tr><td style="padding:14px 0 0;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
               style="border-left:3px solid ${kant};">
          <tr><td style="padding:2px 0 2px 14px;">
            <div style="font-size:11px;letter-spacing:0.08em;color:${kant};font-weight:700;">${merke}</div>
            <div style="margin-top:4px;font-size:16px;font-weight:700;color:${F.tekst};">${e(p.tittel)}</div>
            <div style="margin-top:6px;font-size:15px;line-height:1.55;color:${F.tekst};">${e(p.tekst)}</div>${kroner}
          </td></tr>
        </table>
      </td></tr>`
  }).join('')

  // TOM PLAN ER OGSÅ ET SVAR. Uten dette ville brevet vært en overskrift
  // og ingenting — og en butikksjef som får det, tror noe er i stykker.
  const tomt = plan.punkter.length > 0 ? '' : `
      <tr><td style="padding:14px 0 0;font-size:15px;line-height:1.55;color:${F.svak};">
        Ingen av løftestengene peker feil vei denne måneden. Hold kursen.
      </td></tr>`

  const merknad = plan.merknad === null ? '' : `
      <tr><td style="padding:18px 0 0;">
        <div style="background:${F.gulSvak};border-radius:8px;padding:12px 14px;
                    font-size:13px;line-height:1.5;color:${F.gul};">${e(plan.merknad)}</div>
      </td></tr>`

  const html = `<!doctype html>
<html lang="nb"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:${F.bg};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
       style="background:${F.bg};padding:20px 12px;">
  <tr><td align="center">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
           style="max-width:560px;background:${F.kort};border-radius:14px;padding:24px;
                  font-family:${SKRIFT};">
      <tr><td>
        <span style="display:inline-block;background:${d.bakgrunn};color:${d.farge};
                     font-size:12px;font-weight:700;letter-spacing:0.06em;
                     padding:5px 11px;border-radius:999px;">${d.ord.toUpperCase()}</span>
      </td></tr>
      <tr><td style="padding:12px 0 0;">
        <div style="font-size:22px;font-weight:700;color:${F.tekst};line-height:1.25;">
          ${e(plan.stasjonNavn)} &middot; ${e(mnd)}
        </div>
      </td></tr>
      <tr><td style="padding:10px 0 0;font-size:15px;line-height:1.6;color:${F.svak};">
        ${e(plan.ingress)}
      </td></tr>
      ${punkter}${tomt}${merknad}
      <tr><td style="padding:24px 0 0;">
        <a href="${e(basisUrl)}/regnskap"
           style="display:inline-block;background:${F.primaer};color:#ffffff;
                  text-decoration:none;font-size:15px;font-weight:600;
                  padding:12px 20px;border-radius:9px;">Se tallene</a>
      </td></tr>
      <tr><td style="padding:20px 0 0;border-top:1px solid ${F.kant};margin-top:16px;">
        <div style="padding-top:14px;font-size:12px;line-height:1.5;color:${F.svak};">
          Månedsplanen bygges på retningen i dine egne tall, ikke på nivået.
          Den er lest og sluppet av eier før den ble sendt.
        </div>
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`

  const tekst = [
    `${d.ord.toUpperCase()} — ${plan.stasjonNavn}, ${mnd}`,
    '',
    plan.ingress,
    '',
    ...plan.punkter.flatMap((p) => [
      `${p.slag === 'tiltak' ? (plan.dom === 'medvind' ? 'NESTE' : 'DETTE') : 'GÅR BRA'}: ${p.tittel}`,
      p.tekst,
      p.kronerIAret === null
        ? null
        : `${p.slag === 'tiltak' ? 'Står på spill' : 'Verdt'}: ${kr(p.kronerIAret)} kroner i året`,
      '',
    ].filter((x): x is string => x !== null)),
    ...(plan.punkter.length === 0
      ? ['Ingen av løftestengene peker feil vei denne måneden. Hold kursen.', '']
      : []),
    ...(plan.merknad ? [plan.merknad, ''] : []),
    `Se tallene: ${basisUrl}/regnskap`,
  ].join('\n')

  return { emne, html, tekst }
}
