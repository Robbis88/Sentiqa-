// =====================================================================
// Generatoren: kontrakt -> SQL.
//
// Rene funksjoner. Ingen filsystem, ingen base. Testen kaller dem og
// sammenligner med det som ligger i repoet.
// =====================================================================
import type { Kontrakt, Operasjon, Ressurs } from './kontrakt'
import { rekkevidde } from './kontrakt'

// --- Fasitverdenen ---------------------------------------------------
// Samme UUID-er som `rls_kanarifugl.sql` fra PORT 1. Kolliderende
// butikknummer og ansatt_nr med vilje — en test som består fordi
// radene tilfeldigvis er ulike, beviser ingenting.

const R = {
  A: 'aaaa0000-0000-4000-8000-000000000000',
  B: 'bbbb0000-0000-4000-8000-000000000000',
} as const

const S = {
  A1: 'a1110000-0000-4000-8000-000000000001',
  A2: 'a1110000-0000-4000-8000-000000000002',
  A3: 'a1110000-0000-4000-8000-000000000003',
  B1: 'b1110000-0000-4000-8000-000000000001',
  B2: 'b1110000-0000-4000-8000-000000000002',
} as const

type Stasjon = keyof typeof S
type Kjede = keyof typeof R

export type Identitet = {
  navn: string
  uid: string
  kjede: Kjede
  stasjoner: Stasjon[]
  rolle: 'owner' | 'manager' | 'tablet'
}

export const IDENTITETER: Identitet[] = [
  { navn: 'owner_A', uid: '00000000-0000-0000-0000-00000000a000', kjede: 'A', stasjoner: ['A1', 'A2', 'A3'], rolle: 'owner' },
  { navn: 'manager_A1', uid: '00000000-0000-0000-0000-00000000a001', kjede: 'A', stasjoner: ['A1'], rolle: 'manager' },
  { navn: 'manager_A12', uid: '00000000-0000-0000-0000-00000000a012', kjede: 'A', stasjoner: ['A1', 'A2'], rolle: 'manager' },
  { navn: 'tablet_A1', uid: '00000000-0000-0000-0000-00000000a101', kjede: 'A', stasjoner: ['A1'], rolle: 'tablet' },
  { navn: 'owner_B', uid: '00000000-0000-0000-0000-00000000b000', kjede: 'B', stasjoner: ['B1', 'B2'], rolle: 'owner' },
  { navn: 'manager_B1', uid: '00000000-0000-0000-0000-00000000b001', kjede: 'B', stasjoner: ['B1'], rolle: 'manager' },
  { navn: 'tablet_B1', uid: '00000000-0000-0000-0000-00000000b101', kjede: 'B', stasjoner: ['B1'], rolle: 'tablet' },
]

const KJEDENS_STASJONER: Record<Kjede, Stasjon[]> = {
  A: ['A1', 'A2', 'A3'],
  B: ['B1', 'B2'],
}

const ANNEN_KJEDE: Record<Kjede, Kjede> = { A: 'B', B: 'A' }

/**
 * Målene én identitet prøves mot.
 *
 * Hele egen kjede — det er der delmengden bor, og `manager_A12` mot A3
 * er hele grunnen til at dette ikke er «enda en 1-stasjonsbruker». Så
 * første stasjon i den andre kjeden, for kryss-retailer.
 */
export function maal(i: Identitet): Stasjon[] {
  return [...KJEDENS_STASJONER[i.kjede], KJEDENS_STASJONER[ANNEN_KJEDE[i.kjede]][0]]
}

/** Når identiteten denne stasjonen for denne operasjonen? */
export function tillatt(r: Ressurs, i: Identitet, op: Operasjon, s: Stasjon): boolean {
  const felt = i.rolle === 'owner' ? r.owner : i.rolle === 'manager' ? r.manager : r.tablet
  const rv = rekkevidde(felt, op, r.operasjoner)
  if (rv === 'none') return false
  if (rv === 'retailer') return KJEDENS_STASJONER[i.kjede].includes(s)
  // own_station / assigned_stations
  return i.stasjoner.includes(s)
}

// --- Små hjelpere for SQL-tekst --------------------------------------

const sitat = (s: string) => `'${s.replace(/'/g, "''")}'`

function fyll(mal: string, ctx: Record<string, string>): string {
  return mal.replace(/\{\{([a-z_:]+)\}\}/g, (_, n: string) => {
    if (!(n in ctx)) throw new Error(`Ukjent plassholder {{${n}}}`)
    return ctx[n]
  })
}

/** Deterministisk UUID for en seedet rad. Ingen Math.random. */
function seedId(nokkel: string): string {
  let h = 0
  for (const ch of nokkel) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  const hex = h.toString(16).padStart(8, '0')
  return `${hex}-0000-4000-8000-${h.toString(16).padStart(12, '0').slice(0, 12)}`
}

/** Kolonnene som bærer tenant, gitt scope. */
function tenantKolonner(r: Ressurs, kjede: Kjede, s: Stasjon): Record<string, string> {
  const ut: Record<string, string> = {}
  if (r.tenant_scope === 'retailer' || r.tenant_scope === 'retailer_and_station') {
    ut.retailer_id = sitat(R[kjede])
  }
  if (r.tenant_scope === 'station' || r.tenant_scope === 'retailer_and_station') {
    if (!r.tenant_kolonne) ut.stasjon_id = sitat(S[s])
  }
  return ut
}

function proberadSql(r: Ressurs, kjede: Kjede, s: Stasjon, unik: string): {
  kolonner: string[]; verdier: string[]
} {
  const ctx: Record<string, string> = {
    retailer: R[kjede], stasjon: S[s], unik,
    unik_dato: `date '2026-08-01' + ${parseInt(unik, 36) % 300}`,
  }
  for (const linje of r.seed_ekstra ?? []) {
    for (const m of linje.matchAll(/\{\{seed:([a-z_]+)\}\}/g)) {
      ctx[`seed:${m[1]}`] = seedId(`${r.tabell}:${m[1]}:${s}`)
    }
  }
  const felt = { ...tenantKolonner(r, kjede, s), ...r.proberad }
  const kolonner: string[] = []
  const verdier: string[] = []
  for (const [k, v] of Object.entries(felt)) {
    if (k.startsWith('$')) continue
    kolonner.push(k)
    verdier.push(fyll(v, ctx))
  }
  return { kolonner, verdier }
}

// --- Filhode ---------------------------------------------------------

const ADVARSEL = `-- GENERERT FIL - IKKE REDIGER.
--
-- Kilde: supabase/tenant-kontrakt.json
-- Regenerer: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
--
-- En haandredigering her ville overlevd til neste generering og saa
-- forsvunnet i stillhet. Skal noe endres, endre kontrakten.`

// =====================================================================
// 1) Dekningskontroll
// =====================================================================

export function genererDekning(k: Kontrakt): string {
  const rader = [
    ...k.ressurser.map((r) => [r.tabell, true] as const),
    ...k.uklassifisert_tillatt.tabeller.map((t) => [t, false] as const),
  ].sort((a, b) => a[0].localeCompare(b[0]))
    .map(([t, kl]) => `    (${sitat(t)}, ${kl})`).join(',\n')

  return `${ADVARSEL}
--
-- DEKNINGSKONTROLL. Hver tabell i public skal staa i kontrakten, enten
-- som klassifisert ressurs eller paa lista over uklassifiserte.
--
-- EN NY TABELL STAAR I INGEN AV DEM, og feller derfor denne. Det er
-- meningen: en tabell skal ikke kunne bli usynlig for sikkerhets-
-- systemet fordi ingen husket aa foere den opp.
--
-- Partisjoner er unntatt - de arver forelderens klassifisering, og
-- rettighetene deres vaktes av punkt 10 i rls_vakthund.sql.
do $$
declare
  r record;
  funn text[] := array[]::text[];
  antall_klassifisert int;
begin
  create temp table kontrakt_tabeller (
    tabell text primary key, klassifisert boolean, uten_policy_ok boolean
  ) on commit drop;

  insert into kontrakt_tabeller (tabell, klassifisert, uten_policy_ok) values
${rader};

  select count(*) into antall_klassifisert from kontrakt_tabeller where klassifisert;

  -- KANARIFUGL. En kontrakt uten klassifiserte rader ville gjort hele
  -- sjekken stille - og "ingen funn" ser da noeyaktig ut som en base
  -- uten problemer.
  if antall_klassifisert = 0 then
    raise exception 'TENANT-DEKNING: kontrakten har ingen klassifiserte ressurser - maaler denne sjekken noe?';
  end if;

  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relispartition
      and not exists (select 1 from kontrakt_tabeller kt where kt.tabell = c.relname)
    order by c.relname
  loop
    funn := funn || format('UKLASSIFISERT  public.%s  - foer den opp i supabase/tenant-kontrakt.json. Gjett aldri klassifiseringen; den skal settes av noen som har tatt stilling.', r.relname);
  end loop;

  -- TABELLER UTEN POLICY SKAL VAERE ET FUNN, IKKE USYNLIGE.
  --
  -- Vakthundens dekningssjekk (punkt 4) starter fra pg_policies og ser
  -- derfor bare tabeller SOM HAR policy. En tabell uten policy faller
  -- utenfor den - og ser da noeyaktig ut som en tabell uten problemer.
  -- Slik havnet oversettelse_cache utenfor hver liste i to aar.
  --
  -- Denne starter fra pg_class: alle faktiske databaseobjekter. Er
  -- fravaeret av policy bevisst, skal det staa som ingen_policy i
  -- kontrakten - da er den sett og begrunnet.
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and not c.relispartition
      and not exists (
        select 1 from pg_policies p
        where p.schemaname = 'public' and p.tablename = c.relname)
      and not exists (
        select 1 from kontrakt_tabeller kt
        where kt.tabell = c.relname and kt.uten_policy_ok)
    order by c.relname
  loop
    funn := funn || format('UTEN POLICY  public.%s  - har ingen policy i det hele tatt. Er det med vilje, sett ingen_policy med begrunnelse i kontrakten. RLS uten policy nekter alt, men det skal staa at noen har bestemt det.', r.relname);
  end loop;

  -- Motsatt vei: en kontraktrad uten tabell er en fasit som har raatnet.
  for r in
    select kt.tabell
    from kontrakt_tabeller kt
    where to_regclass('public.' || quote_ident(kt.tabell)) is null
    order by kt.tabell
  loop
    funn := funn || format('KONTRAKT UTEN TABELL  %s  - staar i kontrakten, men finnes ikke i basen.', r.tabell);
  end loop;

  if array_length(funn, 1) > 0 then
    raise exception '%', format('TENANT-DEKNING: %s funn%s%s',
      array_length(funn, 1), chr(10) || chr(10), array_to_string(funn, chr(10)));
  end if;

  raise notice '--- Tenant-dekning: ingen funn. % klassifisert, % uklassifiserte staar igjen ---',
    antall_klassifisert, (select count(*) from kontrakt_tabeller where not klassifisert);
end $$;
`
}

// =====================================================================
// 2) Atferdsmatrisen
// =====================================================================

export function genererMatrise(k: Kontrakt): string {
  const ut: string[] = []
  const varme = k.ressurser.filter((r) => r.data_class === 'warm')

  ut.push(`${ADVARSEL}
--
-- ATFERDSMATRISEN. For hver varm ressurs, hver identitet og hver
-- operasjon kontrakten beskriver: naar den, eller naar den ikke?
--
-- POSITIVE KONTROLLER ER OBLIGATORISKE. En suite som bare beviser
-- "avvist" kan vaere groenn fordi alt er oedelagt. Hver identitet som
-- SKAL naa noe, proever ogsaa det.
--
-- AVVIST MAA VAERE 42501. Et forbudt insert som feiler paa en
-- unique-skranke er ogsaa "avvist", men det beviser ingenting om RLS.
-- rutine_utforinger har unique (rutine_id, dato) og ville gitt akkurat
-- den falske groennheten. \`skriv_avvist\` krever derfor 42501 - eller
-- null rader, som er det \`using\` gir paa update og delete.
begin;
`)

  ut.push(genererSeed())
  ut.push(HJELPERE)
  for (const r of varme) ut.push(genererRessursSeed(r))
  for (const r of varme) ut.push(genererRessurs(r))

  ut.push(`
select pg_temp.som_eier();

select status, navn, detalj
from pg_temp.funn
order by (status = 'FEIL') desc, nr;

rollback;
`)
  return ut.join('\n')
}

function genererSeed(): string {
  const brukere = IDENTITETER.map((i) => `  (${sitat(i.uid)}, ${sitat(`${i.navn}@kanari.local`)})`).join(',\n')
  const rolleNavn = { owner: 'retailer_admin', manager: 'butikksjef', tablet: 'butikkbruker_tablet' } as const
  const profiler = IDENTITETER.map((i) =>
    `  (${sitat(i.uid)}, ${sitat(R[i.kjede])}, ${sitat(rolleNavn[i.rolle])}, ${sitat(i.navn)})`).join(',\n')
  const tildelinger = IDENTITETER
    .filter((i) => i.rolle !== 'owner')
    .flatMap((i) => i.stasjoner.map((s) => `  (${sitat(i.uid)}, ${sitat(S[s])})`)).join(',\n')

  return `-- --- Fasitverdenen ---------------------------------------------------
-- Butikknummer 0001 finnes i BEGGE kjeder, og ansatt_nr 4501 likesaa.
insert into auth.users (id, email) values
${brukere}
on conflict (id) do nothing;

insert into public.retailers (id, navn) values
  (${sitat(R.A)}, 'Kanari A'),
  (${sitat(R.B)}, 'Kanari B');

insert into public.profiler (id, retailer_id, rolle, fullt_navn) values
${profiler};

insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype) values
  (${sitat(S.A1)}, ${sitat(R.A)}, '0001', 'Sentrum', 'sentrum'),
  (${sitat(S.A2)}, ${sitat(R.A)}, '0002', 'Nord',    'pendler'),
  (${sitat(S.A3)}, ${sitat(R.A)}, '0003', 'Vest',    'utfart'),
  (${sitat(S.B1)}, ${sitat(R.B)}, '0001', 'Sentrum', 'sentrum'),
  (${sitat(S.B2)}, ${sitat(R.B)}, '0002', 'Nord',    'pendler');

insert into public.butikksjef_stasjoner (profil_id, stasjon_id) values
${tildelinger};
`
}

function genererRessursSeed(r: Ressurs): string {
  const linjer: string[] = [`-- --- ${r.tabell}: forutsetninger og proberader ---`]
  const alle: Array<[Kjede, Stasjon]> = [
    ['A', 'A1'], ['A', 'A2'], ['A', 'A3'], ['B', 'B1'], ['B', 'B2'],
  ]

  for (const [kjede, s] of alle) {
    for (const linje of r.seed_ekstra ?? []) {
      const ctx: Record<string, string> = { retailer: R[kjede], stasjon: S[s], unik: s, unik_dato: `current_date` }
      for (const m of linje.matchAll(/\{\{seed:([a-z_]+)\}\}/g)) {
        ctx[`seed:${m[1]}`] = seedId(`${r.tabell}:${m[1]}:${s}`)
      }
      linjer.push(`${fyll(linje, ctx)};`)
    }
  }

  // Én fast proberad per stasjon, til lese- og flyttetester.
  for (const [kjede, s] of alle) {
    const { kolonner, verdier } = proberadSql(r, kjede, s, `fast${s}`)
    const id = seedId(`${r.tabell}:fast:${s}`)
    linjer.push(`insert into public.${r.tabell} (id, ${kolonner.join(', ')}) values (${sitat(id)}, ${verdier.join(', ')});`)
  }

  // `nyrad_*` lager en fersk rad rett før en update/delete-test, saa en
  // tillatt sletting ikke river grunnlaget for neste paastand.
  const { kolonner, verdier } = proberadSql(r, 'A', 'A1', 'ny')
  const kolonnerUtenTenant = kolonner.filter((c) => c !== 'stasjon_id' && c !== 'retailer_id')
  const verdierUtenTenant = verdier.filter((_, idx) => kolonner[idx] !== 'stasjon_id' && kolonner[idx] !== 'retailer_id')
  const tenantParam = r.tenant_scope === 'retailer'
    ? ['retailer_id']
    : r.tenant_scope === 'retailer_and_station' ? ['retailer_id', 'stasjon_id'] : ['stasjon_id']
  const tenantVerdi = tenantParam.map((c) => c === 'retailer_id' ? 'p_retailer' : 'p_stasjon')

  linjer.push(`
create or replace function pg_temp.nyrad_${r.tabell}(p_retailer uuid, p_stasjon uuid, p_merke text)
returns uuid language plpgsql security definer as $fn$
declare ny uuid;
begin
  insert into public.${r.tabell} (${[...tenantParam, ...kolonnerUtenTenant].join(', ')})
  values (${[...tenantVerdi, ...verdierUtenTenant.map((v) => v.replace(/'sonde [^']*'/, "'sonde ' || p_merke"))].join(', ')})
  returning id into ny;
  return ny;
end $fn$;`)

  return linjer.join('\n')
}

const HJELPERE = `
-- --- Hjelpere --------------------------------------------------------
create temp table funn (
  nr serial primary key, status text not null, navn text not null, detalj text
) on commit drop;

create or replace function pg_temp.logg(p_status text, p_navn text, p_detalj text default null)
returns void language plpgsql security definer as $$
begin
  insert into pg_temp.funn (status, navn, detalj) values (p_status, p_navn, p_detalj);
end $$;

create or replace function pg_temp.logg_inn_som(p_uid uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end $$;

create or replace function pg_temp.som_eier() returns void
language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

create or replace function pg_temp.paastand(p_navn text, p_ok boolean) returns void
language plpgsql security definer as $$
begin
  perform pg_temp.logg(case when p_ok is true then 'ok' else 'FEIL' end, p_navn);
end $$;

-- SECURITY INVOKER, og det er ikke valgfritt: den dynamiske setningen
-- MAA kjore som testbrukeren. Blir denne definer, gaar skrivingen som
-- eier - forbi RLS - og hele fila blir groenn uansett hva policyen sier.
--
-- 42501 ELLER NULL RADER, INGENTING ANNET. En unique-skranke (23505)
-- eller en fremmednokkel (23503) avviser ogsaa, men beviser ingenting
-- om tenantvernet. Slike svar er FEIL her, ikke ok.
-- KONTROLLKONTEKST. Definer, saa den ser forbi RLS og svarer paa om
-- raden i det hele tatt finnes. Uten den er "0 rader" tvetydig.
create or replace function pg_temp.finnes(p_tabell text, p_id uuid) returns boolean
language plpgsql security definer as $$
declare n int;
begin
  execute format('select count(*) from public.%I where id = $1', p_tabell) into n using p_id;
  return n > 0;
end $$;

create or replace function pg_temp.skriv_avvist(
  p_navn text, p_sql text,
  p_maal_tabell text default null, p_maal_id uuid default null
) returns void
language plpgsql as $$
declare n bigint;
begin
  begin
    execute p_sql;
    get diagnostics n = row_count;
  exception when others then
    if sqlstate = '42501' then
      perform pg_temp.logg('ok', p_navn, 'avvist med 42501');
    else
      perform pg_temp.logg('FEIL', p_navn,
        'avvist av FEIL grunn: ' || sqlstate || ' - beviser ikke tenantvern');
    end if;
    return;
  end;
  if n > 0 then
    perform pg_temp.logg('FEIL', p_navn, 'skrivingen gikk gjennom, ' || n || ' rad(er)');
    return;
  end if;

  -- NULL RADER ER IKKE ET BEVIS I SEG SELV.
  --
  -- \`using\` som utelukker raden gir 0 rader. Men det gjor OGSAA en feil
  -- id, en fixture som aldri ble seedet, eller en tabell som er tom.
  -- Alle tre ser identiske ut herfra, og alle tre ville vaert groenne.
  --
  -- Derfor: raden maa bevises aa finnes i kontrollkonteksten foer 0
  -- rader godtas. Da - og bare da - er det RLS som stoppet skrivingen.
  if p_maal_tabell is null then
    perform pg_temp.logg('FEIL', p_navn,
      '0 rader, men ingen maalrad oppgitt - kan ikke skille RLS fra feil fixture');
  elsif not pg_temp.finnes(p_maal_tabell, p_maal_id) then
    perform pg_temp.logg('FEIL', p_navn,
      '0 rader, men maalraden ' || p_maal_id || ' finnes ikke i ' || p_maal_tabell
      || ' - testen beviser ingenting');
  else
    perform pg_temp.logg('ok', p_navn, '0 rader, maalrad bekreftet');
  end if;
end $$;

create or replace function pg_temp.skriv_tillatt(p_navn text, p_sql text) returns void
language plpgsql as $$
declare n bigint;
begin
  begin
    execute p_sql;
    get diagnostics n = row_count;
  exception when others then
    perform pg_temp.logg('FEIL', p_navn, 'ble blokkert: ' || sqlstate);
    return;
  end;
  if n = 0 then
    perform pg_temp.logg('FEIL', p_navn, 'traff 0 rader - blokkert i stillhet');
  else
    perform pg_temp.logg('ok', p_navn, n || ' rad');
  end if;
end $$;
`

function genererRessurs(r: Ressurs): string {
  const linjer: string[] = ['', `-- =====================================================================`,
    `-- ${r.tabell}  (${r.tenant_scope}, ${r.data_class})`,
    `-- =====================================================================`]

  const stasjonsbasert = r.tenant_scope !== 'retailer'

  for (const i of IDENTITETER) {
    linjer.push(`\nselect pg_temp.logg_inn_som(${sitat(i.uid)});   -- ${i.navn}`)

    const mål = stasjonsbasert ? maal(i) : ([...new Set(maal(i).map((s) => kjedenFor(s)))] as Kjede[])
      .flatMap((kj) => [KJEDENS_STASJONER[kj][0]])

    for (const op of r.operasjoner) {
      for (const s of mål) {
        const ok = tillatt(r, i, op, s)
        const kjede = kjedenFor(s)
        const navn = `${r.tabell} ${i.navn} ${op.toUpperCase()} ${stasjonsbasert ? s : kjede}`
        const fastId = seedId(`${r.tabell}:fast:${s}`)

        if (op === 'select') {
          linjer.push(`select pg_temp.paastand(${sitat(`${navn} -> ${ok ? 'ser' : 'ser ikke'}`)}, ${
            ok ? '' : 'not '}exists (select 1 from public.${r.tabell} where id = ${sitat(fastId)}));`)
          continue
        }

        if (op === 'insert') {
          const { kolonner, verdier } = proberadSql(r, kjede, s, `${i.navn}${s}`)
          const sql = `insert into public.${r.tabell} (${kolonner.join(', ')}) values (${verdier.join(', ')})`
          linjer.push(`select pg_temp.${ok ? 'skriv_tillatt' : 'skriv_avvist'}(${sitat(navn)}, ${sitat(sql)});`)
          continue
        }

        // update og delete far en fersk rad, saa en tillatt sletting
        // ikke river grunnlaget for neste paastand.
        linjer.push(`select pg_temp.som_eier();`)
        linjer.push(`select pg_temp.nyrad_${r.tabell}(${sitat(R[kjede])}, ${sitat(S[s])}, ${sitat(`${i.navn}-${op}`)}) as _;`)
        linjer.push(`select pg_temp.logg_inn_som(${sitat(i.uid)});`)

        const sql = op === 'update'
          ? `update public.${r.tabell} set ${settbartFelt(r)} where id = ${sitat(fastId)}`
          : `delete from public.${r.tabell} where id = ${sitat(fastId)}`
        // Maalraden foelger med paa avvisninger: "0 rader" godtas bare
        // naar kontrollkonteksten bekrefter at raden faktisk finnes.
        const maalrad = `, ${sitat(r.tabell)}, ${sitat(fastId)}`
        linjer.push(ok
          ? `select pg_temp.skriv_tillatt(${sitat(navn)}, ${sitat(sql)});`
          : `select pg_temp.skriv_avvist(${sitat(navn)}, ${sitat(sql)}${maalrad});`)

        // Etter en tillatt sletting maa den faste raden tilbake.
        if (op === 'delete' && ok) {
          linjer.push(`select pg_temp.som_eier();`)
          const { kolonner, verdier } = proberadSql(r, kjede, s, `gjen${i.navn}${s}`)
          linjer.push(`insert into public.${r.tabell} (id, ${kolonner.join(', ')}) values (${sitat(fastId)}, ${verdier.join(', ')});`)
          linjer.push(`select pg_temp.logg_inn_som(${sitat(i.uid)});`)
        }
      }
    }

    // --- TENANT-FLYTTING ---------------------------------------------
    // `using` slipper raden inn fordi den ER hennes. Bare `with check`
    // kan stoppe at den flyttes ut. Dette er den ene testen som skiller
    // de to klausulene fra hverandre.
    if (r.operasjoner.includes('update')) {
      const egen = i.stasjoner.find((s) => tillatt(r, i, 'update', s))
      if (egen) {
        const fastId = seedId(`${r.tabell}:fast:${egen}`)
        const forbudtISammeKjede = KJEDENS_STASJONER[i.kjede].find((s) => !tillatt(r, i, 'update', s))
        const annenKjede = ANNEN_KJEDE[i.kjede]

        if (stasjonsbasert && forbudtISammeKjede && !r.tenant_kolonne) {
          linjer.push(`select pg_temp.skriv_avvist(${sitat(`${r.tabell} ${i.navn} FLYTTER egen rad ${egen} -> ${forbudtISammeKjede}`)}, ${
            sitat(`update public.${r.tabell} set stasjon_id = ${sitat(S[forbudtISammeKjede])} where id = ${sitat(fastId)}`)}, ${sitat(r.tabell)}, ${sitat(fastId)});`)
        }
        if (r.tenant_scope === 'retailer' || r.tenant_scope === 'retailer_and_station') {
          linjer.push(`select pg_temp.skriv_avvist(${sitat(`${r.tabell} ${i.navn} FLYTTER egen rad -> kjede ${annenKjede}`)}, ${
            sitat(`update public.${r.tabell} set retailer_id = ${sitat(R[annenKjede])} where id = ${sitat(fastId)}`)}, ${sitat(r.tabell)}, ${sitat(fastId)});`)
        }
      }
    }
  }
  return linjer.join('\n')
}

function kjedenFor(s: Stasjon): Kjede {
  return KJEDENS_STASJONER.A.includes(s) ? 'A' : 'B'
}

/** Et felt som trygt kan skrives i en update-test. */
function settbartFelt(r: Ressurs): string {
  if (r.oppdaterbart) return r.oppdaterbart
  const kandidat = Object.keys(r.proberad).find((k) => !k.endsWith('_id'))
  if (!kandidat) {
    throw new Error(`${r.tabell}: proberaden har bare fremmednokler - sett \`oppdaterbart\` i kontrakten`)
  }
  const verdi = r.proberad[kandidat]
  return `${kandidat} = ${verdi.includes('{{') ? fyll(verdi, { unik: 'endret', unik_dato: `date '2026-09-09'`, retailer: '', stasjon: '' }) : verdi}`
}
