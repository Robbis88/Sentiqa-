// =====================================================================
// Filnavn -> trygg nokkel i Supabase Storage
//
// Storage avviser nokler med tegn utenfor ASCII. Det er ikke noe man
// oppdager ved a lese dokumentasjonen — man oppdager det den dagen noen
// laster opp «Avtale om fast ansettelse av mindreårig …» og far:
//
//   Invalid key: <uuid>-Avtale om ... av mindreårig i tariffbundet ...
//
// Fem steder i appen bygde nokkelen rett av filnavnet. Ingen av dem
// hadde blitt truffet for, fordi rapportene fra St1 og Visma tilfeldigvis
// heter noe rent engelsk. E-postinntaket er den mest utsatte: der er
// norske vedleggsnavn regelen.
//
// VISNINGSNAVNET ROERES IKKE. `filnavn` i basen beholder «mindreårig»
// med a; det er bare adressen i Storage som ma vaere enkel. Uuid-en
// foran gjor uansett nokkelen unik — navnet henger med for at en fil
// skal kunne kjennes igjen i en bucket-liste.
// =====================================================================

// Kun tegn som ikke lar seg dekomponere med NFD. «å» blir «a» av seg
// selv; «ø» og «æ» er egne bokstaver og ma oversettes.
const BOKSTAVER: Record<string, string> = {
  ø: 'o', Ø: 'O', æ: 'ae', Æ: 'AE', đ: 'd', Đ: 'D', ß: 'ss', ł: 'l', Ł: 'L',
}

const forenkle = (s: string) =>
  s.replace(/[øØæÆđĐßłŁ]/g, (t) => BOKSTAVER[t] ?? t)
    // NFD skiller bokstav fra aksent, sa «å» blir «a» + ring. Ringen
    // fjernes i neste steg.
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')

/**
 * Gjor et filnavn trygt som Storage-nokkel.
 *
 * Beholder endelsen, fordi den avgjor hvordan fila apnes senere. Blir
 * navnet tomt — et rent kinesisk filnavn, for eksempel — brukes «fil»,
 * sa nokkelen aldri ender pa en bindestrek eller ingenting.
 */
export function trygtFilnavn(navn: string, maksLengde = 80): string {
  const punkt = navn.lastIndexOf('.')
  const harEndelse = punkt > 0 && punkt < navn.length - 1
  const stamme = harEndelse ? navn.slice(0, punkt) : navn
  const endelse = harEndelse ? navn.slice(punkt + 1) : ''

  const rens = (s: string) => forenkle(s)
    .replace(/[^A-Za-z0-9._-]+/g, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^[-.]+|[-.]+$/g, '')

  const s = rens(stamme).slice(0, maksLengde) || 'fil'
  const e = rens(endelse).slice(0, 12)
  return e ? `${s}.${e}` : s
}
