'use client'
import { useEffect, useRef, useState } from 'react'
import Link from 'next/link'
import { kravTekst } from '@/lib/ikmat/standard'
import { loggMaaling } from '../handlinger'
import { useT } from '../../oversett-kontekst'
import type { Punkt, Logget } from './maaling-liste'

// =====================================================================
// NIVAA 3 — utfor. En enhet av gangen, med termometeret i den ene haanda.
//
// DET SOM VAR GALT: dette er stedet der jobben faktisk gjoeres — og det
// var lederens sideform. Sidehode, kort, og ALLE enhetene under
// hverandre med hvert sitt felt og hver sin Lagre-knapp. Hun maatte selv
// finne igjen hvilken rad hun sto paa etter hver lagring, mens hun holdt
// et termometer.
//
// Ruta sto dessuten ikke i noen bevisliste. Verken treffomraade,
// kontrast eller lekkasje ble maalt her, paa den ene flata der en
// feilskrevet temperatur er et mattilsynsavvik og ikke en skrivefeil.
//
// NAA: ett navn, ett krav, ett felt. Lagre, og neste enhet tar plassen.
//
// FORKLARINGEN KOMMER NAAR DEN TRENGS. Setningen om at et avvik
// opprettes automatisk sto oeverst paa sida, foer noen hadde maalt noe.
// Den staar naa i det oeyeblikket et tall faller utenfor kravet — der
// den betyr noe.
//
// OMRAADESJEKKEN ER KLIENTSIDENS, MEN IKKE FASIT. Den bestemmer bare
// naar tiltaksfeltet dukker opp. `loggMaaling` regner ut `innenfor` paa
// nytt fra basens egne grenser og nekter aa lagre et avvik uten
// strakstiltak. To beregninger, og serverens er den som gjelder.
// =====================================================================

function utenfor(temp: number, min: number | null, max: number | null) {
  return (min != null && temp < min) || (max != null && temp > max)
}

export function TabletMaaling({
  punkter,
  logget,
  frekvensEtikett,
}: {
  punkter: Punkt[]
  logget: Record<string, Logget>
  frekvensEtikett: string
}) {
  const t = useT()
  const [gjort, setGjort] = useState<Record<string, Logget>>(logget)
  const [temp, setTemp] = useState('')
  const [tiltak, setTiltak] = useState('')
  const [feil, setFeil] = useState<string | null>(null)
  const [venter, setVenter] = useState(false)
  const felt = useRef<HTMLInputElement>(null)

  const igjen = punkter.filter((p) => gjort[p.id] === undefined)
  const naa = igjen[0]
  const malt = punkter.length - igjen.length

  // AUTOFOKUS PER ENHET. Hun skal kunne maale, taste, lagre, maale igjen
  // uten aa treffe et felt med hansker mellom hver.
  //
  // Avhengigheten er ID-en, ikke objektet: neste enhet er en ny id i den
  // SAMME komponenten, og et objekt ville vaert nytt ved hver rendring
  // og stjaalet fokus mens hun skriver.
  const naaId = naa?.id
  useEffect(() => {
    if (naaId) felt.current?.focus()
  }, [naaId])

  if (punkter.length === 0) {
    return (
      <section className="tablet-seksjon">
        <p className="undertittel">{t('Ingen enheter i denne gruppen.')}</p>
      </section>
    )
  }

  const num = Number(temp.replace(',', '.'))
  const harTall = temp.trim() !== '' && Number.isFinite(num)
  const avvik = naa != null && harTall && utenfor(num, naa.min_temp, naa.max_temp)

  function lagre() {
    if (!naa) return
    setFeil(null)
    setVenter(true)
    loggMaaling(naa.id, temp, tiltak)
      .then((r) => {
        if (r.feil) { setFeil(r.feil); return }
        // Neste enhet tar plassen. Feltene toemmes her, ikke i en effekt:
        // en tom rute er beskjeden om at den forrige ER lagret.
        setGjort((g) => ({ ...g, [naa.id]: { temp: num, innenfor: !!r.innenfor } }))
        setTemp('')
        setTiltak('')
      })
      .catch(() => setFeil(t('Målingen ble ikke lagret. Prøv en gang til.')))
      .finally(() => setVenter(false))
  }

  return (
    <>
      {naa ? (
        <section className="tmaal" aria-labelledby="tmaal-navn">
          {/* EN SANN PROGRESJON. Ett tall, ingen konkurrerende linjer. */}
          <p className="tmaal-teller">{malt + 1} {t('av')} {punkter.length}</p>
          <h2 className="tmaal-navn" id="tmaal-navn">{naa.navn}</h2>
          <p className="tmaal-krav">{kravTekst(naa.min_temp, naa.max_temp)}</p>

          <div className="tmaal-felt">
            <input
              ref={felt}
              inputMode="decimal"
              value={temp}
              onChange={(e) => setTemp(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter' && harTall && !venter) lagre() }}
              placeholder="°C"
              aria-label={`${t('Temperatur')} ${naa.navn}`}
              className={avvik ? 'avvik' : ''}
            />
            <button type="button" onClick={lagre} disabled={venter || !harTall}>
              {venter ? t('Lagrer …') : t('Lagre')}
            </button>
          </div>

          {avvik && (
            <div className="tmaal-avvik">
              {/* IKKE STRAFF, MEN INSTRUKS. Hva er galt, hva maa gjoeres,
                  hva skjer naar jeg lagrer. Tre setninger, i den
                  rekkefolgen hun trenger dem. */}
              <p className="tmaal-avvik-tittel">{t('Utenfor kravet')}</p>
              <p className="undertittel">
                {t('Skriv hva du gjorde med en gang. Da opprettes avviket automatisk, og butikksjefen får beskjed.')}
              </p>
              <textarea
                value={tiltak}
                onChange={(e) => setTiltak(e.target.value)}
                rows={3}
                aria-label={t('Strakstiltak')}
                placeholder={t('Hva gjorde du med en gang?')}
              />
            </div>
          )}

          {feil && <p className="feil" role="alert">{feil}</p>}
        </section>
      ) : (
        <section className="tmaal tmaal-ferdig">
          <p className="tmaal-ferdig-tekst">{t('Alle')} {punkter.length} {t('målt')}</p>
          <p className="tmaal-ferdig-under">{frekvensEtikett} · {t('ferdig for i dag')}</p>
          <Link href="/rutiner" className="tmaal-videre">{t('Tilbake til vakta')}</Link>
        </section>
      )}

      {malt > 0 && (
        <section className="tablet-seksjon">
          <h2>{t('Målt i dag')} <span className="undertittel">· {malt}</span></h2>
          <ul className="rutine-liste">
            {punkter.filter((p) => gjort[p.id] !== undefined).map((p) => {
              const g = gjort[p.id]
              return (
                <li key={p.id} className={g.innenfor ? 'gjort' : ''}>
                  <span className={`kryss ${g.innenfor ? 'av' : ''}`} aria-hidden>{g.innenfor ? '✓' : ''}</span>
                  <span className="rutine-tekst">
                    <strong>{p.navn}</strong>
                    <span className="undertittel"> — {g.temp}°C</span>
                    {/* Avviket staar i ord. En farge alene ville forsvunnet
                        for den som ikke skiller roedt fra graatt. */}
                    {!g.innenfor && <span className="ikmat-utenfor">{t('utenfor kravet')}</span>}
                  </span>
                </li>
              )
            })}
          </ul>
        </section>
      )}
    </>
  )
}
