import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { SEKSJONER, stengteSeksjoner } from './seksjoner'

// =====================================================================
// EN SEKSJON SOM FALLER MELLOM STOLENE SER UT SOM EN UTEN PROBLEMER
// =====================================================================
//
// `0192` svartelistet seksjoner for butikksjefen, med vilje: en
// hvitliste ville fått en ny seksjon til å forsvinne i stillhet for
// henne. Baksiden er at en ny seksjon i stedet slipper INN i stillhet —
// og det er nøyaktig det som skjedde med `bp_kostnad`, som bærer
// `5010 Faste lønninger` per stasjon per måned.
//
// Denne fila leser seksjonsnavnene ut av KILDEN, ikke av en liste, og
// krever at hvert eneste er klassifisert for hånd. Samme regel som
// `tenant_dekning.sql` bruker for tabeller: trygg og sett er to
// forskjellige ting.
// =====================================================================

const ROT = join(process.cwd())
const KATALOG = join(ROT, 'supabase', 'migrations')

/**
 * Seksjonsnavnene importen faktisk skriver.
 *
 * To kilder, fordi de skrives på to måter: `RegnskapSeksjon` i
 * `parsere/typer.ts` er parserens egne, og `bpLinje('bp_…')` i
 * importkjernen er BP-ens. Den andre er nettopp den som ble glemt.
 */
/**
 * Leser en kildefil med LF, uansett hva som ligger på disk.
 *
 * FILENE SJEKKES UT MED CRLF PÅ WINDOWS. Første utgave av denne fila
 * lette etter `\n\n` og fant `\r\n\r\n` — altså ingenting — og kastet
 * «fant ikke RegnskapSeksjon i typer.ts».
 *
 * Den var GRØNN I CI, som kjører på Linux med LF, og rød bare lokalt.
 * Det er den verste varianten: porten sier ikke fra, og vakten har
 * sluttet å måle for den som utvikler.
 *
 * Tredje gang denne fella tas i dette prosjektet. Se crlf-notatet i
 * AGENTS.md-sporet.
 */
function les(sti: string): string {
  return readFileSync(join(ROT, sti), 'utf8').replace(/\r\n/g, '\n')
}

function seksjonerIKilden(): Set<string> {
  const funnet = new Set<string>()

  const m = /export type RegnskapSeksjon =([\s\S]*?)\n\n/.exec(les('src/lib/parsere/typer.ts'))
  if (!m) throw new Error('fant ikke RegnskapSeksjon i typer.ts')
  for (const t of m[1].matchAll(/'([a-z_]+)'/g)) funnet.add(t[1])

  for (const t of les('src/lib/import/kjerne.ts').matchAll(/bpLinje\('([a-z_]+)'/g)) {
    funnet.add(t[1])
  }

  return funnet
}

/** Siste migrasjon som definerer `regnskapslinjer_les`, uten kommentarer. */
function policykropp(): { fil: string; sql: string } {
  let funn: { fil: string; sql: string } | null = null
  for (const fil of readdirSync(KATALOG).filter((n) => n.endsWith('.sql')).sort()) {
    const ren = readFileSync(join(KATALOG, fil), 'utf8')
      .replace(/\r\n/g, '\n')
      .replace(/--.*/g, '')
    const m = /create policy regnskapslinjer_les[\s\S]*?;\s*$/m.exec(ren)
    if (m) funn = { fil, sql: m[0] }
  }
  if (!funn) throw new Error('fant ingen definisjon av regnskapslinjer_les')
  return funn
}

const policy = policykropp()

describe('seksjonsdekning', () => {
  it('KANARI: uttrekket finner faktisk seksjonene', () => {
    // Skrives typen om til noe annet enn en union av strengliteraler,
    // eller bpLinje til en variabel, blir settet tomt — og «alle er
    // klassifisert» ville vært sant fordi det ikke er noen.
    const s = seksjonerIKilden()
    expect(s.size, 'fant ingen seksjoner i kilden').toBeGreaterThanOrEqual(8)
    expect(s).toContain('driftskostnader')
    expect(s, 'BP-grenen ble ikke funnet - og det var DEN som ble glemt')
      .toContain('bp_kostnad')
  })

  it('KANARI: uttrekket tåler CRLF', () => {
    // Den konkrete feilen, gjenskapt. Uten normaliseringen finner
    // regexen ingenting, og testen under KASTER i stedet for å måle —
    // grønn i CI, rød bare på Windows.
    const medCrlf = "export type RegnskapSeksjon =\r\n  | 'omsetning'\r\n\r\nannet"
    const m = /export type RegnskapSeksjon =([\s\S]*?)\n\n/
    expect(m.test(medCrlf)).toBe(false)
    expect(m.test(medCrlf.replace(/\r\n/g, '\n'))).toBe(true)
  })

  it('hver seksjon importen skriver er klassifisert', () => {
    const uklassifisert = [...seksjonerIKilden()].filter((s) => !SEKSJONER[s]).sort()
    expect(
      uklassifisert,
      `\nSeksjonene ${uklassifisert.join(', ')} skrives til regnskapslinjer, men `
      + 'staar ikke i SEKSJONER.\n\n'
      + 'Butikksjefarmen i policyen er en SVARTELISTE - en seksjon ingen har '
      + 'tatt stilling til er derfor SYNLIG for butikksjefen. Slik laa '
      + '`bp_kostnad` aapent med 5010 Faste loenninger fra den ble skrevet til '
      + '0204.\n\nTa stilling i src/lib/regnskap/seksjoner.ts.\n',
    ).toEqual([])
  })

  it('ingen klassifisering uten begrunnelse', () => {
    for (const [navn, post] of Object.entries(SEKSJONER)) {
      expect(post.hvorfor.length, `${navn} mangler begrunnelse`).toBeGreaterThan(60)
    }
  })

  it('ingen klassifisering av en seksjon som ikke finnes', () => {
    // Motsatt vei: en post for en seksjon importen ikke lenger skriver
    // er en regel som later som den gjoer noe.
    const iKilden = seksjonerIKilden()
    const foreldet = Object.keys(SEKSJONER).filter((s) => !iKilden.has(s)).sort()
    expect(foreldet, `Klassifisert, men skrives ikke: ${foreldet.join(', ')}`).toEqual([])
  })
})

describe('policyen håndhever klassifiseringen', () => {
  it('hver stengt seksjon har sin egen arm', () => {
    const mangler = stengteSeksjoner().filter(
      (s) => !new RegExp(`seksjon\\s*<>\\s*'${s}'`).test(policy.sql),
    )
    expect(
      mangler,
      `\nSeksjonene ${mangler.join(', ')} er klassifisert som «nei», men `
      + `${policy.fil} stenger dem ikke. En svarteliste som mangler en linje `
      + 'ser noeyaktig ut som en som er komplett.\n',
    ).toEqual([])
  })

  it('KANARI: armsjekken ville sett en manglende arm', () => {
    // Uten denne kunne regexen vaere doed, og loekka over alltid tom.
    expect(/seksjon\s*<>\s*'resultat'/.test("using (seksjon <> 'bp_kostnad')")).toBe(false)
    expect(/seksjon\s*<>\s*'resultat'/.test("using (seksjon <> 'resultat')")).toBe(true)
  })

  it('KANARI: bp_kostnad er faktisk stengt — regelen Robert satte', () => {
    // «butikksjefene skal aldri se noe annet enn total loennsbudsjett.
    // aldri budsjett paa fastloenn.» Seksjonen baerer 5010 per maaned.
    expect(SEKSJONER.bp_kostnad.tilgang).toBe('nei')
    expect(policy.sql).toMatch(/seksjon\s*<>\s*'bp_kostnad'/)
  })

  it('bp_omsetning er IKKE stengt', () => {
    // Butikksjefen leser den ekte: /salg og ukebriefen henter
    // `seksjon in (omsetning, bp_omsetning)`. Stenges den, blir
    // budsjettkolonnen tom for nettopp den rollen - stille.
    expect(SEKSJONER.bp_omsetning.tilgang).toBe('ja')
    expect(policy.sql).not.toMatch(/seksjon\s*<>\s*'bp_omsetning'/)
  })
})
