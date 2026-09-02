import { describe, it, expect } from 'vitest'
import { hentHjemData } from './tablethjem'

// =====================================================================
// «Mat og drikke» skal vaere mat og drikke.
//
// Fanen het «Samlet» og summerte `omsetning` - alt butikksalg uten
// drivstoff. Kiosk, tobakk, bilvask, bil, fritid og pant laa altsaa inne
// i tallet stasjonen ble maalt paa mot fjoraaret, og en god uke paa
// tobakk kunne dekke over en daarlig uke paa mat.
//
// Robert 2026-08-24: «det skal kun vaere mat og drikke som maales her
// mot salget i fjor.» Avdeling 120 + 140.
// =====================================================================

type Rad = { dato: string; mat_omsetning: number; kald_drikke_omsetning: number }

/**
 * Klient som svarer paa spoerringene `hentHjemData` gjoer.
 * Bare salgsradene betyr noe her; resten skal bare ikke velte.
 *
 * `skills_score` og `pengepremie_bruk` leses ikke lenger som TABELLER
 * (0165) - nettbrettet ville faatt lederens kommentar og hva pengene gikk
 * til paa kjoepet. De to tallene kommer fra `hjem_stasjonstall`, og
 * `rpc` under er derfor en del av fasiten, ikke pynt.
 */
function fakeKlient(salg: Rad[]) {
  const sett = new Set<string>()
  const svar: Record<string, unknown> = {
    pengepremie: [],
    v_salg_per_stasjon_dag: salg,
    produksjonsplan_hode: null,
    produksjonsplan_linjer: [],
  }
  const bygg = (tabell: string, valgt: { felt?: string }) =>
    new Proxy({} as Record<string, unknown>, {
      get(_t, prop) {
        if (prop === 'then') {
          const d = svar[tabell]
          return (ok: (v: unknown) => unknown) =>
            Promise.resolve({ data: d ?? null, error: null }).then(ok)
        }
        if (prop === 'select') {
          return (felt: string) => {
            valgt.felt = felt
            return bygg(tabell, valgt)
          }
        }
        return () => bygg(tabell, valgt)
      },
    })

  const valgtePerTabell: Record<string, { felt?: string }> = {}
  return {
    klient: {
      from(tabell: string) {
        sett.add(tabell)
        valgtePerTabell[tabell] ??= {}
        return bygg(tabell, valgtePerTabell[tabell])
      },
      rpc(navn: string) {
        sett.add(`rpc:${navn}`)
        return {
          maybeSingle: async () => ({
            data: { skills_prosent: null, premie_brukt_kr: 0 }, error: null,
          }),
        }
      },
    },
    sett,
    valgtePerTabell,
  }
}

const rad = (dato: string, mat: number, drikke: number): Rad => ({
  dato,
  mat_omsetning: mat,
  kald_drikke_omsetning: drikke,
})

async function vekst(salg: Rad[]) {
  const { klient, valgtePerTabell } = fakeKlient(salg)
  const d = await hentHjemData(klient as never, 'stasjon-1')
  return { vekst: d.vekst, felt: valgtePerTabell['v_salg_per_stasjon_dag']?.felt ?? '' }
}

describe('vekstkortet maaler mat og kald drikke', () => {
  it('summerer avdeling 120 og 140, ikke hele butikken', async () => {
    // 2026-08-23 og fjoraarets samme ukedag, 364 dager foer.
    const { vekst: v } = await vekst([rad('2026-08-23', 100, 40), rad('2025-08-24', 80, 20)])
    expect(v?.metrikker.matOgDrikke.sisteDag.iAar).toBe(140)
    expect(v?.metrikker.matOgDrikke.sisteDag.iFjor).toBe(100)
  })

  it('mat og kald drikke staar fortsatt hver for seg', async () => {
    const { vekst: v } = await vekst([rad('2026-08-23', 100, 40), rad('2025-08-24', 80, 20)])
    expect(v?.metrikker.mat.sisteDag.iAar).toBe(100)
    expect(v?.metrikker.kaldDrikke.sisteDag.iAar).toBe(40)
  })

  it('summen er nøyaktig de to fanene ved siden av', async () => {
    const { vekst: v } = await vekst([rad('2026-08-23', 137, 63), rad('2025-08-24', 90, 10)])
    const m = v!.metrikker
    expect(m.matOgDrikke.sisteDag.iAar).toBe(m.mat.sisteDag.iAar + m.kaldDrikke.sisteDag.iAar)
  })

  it('taaler at en avdeling mangler for dagen', async () => {
    const { vekst: v } = await vekst([
      { dato: '2026-08-23', mat_omsetning: 50, kald_drikke_omsetning: null as never },
      rad('2025-08-24', 40, 5),
    ])
    expect(v?.metrikker.matOgDrikke.sisteDag.iAar).toBe(50)
  })

  // KANARIFUGL, OG DEN ER HELE POENGET.
  //
  // Hentes `omsetning` inn igjen, er det ingenting i regnestykket som
  // sier fra - `beregn` ville bare faatt et stoerre tall, og kortet ville
  // sett helt normalt ut. Derfor maales SPOERRINGEN: kolonnen som
  // summerer hele butikken skal ikke engang komme over nettverket.
  it('kanarifugl: `omsetning` hentes ikke i det hele tatt', async () => {
    const { felt } = await vekst([rad('2026-08-23', 10, 5)])
    expect(felt).toContain('mat_omsetning')
    expect(felt).toContain('kald_drikke_omsetning')
    expect(felt.split(/[\s,]+/)).not.toContain('omsetning')
  })

  it('gir null vekst naar det ikke finnes salg', async () => {
    const { vekst: v } = await vekst([])
    expect(v).toBeNull()
  })
})

// =====================================================================
// NETTBRETTET SER TALLET, IKKE VURDERINGEN (0165)
//
// `skills_score.prosent` kom foer med `kommentar` - butikksjefens
// skriftlige vurdering av stasjonen - og `registrert_av`.
// `pengepremie_bruk.belop_kr` kom med `beskrivelse`, altsaa hva pengene
// gikk til. Nettbrettet er en DELT enhet i butikken.
//
// Klassifisert som capability-gjeld i Port 1, bygget 2026-09-02.
// =====================================================================
describe('hjemskjermen leser to tall, ikke to tabeller', () => {
  async function kall() {
    const { klient, sett } = fakeKlient([rad('2026-08-23', 10, 5)])
    await hentHjemData(klient as never, 'stasjon-1')
    return sett
  }

  it('KANARIFUGL: gaar gjennom hjem_stasjonstall', async () => {
    // Uten denne kunne paastandene under bestaatt fordi kallet forsvant
    // helt - og da ville hjemskjermen mangle tallene i stillhet.
    expect([...await kall()]).toContain('rpc:hjem_stasjonstall')
  })

  it('roerer ikke skills_score eller pengepremie_bruk som tabeller', async () => {
    const sett = await kall()
    expect([...sett], 'leser lederens kommentar').not.toContain('skills_score')
    expect([...sett], 'leser hva pengene gikk til').not.toContain('pengepremie_bruk')
  })

  it('leser fortsatt pengepremie selv - den har bare beloepet', async () => {
    // Tildelingen er ikke gjeld: raden sier hvor mye stasjonen vant, og
    // det er nettopp det nettbrettet skal vise.
    expect([...await kall()]).toContain('pengepremie')
  })

  it('KANARIFUGL: en feil fra funksjonen svelges ikke', async () => {
    // «Funksjonen finnes ikke» ville ellers sett ut som «ingen data», og
    // kortet bare uteblitt - samme form som `/maaling` sto i i maanedsvis.
    const { klient } = fakeKlient([rad('2026-08-23', 10, 5)])
    const rpc = () => ({
      maybeSingle: async () => ({ data: null, error: { message: 'function does not exist' } }),
    })
    await expect(hentHjemData({ ...klient, rpc } as never, 'stasjon-1'))
      .rejects.toThrow(/stasjonstallene/)
  })
})
