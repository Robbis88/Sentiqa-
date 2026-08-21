'use client'
import { useState } from 'react'
import { svarSjekkpunktTablet } from './handlinger'
import { useT } from '../oversett-kontekst'

// =====================================================================
// NIVAA 3 — utfor. Ett spoersmaal av gangen.
//
// DET SOM VAR GALT: koen paa «I dag» satte sjekkpunktene oeverst, kritisk
// foerst, og lenket hit. Her moette hun LEDERENS side — sidehode,
// sidepanel, «Nytt sjekkpunkt», sletteknapper — med alle spoersmaalene i
// en liste per stasjon. Samtidig ble de samme spoersmaalene stilt av en
// popup som dukket opp av seg selv etter 2,5 sekunder.
//
// To grensesnitt for den samme jobben, og det daarligste sto der koen
// pekte. Det er noeyaktig den doble maaleflaten /ikmat hadde foer bolge
// 5 — her paa den raden som er merket kritisk.
//
// NAA: ett spoersmaal fyller flata. Ja eller nei, to store knapper, og
// neste spoersmaal tar plassen. Rekkefolgen er koens egen: kritisk
// foerst, saa etter klokkeslett.
//
// HVORFOR IKKE EN LISTE MED HAKER? Fordi et sjekkpunkt ikke er en
// avkryssing — det er et SPOERSMAAL, og et «nei» paa et kritisk punkt
// skal foelges opp samme dag. Staar de ti under hverandre, hakes de av
// nedover uten aa leses. Ett av gangen tvinger et blikk per spoersmaal.
// =====================================================================

export type Punkt = {
  id: string
  stasjonId: string
  sporsmaal: string
  kritisk: boolean
  klokkeslett: string | null
  /** Dagens svar, om det er gitt. */
  svar: boolean | null
}

export function TabletSjekk({ punkter }: { punkter: Punkt[] }) {
  const t = useT()
  const [svarene, setSvarene] = useState<Record<string, boolean>>(
    Object.fromEntries(punkter.filter((p) => p.svar !== null).map((p) => [p.id, p.svar as boolean])),
  )
  const [venter, setVenter] = useState<string | null>(null)
  const [feil, setFeil] = useState<string | null>(null)

  const ubesvart = punkter.filter((p) => svarene[p.id] === undefined)
  const besvart = punkter.filter((p) => svarene[p.id] !== undefined)
  const naa = ubesvart[0]

  function svarPaa(p: Punkt, ja: boolean) {
    setVenter(p.id)
    setFeil(null)
    svarSjekkpunktTablet(p.id, p.stasjonId, ja)
      .then((r) => {
        // FEILER SYNLIG. Et sjekkpunkt som ser besvart ut uten aa vaere
        // det, er verre enn et som ser ubesvart ut: det foerste oppdages
        // aldri, det andre stilles en gang til.
        if (r?.ok) setSvarene((s) => ({ ...s, [p.id]: ja }))
        else setFeil(t('Svaret ble ikke lagret. Prøv en gang til.'))
      })
      .catch(() => setFeil(t('Svaret ble ikke lagret. Prøv en gang til.')))
      .finally(() => setVenter(null))
  }

  if (punkter.length === 0) {
    return (
      <section className="tablet-seksjon">
        <p className="undertittel">{t('Ingen sjekkpunkter satt opp på denne stasjonen.')}</p>
      </section>
    )
  }

  return (
    <>
      {naa ? (
        <section className="tsjekk" aria-labelledby="tsjekk-sp">
          {/* EN SANN PROGRESJON. Ikke en linje for besvarte og en for
              gjenstaaende — ett tall som sier hvor i koen hun er. */}
          <p className="tsjekk-teller">
            {besvart.length + 1} {t('av')} {punkter.length}
            {naa.kritisk && <span className="tsjekk-kritisk">{t('Kritisk')}</span>}
          </p>
          <h2 className="tsjekk-sporsmaal" id="tsjekk-sp">{naa.sporsmaal}</h2>
          {naa.klokkeslett && (
            <p className="undertittel">{t('skulle vært gjort')} {naa.klokkeslett}</p>
          )}
          <div className="tsjekk-knapper">
            <button
              type="button" className="tsjekk-ja" disabled={venter === naa.id}
              onClick={() => svarPaa(naa, true)}
            >{t('Ja')}</button>
            <button
              type="button" className="tsjekk-nei" disabled={venter === naa.id}
              onClick={() => svarPaa(naa, false)}
            >{t('Nei')}</button>
          </div>
          {feil && <p className="feil" role="alert">{feil}</p>}
        </section>
      ) : (
        <section className="tsjekk tsjekk-ferdig">
          <p className="tsjekk-ferdig-tekst">{t('Alt er besvart')}</p>
          <p className="tsjekk-ferdig-under">
            {punkter.length} {punkter.length === 1 ? t('spørsmål') : t('spørsmål')} · {t('ferdig for i dag')}
          </p>
        </section>
      )}

      {/* DET SOM ER GJORT, SAMLET OG STILLE. Et «nei» staar i ord, ikke i
          en farge — den som svarte det skal kunne se det igjen. */}
      {besvart.length > 0 && (
        <section className="tablet-seksjon">
          <h2>{t('Besvart i dag')} <span className="undertittel">· {besvart.length}</span></h2>
          <ul className="rutine-liste">
            {besvart.map((p) => (
              <li key={p.id} className="gjort">
                <span className="kryss av" aria-hidden>✓</span>
                <span className="rutine-tekst">
                  <strong>{p.sporsmaal}</strong>
                  <span className="undertittel"> — {svarene[p.id] ? t('Ja') : t('Nei')}</span>
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </>
  )
}
