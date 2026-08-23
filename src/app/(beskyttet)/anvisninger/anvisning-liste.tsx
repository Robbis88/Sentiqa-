'use client'
import { useState } from 'react'
import { Sok } from '@/components/ui/sok'
import { SlettKnapp } from '@/components/ui/slett-knapp'
import { sok, type Anvisning } from '@/lib/anvisningssok'
import { slettAnvisning } from './handlinger'

// =====================================================================
// Arkivet, med søk.
//
// FOR EN SOM STÅR MED HENDENE FULLE. Hun har et problem og trenger
// svaret — ikke et bibliotek å bla i. Derfor søk øverst, og derfor
// treffer det mens hun skriver.
//
// KATEGORIENE BEHOLDES NÅR HUN IKKE SØKER. Folk leter etter «Hurtigmat»,
// ikke etter den fjerde anvisningen, og grupperingen er en ekte
// inndeling. Men i det hun skriver noe, er kategorien i veien: da vil
// hun se treffene, ikke hvor de bor. Flat liste så lenge søket varer.
//
// TOMT SØK VISER HELE ARKIVET. En tom skjerm med «søk for å begynne»
// tvinger den som bare vil bla til å gjette et ord først.
//
// TEKST OG PDF I SAMME LISTE. Et ark er et ark; at det ene er skrevet
// inn og det andre lastet opp er vår sak, ikke hennes. Tekstark folder
// seg ut på stedet, PDF-er åpnes i ny fane — så søkeresultatet står
// igjen når hun lukker arket.
// =====================================================================

export type Rad = Anvisning & {
  /** Signert URL, hentet batchet på serveren. Null for tekstark. */
  url: string | null
  /** Oversatt tittel/kategori/innhold. Oversettelsen skjer på serveren. */
  vist: { tittel: string; kategori: string; innhold: string | null }
}

function Merkelapper({ rad }: { rad: Rad }) {
  const deler = [
    rad.stikkord.length > 0 ? rad.stikkord.join(' · ') : null,
    // Datoene står trykt på arket. Personalet kjenner dem igjen, og de
    // avgjør hvilket ark som gjelder.
    rad.dato ? `Gjelder fra ${rad.dato}` : null,
    rad.erstatter_dato ? `Erstatter ${rad.erstatter_dato}` : null,
  ].filter(Boolean)
  if (deler.length === 0) return null
  return <span className="anv-stikkord">{deler.join(' · ')}</span>
}

function Kort({ rad, erLeder }: { rad: Rad; erLeder: boolean }) {
  if (rad.url) {
    return (
      <div className="anv-kort">
        {/* HELE KORTET ER LENKEN, ikke bare tittelen. Med hansker treffer
            man et kort; man treffer ikke en tekstlinje. */}
        <a className="anv-kort-lenke" href={rad.url} target="_blank" rel="noreferrer">
          <span className="anv-kategori">{rad.vist.kategori}</span>
          <strong>{rad.vist.tittel}</strong>
          <Merkelapper rad={rad} />
        </a>
        {erLeder && (
          <div className="knapperad">
            <SlettKnapp
              hva={rad.tittel}
              handling={slettAnvisning}
              id={rad.id}
              bekreftelse="Anvisningen slettet"
            />
          </div>
        )}
      </div>
    )
  }

  return (
    <details className="anvisning">
      <summary>{rad.vist.tittel}</summary>
      <Merkelapper rad={rad} />
      {/* Linjeskiftene i en oppskrift ER innholdet. */}
      <p className="sq-brodtekst">{rad.vist.innhold}</p>
      {erLeder && (
        <div className="knapperad">
          <SlettKnapp
            hva={rad.tittel}
            handling={slettAnvisning}
            id={rad.id}
            bekreftelse="Anvisningen slettet"
          />
        </div>
      )}
    </details>
  )
}

export function AnvisningListe({
  rader,
  erLeder,
  tekst,
}: {
  rader: Rad[]
  erLeder: boolean
  /** Oversatte faste ord. Klienten oversetter ikke. */
  tekst: { plassholder: string; ingenTreff: string; merkelapp: string }
}) {
  const [q, settQ] = useState('')
  const treff = sok(rader, q) as Rad[]
  const soker = q.trim().length > 0

  const grupper = new Map<string, Rad[]>()
  for (const r of treff) {
    const l = grupper.get(r.vist.kategori) ?? []
    l.push(r)
    grupper.set(r.vist.kategori, l)
  }

  return (
    <>
      {/* KLEBRIG, saa feltet ikke forsvinner naar hun blar. Den som soeker
          igjen skal ikke maatte scrolle opp for aa gjoere det. */}
      <div className="anv-sok">
        <Sok
          verdi={q}
          onEndre={settQ}
          plassholder={tekst.plassholder}
          merkelapp={tekst.merkelapp}
        />
      </div>

      {treff.length === 0 ? (
        // GJENTAR SOEKEORDET. «Ingen treff» alene lar henne lure paa om
        // hun skrev feil eller om arket ikke finnes.
        <p className="undertittel">{tekst.ingenTreff} «{q.trim()}»</p>
      ) : soker ? (
        <section className="anv-rutenett">
          {treff.map((r) => <Kort key={r.id} rad={r} erLeder={erLeder} />)}
        </section>
      ) : (
        [...grupper.entries()].map(([kat, liste]) => (
          <section className="sq-anvkat" key={kat}>
            <h2>{kat} <span className="undertittel">· {liste.length}</span></h2>
            <div className="anv-rutenett">
              {liste.map((r) => <Kort key={r.id} rad={r} erLeder={erLeder} />)}
            </div>
          </section>
        ))
      )}
    </>
  )
}
