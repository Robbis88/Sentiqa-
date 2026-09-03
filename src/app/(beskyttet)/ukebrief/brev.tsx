import Link from 'next/link'
import type { Rangert, Ukebrief } from '@/lib/ukebrief/type'
import type { Dagsrad, Skjemabilde } from '@/lib/ukebrief/skjema'

// =====================================================================
// Brevet.
//
// Samme komponent tegner både sidevisningen og e-postvisningen — det er
// hele poenget med at `bygg.ts` er ren. Blir de to ulike, er det fordi
// noen har skrevet innhold inn i presentasjonen, og da har vi to
// sannheter igjen.
//
// E-postvisningen viser INNHOLDET og rekkefølgen, ikke den endelige
// e-post-HTML-en. Ekte e-post krever inline-stiler og <table> for at
// Outlook skal oppføre seg, og begge deler er forbudt i appen av
// designvakten. Den oversettelsen hører til utsendingen, som ikke er
// bygget ennå.
// =====================================================================

/** Ordene er butikksjefens, ikke databasens. «Sterk indikasjon» sier noe
    en leder kan handle på; «indikasjon» alene sier ingenting om styrke. */
const GRUNNLAG: Record<Rangert['grunnlag'], string> = {
  fakta: 'Fakta',
  indikasjon: 'Sterk indikasjon',
  hypotese: 'Mulig forklaring',
  mangler_data: 'Ikke nok data',
}

function Funn({ s }: { s: Rangert }) {
  return (
    <li className="ub-funn">
      <div className="ub-funn-topp">
        <span className="ub-funn-tittel">{s.tittel}</span>
        {s.endring && <span className="ub-funn-tall">{s.endring}</span>}
      </div>
      <p className="ub-funn-detalj">{s.detalj}</p>
      <div className="ub-funn-bunn">
        <span className={`ub-grunnlag ub-grunnlag-${s.grunnlag}`}>{GRUNNLAG[s.grunnlag]}</span>
        <span className="ub-kilde">{s.merke}</span>
        <Link href={s.lenke} className="ub-lenke">Se tallene</Link>
      </div>
    </li>
  )
}

/** Grønn ved fullt, rød under terskelen, ellers nøytral. Fargen er en
    andrelesing — tallet står der uansett, for den som ikke ser farge. */
function dagsklasse(d: Dagsrad): string {
  if (d.prosent === null) return 'ub-dag ub-dag-tom'
  if (d.prosent >= 100) return 'ub-dag ub-dag-full'
  if (d.prosent < 90) return 'ub-dag ub-dag-lav'
  return 'ub-dag'
}

function Skjemarad({ b }: { b: Skjemabilde }) {
  return (
    <div className="ub-skjema">
      <div className="ub-skjema-hode">
        <span className="ub-funn-tittel">{b.navn}</span>
        <span className="ub-funn-tall">{b.prosent} % · {b.utfort} av {b.krevd}</span>
      </div>
      {/* Sju celler, ikke en tabell. Spørsmålet er «hvilken dag», og det
          svares raskest av en rad man kan se på i ett blikk. */}
      <ul className="ub-dager">
        {b.dager.map((d) => (
          <li key={d.dato} className={dagsklasse(d)}>
            <span className="ub-dag-navn">{d.ukedag}</span>
            <span className="ub-dag-tall">{d.prosent === null ? '–' : `${d.prosent} %`}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

export function Brev({ brief }: { brief: Ukebrief }) {
  return (
    <article className="ub-brev">
      <header className="ub-hode">
        <p className="ub-uke">Uke {brief.ukenummer} · {brief.stasjonNavn}</p>
        <h2 className="ub-overskrift">{brief.overskrift}</h2>
        <p className="ub-ingress">{brief.ingress}</p>
      </header>

      {brief.handlinger.length > 0 && (
        <section className="ub-seksjon ub-handlinger">
          <h3 className="ub-seksjon-tittel">Dette ville jeg tatt tak i</h3>
          <ol className="ub-handlingsliste">
            {brief.handlinger.map((h) => (
              <li key={h.fraSignal}>{h.tekst}</li>
            ))}
          </ol>
        </section>
      )}

      {brief.oppmerksomhet.length > 0 && (
        <section className="ub-seksjon">
          <h3 className="ub-seksjon-tittel">Trenger oppmerksomhet</h3>
          <ul className="ub-funnliste">
            {brief.oppmerksomhet.map((s) => <Funn key={s.id} s={s} />)}
          </ul>
        </section>
      )}

      {brief.bra.length > 0 && (
        <section className="ub-seksjon">
          <h3 className="ub-seksjon-tittel">Dette gikk bra</h3>
          <ul className="ub-funnliste">
            {brief.bra.map((s) => <Funn key={s.id} s={s} />)}
          </ul>
        </section>
      )}

      {brief.skjema.length > 0 && (
        <section className="ub-seksjon">
          <h3 className="ub-seksjon-tittel">Utført per dag</h3>
          {brief.skjema.map((b) => <Skjemarad key={b.navn} b={b} />)}
        </section>
      )}

      {/* Står SIST og ikke først: det er en fotnote til leseren, ikke en
          unnskyldning brevet åpner med. Men det står, hver gang — et brev
          som tier om hva det ikke vet, later som det vet alt. */}
      {brief.viIkkeVet.length > 0 && (
        <section className="ub-seksjon ub-ikkevet">
          <h3 className="ub-seksjon-tittel">Dette vet vi ikke</h3>
          <ul className="ub-ikkevet-liste">
            {brief.viIkkeVet.map((t) => <li key={t}>{t}</li>)}
          </ul>
        </section>
      )}
    </article>
  )
}
