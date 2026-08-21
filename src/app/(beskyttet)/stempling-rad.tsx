import Link from 'next/link'

// =====================================================================
// ARBEIDSDAGEN, IKKE ENHETEN.
//
// Nettbrettet har TO ting som ser ut som «logg inn», og de er ikke det
// samme. Forskjellen maa staa i ordene, ellers laerer hun aldri hvilken
// av dem som betaler henne:
//
//   VAKT (toppstripa)   PIN alene, informasjonskapsel i 12 timer, ingen
//                       skriving. Svarer paa «hvem holder nettbrettet»
//                       saa handlingene kan tilskrives.
//
//   STEMPLING (her)     Ansattnummer + PIN, rad i `stempling_hendelse`,
//                       og ved utstempling timer i `stempling` som
//                       lonnsfila leser. Svarer paa «naar jobbet jeg».
//
// De ble ikke slaatt sammen, og det er med vilje: vakta identifiserer
// paa PIN ALENE, og en kollega som har sett koden din kan sjekke inn som
// deg. Aa la den skrive lonnsgrunnlag ville flyttet den svakeste
// identifikasjonen inn i det som betaler folk. Se stempling/handlinger.ts.
//
// Raden staar i «I dag» fordi det ER dagen — men den staar UNDER koen.
// Har hun glemt aa stemple inn, er det ikke det som haster mest klokka
// 14; er hun ferdig, er det det siste hun gjor.
// =====================================================================

export type Stemplingstilstand =
  /** Vet ikke hvem hun er — ingen vakt-PIN er tastet inn. */
  | { slag: 'ukjent' }
  /** Sist stemplet ut, eller aldri stemplet. Neste trykk er «inn». */
  | { slag: 'ute' }
  /** Staar inne. `siden` er klokkeslettet hun stemplet inn. */
  | { slag: 'inne'; siden: string }

export function StemplingRad({
  tilstand,
  ord = {},
}: {
  tilstand: Stemplingstilstand
  ord?: Record<string, string>
}) {
  const t = (s: string) => ord[s] ?? s

  // Ordene er handlingen, ikke tilstanden: «Stemple ut» sier hva som
  // skjer om hun trykker. Tilstanden staar under, i mindre skrift.
  const { handling, under } = tilstand.slag === 'inne'
    ? { handling: t('Stemple ut'), under: `${t('På jobb siden')} ${tilstand.siden}` }
    : tilstand.slag === 'ute'
      ? { handling: t('Stemple inn'), under: t('Du er ikke stemplet inn') }
      : { handling: t('Stemple inn eller ut'), under: t('Timene dine — ikke det samme som vakt-PIN-en') }

  return (
    <Link
      href="/stempling"
      className={`stempling-rad${tilstand.slag === 'inne' ? ' inne' : ''}`}
    >
      <span className="stempling-rad-tekst">
        <strong>{handling}</strong>
        <span className="undertittel">{under}</span>
      </span>
      <span className="stempling-rad-pil" aria-hidden>›</span>
    </Link>
  )
}
