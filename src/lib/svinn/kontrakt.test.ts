import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { kastprosent, velgGrunnlagPerNoekkel } from './grunnlag'
import { TILFELLER, type Kontraktsrad, type Tilfelle } from './kontrakt-tilfeller'

const PROBE = join(process.cwd(), 'supabase', 'tests', 'svinn_grunnlag_kontrakt.sql')

// =====================================================================
// KONTRAKTEN MELLOM TYPESCRIPT OG SQL
// =====================================================================
// Se `kontrakt-tilfeller.ts` for hvorfor, og for den ærlige
// begrensningen: CI kjører TypeScript-siden og beviser at proben er i
// takt med fasiten. Proben selv krever en base.
// =====================================================================

const noekkel = (r: Kontraktsrad) => `${r.stasjon}|${r.periode}`

function summer(rader: readonly Kontraktsrad[]) {
  return rader.reduce((a, r) => ({
    salg: a.salg + (r.salg ?? 0),
    kast: a.kast + (r.kast ?? 0),
    usynlig: a.usynlig + (r.usynlig_kr ?? 0),
  }), { salg: 0, kast: 0, usynlig: 0 })
}

describe('TypeScript-siden av grunnlagsregelen', () => {
  for (const t of TILFELLER) {
    it(t.navn, () => {
      const { perNoekkel } = velgGrunnlagPerNoekkel(t.rader, noekkel)
      for (const [k, f] of Object.entries(t.forvent)) {
        const valg = perNoekkel.get(k)
        if (f.datastatus === 'utilgjengelig') {
          // Ingen rader i det hele tatt for noekkelen: regelen faar den
          // aldri til vurdering, og fravaeret ER svaret.
          expect(valg, `${t.navn}: ${k} skulle ikke hatt rader`).toBeUndefined()
          continue
        }
        expect(valg, `${t.navn}: mangler valg for ${k}`).toBeDefined()
        expect(valg!.grunnlag, `${t.navn}: ${k} grunnlag`).toBe(f.grunnlag)
        expect(valg!.datastatus, `${t.navn}: ${k} datastatus`).toBe(f.datastatus)
        expect(valg!.rader.length, `${t.navn}: ${k} radantall`).toBe(f.rader)
        const s = summer(valg!.rader)
        expect(s.salg, `${t.navn}: ${k} salg`).toBeCloseTo(f.salg, 2)
        expect(s.kast, `${t.navn}: ${k} kast`).toBeCloseTo(f.kast, 2)
        expect(s.usynlig, `${t.navn}: ${k} usynlig`).toBeCloseTo(f.usynlig, 2)
      }
    })
  }
})

describe('kastprosent skiller tre tilstander', () => {
  it('0 % kast MED gyldig positivt salg er et ekte tall', () => {
    const p = kastprosent(0, 1000)
    expect(p.pst).toBe(0)
    expect(p.status).toBe('ok')
  })

  it('salg = 0 gjør prosenten ikke beregnbar — 16015 KAMPANJE', () => {
    const p = kastprosent(3655.42, 0)
    expect(p.pst).toBeNull()
    expect(p.status).toBe('ikke_beregnbar')
    expect(p.tekst).toBe('Kast registrert uten registrert salg i samme periode.')
  })

  it('manglende kasttall er en TREDJE tilstand', () => {
    expect(kastprosent(null, 1000).status).toBe('mangler_data')
    expect(kastprosent(100, null).status).toBe('mangler_data')
    expect(kastprosent(null, 1000).pst).toBeNull()
  })

  it('KANARI: de tre må ikke kollapse til samme svar', () => {
    const tre = [kastprosent(0, 1000), kastprosent(3655.42, 0), kastprosent(null, null)]
    expect(new Set(tre.map((t) => t.status)).size).toBe(3)
    // Og ingen av dem har 0 som «ukjent».
    expect(tre.filter((t) => t.pst === 0)).toHaveLength(1)
    expect(tre.filter((t) => t.pst === null)).toHaveLength(2)
  })
})

describe('16015 KAMPANJE hører til gruppe 160, ikke Mat 120', () => {
  const t = TILFELLER.find((x) => x.navn.includes('KAMPANJE'))!

  it('beløpet ligger på 160-koden', () => {
    const rad = t.rader.find((r) => r.kode === '16015')!
    expect(rad.kode.slice(0, 3)).toBe('160')
    expect(rad.kast).toBeCloseTo(3655.42, 2)
  })

  it('Mat 120 er uberørt av beløpet', () => {
    const mat = t.rader.filter((r) => r.kode.startsWith('120'))
    expect(mat.reduce((a, r) => a + (r.kast ?? 0), 0)).toBe(100)
  })

  it('dette forklarer differansen i importerte svinnrader, ikke manglende matkast', () => {
    // 589 i min simulering mot 588 i basen: den gamle parseren stoppet
    // raden paa `usynligKr === 0 && salg === 0`. Det er en KIOSK-rad, og
    // matavstemmingen er urørt av den.
    expect(t.hvorfor).toMatch(/3 655,42/)
    expect(t.hvorfor).not.toMatch(/mat/i)
  })
})

// ---------------------------------------------------------------------
// SQL-PROBEN GENERERES FRA SAMME FASIT
// ---------------------------------------------------------------------

function sqlTekst(v: string | number | null): string {
  if (v === null) return 'null'
  if (typeof v === 'number') return String(v)
  return `'${v.replace(/'/g, "''")}'`
}

function byggProbe(tilfeller: readonly Tilfelle[]): string {
  const deler: string[] = []
  deler.push(`-- =====================================================================
-- KONTRAKT: public.v_svinn_grunnlag MOT src/lib/svinn/grunnlag.ts
-- =====================================================================
-- GENERERT fra src/lib/svinn/kontrakt-tilfeller.ts. Rediger aldri for
-- haand - kjoer:
--
--   OPPDATER_SVINNKONTRAKT=1 npx vitest run src/lib/svinn/kontrakt
--
-- Regelen finnes to steder, og denne fila er det eneste som hindrer at
-- de driver fra hverandre. TypeScript-siden kjoeres i CI; denne siden
-- krever en base og kjoeres i SQL Editor.
--
-- TRYGG I PRODUKSJON: alt skjer i én transaksjon som avsluttes med
-- \`rollback\`. Fiksturradene bruker periodene 1999-01-01 og 1999-02-01,
-- som ikke finnes i ekte data.
--
-- Kvittering: siste \`select\` skal gi NULL rader. Hver rad er et avvik
-- mellom fasiten og det viewet svarte.
-- =====================================================================

begin;

create temp table kontraktsavvik (
  tilfelle  text,
  noekkel   text,
  felt      text,
  forventet text,
  faktisk   text
) on commit drop;

do $kontrakt$
declare
  v_ret uuid;
  v_a   uuid;
  v_b   uuid;
  v_val record;
begin
  select id into v_ret from public.retailers order by opprettet_tid limit 1;
  if v_ret is null then
    raise exception 'kontrakt: fant ingen retailer aa teste med';
  end if;

  select id into v_a from public.stasjoner
   where retailer_id = v_ret and slettet_tid is null order by butikknummer limit 1;
  select id into v_b from public.stasjoner
   where retailer_id = v_ret and slettet_tid is null and id <> v_a
   order by butikknummer limit 1;
  if v_a is null or v_b is null then
    raise exception 'kontrakt: trenger to stasjoner, fant % og %', v_a, v_b;
  end if;
`)

  for (const t of tilfeller) {
    deler.push(`
  -- -------------------------------------------------------------------
  -- ${t.navn}
  --
  -- ${t.hvorfor.replace(/\n/g, '\n  -- ')}
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
`)
    for (const r of t.rader) {
      deler.push(`  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, ${r.stasjon === 'a' ? 'v_a' : 'v_b'}, date ${sqlTekst(r.periode)}, ${sqlTekst(r.kode)},
    ${sqlTekst(`kontrakt ${r.kode}`)}, ${sqlTekst(r.nivaa)}, ${sqlTekst(r.analyseomraade)},
    ${sqlTekst(r.salg)}, ${sqlTekst(r.kast)}, ${sqlTekst(r.usynlig_kr)});
`)
    }
    for (const [k, f] of Object.entries(t.forvent)) {
      const [stasjon, periode] = k.split('|')
      const id = stasjon === 'a' ? 'v_a' : 'v_b'
      deler.push(`  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = ${id} and periode = date ${sqlTekst(periode)};

  if v_val.rader <> ${f.rader} then
    insert into kontraktsavvik values (${sqlTekst(t.navn)}, ${sqlTekst(k)}, 'rader', '${f.rader}', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> ${f.salg} then
    insert into kontraktsavvik values (${sqlTekst(t.navn)}, ${sqlTekst(k)}, 'salg', '${f.salg}', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> ${f.kast} then
    insert into kontraktsavvik values (${sqlTekst(t.navn)}, ${sqlTekst(k)}, 'kast', '${f.kast}', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> ${f.usynlig} then
    insert into kontraktsavvik values (${sqlTekst(t.navn)}, ${sqlTekst(k)}, 'usynlig', '${f.usynlig}', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> ${sqlTekst(f.datastatus)} then
    insert into kontraktsavvik values (${sqlTekst(t.navn)}, ${sqlTekst(k)}, 'datastatus', ${sqlTekst(f.datastatus)}, v_val.datastatus);
  end if;
`)
    }
  }

  deler.push(`end $kontrakt$;

-- KVITTERING. Null rader = TypeScript og SQL er enige.
select * from kontraktsavvik order by tilfelle, noekkel, felt;

select count(*) as avvik,
       ${tilfeller.length} as tilfeller,
       case when count(*) = 0 then 'KONTRAKT HOLDER' else 'DRIFT - se raderne over' end as dom
  from kontraktsavvik;

rollback;
`)
  return deler.join('')
}

describe('SQL-proben er i takt med fasiten', () => {
  const ny = byggProbe(TILFELLER)

  if (process.env.OPPDATER_SVINNKONTRAKT === '1') {
    writeFileSync(PROBE, ny, 'utf8')
  }

  it('proben finnes', () => {
    expect(existsSync(PROBE), `mangler ${PROBE}. Kjør OPPDATER_SVINNKONTRAKT=1`).toBe(true)
  })

  it('proben stemmer med tilfellene', () => {
    const paa_disk = readFileSync(PROBE, 'utf8').replace(/\r\n/g, '\n')
    expect(paa_disk,
      'SQL-proben er ikke regenerert etter at fasiten endret seg. '
      + 'Kjør: OPPDATER_SVINNKONTRAKT=1 npx vitest run src/lib/svinn/kontrakt',
    ).toBe(ny)
  })

  it('KANARI: proben dekker HVERT tilfelle, og ruller tilbake', () => {
    const paa_disk = readFileSync(PROBE, 'utf8')
    for (const t of TILFELLER) {
      expect(paa_disk, `tilfellet «${t.navn}» mangler i proben`).toContain(t.navn)
    }
    expect(paa_disk).toContain('rollback;')
    expect(paa_disk).toContain('v_svinn_grunnlag')
    // Ingen ekte periode skal roeres.
    expect(paa_disk).not.toMatch(/date '20\d\d-/)
  })
})
