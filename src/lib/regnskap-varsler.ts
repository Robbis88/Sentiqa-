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

// Terskler — alt justerbart på ett sted.
const T = {
  omsRod: -10, omsGul: -3, // omsetning, index % under budsjett
  driftRod: 10, driftGul: 3, // driftskostnader, % over budsjett
  brfGul: -5, // bruttofortjeneste, index % under budsjett
  resGul: -10_000, // resultat, kr under budsjett (men positivt)
  lonnOverRod: 10, lonnOverGul: 5, // lønn over LØNNSBUDSJETT i % (St1 setter budsjett)
  lonnBruttoMiss: -3, // brutto under budsjett % når lønnsbudsjettet er brukt
  mankoRod: 15_000, mankoGul: 5_000, mankoPstRod: 10, mankoPstGul: 4,
  overskudd: 5_000, overskuddPst: 4,
  kast: 4_000, kastPst: 3,
}

type Linje = { stasjon_id: string | null; seksjon: string; kode: string | null; post: string; regnskap: number | null; budsjett: number | null; avvik: number | null; index_pct: number | null }
type Svinn = { stasjon_id: string | null; navn: string; salg: number | null; usynlig_kr: number | null; usynlig_pst: number | null; kast: number | null }

const kr0 = (n: number) => `${Math.round(n).toLocaleString('nb-NO')} kr`
const pst1 = (n: number) => `${n.toFixed(1)} %`

export async function hentRegnskapVarsler(
  supabase: SupabaseClient,
  retailerId: string,
  periode: string,
): Promise<RegnskapVarsel[]> {
  const [{ data: linjer }, { data: stasjoner }, { data: svinn }] = await Promise.all([
    supabase.from('regnskapslinjer').select('stasjon_id, seksjon, kode, post, regnskap, budsjett, avvik, index_pct').eq('retailer_id', retailerId).eq('periode', periode).is('slettet_tid', null).overrideTypes<Linje[]>(),
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null),
    supabase.from('regnskap_usynlig_svinn').select('stasjon_id, navn, salg, usynlig_kr, usynlig_pst, kast').eq('retailer_id', retailerId).eq('periode', periode).is('slettet_tid', null).overrideTypes<Svinn[]>(),
  ])

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const alle = linjer ?? []
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
    if ((resEx.regnskap ?? 0) < 0) legg('rod', 'Selskap', 'Negativt driftsresultat', `Resultat (ex 9900) er ${kr0(resEx.regnskap ?? 0)} denne perioden.`, Math.abs(resEx.regnskap ?? 0), 0)
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
  for (const s of svinn ?? []) {
    const navn = s.stasjon_id ? navnFor.get(s.stasjon_id) : null
    if (!navn) continue
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
