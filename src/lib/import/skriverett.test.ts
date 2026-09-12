import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import kontrakt from '../../../supabase/tenant-kontrakt.json'
import { rekkevidde, type Rollefelt, type Operasjon } from '@/lib/tenant/kontrakt'

/**
 * =====================================================================
 * IMPORTEN SKRIVER SOM EIEREN, IKKE SOM TJENESTEN
 * =====================================================================
 *
 * `behandleJobbKjerne` har TO kallsteder med hver sin nøkkel:
 *
 *   api/epost-inntak/route.ts   lagSupabaseAdminKlient()   tjenestenøkkel
 *   import/behandle.ts          lagSupabaseServerKlient()  brukerens sesjon
 *
 * Den andre er «Behandle»-knappen, og der gjelder RLS. En tabell
 * importen skriver uten at `retailer_admin` har skrivepolicy avviser
 * derfor opplastingen — men bare den veien, så den ser ut til å virke
 * helt til noen trykker på knappen.
 *
 * 0198, 0199 og 0200 skrev alle tre «radene kommer fra importen gjennom
 * tjenestenøkkelen» og sløyfet skrivepolicyen. BP26 feilet med «new row
 * violates row-level security policy for table "royaltysats"», og de to
 * neste ville stoppet regnskapsfilene rett etterpå.
 *
 * DENNE VAKTEN LESER KILDEN, IKKE EN LISTE. En ny tabell i importen blir
 * med av seg selv — det var nettopp det en håndholdt liste ikke gjorde.
 */

const ROT = join(import.meta.dirname, '..', '..', '..')

/** Filene importkjernen skriver gjennom. Kjernen selv, og det den kaller. */
const KILDER = [
  'src/lib/import/kjerne.ts',
  'src/lib/kurs/lagre.ts',
]

/**
 * Tabeller kjernen rører som IKKE er retailer-eide forretningsdata.
 *
 * Hver av dem trenger en skrevet begrunnelse. Et unntak uten begrunnelse
 * er en liste, ikke en beslutning — samme regel som omfangsvakten
 * bruker.
 */
const UNNTAK: Record<string, string> = {
  retailers: 'Kjeden selv. Oppdateres ikke av importen — leses for navn og innstillinger.',
  stasjoner: 'Stasjonsregisteret. Importen oppretter stasjoner den ser i filene; '
    + 'står i kontrakten med egen skriveradgang for eier.',
}

type Ressurs = {
  tabell?: string
  operasjoner?: Operasjon[]
  owner?: Rollefelt
}

const RESSURSER = (kontrakt as { ressurser: Ressurs[] }).ressurser

function ressurs(tabell: string): Ressurs | undefined {
  return RESSURSER.find((r) => r.tabell === tabell)
}

/**
 * Tabellene kildene skriver til.
 *
 * To former, og begge må med: `skrivBatch(supabase, 'x', …)` er den
 * vanlige, og en rå `.from('x').insert/upsert/update` finnes der batchen
 * ikke passer. Rekkefølgen på kjeden varierer (`.from(...)` og
 * skrivekallet står ofte på hver sin linje), så vi ser i et vindu
 * framover — ikke etter et eksakt uttrykk.
 */
function skrevneTabeller(kilde: string): Set<string> {
  const funnet = new Set<string>()

  for (const m of kilde.matchAll(/skrivBatch\(\s*\w+\s*,\s*'([a-z_]+)'/g)) {
    funnet.add(m[1])
  }

  for (const m of kilde.matchAll(/\.from\('([a-z_]+)'\)/g)) {
    const etter = kilde.slice(m.index + m[0].length, m.index + m[0].length + 120)
    if (/^[\s\S]*?\.(insert|upsert|update|delete)\s*\(/.test(etter)) funnet.add(m[1])
  }

  return funnet
}

function allePavirkede(): Map<string, string> {
  const per = new Map<string, string>()
  for (const fil of KILDER) {
    const kilde = readFileSync(join(ROT, fil), 'utf8')
    for (const t of skrevneTabeller(kilde)) if (!per.has(t)) per.set(t, fil)
  }
  return per
}

describe('importen skriver som eieren', () => {
  it('KANARI: detektoren finner noe i det hele tatt', () => {
    // En vakt som slutter å se, ser nøyaktig ut som en vakt som ikke
    // finner noe. Flytter noen `skrivBatch` til en annen form, skal
    // dette bli rødt før stillheten rekker å bli en konklusjon.
    const funnet = allePavirkede()
    expect(funnet.size).toBeGreaterThan(8)
    expect([...funnet.keys()]).toContain('royaltysats')
    expect([...funnet.keys()]).toContain('bilagssum')
    expect([...funnet.keys()]).toContain('maanedsplan')
  })

  it('KANARI: begge deteksjonsformene virker hver for seg', () => {
    // Uten denne kunne én av de to regexene være død mens den andre bar
    // hele funnet — og da ville en ny tabell skrevet på den døde formen
    // gått rett gjennom.
    expect(skrevneTabeller("await skrivBatch(supabase, 'kanari_batch', rader)"))
      .toContain('kanari_batch')
    expect(skrevneTabeller("await supabase\n  .from('kanari_raa')\n  .upsert(rad)"))
      .toContain('kanari_raa')
  })

  it('hver tabell importen skriver står i tenant-kontrakten', () => {
    const mangler = [...allePavirkede().keys()]
      .filter((t) => !UNNTAK[t] && !ressurs(t))
    expect(mangler, 'skrives av importen, men finnes ikke i tenant-kontrakten').toEqual([])
  })

  it('eieren kan SKRIVE hver av dem — ellers feiler «Behandle»', () => {
    const uten: string[] = []

    for (const [tabell, fil] of allePavirkede()) {
      if (UNNTAK[tabell]) continue
      const r = ressurs(tabell)
      if (!r) continue // dekkes av testen over

      const ops = r.operasjoner ?? []
      const kanSkrive = rekkevidde(r.owner ?? 'none', 'insert', ops) !== 'none'
      if (!kanSkrive) uten.push(`${tabell} (${fil})`)
    }

    expect(
      uten,
      'Importkjernen skriver disse, men eieren har ingen insert i kontrakten. '
      + '«Behandle»-knappen kjører kjernen med brukerens sesjon, så RLS gjelder '
      + 'og opplastingen avvises. Se 0202.',
    ).toEqual([])
  })

  it('KANARI: en tabell uten skriverett for eieren blir faktisk fanget', () => {
    // Injeksjonen: en ressurs som bare kan leses. Fanger ikke regelen
    // den, måler den ingenting — og det var nøyaktig slik royaltysats
    // slapp gjennom.
    const baresLes: Ressurs = { tabell: 'kanari', operasjoner: ['select'], owner: { select: 'retailer' } }
    expect(rekkevidde(baresLes.owner!, 'insert', baresLes.operasjoner!)).toBe('none')

    // ... og at den motsatte sier ja, så testen over ikke er grønn fordi
    // `rekkevidde` alltid svarer `none`.
    const skriver: Ressurs = {
      tabell: 'kanari',
      operasjoner: ['select', 'insert'],
      owner: { select: 'retailer', insert: 'retailer' },
    }
    expect(rekkevidde(skriver.owner!, 'insert', skriver.operasjoner!)).not.toBe('none')
  })

  it('hvert unntak har en begrunnelse', () => {
    for (const [tabell, grunn] of Object.entries(UNNTAK)) {
      expect(grunn.length, `unntaket for ${tabell} mangler begrunnelse`).toBeGreaterThan(30)
    }
  })
})
