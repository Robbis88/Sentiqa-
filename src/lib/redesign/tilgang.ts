// =====================================================================
// Lover menyen noe sida ikke holder?
//
// Layoutet logger deg inn. Rollesjekken gjør HVER side for seg, for
// hånd, mens menyen deklarerer roller per rute i navigasjon.ts. To
// steder som må si det samme, uten at noe holder dem sammen.
//
// Går de fra hverandre, går det galt i to retninger:
//
//   MENYEN LOVER FOR MYE   butikksjefen ser punktet, trykker, og møter
//                          «Du har ikke tilgang». En død lenke som ser
//                          ut som en feil hun har gjort.
//
//   MENYEN LOVER FOR LITE  sida slipper inn en rolle menyen skjuler den
//                          for. Da er skjulingen det eneste som holder
//                          folk ute, og en URL er nok til å komme forbi.
//
// Denne fila leser den FØRSTE retningen, fordi den kan leses uten
// gjetting. Den andre krever at man vet hva som er ment, og hører
// hjemme i en deklarasjon — ikke i en regex som later som den vet.
//
// SKILLET SOM GJØR DETTE MULIG: i denne kodebasen avviser en side med
// `return <p>Du har ikke tilgang</p>`, mens den forgrener på rolle med
// `return <TabletHjem …/>`. Portner returnerer tekst, gren returnerer
// komponent. Ser vi et rollekall foran et `return <p>`, er det en
// avvisning. Ser vi det foran en komponent, er det to visninger av
// samme side.
//
// Kjenner den ikke igjen formen, sier den fra i stedet for å anta at
// alt er i orden. En vakt som tier når den er forvirret, er verre enn
// ingen vakt.
// =====================================================================

export type Rolle =
  | 'retailer_admin'
  | 'butikksjef'
  | 'butikkbruker_tablet'
  | 'plattform_redaktor'

export const ALLE_ROLLER: Rolle[] = [
  'retailer_admin', 'butikksjef', 'butikkbruker_tablet', 'plattform_redaktor',
]

/** `erLeder()` i src/lib/auth/roller.ts. Speilet her, og testet mot den. */
export const LEDERE: Rolle[] = ['retailer_admin', 'butikksjef']

export type Avvisning =
  | { slag: 'roller'; nektede: Rolle[] }
  | { slag: 'ukjent'; tekst: string }

const erRolle = (s: string): s is Rolle => (ALLE_ROLLER as string[]).includes(s)

/**
 * Rollene siden avviser med en tekstretur.
 *
 * Vi leter etter et rollekall som står rett foran et `return <p>` eller
 * et `return <>…<p>`. Mellomrom og linjeskift varierer, klammer er
 * valgfrie, og begge deler er dekket.
 */
export function avvisteRoller(kilde: string): Avvisning {
  const nektede = new Set<Rolle>()

  // REKKEFØLGE ER ALT. /regnskap håndterer butikksjefen i en gren som
  // returnerer en komponent, og har DERETTER en portner som avviser alt
  // som ikke er eier. Leser man bare portneren, ser det ut som
  // butikksjefen er stengt ute av sin egen side. Det gjorde denne
  // vakten på første kjøring — et falskt funn, og en vakt som roper
  // ulv blir slått av.
  //
  // Derfor: én gjennomgang i kildens rekkefølge. En rolle som allerede
  // har fått sitt svar, når aldri portneren under.
  const haandtert = new Set<Rolle>()

  // `if (<vilkår>) [{] return <Noe` eller `… redirect(`. Taggen skiller:
  // liten forbokstav / fragment = tekstsvar = portner. Stor forbokstav
  // = komponent = egen visning for den rollen. redirect = sendt videre.
  //
  // Vilkåret må tåle ETT nivå parenteser. Første forsøk brukte `[^)]*`,
  // og da var `!erLeder(bruker.rolle)` — portneren på rundt tjuefem
  // sider — usynlig. Vakten var grønn fordi den ikke fant noe i det
  // hele tatt. Det er den farligste tilstanden en vakt kan ha, og den
  // så helt frisk ut.
  const grener =
    /if\s*\(((?:[^()]|\([^()]*\))*)\)\s*\{?\s*(?:return\s*\(?\s*<(\w+|>)|(redirect)\s*\()/g

  for (const m of kilde.matchAll(grener)) {
    const vilkaar = m[1].replace(/\s+/g, ' ').trim()
    // Vilkår uten rolle i seg er ikke en tilgangssjekk — «if (!person)
    // return <p>Ingen ansatte</p>» er en tom tilstand, ikke en portner.
    if (!/rolle/.test(vilkaar)) continue

    const tagg = m[2] ?? ''
    const erVideresendt = m[3] === 'redirect'
    const erKomponent = /^[A-Z]/.test(tagg)

    // Fikk rollen sitt eget svar her? Da er den ferdig behandlet.
    if (erKomponent || erVideresendt) {
      const nettoppEn = vilkaar.match(/^bruker\.rolle\s*===\s*'([a-z_]+)'$/)
      if (nettoppEn && erRolle(nettoppEn[1])) haandtert.add(nettoppEn[1])
      // Andre former for forgrening trenger vi ikke forstå: de avviser
      // ingen, og portneren under er fortsatt den som bestemmer.
      continue
    }

    // 1) `!erLeder(bruker.rolle)` — alle utenom lederne avvises.
    if (/^!\s*erLeder\s*\(\s*bruker\.rolle\s*\)$/.test(vilkaar)) {
      for (const r of ALLE_ROLLER) if (!LEDERE.includes(r)) nektede.add(r)
      continue
    }

    // 2) `bruker.rolle !== 'X'` — alle utenom X avvises.
    const bareEn = vilkaar.match(/^bruker\.rolle\s*!==\s*'([a-z_]+)'$/)
    if (bareEn && erRolle(bareEn[1])) {
      for (const r of ALLE_ROLLER) if (r !== bareEn[1]) nektede.add(r)
      continue
    }

    // 3) `bruker.rolle === 'X'` — X avvises, resten slipper inn.
    const nettoppEn = vilkaar.match(/^bruker\.rolle\s*===\s*'([a-z_]+)'$/)
    if (nettoppEn && erRolle(nettoppEn[1])) {
      nektede.add(nettoppEn[1])
      continue
    }

    // 4) `!erAdmin && !erButikksjef` — konstantene løses opp under.
    const viaKonstanter = vilkaar.match(/^!(\w+)\s*&&\s*!(\w+)$/)
    if (viaKonstanter) {
      const løst = [viaKonstanter[1], viaKonstanter[2]].map((navn) => {
        const d = kilde.match(
          new RegExp(`const\\s+${navn}\\s*=\\s*bruker\\.rolle\\s*===\\s*'([a-z_]+)'`),
        )
        return d?.[1]
      })
      if (løst.every((r) => r !== undefined && erRolle(r))) {
        const tillatt = løst as Rolle[]
        for (const r of ALLE_ROLLER) if (!tillatt.includes(r)) nektede.add(r)
        continue
      }
    }

    return { slag: 'ukjent', tekst: vilkaar }
  }

  // Trekk fra de som fikk svaret sitt lenger opp.
  for (const r of haandtert) nektede.delete(r)
  return { slag: 'roller', nektede: [...nektede].sort() }
}
