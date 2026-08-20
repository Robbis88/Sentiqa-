import Link from 'next/link'
import type { Signal } from '@/lib/signaler'
import { Status } from '@/components/ui/status'
import { SignalKnapper } from './signal-knapper'

// =====================================================================
// Den rangerte lista — hovedinnholdet på forsiden for begge lederroller.
//
// Ett funn = én rad, ikke ett kort. Et kort sier «her er en modul»; en
// rad med alvorlighetsstripe sier «her er en sak». Rekkefølgen er
// informasjon, så alle radene ser like ut bortsett fra alvoret og
// tallet.
//
// TRE TING ER FLYTTET UT AV UTVIDELSEN, og alle tre av samme grunn:
// det som forklarer rekkefølgen, og det man kom for å gjøre, kan ikke
// ligge bak et klikk.
//
//   Alvoret      stod som en egen liten etikett (`.sq-nivaa`). Nå er det
//                Status, samme som resten av systemet.
//   Grunnlaget   kroner og dager er PRESIS det motoren rangerer etter
//                (signaler.ts). Lå det skjult, måtte man tro på
//                rekkefølgen i stedet for å se den.
//   «Undersøk»   lå som første knapp i utvidelsen. Veien til saken
//                kostet da to klikk, og pila til høyre lovet noe annet
//                enn den gjorde — den åpnet, den gikk ikke.
//
// Utvidelsen har fortsatt de fire handlingene som ENDRER noe: oppgave,
// fokus, tablet, skjul. De er sjeldnere, og de skal ikke stå og friste
// på tvers av åtte rader.
//
// <details> er bevisst: utvidelsen virker uten JavaScript, og
// skjermlesere får åpne/lukke gratis. Lenken ligger UTENFOR <summary> —
// et fokuserbart element inni en summary er en knapp inni en knapp.
// =====================================================================

const NIVAA_ORD: Record<string, string> = {
  kritisk: 'Haster',
  folg: 'Følg med',
  info: 'Til orientering',
}

/**
 * Alvoret i systemets eget språk.
 *
 * `info` blir NORMAL, ikke en farge til. En orientering er ikke en
 * mild advarsel — den er utgangspunktet, og fargebudsjettet skal gå til
 * de to over.
 */
const NIVAA_STATUS = {
  kritisk: 'kritisk',
  folg: 'handling',
  info: 'normal',
} as const

/** Bare sifrene, så to skrivemåter av samme tall kan sammenlignes. */
const sifre = (s: string) => s.replace(/\D/g, '')

/**
 * Grunnlaget for rangeringen, som ord.
 *
 * Noen signaler har allerede tallet sitt i `endring` — «5 dager på rad»
 * står i overskriften på treffsignalet, og kronebeløpet i utsolgt. Å
 * gjenta det ville lært øyet at grunnlaget er pynt. Derfor droppes en
 * verdi som allerede står der.
 */
function grunnlag(s: Signal): string[] {
  const ut: string[] = []
  const alt = sifre(s.endring ?? '')
  if (s.konsekvensKr != null) {
    const kr = Math.abs(Math.round(s.konsekvensKr))
    const tekst = `${kr.toLocaleString('nb-NO')} kr i utslag`
    if (!alt.includes(sifre(tekst))) ut.push(tekst)
  }
  if (s.dager != null) {
    const tekst = `${s.dager} ${s.dager === 1 ? 'dag' : 'dager'} på rad`
    if (!alt.includes(sifre(tekst))) ut.push(tekst)
  }
  return ut
}

// «7 ting trenger oppmerksomhet» sier ikke om det er sju kritiske eller sju
// uleste meldinger. Da må sjefen lese alle sju for å finne de to som betyr
// noe — nøyaktig jobben denne lista skulle spare hen for.
function overskrift(signaler: Signal[]): string {
  const haster = signaler.filter((s) => s.niva === 'kritisk').length
  const resten = signaler.length - haster
  if (haster === 0) return `${resten} ${resten === 1 ? 'ting' : 'ting'} å se på`
  if (resten === 0) return `${haster} ting haster`
  return `${haster} ting haster · ${resten} til orientering`
}

export function Oppmerksomhet({ signaler }: { signaler: Signal[] }) {
  if (signaler.length === 0) {
    return (
      <section className="sq-seksjon">
        <div className="sq-seksjon-hode">
          <h2>Ingenting trenger oppmerksomhet</h2>
        </div>
        <p className="undertittel">
          Ingen avvik i salget, ingen forsinkede oppgaver og ingen uleste tilbakemeldinger.
        </p>
      </section>
    )
  }

  return (
    <section className="sq-seksjon">
      <div className="sq-seksjon-hode">
        <h2>{overskrift(signaler)}</h2>
        <span className="sq-merkelapp">Viktigst øverst</span>
      </div>

      <ul className="sq-saker">
        {signaler.map((s) => {
          const bevis = grunnlag(s)
          return (
            <li className="sq-sak" data-niva={s.niva} key={s.id}>
              {/* Stripen forsterker alvoret; den bærer det ikke. Den er
                  usynlig for skjermlesere og for den som ikke skiller
                  rødt fra gult — derfor står ordet ved siden av. */}
              <span className="sq-stripe" aria-hidden="true" />

              <div className="sq-sak-tekst">
                <span className="sq-sak-tittel">
                  <Status nivaa={NIVAA_STATUS[s.niva]}>{NIVAA_ORD[s.niva] ?? s.niva}</Status>
                  <b>{s.tittel}</b>
                  {s.endring ? <span className="sq-endring">{s.endring}</span> : null}
                </span>
                <span className="sq-sak-under">{s.detalj}</span>
                {bevis.length > 0 && (
                  <span className="sq-bevis">
                    {bevis.map((b) => <span key={b}>{b}</span>)}
                  </span>
                )}

                <details className="sq-sak-mer">
                  <summary>Flere handlinger</summary>
                  <div className="sq-handlinger">
                    <SignalKnapper
                      signalId={s.id} tittel={s.tittel} detalj={s.detalj} stasjonId={s.stasjonId}
                    />
                  </div>
                </details>
              </div>

              <div className="sq-sak-hoyre">
                <span className="sq-merkelapp">{s.merke}</span>
                {/* Rolig, ikke primær. Åtte grønne knapper under hverandre
                    ville gjort rangeringen usynlig igjen — alvoret skal
                    skille radene, ikke knappen som er lik på alle. */}
                <Link href={s.lenke} className="sq-knapp sq-sak-gaa">Undersøk</Link>
              </div>
            </li>
          )
        })}
      </ul>
    </section>
  )
}
