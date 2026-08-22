import { describe, expect, test } from 'vitest'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { ARSVERK_TIMER, timerPerManed, timetall } from './lederdekning'

// =====================================================================
// Ett årsverk, to språk.
//
// `ARSVERK_TIMER` her og `arsverk_timer := 1695` i migrasjonen som
// definerer `v_timeregnskap` er samme tall. SQL kan ikke importere fra
// TypeScript, så det står to steder — og da må noe binde dem sammen.
//
// SAMME GREP SOM `utelatte-koder.test.ts`, og av samme grunn: to kopier
// av samme sannhet går fra hverandre. `rls_vakthund.sql` og
// `rls_funn.sql` gjorde det 2026-08-19, og verktøyet man brukte for å
// SE funnene løy om tabeller som var i orden.
// =====================================================================

const KATALOG = join(process.cwd(), 'supabase', 'migrations')

/** Den nyeste migrasjonen som definerer viewet — ikke et filnavn. */
function nyesteViewfil(): string {
  const treff = readdirSync(KATALOG)
    .filter((n) => n.endsWith('.sql'))
    .filter((n) => /create\s+(or\s+replace\s+)?view\s+public\.v_timeregnskap/i
      .test(readFileSync(join(KATALOG, n), 'utf8')))
    .sort()
  if (treff.length === 0) throw new Error('Ingen migrasjon definerer v_timeregnskap.')
  return join(KATALOG, treff[treff.length - 1])
}

describe('lederdekning', () => {
  test('årsverket er det samme i SQL som i TypeScript', () => {
    const sql = readFileSync(nyesteViewfil(), 'utf8')
    const markert = sql.match(/arsverk_timer\s*:=\s*(\d+)/)

    // KANARIFUGL. Uten markøren finner uttrekket ingenting, og
    // sammenligningen under blir trivielt grønn — da måler testen at
    // ingenting er likt ingenting.
    expect(markert, 'fant ingen `arsverk_timer := <tall>` i migrasjonen')
      .not.toBeNull()
    expect(Number(markert![1]), 'markøren i migrasjonen').toBe(ARSVERK_TIMER)

    // Og tallet må faktisk brukes i regnestykket, ikke bare stå i en
    // kommentar. Markøren er dokumentasjon; dette er koden.
    const brukt = sql.match(
      new RegExp(`nullif\\(a\\.fast_arsverk_timer,\\s*0\\),\\s*${ARSVERK_TIMER}\\)`, 'g'),
    )
    expect(brukt?.length, `${ARSVERK_TIMER} skal brukes som reserve i viewet`)
      .toBeGreaterThanOrEqual(2)
  })

  test('1695 er tallet St1 faktisk trekker fra', () => {
    // En speiltest beviser at to lister er LIKE, aldri at de er
    // RIKTIGE. Dette er ankeret: 0082 dokumenterer 1695 som ett årsverk.
    expect(ARSVERK_TIMER).toBe(1695)
    const oppsett = readFileSync(
      join(KATALOG, '0082_bemanning_budsjett_v2.sql'), 'utf8',
    )
    expect(oppsett, '0082 skal fortsatt dokumentere 1695 som ett aarsverk')
      .toContain('1695')
  })

  test('timene per måned beholder desimalen', () => {
    // 1695/12 = 141,25. Runder vi til 141, taper stasjonen tre timer i
    // året på en avrunding ingen har bestemt.
    expect(timerPerManed(ARSVERK_TIMER)).toBe(141.25)
    expect(timetall(141.25)).toBe('141,25')
    expect(timerPerManed(1200)).toBe(100)
  })
})
