import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { BUTIKKSJEF_PERSONAL_KODER } from './regnskap-tilgang'
import { SKJUL_OMS_KODER as SKJUL_OMS } from './avdelinger'

// Deterministisk regel-motor: «varsle admin om ALT som ikke er bra» rett etter
// opplastet regnskap. Ingen AI — kjører umiddelbart på lagrede tall, kan aldri
// time ut. Dekker selskap (cluster), nøkkeltall per stasjon, og usynlig/synlig
// svinn per varegruppe. Fortegn usynlig: + = manko (tap), − = overskudd (feilslag).

export type VarselNiva = 'rod' | 'gul'
// gruppe styrer rekkefølge: 0 selskap, 1 nøkkeltall per stasjon, 2 svinn per vare.
export type RegnskapVarsel = {
  nivaa: VarselNiva
  omfang: string // 'Selskap' eller stasjonsnavn
  tittel: string
  detalj: string
  vekt: number // |beløp| for sortering innen gruppe
  gruppe: number
}

import { TERSKLER } from './regnskap/terskler'
const T = TERSKLER

type Linje = { stasjon_id: string | null; seksjon: string; kode: string | null; post: string; regnskap: number | null; budsjett: number | null; avvik: number | null; index_pct: number | null }
type Svinn = { stasjon_id: string | null; kode: string | null; navn: string; salg: number | null; usynlig_kr: number | null; usynlig_pst: number | null; kast: number | null }

const kr0 = (n: number) => `${Math.round(n).toLocaleString('nb-NO')} kr`
const pst1 = (n: number) => `${n.toFixed(1)} %`

// Vurderingen er HITTIL I ÅR (ny start hvert år): summen jan→valgt periode, slik
// at en enkelt minus-måned som netter ut over året ikke flagges. Status (rød/
// gul/grønn) skal speile den røde tråden — ikke en tilfeldig måned.
// =====================================================================
// VAREGRUPPER SOM MOTPOSTERER HVERANDRE
//
// Roberts regel, foerst skrevet ned 2026-08-23: kaffen forsvinner fra
// lageret og gir manko paa 13010. Slaas utdelingen inn, gir den et
// tilsvarende OVERSKUDD paa 13011. Te hoerer med i samme familie - folk
// tar te gratis ogsaa. Samme form paa vask: 21014 MASKINVASK APP selger
// vasken, 21010 MASKINVASK forbruker den.
//
// Maalt paa Boenes, juli 2026:
//
//   13010 KAFFE          + 8 783      13011 KAFFELOJALITET  - 5 328
//   21010 MASKINVASK     + 7 964      21014 MASKINVASK APP  -22 592
//
// Varsellista viste bare de positive. Maskinvask sto som roedt varsel paa
// 7 964 kr mens gruppa hadde 14 628 kr i OVERSKUDD, og kaffe sto oeverst
// hver maaned paa et tall som var mer enn halvert av sin egen motpost.
//
// `left(kode, 3)` er avdelingen - samme noekkel `v_kaffe_svinn` (0126)
// bruker for aa nette hele varm drikke, te inkludert.
//
// IKKE EN GENERELL REGEL. Bare de to avdelingene Robert har bekreftet.
// En ny avdeling skal ikke bli netto-vurdert fordi den tilfeldigvis har
// to varegrupper - da ville en ekte manko kunne skjules av et urelatert
// overskudd i naborgruppen.
// =====================================================================
export const MOTPOSTER: Record<string, string> = {
  '130': 'Varm drikke (kaffe, te og lojalitet)',
  '210': 'Vask (maskin og app)',
}

/** Hoerer varegruppen til en avdeling som motposterer seg selv? */
export function erMotpost(kode: string | null): boolean {
  return (kode ?? '').slice(0, 3) in MOTPOSTER
}

export type Motpostgruppe = {
  stasjonId: string
  avdeling: string
  navn: string
  kr: number
  salg: number
  pst: number
}

/** Summerer motpost-avdelingene per stasjon, saa nettoen vurderes. */
export function nettMotposter(
  svinn: { stasjon_id: string | null; kode: string | null; salg: number | null; usynlig_kr: number | null }[],
): Motpostgruppe[] {
  const ut = new Map<string, Motpostgruppe>()
  for (const s of svinn) {
    const avd = (s.kode ?? '').slice(0, 3)
    if (!s.stasjon_id || !(avd in MOTPOSTER)) continue
    const noekkel = `${s.stasjon_id}|${avd}`
    const f = ut.get(noekkel) ?? {
      stasjonId: s.stasjon_id, avdeling: avd, navn: MOTPOSTER[avd], kr: 0, salg: 0, pst: 0,
    }
    f.kr += s.usynlig_kr ?? 0
    f.salg += s.salg ?? 0
    ut.set(noekkel, f)
  }
  for (const g of ut.values()) g.pst = g.salg > 0 ? (g.kr / g.salg) * 100 : 0
  return [...ut.values()]
}

export async function hentRegnskapVarsler(
  supabase: SupabaseClient,
  retailerId: string,
  periode: string,
): Promise<RegnskapVarsel[]> {
  const fra = `${periode.slice(0, 4)}-01-01` // ny start hvert år
  type SumRad = { stasjon_id: string | null; seksjon: string; kode: string | null; post: string; sortering: number | null; regnskap: number | null; budsjett: number | null }
  type SvinnRad = { stasjon_id: string | null; kode: string | null; navn: string; salg: number | null; usynlig_kr: number | null; kast: number | null }
  // SJEKKER `error`. `svinn_sum` manglet i produksjon fordi `0065` var
  // kjort halvveis, og varslene var stille i maanedsvis - ikke fordi det
  // ikke var svinn, men fordi kallet feilet og ingen saa det.
  const [
    { data: sumLinjer, error: linjeFeil },
    { data: stasjoner },
    { data: sumSvinn, error: svinnFeil },
  ] = await Promise.all([
    supabase.rpc('regnskap_sum', { p_fra: fra, p_til: periode }),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    supabase.rpc('svinn_sum', { p_fra: fra, p_til: periode }),
  ])

  // KASTER framfor aa returnere tomt. Et varsel som mangler fordi
  // kallet feilet, ser ut som fravaer av avvik - og det er den farligste
  // formen for stillhet i et regnskap.
  if (linjeFeil) throw new Error(`regnskap_sum feilet: ${linjeFeil.message}`)
  if (svinnFeil) throw new Error(`svinn_sum feilet: ${svinnFeil.message}`)

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const alle: Linje[] = ((sumLinjer ?? []) as SumRad[]).map((r) => ({
    ...r, avvik: (r.regnskap ?? 0) - (r.budsjett ?? 0),
    index_pct: r.budsjett ? (((r.regnskap ?? 0) - r.budsjett) / r.budsjett) * 100 : null,
  }))
  const svinn: Svinn[] = ((sumSvinn ?? []) as SvinnRad[]).map((s) => ({
    ...s, usynlig_pst: s.salg ? ((s.usynlig_kr ?? 0) / s.salg) * 100 : 0,
  }))
  const cluster = alle.filter((l) => l.stasjon_id == null)
  const v: RegnskapVarsel[] = []
  const legg = (nivaa: VarselNiva, omfang: string, tittel: string, detalj: string, vekt: number, gruppe: number) =>
    v.push({ nivaa, omfang, tittel, detalj, vekt, gruppe })

  // ── Selskap (cluster-P&L) ───────────────────────────────────────────────
  const finn = (seksjon: string, re: RegExp) => cluster.find((l) => l.seksjon === seksjon && re.test(l.post))

  const omsTot = finn('omsetning', /^omsetning totalt/i)
  if (omsTot?.index_pct != null) {
    const i = omsTot.index_pct
    if (i <= T.omsRod) legg('rod', 'Selskap', `Omsetning ${pst1(i)} mot budsjett`, `Hele kjeden ligger ${kr0(Math.abs(omsTot.avvik ?? 0))} under budsjett.`, Math.abs(omsTot.avvik ?? 0), 0)
    else if (i <= T.omsGul) legg('gul', 'Selskap', `Omsetning ${pst1(i)} mot budsjett`, `Litt under budsjett (${kr0(Math.abs(omsTot.avvik ?? 0))}).`, Math.abs(omsTot.avvik ?? 0), 0)
  }

  const brfTot = finn('bruttofortjeneste', /^bruttofortjeneste/i)
  if (brfTot?.index_pct != null && brfTot.index_pct <= T.brfGul) {
    legg('gul', 'Selskap', `Bruttofortjeneste ${pst1(brfTot.index_pct)} mot budsjett`, `BRF ligger ${kr0(Math.abs(brfTot.avvik ?? 0))} under budsjett.`, Math.abs(brfTot.avvik ?? 0), 0)
  }

  const driftTot = finn('driftskostnader', /totalt|^sum|^driftskostnader/i)
  if (driftTot && driftTot.regnskap != null && driftTot.budsjett && driftTot.budsjett > 0) {
    const over = ((driftTot.regnskap - driftTot.budsjett) / driftTot.budsjett) * 100
    if (over >= T.driftRod) legg('rod', 'Selskap', `Driftskostnader ${pst1(over)} over budsjett`, `${kr0(driftTot.regnskap - driftTot.budsjett)} høyere enn budsjettert.`, driftTot.regnskap - driftTot.budsjett, 0)
    else if (over >= T.driftGul) legg('gul', 'Selskap', `Driftskostnader ${pst1(over)} over budsjett`, `${kr0(driftTot.regnskap - driftTot.budsjett)} over budsjett.`, driftTot.regnskap - driftTot.budsjett, 0)
  }

  // Driftsresultat: bruk RESULTAT EX 9900 (uten admin-stasjon) — som KPI/AI.
  // Total-RESULTAT inkluderer 9900/finans og kan være negativ strukturelt.
  const resEx = finn('resultat', /resultat ex 9900/i) ?? finn('resultat', /^resultat$/i)
  if (resEx) {
    if ((resEx.regnskap ?? 0) < 0) legg('rod', 'Selskap', 'Negativt driftsresultat', `Resultat (ex 9900) er ${kr0(resEx.regnskap ?? 0)} hittil i år.`, Math.abs(resEx.regnskap ?? 0), 0)
    else if ((resEx.avvik ?? 0) <= T.resGul) legg('gul', 'Selskap', 'Driftsresultat under budsjett', `${kr0(Math.abs(resEx.avvik ?? 0))} svakere enn budsjettert.`, Math.abs(resEx.avvik ?? 0), 0)
  }

  // ── Per stasjon (nøkkeltall) ────────────────────────────────────────────
  const perStasjon = new Map<string, Linje[]>()
  for (const l of alle) {
    if (l.stasjon_id == null || !navnFor.has(l.stasjon_id)) continue
    const liste = perStasjon.get(l.stasjon_id) ?? []
    liste.push(l)
    perStasjon.set(l.stasjon_id, liste)
  }

  for (const [id, liste] of perStasjon) {
    const navn = navnFor.get(id)!
    // Omsetning/BRF: summer basis-avdelinger eks drivstoff/pant/CR (ingen dobbel).
    const total = (seksjon: string) => {
      const ls = liste.filter((l) => l.seksjon === seksjon && !SKJUL_OMS.has(l.kode ?? ''))
      return { r: ls.reduce((a, l) => a + (l.regnskap ?? 0), 0), b: ls.reduce((a, l) => a + (l.budsjett ?? 0), 0) }
    }
    const { r: omsR, b: omsB } = total('omsetning')
    const { r: brfR, b: brfB } = total('bruttofortjeneste')
    const personalLinjer = liste.filter((l) => l.seksjon === 'driftskostnader' && BUTIKKSJEF_PERSONAL_KODER.has(l.kode ?? ''))
    const lonnR = personalLinjer.reduce((a, l) => a + (l.regnskap ?? 0), 0)
    const lonnB = personalLinjer.reduce((a, l) => a + (l.budsjett ?? 0), 0)

    if (omsB > 0) {
      const i = ((omsR - omsB) / omsB) * 100
      if (i <= T.omsRod) legg('rod', navn, `Omsetning ${pst1(i)} mot budsjett`, `${kr0(Math.abs(omsR - omsB))} under budsjett.`, Math.abs(omsR - omsB), 1)
      else if (i <= T.omsGul) legg('gul', navn, `Omsetning ${pst1(i)} mot budsjett`, `${kr0(Math.abs(omsR - omsB))} under budsjett.`, Math.abs(omsR - omsB), 1)
    }

    // Lønn MOT LØNNSBUDSJETT (ikke mot omsetning/BRF). To budskap:
    // (1) over lønnsbudsjett → skjerp; (2) brukt lønnsbudsjett men brutto under.
    if (lonnB > 0) {
      const avvik = lonnR - lonnB
      const lonnPst = (avvik / lonnB) * 100
      const brfPst = brfB > 0 ? ((brfR - brfB) / brfB) * 100 : 0
      if (lonnPst >= T.lonnOverRod) {
        legg('rod', navn, `Lønn ${pst1(lonnPst)} over budsjett`, `Personalkostnad ${kr0(lonnR)} mot lønnsbudsjett ${kr0(lonnB)} — ${kr0(avvik)} over. Skjerp bemanning/vaktplan.`, Math.abs(avvik), 1)
      } else if (lonnPst >= T.lonnOverGul) {
        legg('gul', navn, `Lønn ${pst1(lonnPst)} over budsjett`, `Personalkostnad ${kr0(lonnR)} mot lønnsbudsjett ${kr0(lonnB)} — ${kr0(avvik)} over.`, Math.abs(avvik), 1)
      } else if (lonnPst >= -10 && brfPst <= T.lonnBruttoMiss && brfB > 0) {
        // Brukte (nær) hele lønnsbudsjettet, men leverer ikke brutto.
        legg('gul', navn, `Lønn brukt, men brutto ${pst1(brfPst)} under budsjett`, `Bruker lønnsbudsjettet (${kr0(lonnR)} av ${kr0(lonnB)}), men bruttofortjenesten ligger ${kr0(Math.abs(brfR - brfB))} under budsjett — bemanningen leverer ikke nok salg/brutto.`, Math.abs(brfR - brfB), 1)
      }
    }

    // Bruk RESULTAT EX 9900 (før eierlønn) — ellers flagges «tap» feilaktig når
    // eierlønnen 9900 er trukket fra. Faller tilbake til total-RESULTAT.
    const res = liste.find((l) => l.seksjon === 'resultat' && /resultat ex 9900/i.test(l.post))
      ?? liste.find((l) => l.seksjon === 'resultat' && /^resultat$/i.test(l.post))
    if (res && (res.regnskap ?? 0) < 0) {
      const andel = omsR > 0 ? Math.abs((res.regnskap ?? 0) / omsR) * 100 : 0
      legg('rod', navn, 'Negativt resultat', `${kr0(res.regnskap ?? 0)}${andel ? ` (${andel.toFixed(1)} % av omsetning)` : ''}.`, Math.abs(res.regnskap ?? 0), 1)
    }
  }

  // ── Svinn per varegruppe (per stasjon) ──────────────────────────────────
  //
  // Se `nettMotposter` over: gruppene summeres foer de vurderes.
  const grupper = nettMotposter(svinn ?? [])

  for (const g of grupper) {
    const navn = navnFor.get(g.stasjonId)
    if (!navn) continue
    if (g.kr > 0 && (g.kr >= T.mankoGul || g.pst >= T.mankoPstGul)) {
      const rod = g.kr >= T.mankoRod || (g.pst >= T.mankoPstRod && g.kr >= T.mankoGul)
      legg(rod ? 'rod' : 'gul', navn, `${g.navn}: ${kr0(g.kr)} usynlig manko`,
        `${Math.round(g.pst)} % av salg — samlet for gruppen, etter at `
        + 'motpostene er trukket fra.', g.kr, 2)
    }
    // Netto overskudd er ikke et funn her. I en gruppe som motposterer
    // seg selv er et minus normaltilstanden naar utdelingen er slaatt
    // inn - det er nettopp det som skal skje.
  }

  for (const s of svinn ?? []) {
    const navn = s.stasjon_id ? navnFor.get(s.stasjon_id) : null
    if (!navn) continue
    // Medlemmene er alt vurdert samlet over.
    if (erMotpost(s.kode ?? null)) continue
    const krV = s.usynlig_kr ?? 0
    const pstV = s.usynlig_pst ?? 0

    if (krV > 0 && (krV >= T.mankoGul || pstV >= T.mankoPstGul)) {
      // Rød krever reelt beløp: ≥15k, eller ≥10 % AND ≥5k. Smått = gul (flagges, men ikke rødt).
      const rod = krV >= T.mankoRod || (pstV >= T.mankoPstRod && krV >= T.mankoGul)
      legg(rod ? 'rod' : 'gul', navn, `${s.navn}: ${kr0(krV)} usynlig manko`, `${Math.round(pstV)} % av salg — penger/varer borte etter telling.`, krV, 2)
    } else if (krV < 0 && (-krV >= T.overskudd || -pstV >= T.overskuddPst)) {
      legg('gul', navn, `${s.navn}: ${kr0(krV)} usynlig overskudd`, `Uforklart overskudd — ofte feilslag/registrering på kassa.`, -krV, 2)
    }

    const kast = s.kast ?? 0
    const salg = s.salg ?? 0
    if (kast >= T.kast && salg > 0 && (kast / salg) * 100 >= T.kastPst) {
      legg('gul', navn, `${s.navn}: ${kr0(kast)} kastet/synlig svinn`, `${((kast / salg) * 100).toFixed(1)} % av salget kastes.`, kast, 2)
    }
  }

  // Rød først, så gruppe (selskap → nøkkeltall → svinn), så størst beløp øverst.
  const niv = (x: RegnskapVarsel) => (x.nivaa === 'rod' ? 0 : 1)
  return v.sort((a, b) => niv(a) - niv(b) || a.gruppe - b.gruppe || b.vekt - a.vekt)
}
