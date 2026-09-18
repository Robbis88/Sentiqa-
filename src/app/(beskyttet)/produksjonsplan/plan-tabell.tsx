'use client'
import { useRef, useState, useTransition } from 'react'
import { tall } from '@/lib/format'
import { setLinje, setNotat, publiser, setProsent } from './handlinger'
import { medMargin, startAntall, effektivProsent, STANDARD_KODE, type PlanForklaring, type ProduksjonsForklaring } from '@/lib/produksjonsplan'
import { Nokkeltall } from '@/components/ui/side'
import { Knapp } from '@/components/ui/knapp'
import { Status } from '@/components/ui/status'

export type Produkt = {
  varenavn: string
  baseline: number
  fjorMedian?: number | null
  nyligSnitt?: number | null
  faktor: number
  foreslatt: number
  planlagt: number
  start_antall: number
  ekskludert: boolean
  flagg?: string[]
  forklaring?: ProduksjonsForklaring & {
    selvlaertKorreksjon: number
    selvlaertAntall: number | null
    marginProsent: number
    startProsent: number
    automatiskForslag: number
    automatiskPlanlagt: number
    automatiskStart: number
    avvikerFraAutomatisk: boolean
    vaerfaktor: number
    trendfaktor: number
    arrangementFaktor: number
  }
}
export type Gruppe = { kode: string | null; navn: string; produkter: Produkt[] }

const FLAGG_MERKE: Record<string, { ikon: string; tekst: string }> = {
  fjor_kampanje: { ikon: '🚩', tekst: 'Mulig kampanjepåvirkning — uvanlig salgsutslag i fjoråret' },
  paagaaende_kampanje: { ikon: '🎯', tekst: 'Mulig kampanjepåvirkning — uvanlig nylig salgsutslag' },
  ny: { ikon: '✨', tekst: 'Nytt produkt — basert på nylig salg' },
  fa_data: { ikon: '⚠️', tekst: 'Lite historikk' },
}

export type Prosentpar = { start: number | null; margin: number | null }

export function PlanTabell({
  grupper, stasjonId, dato, notat: notatInit, publisertTid,
  prosent: prosentInit, gruppeAvvik: avvikInit,
  planForklaring,
}: {
  grupper: Gruppe[]
  stasjonId: string
  dato: string
  notat: string | null
  publisertTid: string | null
  /** Stasjonens standard (0149). */
  prosent: { start: number; margin: number }
  /** Avvik per varegruppekode. null i et felt = arv fra standarden. */
  gruppeAvvik: Record<string, Prosentpar>
  planForklaring?: PlanForklaring
}) {
  const alle = grupper.flatMap((g) => g.produkter)
  const lag = (felt: 'planlagt' | 'start_antall') => Object.fromEntries(alle.map((p) => [p.varenavn, p[felt]]))
  const [planlagt, setPlanlagt] = useState<Record<string, number>>(lag('planlagt'))
  const [start, setStart] = useState<Record<string, number>>(lag('start_antall'))
  const [ekskl, setEkskl] = useState<Set<string>>(() => new Set(alle.filter((p) => p.ekskludert).map((p) => p.varenavn)))
  const [notat, setNotatTekst] = useState(notatInit ?? '')
  const lagretNotat = useRef(notatInit ?? '')
  const [publisert, setPublisert] = useState<boolean>(!!publisertTid)
  const [melding, setMelding] = useState<string | null>(null)
  const [std, setStd] = useState(prosentInit)
  const [avvik, setAvvik] = useState<Record<string, Prosentpar>>(avvikInit)
  const [lagrer, setLagrer] = useState(false)
  const [feil, setFeil] = useState<string | null>(null)
  const [inputVersjon, setInputVersjon] = useState(0)
  const sender = useRef(false)
  const [, overgang] = useTransition()

  function bekreftet(skriv: () => Promise<void>) {
    if (sender.current) return
    sender.current = true
    setLagrer(true)
    setFeil(null)
    setMelding(null)
    overgang(async () => {
      try { await skriv() }
      catch { setFeil('Endringen ble ikke lagret. Prøv igjen.'); setMelding(null) }
      finally { sender.current = false; setLagrer(false); setInputVersjon((v) => v + 1) }
    })
  }

  function lagre(g: Gruppe, p: Produkt, over: { planlagt?: number; start_antall?: number; ekskludert?: boolean }) {
    const nyPlan = over.planlagt ?? planlagt[p.varenavn] ?? p.foreslatt
    const nyStart = over.start_antall ?? start[p.varenavn] ?? 0
    if (nyStart > nyPlan) {
      setFeil('Startpartiet kan ikke være større enn dagsplanen.')
      setInputVersjon((v) => v + 1)
      return
    }
    bekreftet(async () => {
      await setLinje({
        stasjon_id: stasjonId, dato, varenavn: p.varenavn, varegruppe_kode: g.kode, varegruppe_navn: g.navn,
        foreslatt: p.foreslatt,
        planlagt: nyPlan,
        start_antall: nyStart,
        ekskludert: over.ekskludert ?? ekskl.has(p.varenavn),
      })
      setPlanlagt((s) => ({ ...s, [p.varenavn]: nyPlan }))
      setStart((s) => ({ ...s, [p.varenavn]: nyStart }))
      if (over.ekskludert !== undefined) setEkskl((s) => {
        const c = new Set(s)
        if (over.ekskludert) c.add(p.varenavn); else c.delete(p.varenavn)
        return c
      })
      setMelding('Endringen er lagret')
    })
  }
  function endrePlan(g: Gruppe, p: Produkt, ny: number) {
    const v = Math.max(0, Math.round(ny || 0)); lagre(g, p, { planlagt: v })
  }
  function endreStart(g: Gruppe, p: Produkt, ny: number) {
    const v = Math.max(0, Math.round(ny || 0)); lagre(g, p, { start_antall: v })
  }
  function toggleEkskl(g: Gruppe, p: Produkt) {
    const ny = !ekskl.has(p.varenavn)
    lagre(g, p, { ekskludert: ny })
  }
  // Prosentene per gruppe, med arv loest. Brukes baade til visningen og
  // til «bruk paa hele planen».
  function forGruppe(kode: string | null) {
    const av = avvik[kode ?? ''] ?? { start: null, margin: null }
    return {
      start: effektivProsent(std.start, av.start),
      margin: effektivProsent(std.margin, av.margin),
    }
  }

  function endreStandard(felt: 'start' | 'margin', ny: number) {
    const v = Math.max(0, Math.min(felt === 'start' ? 99 : 100, Math.round(ny || 0)))
    const neste = { ...std, [felt]: v }
    bekreftet(async () => {
      await setProsent(stasjonId, STANDARD_KODE, neste)
      setStd(neste)
      setMelding('Driftsregelen er lagret')
    })
  }

  function endreGruppe(kode: string | null, felt: 'start' | 'margin', raa: string) {
    if (kode == null) return
    // Tomt felt betyr ARV, ikke null prosent. Skal gruppa faktisk ha
    // null, skriver man 0 — og da vinner den over standarden.
    const v = raa.trim() === ''
      ? null
      : Math.max(0, Math.min(felt === 'start' ? 99 : 100, Math.round(Number(raa.replace(/\D/g, '')) || 0)))
    const forrige = avvik[kode] ?? { start: null, margin: null }
    const neste = { ...forrige, [felt]: v }
    bekreftet(async () => {
      await setProsent(stasjonId, kode, neste)
      setAvvik((a) => ({ ...a, [kode]: neste }))
      setMelding('Driftsregelen er lagret')
    })
  }

  // BRUKER PROSENTENE PAA DAGENS PLAN, én gang, paa knappetrykk.
  //
  // Prosentene seeder nye plandager av seg selv. Denne knappen finnes
  // fordi en plan som ALT er laget ikke skal endre seg i stillhet naar
  // noen justerer en innstilling — da ville et lite dytt paa «planlagt»
  // flyttet «start» ogsaa, uten at noen ba om det.
  function brukPaaPlanen() {
    bekreftet(async () => {
      let rort = 0
      for (const g of grupper) {
        const { start: sPst, margin: mPst } = forGruppe(g.kode)
        for (const p of g.produkter) {
          if (ekskl.has(p.varenavn)) continue
          const nyPlan = medMargin(p.foreslatt, mPst)
          const nyStart = startAntall(nyPlan, sPst)
          await setLinje({
            stasjon_id: stasjonId, dato, varenavn: p.varenavn,
            varegruppe_kode: g.kode, varegruppe_navn: g.navn,
            foreslatt: p.foreslatt, planlagt: nyPlan, start_antall: nyStart,
            ekskludert: false,
          })
          setPlanlagt((s) => ({ ...s, [p.varenavn]: nyPlan }))
          setStart((s) => ({ ...s, [p.varenavn]: nyStart }))
          rort++
        }
      }
      setMelding(`${rort} produkter satt fra prosentene`)
    })
  }

  function publiserNa() {
    bekreftet(async () => {
      const linjer = grupper.flatMap((g) => g.produkter.map((p) => ({
        varenavn: p.varenavn, varegruppe_kode: g.kode, varegruppe_navn: g.navn,
        foreslatt: p.foreslatt, planlagt: planlagt[p.varenavn] ?? p.planlagt,
        start_antall: start[p.varenavn] ?? p.start_antall, ekskludert: ekskl.has(p.varenavn),
      })))
      const r = await publiser(stasjonId, dato, linjer, notat)
      if (!r.ok) { setFeil(r.feil ?? 'Planen ble ikke publisert. Prøv igjen.'); return }
      lagretNotat.current = notat
      setPublisert(true); setMelding('Publisert ✓')
    })
  }

  const aktive = (p: Produkt) => !ekskl.has(p.varenavn)
  const total = alle.filter(aktive).reduce((a, p) => a + (planlagt[p.varenavn] ?? 0), 0)
  const totalForeslatt = alle.filter(aktive).reduce((a, p) => a + p.foreslatt, 0)
  const totalStart = alle.filter(aktive).reduce((a, p) => a + (start[p.varenavn] ?? 0), 0)
  const medDato = (iso: string) => new Intl.DateTimeFormat('nb-NO', { day: 'numeric', month: 'short' }).format(new Date(`${iso}T12:00:00Z`))
  const medAntall = (n: number) => tall.format(Math.round(n))
  const medFaktor = (n: number) => `×${n.toFixed(2)}`
  const forklarbare = alle.filter((p) => p.forklaring)
  const vaerPaavirkede = forklarbare.filter((p) => p.forklaring?.vaerfaktor !== 1).length
  const muligeKampanjer = forklarbare.filter((p) => p.forklaring?.muligKampanjepavirkning).length
  const selvlaerte = forklarbare.filter((p) => p.forklaring && p.forklaring.selvlaertKorreksjon !== 1)

  return (
    <>
      {feil && <p className="feil" role="alert">{feil}</p>}
      {lagrer && <p className="undertittel" role="status">Lagrer …</p>}
      {/* TO TALL, IKKE TRE. «AI-forslag» stod som et eget nokkeltall ved
          siden av «Planlagt», og den eneste jobben det hadde var aa vaere
          noe aa sammenligne med. Naa ER det sammenligningen - tallet er
          fortsatt der, men det staar der det betyr noe.

          INGEN DOM. `bra` er ikke satt paa noen av dem: aa planlegge over
          eller under forslaget er ikke bra eller daarlig, det er
          butikksjefens vurdering. Farge her ville vaert systemet som
          mener noe det ikke har grunnlag for. */}
      <div className="sq-nokkelrad">
        <Nokkeltall
          merkelapp="Planlagt"
          verdi={`${tall.format(total)} stk`}
          sammenlignet={`mot forslagets ${tall.format(totalForeslatt)}`}
          retning={total > totalForeslatt ? 'opp' : total < totalForeslatt ? 'ned' : 'flat'}
        />
        <Nokkeltall
          merkelapp="Klart til morgenskift"
          verdi={`${tall.format(totalStart)} stk`}
          sammenlignet={`av ${tall.format(total)} planlagt`}
        />
      </div>

      {planForklaring && (
        <details className="sq-forklaring pp-forklaring">
          <summary>Hvorfor ser planen slik ut i dag?</summary>
          <div className="pp-forklaring-innhold">
            <p>
              Planen bruker historikk fra {planForklaring.fjorDatoer.length} sammenlignbare dag{planForklaring.fjorDatoer.length === 1 ? '' : 'er'}.
              {planForklaring.helligdag ? ` Måldagen sammenlignes med samme helligdag (${medDato(planForklaring.fjorDato)}).` : ' På vanlige dager brukes samme ukedag rundt fjorårsdatoen.'}
            </p>
            {planForklaring.trendfaktor !== 1 && <p>Det samlede produksjonssalget gir en trendjustering på {medFaktor(planForklaring.trendfaktor)}.</p>}
            {vaerPaavirkede > 0 && <p>Værforholdene påvirker {vaerPaavirkede} produkt{vaerPaavirkede === 1 ? '' : 'er'}.</p>}
            {planForklaring.arrangementFaktor !== 1 && <p>Bekreftede arrangementer påvirker planen med {medFaktor(planForklaring.arrangementFaktor)}.</p>}
            {muligeKampanjer > 0 && <p>Mulig kampanjepåvirkning: {muligeKampanjer} produkt{muligeKampanjer === 1 ? '' : 'er'} har et uvanlig salgsutslag i historikken.</p>}
            {selvlaerte.length > 0 && <p>Selvlært korreksjon er aktiv for {selvlaerte.length} produkt{selvlaerte.length === 1 ? '' : 'er'} basert på stasjonens egne treffmålinger.</p>}
            {forklarbare.length === 0 && <p>Forklaringsgrunnlag mangler for denne planen.</p>}
          </div>
        </details>
      )}

      {/* DRIFTSREGLENE. To tall et menneske setter, over hele planen.
          De seeder nye plandager av seg selv; knappen finnes for planen
          som alt er laget, som ikke skal endre seg i stillhet. */}
      <section className="kort pp-regler">
        <h2>Driftsregler for stasjonen</h2>
        <div className="pp-regelrad">
          <label className="felt pp-regel">
            <span>Klart til morgenskift</span>
            <span className="pp-regel-inn">
              <input
                key={`std-start:${inputVersjon}`} inputMode="numeric" defaultValue={std.start} disabled={lagrer}
                onBlur={(e) => { if (Number(e.target.value) !== std.start) endreStandard('start', Number(e.target.value.replace(/\D/g, ''))) }}
                aria-label="Andel klart til morgenskift, i prosent"
              />
              <span className="pp-regel-enhet">%</span>
            </span>
            <span className="undertittel">Rundes opp. 9 stk × 50 % blir 5.</span>
          </label>
          <label className="felt pp-regel">
            <span>Margin over forslaget</span>
            <span className="pp-regel-inn">
              <input
                key={`std-margin:${inputVersjon}`} inputMode="numeric" defaultValue={std.margin} disabled={lagrer}
                onBlur={(e) => { if (Number(e.target.value) !== std.margin) endreStandard('margin', Number(e.target.value.replace(/\D/g, ''))) }}
                aria-label="Margin over forslaget, i prosent"
              />
              <span className="pp-regel-enhet">%</span>
            </span>
            <span className="undertittel">Forslaget treffer forventet salg. Dette er påslaget du velger.</span>
          </label>
        </div>
        {/* HANDLINGEN UNDER REGLENE, IKKE I RADEN MED DEM. Den er ikke et
            tredje felt, og den har ingen etikett — sto den i feltraden,
            la den seg på en tredje høyde uansett justering.

            IKKE EN <Status>. Sida har én status — om planen er
            publisert — og den er det e2e-testen peker på. Dette er en
            forklaring til en knapp, ikke et signal om tilstand. Bruker
            man signalprimitivet til bildetekster, slutter det å bety
            noe. */}
        <div className="pp-regel-handling">
          {/* TEKSTEN STO FEIL VEI. «Bruk på hele planen / Endrer dagens
              tall nå» leste som «trykk her, ellers skjer ingenting» —
              og det motsatte er sant. Prosenten lagres i det den
              skrives, og serveren regner den inn i hver linje ingen har
              tatt stilling til, både i dag og på hver dag framover
              (`l?.planlagt ?? medMargin(...)` i page.tsx).

              Knappen finnes for det ENE tilfellet regelen ikke dekker:
              linjene noen HAR rørt. Den overskriver dem. Det er den ene
              tingen resten av sida verner om, så det må stå på knappen.

              Merk hva 0 % gjør: planlagt settes til forslaget på alle
              linjer, og `startAntall` returnerer 0 — hele morgenskiftet
              nulles. Derfor «skriv over», ikke «bruk». */}
          <Knapp onClick={brukPaaPlanen} disabled={lagrer}>Skriv over dagens tall</Knapp>
          <span className="undertittel">Også linjer du har justert selv</span>
        </div>
      </section>

      {grupper.map((g) => {
        const sum = g.produkter.filter(aktive).reduce((b, p) => b + (planlagt[p.varenavn] ?? 0), 0)
        return (
          <section className="kort" key={g.kode ?? g.navn}>
            <h2>{g.navn} <span className="undertittel">· {g.kode}</span> <span className="gruppe-sum">{tall.format(sum)} stk</span></h2>
            {/* Avvik for denne gruppa. Tomt felt = arv fra standarden;
                0 = null prosent, og det er et valg som vinner. */}
            {g.kode && (
              <div className="pp-gruppe-regel">
                <label>
                  <span>Start</span>
                  <input
                    inputMode="numeric" placeholder={`${std.start}`}
                    key={`gruppe-start:${inputVersjon}`} disabled={lagrer} defaultValue={avvik[g.kode]?.start ?? ''}
                    onBlur={(e) => { if (e.target.value !== String(avvik[g.kode!]?.start ?? '')) endreGruppe(g.kode, 'start', e.target.value) }}
                    aria-label={`Startprosent for ${g.navn}`}
                  />
                  <span className="pp-regel-enhet">%</span>
                </label>
                <label>
                  <span>Margin</span>
                  <input
                    inputMode="numeric" placeholder={`${std.margin}`}
                    key={`gruppe-margin:${inputVersjon}`} disabled={lagrer} defaultValue={avvik[g.kode]?.margin ?? ''}
                    onBlur={(e) => { if (e.target.value !== String(avvik[g.kode!]?.margin ?? '')) endreGruppe(g.kode, 'margin', e.target.value) }}
                    aria-label={`Marginprosent for ${g.navn}`}
                  />
                  <span className="pp-regel-enhet">%</span>
                </label>
                <span className="undertittel">Tomt felt arver stasjonens standard</span>
              </div>
            )}
            <table className="tabell pp-tabell">
              <thead>
                <tr><th>Produkt</th><th className="mob-skjul">Grunnlag</th><th className="mob-skjul">×</th><th>Forslag</th><th>Start</th><th>Planlagt</th><th></th></tr>
              </thead>
              <tbody>
                {g.produkter.map((p) => {
                  const ute = ekskl.has(p.varenavn)
                  return (
                    <tr key={p.varenavn} className={ute ? 'pp-ute' : ''}>
                      <td>
                        {p.varenavn}
                        {(p.flagg ?? []).map((fl) => FLAGG_MERKE[fl] ? <span key={fl} className="pp-flagg" title={FLAGG_MERKE[fl].tekst}> {FLAGG_MERKE[fl].ikon}</span> : null)}
                      </td>
                      <td className="mob-skjul">{tall.format(Math.round(p.baseline))}</td>
                      <td className="mob-skjul">{p.faktor.toFixed(2)}</td>
                      <td>{tall.format(p.foreslatt)}</td>
                      <td>
                        <div className="stepper liten">
                          <button type="button" disabled={ute || lagrer} onClick={() => endreStart(g, p, (start[p.varenavn] ?? 0) - 1)} aria-label="Mindre start">−</button>
                          <input key={`start:${inputVersjon}`} inputMode="numeric" disabled={ute || lagrer} defaultValue={start[p.varenavn] ?? 0} onBlur={(e) => { if (Number(e.target.value) !== start[p.varenavn]) endreStart(g, p, Number(e.target.value.replace(/\D/g, ''))) }} aria-label={`Start ${p.varenavn}`} />
                          <button type="button" disabled={ute || lagrer} onClick={() => endreStart(g, p, (start[p.varenavn] ?? 0) + 1)} aria-label="Mer start">+</button>
                        </div>
                      </td>
                      <td>
                        <div className="stepper">
                          <button type="button" disabled={ute || lagrer} onClick={() => endrePlan(g, p, (planlagt[p.varenavn] ?? 0) - 1)} aria-label="Mindre">−</button>
                          <input key={`plan:${inputVersjon}`} inputMode="numeric" disabled={ute || lagrer} defaultValue={planlagt[p.varenavn] ?? 0} onBlur={(e) => { if (Number(e.target.value) !== planlagt[p.varenavn]) endrePlan(g, p, Number(e.target.value.replace(/\D/g, ''))) }} aria-label={`Planlagt ${p.varenavn}`} />
                          <button type="button" disabled={ute || lagrer} onClick={() => endrePlan(g, p, (planlagt[p.varenavn] ?? 0) + 1)} aria-label="Mer">+</button>
                        </div>
                      </td>
                      <td>
                        {p.forklaring && (
                          <details className="pp-produkt-forklaring">
                            <summary aria-label={`Hvorfor ${p.varenavn}?`}>Hvorfor?</summary>
                            <div className="pp-produkt-forklaring-innhold">
                              <p><strong>Automatisk forslag:</strong> {medAntall(p.forklaring.automatiskForslag)} stk</p>
                              {p.forklaring.fjor.some((r) => r.antall > 0)
                                ? <p><strong>Fjorårsdager:</strong> {p.forklaring.fjor.filter((r) => r.antall > 0).map((r) => `${medDato(r.dato)} ${medAntall(r.antall)}`).join(', ')}. Median: {p.fjorMedian != null ? medAntall(p.fjorMedian) : 'mangler'}.</p>
                                : <p><strong>Fjorår:</strong> Mangler salg for sammenlignbare dager.</p>}
                              {p.forklaring.nylig.length > 0
                                ? <p><strong>Nylig salg:</strong> {p.forklaring.nylig.filter((r) => r.sammeUkedag).length >= 2 ? 'samme ukedag siste 28 dager' : 'siste 28 dager'}: {p.forklaring.nylig.map((r) => `${medDato(r.dato)} ${medAntall(r.antall)}`).join(', ')}{p.nyligSnitt != null ? `. Snitt: ${medAntall(p.nyligSnitt)}.` : '.'}</p>
                                : <p><strong>Nylig salg:</strong> Mangler historikk.</p>}
                              {p.forklaring.trendfaktor !== 1 && <p><strong>Trendjustering:</strong> {medFaktor(p.forklaring.trendfaktor)}.</p>}
                              {p.forklaring.vaerfaktor !== 1 && <p><strong>Værjustering:</strong> {medFaktor(p.forklaring.vaerfaktor)}.</p>}
                              {p.forklaring.arrangementFaktor !== 1 && <p><strong>Arrangement:</strong> {medFaktor(p.forklaring.arrangementFaktor)}.</p>}
                              {p.forklaring.muligKampanjepavirkning && <p><strong>Mulig kampanjepåvirkning:</strong> uvanlig salgsutslag oppdaget i {p.forklaring.muligKampanjepavirkning === 'fjor' ? 'fjoråret' : 'nylig salg'}.</p>}
                              {p.forklaring.selvlaertKorreksjon !== 1 && <p><strong>Selvlært korreksjon:</strong> {medFaktor(p.forklaring.selvlaertKorreksjon)}{p.forklaring.selvlaertAntall != null ? `, basert på ${p.forklaring.selvlaertAntall} målinger` : ''}.</p>}
                              {p.forklaring.marginProsent > 0 && <p><strong>Margin:</strong> {p.forklaring.marginProsent} % → {medAntall(p.forklaring.automatiskPlanlagt)} stk planlagt.</p>}
                              {(p.forklaring.startProsent > 0 || (start[p.varenavn] ?? p.start_antall) !== p.forklaring.automatiskStart) && <p><strong>Klart til morgenskift:</strong> {p.forklaring.startProsent} % → {medAntall(p.forklaring.automatiskStart)} stk automatisk, {medAntall(start[p.varenavn] ?? p.start_antall)} stk i planen.</p>}
                              {p.forklaring.avvikerFraAutomatisk && <p>Planlagt antall avviker fra dagens automatiske forslag.</p>}
                              <p><strong>Endelig planlagt:</strong> {medAntall(planlagt[p.varenavn] ?? p.planlagt)} stk.</p>
                            </div>
                          </details>
                        )}
                        <button type="button" disabled={lagrer} className="pp-ekskl" onClick={() => toggleEkskl(g, p)} title={ute ? 'Ta med igjen' : 'Ekskluder fra planen'}>{ute ? '↩' : '✕'}</button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </section>
        )
      })}

      {/* NIVAA 2: neste steg.
          Knappen stod naken her - uten variant, blant fem andre knapper
          som saa likere ut enn de var. Nettbrettet ser ingenting for den
          er trykket, saa dette ER handlingen sida sikter mot, og den
          eneste som skal se sann ut.

          NOTATET HADDE INGEN ETIKETT. Overskriften over sa hva feltet
          var, men den var en <h2> - ikke knyttet til feltet, og dermed
          usynlig for en skjermleser som staar i det. Plassholderen
          forsvinner idet man begynner aa skrive. */}
      <section className="kort">
        <h2>Notat til de ansatte</h2>
        <label className="felt" htmlFor="pp-notat">
          <span className="sq-skjult">Notat til de ansatte</span>
          <textarea
            id="pp-notat"
            className="pp-notat" rows={2} value={notat} disabled={lagrer} placeholder="F.eks. «Ekstra fokus på baguetter til lunsj»"
            onChange={(e) => setNotatTekst(e.target.value)}
            onBlur={(e) => {
              // Publisering tar med notatet i samme atomiske snapshot.
              if (lagretNotat.current === notat || e.relatedTarget?.closest('.pp-publiser')) return
              bekreftet(async () => {
                await setNotat(stasjonId, dato, notat)
                lagretNotat.current = notat
                setMelding('Notatet er lagret')
              })
            }}
          />
        </label>
        <div className="pp-publiser">
          <Knapp variant="primar" onClick={publiserNa} disabled={lagrer}>
            {publisert ? 'Publiser på nytt' : 'Publiser til nettbrettet'}
          </Knapp>
          <Status nivaa={publisert ? 'normal' : 'handling'}>
            {publisert ? 'Synlig på nettbrettet' : 'Ikke publisert ennå'}
          </Status>
          {melding && <span className="generer-melding">{melding}</span>}
        </div>
      </section>
    </>
  )
}
