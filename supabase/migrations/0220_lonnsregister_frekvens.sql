-- =====================================================================
-- 0220: betalingsfrekvens i lonnsregister
-- =====================================================================
--
-- ADDITIV. Én nullbar kolonne og et check-constraint. Ingen eksisterende
-- rad endres, ingen policy roeres, ingen indeks droppes. `0218` staar
-- uroert - en kjoert migrasjon endres aldri.
--
-- ---------------------------------------------------------------------
-- TALLET UTEN ENHETEN ER IKKE ET TALL
--
-- `lonnsregister.timesats` inneholder i dag 48736 for Sandra paa Lone i
-- juli 2026. Det er ikke en timesats - det er maanedsloenna hennes, i en
-- kolonne som lover at enheten er timer.
--
-- Easy@Work sa det rett ut hele tiden. Loennsgrunnlaget har kolonnen
-- `Betalingsfrekvens`, og parseren brukte den bare til aa kjenne igjen
-- filtypen foer den kastet den. Vi lagret tallet og mistet enheten.
--
-- MAALT over alle 28 loennsgrunnlagsfilene: kolonnen finnes i hver
-- eneste én, 518 ansattmaaneder, 511 «Time» og 7 «Maaned». Alle sju er
-- Sandra, januar til juli 2026, alle med 48736. I august staar hun med
-- «Time» og 285.
--
-- ---------------------------------------------------------------------
-- TO VERDIER, IKKE FLERE
--
-- `time` og `maaned` er de eneste observerte, og de eneste tillatte.
-- Kilden skriver dem med norske tegn («Måned»); konverteringen til
-- ASCII skjer ÉN gang, eksplisitt, paa parsergrensen. Da flyter ikke
-- «Måned», «Maaned» og tilfeldige varianter rundt som tre semantikker.
--
-- `null` er lovlig og betyr UKJENT - enten en rad skrevet foer denne
-- migrasjonen, eller en verdi kilden ga som vi ikke kjenner igjen. Det
-- er ikke det samme som «Time», og skal aldri bli det.
--
-- ---------------------------------------------------------------------
-- HVA KOLONNEN BETYR, OG HVA DEN IKKE BETYR
--
-- `maaned` er et veto mot TIMEPRISING. Den sier ikke at personen koster
-- null kroner - fastloenn er ofte en stor faktisk loennskostnad. Den
-- sier at Sentiqa ikke skal finne paa en timesats og gange timene med
-- den. Timene beholdes, telles og knyttes til faktisk arbeidssted; de
-- bidrar bare ikke til den TIMEBEREGNEDE 503-komponenten i A1.
--
-- ---------------------------------------------------------------------
-- HISTORIKKEN OMSKRIVES IKKE
--
-- Sandra staar «Maaned» i sju maaneder og «Time» i august. Vi vet ikke
-- om arbeidsforholdet endret seg eller om Easy-data ble rettet.
-- Registeret bevarer begge observasjonene, maaned for maaned, og velger
-- ikke side. Det er hele grunnen til at `kilde_maaned` er en
-- noekkeldel.
-- =====================================================================

alter table public.lonnsregister
  add column if not exists betalingsfrekvens text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'lonnsregister_frekvens_sjekk'
  ) then
    alter table public.lonnsregister
      add constraint lonnsregister_frekvens_sjekk
      check (betalingsfrekvens is null or betalingsfrekvens in ('time', 'maaned'));
  end if;
end $$;

comment on column public.lonnsregister.betalingsfrekvens is
  'ENHETEN paa timesats-kolonnen, slik easy@work oppga den for maaneden. '
  '«maaned» betyr at tallet er maanedsloenn og ALDRI skal timeprises. '
  'null = ukjent, ikke «time».';


-- ---------------------------------------------------------------------
-- SNAPSHOT-RPC-EN MAA KJENNE FELTET
-- ---------------------------------------------------------------------
-- Samme signatur som i `0218`, saa `create or replace` holder og ingen
-- grant maa settes paa nytt. Kroppen er identisk bortsett fra den nye
-- kolonnen i `insert` og i `jsonb_to_recordset`.
--
-- Kjores hele settet fra bunn, oppretter 0218 funksjonen uten feltet og
-- 0220 erstatter den. Rekkefoelgen er allerede riktig.
create or replace function public.lonnsregister_snapshot(
  p_stasjon_id uuid,
  p_maaned     text,
  p_jobb_id    uuid,
  p_rader      jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  -- 1. TENANTPREDIKATET STAAR HER, ikke i en policy noen kan glemme.
  if p_stasjon_id is null or not exists (
    select 1 from public.mine_stasjoner() m where m = p_stasjon_id
  ) then
    raise exception 'Stasjonen finnes ikke, eller du har ikke tilgang til den.';
  end if;

  -- 2. Samme rollekrav som skrivepolicyen.
  if (select public.gjeldende_rolle()) not in ('retailer_admin', 'butikksjef') then
    raise exception 'Rollen din kan ikke skrive loennsdata.';
  end if;

  -- 3. Maaneden er en noekkeldel.
  if p_maaned is null or p_maaned !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'Ugyldig maaned «%». Forventet yyyy-mm.', p_maaned;
  end if;

  -- 4. Proveniens som peker paa en annen kjede er verre enn ingen.
  if p_jobb_id is not null and not exists (
    select 1
      from public.import_jobber j
      join public.stasjoner s on s.id = p_stasjon_id
     where j.id = p_jobb_id
       and j.retailer_id = s.retailer_id
  ) then
    raise exception 'Importjobben hoerer ikke til samme kjede som stasjonen.';
  end if;

  -- RYDD FOERST, SKRIV ETTERPAA - i samme transaksjon.
  delete from public.lonnsregister
   where stasjon_id  = p_stasjon_id
     and kilde_maaned = p_maaned;

  -- STASJON OG MAANED KOMMER FRA PARAMETRENE, IKKE FRA NYTTELASTEN.
  insert into public.lonnsregister
    (stasjon_id, kilde_maaned, ansatt_nr, navn, timesats, betalingsfrekvens,
     import_jobb_id)
  select
    p_stasjon_id,
    p_maaned,
    r.ansatt_nr,
    r.navn,
    r.timesats,
    r.betalingsfrekvens,
    p_jobb_id
  from jsonb_to_recordset(coalesce(p_rader, '[]'::jsonb))
    as r(ansatt_nr text, navn text, timesats numeric, betalingsfrekvens text);

  get diagnostics n = row_count;
  return n;
end;
$$;

comment on function public.lonnsregister_snapshot(uuid, text, uuid, jsonb) is
  'Erstatter registersnapshotet for én stasjon og maaned, atomisk. '
  'Baerer fra 0220 ogsaa betalingsfrekvens - enheten paa timesatsen. '
  'Validerer tenant, rolle, maaned og importjobb selv; radenes stasjon '
  'og maaned tas fra parametrene, aldri fra nyttelasten.';


-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- En migrasjon som lykkes uten aa si fra, ser ut som en som feilet.
select
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'lonnsregister'
      and column_name = 'betalingsfrekvens')                              as kolonnen,
  (select count(*) from pg_constraint
    where conname = 'lonnsregister_frekvens_sjekk')                       as skranken,
  (select count(*) from public.lonnsregister)                             as rader_totalt,
  (select count(*) from public.lonnsregister
    where betalingsfrekvens is not null)                                  as med_frekvens,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'lonnsregister')          as policyer,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'lonnsregister'
      and grantee = 'anon')                                               as anon_grants;
