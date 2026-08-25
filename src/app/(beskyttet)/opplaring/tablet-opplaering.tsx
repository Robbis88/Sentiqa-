'use client'
import { useState } from 'react'
import { hakAvPaaNettbrett } from './handlinger'
import { useT } from '../oversett-kontekst'

// =====================================================================
// Opplæringen der den skjer.
//
// Butikksjefen planlegger «29. august, 16–23» på kontoret. Den dagen
// står sjekklista på stasjonens nettbrett av seg selv — ingen
// publisering, ingen kopiering. Skift-kalenderen er utløseren, og den
// har ligget i basen siden 0042 uten at noe leste den.
//
// ---------------------------------------------------------------------
// HVORFOR EN LISTE HER, NÅR SJEKKPUNKTENE VISER ETT AV GANGEN
//
// Et sjekkpunkt er et **spørsmål**, og et «nei» på et kritisk punkt skal
// følges opp samme dag. Står de ti under hverandre, hakes de av nedover
// uten å leses — derfor ett av gangen der.
//
// En opplæringsoppgave er ikke et spørsmål. Den er en ting som skal
// læres bort, i den rekkefølgen dagen tillater: kassa når det er rolig,
// bakingen når ovnen er varm. Den som lærer bort må kunne se hele
// listen og velge neste selv. Å tvinge fram rekkefølgen ville gjort
// nettbrettet til en hindring i stedet for en huskeliste.
//
// ---------------------------------------------------------------------
// EN HAKE KAN SETTES HER, MEN IKKE FJERNES
//
// `opp2_utfort_del` (0133) er fortsatt leder-only. Å ta bort en hake er
// å si at noe likevel ikke er lært bort — det er en vurdering, ikke en
// registrering. Derfor er en gjort oppgave ikke en knapp her, og siden
// sier hvem som kan angre. En knapp som ser ut som den virker og blir
// avvist av databasen er verre enn ingen knapp.
//
// FEILER SYNLIG. Haken settes først når serveren har svart ja. En
// oppgave som ser gjort ut uten å være det, oppdages aldri — den blir
// stående som opplært i en journal noen kan komme til å lene seg på.
// =====================================================================

export type Oppgave = {
  id: string
  kategori: string
  tittel: string
  gjort: boolean
}

export type Opplaering = {
  periodeId: string
  ansattNavn: string
  /** «16:00–23:00», eller null når skiftet gjelder hele dagen. */
  tidsrom: string | null
  oppgaver: Oppgave[]
}

export function TabletOpplaering({ opplaeringer }: { opplaeringer: Opplaering[] }) {
  const t = useT()
  const [gjort, setGjort] = useState<Set<string>>(
    () => new Set(opplaeringer.flatMap((o) =>
      o.oppgaver.filter((x) => x.gjort).map((x) => `${o.periodeId}:${x.id}`))),
  )
  const [venter, setVenter] = useState<string | null>(null)
  const [feil, setFeil] = useState<string | null>(null)

  if (opplaeringer.length === 0) return null

  function hakAv(periodeId: string, oppgaveId: string) {
    const nokkel = `${periodeId}:${oppgaveId}`
    setVenter(nokkel)
    setFeil(null)
    hakAvPaaNettbrett(periodeId, oppgaveId)
      .then((r) => {
        if (r?.ok) setGjort((s) => new Set(s).add(nokkel))
        else setFeil(t('Haken ble ikke lagret. Prøv en gang til.'))
      })
      .catch(() => setFeil(t('Haken ble ikke lagret. Prøv en gang til.')))
      .finally(() => setVenter(null))
  }

  return (
    <>
      {opplaeringer.map((o) => {
        const ferdig = o.oppgaver.filter((x) => gjort.has(`${o.periodeId}:${x.id}`)).length
        const pst = o.oppgaver.length > 0
          ? Math.round((ferdig / o.oppgaver.length) * 100) : 0

        // Gruppert på kategori, i den rekkefølgen master-lista er
        // sortert. Rekkefølgen er butikksjefens, ikke denne fila sin.
        const kategorier: { navn: string; oppgaver: Oppgave[] }[] = []
        for (const opg of o.oppgaver) {
          const siste = kategorier[kategorier.length - 1]
          if (siste && siste.navn === opg.kategori) siste.oppgaver.push(opg)
          else kategorier.push({ navn: opg.kategori, oppgaver: [opg] })
        }

        return (
          <section key={o.periodeId} className="tablet-seksjon topl" aria-labelledby={`topl-${o.periodeId}`}>
            <div className="topl-topp">
              <span className="topl-tekst">
                <strong id={`topl-${o.periodeId}`}>{t('Opplæring')}: {o.ansattNavn}</strong>
                <span>
                  {o.tidsrom ? <>{t('I dag')} {t('kl.')} {o.tidsrom}</> : t('I dag')}
                  {' · '}{ferdig}/{o.oppgaver.length} {t('gjort')}
                </span>
              </span>
              <span className="topl-pst">{pst} %</span>
            </div>
            <div className="topl-bar"><span style={{ width: `${pst}%` }} /></div>

            {kategorier.map((k) => (
              <div key={k.navn} className="topl-gruppe">
                <h3 className="topl-kategori">{k.navn}</h3>
                <ul className="topl-liste">
                  {k.oppgaver.map((opg) => {
                    const nokkel = `${o.periodeId}:${opg.id}`
                    const erGjort = gjort.has(nokkel)
                    return (
                      <li key={opg.id} className={erGjort ? 'topl-rad topl-gjort' : 'topl-rad'}>
                        {erGjort ? (
                          // IKKE EN KNAPP. Nettbrettet kan ikke fjerne
                          // haken, og en knapp som blir avvist av
                          // databasen er verre enn ingen knapp.
                          <span className="topl-ferdig">
                            <span aria-hidden>✓</span> {opg.tittel}
                          </span>
                        ) : (
                          <button
                            type="button"
                            onClick={() => hakAv(o.periodeId, opg.id)}
                            disabled={venter === nokkel}
                          >
                            {venter === nokkel ? t('Lagrer …') : opg.tittel}
                          </button>
                        )}
                      </li>
                    )
                  })}
                </ul>
              </div>
            ))}

            {ferdig > 0 && (
              <p className="undertittel topl-angre">
                {t('En hake kan bare tas bort av butikksjefen.')}
              </p>
            )}
          </section>
        )
      })}

      {/* FEILEN STAAR DER HANDLINGEN SKJEDDE, ikke i en logg. */}
      {feil && <p className="feil" role="alert">{feil}</p>}
    </>
  )
}
