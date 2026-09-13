import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import {
  ALLE_ANALYSER, FORBEHOLD, KJEDEANALYSER, forbehold, forbeholdForStasjon,
  forbeholdstekst,
} from './forbehold'
import { PARSERVERSJON, kjennerNivaamodellen, parsergrunnlag } from '@/lib/import/parserversjon'

// =====================================================================
// JUNI ER DIMENSJONERT: PERIODE, STASJON OG ANALYSE
// =====================================================================
// Rad-for-rad-avstemming 2026-09-13 erstattet den tidligere paastanden
// om at stasjonstallene var identiske. De er det ikke — men bare for
// pant, brutto, CR og resultat, og bare paa Lone og Dale.
//
// Mat og svinn er identisk mellom filversjonene. Et forbehold paa hele
// juni ville sperret Boenes' matanalyse for en pantpostering paa Lone.
// =====================================================================

const JUNI = '2026-06-01'
const LONE = '4177'
const DALE = '4185'
const ANDRE = ['9038', '9145', '9467'] as const

describe('juni 2026 — de aatte bevisene', () => {
  it('1 · resultat for Lone er usikkert', () => {
    const f = forbehold(JUNI, 'resultat_stasjon', LONE)
    expect(f.status).toBe('usikker')
    expect(f.belopKr).toBe(7143.80)
    expect(f.aarsak).toMatch(/pantomklassifisering/)
  })

  it('2 · resultat for Dale er usikkert', () => {
    const f = forbehold(JUNI, 'resultat_stasjon', DALE)
    expect(f.status).toBe('usikker')
    expect(f.belopKr).toBe(6617.69)
    expect(f.aarsak).toMatch(/0,01/)   // kassedifferansen er med i beloepet
  })

  it('3 · mat og svinn for Lone er OK', () => {
    expect(forbehold(JUNI, 'mat_svinn_stasjon', LONE).status).toBe('ok')
  })

  it('4 · mat og svinn for Dale er OK', () => {
    expect(forbehold(JUNI, 'mat_svinn_stasjon', DALE).status).toBe('ok')
  })

  it('5 · resultat for de tre andre stasjonene er OK', () => {
    // Ingen diff-rad traff dem. Et forbehold uten en maalt differanse er
    // en anelse, ikke et funn.
    for (const s of ANDRE) {
      expect(forbehold(JUNI, 'resultat_stasjon', s).status, s).toBe('ok')
      expect(forbehold(JUNI, 'bruttofortjeneste_stasjon', s).status, s).toBe('ok')
      expect(forbehold(JUNI, 'cr_stasjon', s).status, s).toBe('ok')
    }
  })

  it('6 · klynge og kjederesultat er usikre', () => {
    for (const a of KJEDEANALYSER) {
      const f = forbehold(JUNI, a)
      expect(f.status, a).toBe('usikker')
      expect(f.belopKr, a).toBe(13101.49)
    }
  })

  it('7 · andre maaneder er uberoert', () => {
    for (const p of ['2026-05-01', '2026-07-01', '2026-01-01']) {
      for (const a of ALLE_ANALYSER) {
        expect(forbehold(p, a, LONE).status, `${p} ${a}`).toBe('ok')
        expect(forbehold(p, a, DALE).status, `${p} ${a}`).toBe('ok')
      }
    }
  })

  it('8 · flaten kan vise aarsak og beloep uten aa vedta versjon B', () => {
    const t = forbeholdstekst(forbehold(JUNI, 'resultat_stasjon', LONE))!
    expect(t).toMatch(/^Usikkert tall\./)
    expect(t).toMatch(/7 143,80 kr/)
    const kjede = forbeholdstekst(forbehold(JUNI, 'kjederesultat'))!
    expect(kjede).toMatch(/ikke vedtatt regnskapsfasit/)
    // Og en OK-analyse har ingen tekst i det hele tatt.
    expect(forbeholdstekst(forbehold(JUNI, 'mat_svinn_stasjon', LONE))).toBeNull()
  })
})

describe('dimensjonen holder', () => {
  it('KANARI: forbeholdet smitter ikke til nabostasjonen', () => {
    // Uten stasjonsdimensjonen ville Boenes' resultat blitt usikkert av
    // en pantpostering paa Lone.
    expect(forbehold(JUNI, 'resultat_stasjon', LONE).status).toBe('usikker')
    expect(forbehold(JUNI, 'resultat_stasjon', '9467').status).toBe('ok')
  })

  it('KANARI: forbeholdet smitter ikke til nabomaaltallet', () => {
    const per = forbeholdForStasjon(JUNI, LONE)
    const merket = ALLE_ANALYSER.filter((a) => per[a].status !== 'ok')
    expect(merket.sort()).toEqual(
      ['bruttofortjeneste_stasjon', 'cr_stasjon', 'kjederesultat',
        'klyngeanalyse', 'resultat_stasjon'].sort())
  })

  it('beloepene summerer seg til kjededifferansen', () => {
    // 7 143,80 + 6 617,69 = 13 761,49, og med Admins 660,00 trukket fra
    // blir det 13 101,49. Det er ikke pynt - det er beviset paa at
    // fordelingen og totalen kommer fra samme avstemming.
    const lone = forbehold(JUNI, 'resultat_stasjon', LONE).belopKr!
    const dale = forbehold(JUNI, 'resultat_stasjon', DALE).belopKr!
    const kjede = forbehold(JUNI, 'kjederesultat').belopKr!
    expect(Math.round((lone + dale - 660.00) * 100) / 100).toBe(kjede)
  })

  it('hver post har aarsak, beloep, kildeversjoner OG en utvei', () => {
    for (const p of FORBEHOLD) {
      expect(p.aarsak.length, p.periode).toBeGreaterThan(40)
      expect(p.loesesAv.length, p.periode).toBeGreaterThan(20)
      expect(p.gjelder.length, p.periode).toBeGreaterThan(0)
      expect(p.belopKr, p.periode).not.toBeNull()
      expect(p.kildeversjoner, p.periode).toMatch(/202606/)
    }
  })

  it('ukjent kombinasjon er OK, ikke tvil', () => {
    expect(forbehold('2030-01-01', 'kjederesultat').status).toBe('ok')
    expect(forbehold(JUNI, 'personalkost_stasjon', LONE).status).toBe('ok')
  })
})

describe('parserversjon', () => {
  it('er et navn, ikke et tidspunkt eller en hash', () => {
    expect(PARSERVERSJON).toBe('svinn-nivaa-1')
    // Et tidsstempel eller en hash ville endret seg uten at parseren
    // gjorde det, og «hvilke jobber har den nye modellen?» ville blitt
    // uleselig.
    expect(PARSERVERSJON).not.toMatch(/\d{4}-\d{2}-\d{2}/)
    expect(PARSERVERSJON).not.toMatch(/^[0-9a-f]{8,}$/)
  })

  it('gamle jobber er «eldre parsergrunnlag», ikke ukjente', () => {
    expect(parsergrunnlag(null)).toBe('eldre parsergrunnlag')
    expect(parsergrunnlag(PARSERVERSJON)).toBe(PARSERVERSJON)
    expect(kjennerNivaamodellen(null)).toBe(false)
    expect(kjennerNivaamodellen(PARSERVERSJON)).toBe(true)
  })

  it('importen skriver versjonen på jobben', () => {
    const kjerne = readFileSync(
      join(process.cwd(), 'src', 'lib', 'import', 'kjerne.ts'), 'utf8')
    expect(kjerne).toContain('parserversjon: PARSERVERSJON')
    expect(kjerne).toContain('avstemt_tid:')
    expect(kjerne).toContain('avviksantall:')
  })

  it('aktiveringen bytter i TO setninger, ikke én', () => {
    // `0209` byttet aktiv jobb med én update, «saa det aldri finnes et
    // oeyeblikk med to aktive». En partiell unik indeks kan ikke
    // utsettes og sjekkes per rad — foerste ekte kall ga 23505.
    // Atomisiteten kommer fra transaksjonen, ikke fra setningen.
    // KODEN, IKKE KOMMENTAREN. `0212` siterer den gamle formen i hodet
    // for å forklare feilen, og en rå `toContain` kunne ikke skille de
    // to — vakten ble rød på sin egen begrunnelse. Samme felle som
    // AGENTS.md beskriver: «verst når en ustrippet kommentar oppfyller
    // en toContain».
    const kode = readFileSync(join(process.cwd(), 'supabase', 'migrations',
      '0212_aktivering_i_to_setninger.sql'), 'utf8')
      .split('\n').filter((l) => !l.trimStart().startsWith('--')).join('\n')

    expect(kode).toContain('set aktiv = false')
    expect(kode).toContain('set aktiv = true')
    // Den gamle formen skal ikke komme tilbake.
    expect(kode).not.toContain('set aktiv = (id = p_jobb)')
    // Rekkefølgen er hele poenget: deaktiver før aktiver.
    expect(kode.indexOf('set aktiv = false')).toBeLessThan(kode.indexOf('set aktiv = true'))
  })

  it('proben som ville fanget det finnes, og ruller tilbake', () => {
    const probe = readFileSync(join(process.cwd(), 'supabase', 'tests',
      'aktiver_import_probe.sql'), 'utf8')
    expect(probe).toContain('public.aktiver_import(')
    expect(probe).toContain('rollback;')
    expect(probe).toContain('unique_violation')
    // Fiksturperioden maa ligge utenfor ekte data.
    expect(probe).toContain("date '1999-03-01'")
    expect(probe).not.toMatch(/date '20\d\d-/)
  })

  it('KANARI: aktivering krever bevis, ikke bare «parset»', () => {
    const sql = readFileSync(join(process.cwd(), 'supabase', 'migrations',
      '0211_aktivering_krever_bevis.sql'), 'utf8')
    // Fem porter. Faller én ut, kan en uavstemt jobb bli synlig.
    expect(sql).toContain('mangler parserversjon')
    expect(sql).toContain('er ikke avstemt')
    expect(sql).toContain('avviksantall = %')
    expect(sql).toContain('ingen grupperader')
    expect(sql).toContain('kontrollen av usynlig svinn')
    // Gamle aktive jobber skal IKKE miste flagget av at dette kjøres.
    expect(sql).not.toMatch(/update public\.import_jobber\s+set aktiv = false/)
  })
})
