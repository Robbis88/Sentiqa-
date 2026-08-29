-- =====================================================================
-- SEMANTISK KODEMAPPING PER RETAILER
--
-- `v_butikksalg` og `PRODUKSJON_KODER` har identifisert drivstoff og
-- produksjonsvarer med St1-litteraler. Baselinen 2026-08-28 viste hvor
-- skjoert det var: koden `10` fantes ikke i data i det hele tatt, og det
-- var navnesjekken paa `ENERGI` som gjorde hele jobben alene.
--
-- Denne migrasjonen flytter definisjonen fra kode til konfigurasjon.
--
-- ---------------------------------------------------------------------
-- FAIL-CLOSED, OG HVORFOR
--
-- En kjede uten drivstoffkonfigurasjon ser NULL rader i `v_butikksalg`.
-- Det er med vilje. Alternativet - aa slippe alt gjennom ufiltrert -
-- gir troverdige og gale butikktall, og drivstoff er 25-62 % av
-- omsetningen per stasjon. En synlig sperre er bedre enn et tall ingen
-- vet er feil.
--
-- Tom konfigurasjon betyr **uavklart**, ikke "ingen drivstoff". De to
-- skilles av en eksplisitt erklaering.
--
-- ---------------------------------------------------------------------
-- HVEM KAN AAPNE ALT
--
-- Paastanden "vi har ikke drivstoff" aapner hver eneste rad. Den krever
-- derfor en Sentiqa-kontroll foer den teller.
--
-- Det finnes ingen Sentiqa-rolle i basen - rollene er `retailer_admin`,
-- `butikksjef`, `butikkbruker_tablet` og `plattform_redaktor`. Derfor er
-- `kontrollert_tid` **ikke skrivbar fra appen i det hele tatt**:
-- `with check`-klausulene krever at den er null. Kontrollen settes av oss
-- i SQL Editor, som de oevrige kontrollpunktene i onboardingmodellen.
--
-- Det er ikke en forglemmelse. Det er den eneste formen som er trygg foer
-- en Sentiqa-flate finnes: ingen vei gjennom appen kan aapne alt.
--
-- ---------------------------------------------------------------------
-- MAALT FOER FORMEN BLE VALGT
--
-- `not exists` mot en anti-join mot dagens litteralfilter, to
-- arbeidsmengder, 2026-08-28. `not exists` og anti-join gav samme plan
-- (1376 mot 1425 ms bredt). Kostnaden er 3,8x paa 400 dager x alle
-- stasjoner - 1,4 sekunder - og 8 -> 20 ms paa det brukeren venter paa.
-- Se `supabase/tests/maaling_kodemapping_resultat.txt`.
--
-- Idempotent: `if not exists` / `or replace` / vaktede innsettinger.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELLENE
-- ---------------------------------------------------------------------

create table if not exists public.retailer_kodeerklaering (
  retailer_id     uuid not null references public.retailers(id) on delete cascade,
  -- Bare drivstoff i P0. Produksjon trenger ingen erklaering: tom mapping
  -- der gir tom plan, som er synlig og ufarlig. Sjekken hindrer at noen
  -- skriver en produksjonsrad i dag; aa aapne for det senere er en linje.
  rolle           text not null default 'drivstoff'
                  check (rolle in ('drivstoff')),
  gjelder         boolean not null,
  oppgitt_av      uuid references public.profiler(id) on delete set null,
  oppgitt_tid     timestamptz not null default now(),
  kontrollert_av  uuid references public.profiler(id) on delete set null,
  kontrollert_tid timestamptz,
  -- Halv kontroll finnes ikke.
  check ((kontrollert_av is null) = (kontrollert_tid is null)),
  primary key (retailer_id, rolle)
);

create table if not exists public.retailer_koderegel (
  id          uuid primary key default gen_random_uuid(),
  retailer_id uuid not null references public.retailers(id) on delete cascade,
  rolle       text not null check (rolle in ('drivstoff', 'produksjon')),
  nivaa       text not null check (nivaa in ('avdeling', 'varegruppe')),
  kode        text,
  navn        text,
  opprettet_av  uuid references public.profiler(id) on delete set null,
  opprettet_tid timestamptz not null default now(),
  -- En regel uten bade kode og navn treffer ingenting, og ville sett ut
  -- som en konfigurasjon uten aa vaere det.
  check (kode is not null or navn is not null),
  -- P0-kontrakten: drivstoff paa avdeling, produksjon paa varegruppe.
  -- Ingen bevist retailer trenger noe annet, saa ingenting bygges for det.
  check ((rolle = 'drivstoff'  and nivaa = 'avdeling')
      or (rolle = 'produksjon' and nivaa = 'varegruppe'))
);

-- Navn sammenlignes uten hensyn til store bokstaver overalt, saa unikheten
-- maa gjoere det samme - ellers kan 'ENERGI' og 'Energi' ligge side om side
-- og se ut som to regler mens de er en.
create unique index if not exists retailer_koderegel_unik
  on public.retailer_koderegel
     (retailer_id, rolle, nivaa, coalesce(kode, ''), coalesce(upper(navn), ''));

create index if not exists retailer_koderegel_oppslag
  on public.retailer_koderegel (retailer_id, rolle, nivaa);

-- ---------------------------------------------------------------------
-- 2. RETTIGHETER OG RLS
-- ---------------------------------------------------------------------
-- `anon` er rollen bak den offentlige noekkelen i hver sidelast.

revoke all on public.retailer_kodeerklaering from anon, authenticated;
revoke all on public.retailer_koderegel      from anon, authenticated;

grant select, insert, update, delete on public.retailer_kodeerklaering to authenticated;
grant select, insert, update, delete on public.retailer_koderegel      to authenticated;
grant all on public.retailer_kodeerklaering to service_role;
grant all on public.retailer_koderegel      to service_role;

alter table public.retailer_kodeerklaering enable row level security;
alter table public.retailer_koderegel      enable row level security;

-- SELECT for HELE tenanten, ikke bare eier.
--
-- `v_butikksalg` joiner `retailer_kodeerklaering`. Mangler en rolle
-- leserett her, finner joinen ingenting - og DA SER DEN ROLLEN NULL
-- SALGSRADER. Nettbrettet og butikksjefen ville mistet alt, uten at noe
-- sa fra. Dette er migrasjonens farligste linje.
drop policy if exists kodeerklaering_les on public.retailer_kodeerklaering;
create policy kodeerklaering_les on public.retailer_kodeerklaering
  for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists koderegel_les on public.retailer_koderegel;
create policy koderegel_les on public.retailer_koderegel
  for select to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id()));

-- SKRIV: kun eier, og ALDRI kontrollfeltene.
--
-- `with check` binder kolonneverdier, ikke bare rader. Det er den som
-- hindrer at en retailer bekrefter sin egen "ingen drivstoff"-paastand og
-- dermed aapner alle radene sine. Kolonnerettigheter ville ikke hjulpet:
-- alle approller deler postgres-rollen `authenticated`.
drop policy if exists kodeerklaering_ny on public.retailer_kodeerklaering;
create policy kodeerklaering_ny on public.retailer_kodeerklaering
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin'
              and kontrollert_av is null and kontrollert_tid is null);

drop policy if exists kodeerklaering_endre on public.retailer_kodeerklaering;
create policy kodeerklaering_endre on public.retailer_kodeerklaering
  for update to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin')
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and kontrollert_av is null and kontrollert_tid is null);

drop policy if exists kodeerklaering_slett on public.retailer_kodeerklaering;
create policy kodeerklaering_slett on public.retailer_kodeerklaering
  for delete to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists koderegel_ny on public.retailer_koderegel;
create policy koderegel_ny on public.retailer_koderegel
  for insert to authenticated
  with check (retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle())::text = 'retailer_admin');

drop policy if exists koderegel_endre on public.retailer_koderegel;
create policy koderegel_endre on public.retailer_koderegel
  for update to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin')
  with check (retailer_id = (select public.gjeldende_retailer_id()));

drop policy if exists koderegel_slett on public.retailer_koderegel;
create policy koderegel_slett on public.retailer_koderegel
  for delete to authenticated
  using (retailer_id = (select public.gjeldende_retailer_id())
         and (select public.gjeldende_rolle())::text = 'retailer_admin');

-- ---------------------------------------------------------------------
-- 3. BACKFILL - FOER VIEWET BYTTER KILDE
-- ---------------------------------------------------------------------
-- Rekkefoelgen er sikkerhetskritisk. Kjoeres bare halve migrasjonen, og
-- viewet bytter foer radene finnes, ser Kelsar null salg i hele
-- produktet. Det er `0065`-formen: halvveis kjoert, stille galt.
--
-- Bare kjeder som FAKTISK HAR SALG backfilles. En kjede uten data kan
-- ikke skades av aa vaere laast, og aa laase den er det riktige svaret.

insert into public.retailer_kodeerklaering (retailer_id, rolle, gjelder)
select distinct d.retailer_id, 'drivstoff', true
from public.daglig_salg d
where d.slettet_tid is null
  and not exists (select 1 from public.retailer_kodeerklaering e
                  where e.retailer_id = d.retailer_id and e.rolle = 'drivstoff');

-- BEGGE armene fra dagens filter: koden OG navnet. Baselinen viste at
-- koden aldri traff noe - men aa droppe den her ville vaert en endring i
-- atferd, og denne migrasjonen skal ikke endre Kelsars tall.
insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode, navn)
select r.retailer_id, 'drivstoff', 'avdeling', v.kode, v.navn
from (select distinct retailer_id from public.daglig_salg where slettet_tid is null) r
cross join (values ('10'::text, null::text),
                   ('1000'::text, null::text),
                   (null::text, 'ENERGI'::text)) v(kode, navn)
where not exists (
  select 1 from public.retailer_koderegel x
  where x.retailer_id = r.retailer_id and x.rolle = 'drivstoff' and x.nivaa = 'avdeling'
    and coalesce(x.kode, '') = coalesce(v.kode, '')
    and coalesce(upper(x.navn), '') = coalesce(upper(v.navn), ''));

insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode, navn)
select r.retailer_id, 'produksjon', 'varegruppe', k, null
from (select distinct retailer_id from public.daglig_salg where slettet_tid is null) r
cross join unnest(array['1201','1202','1203','1216','1217','1218','1219','1221']) k
where not exists (
  select 1 from public.retailer_koderegel x
  where x.retailer_id = r.retailer_id and x.rolle = 'produksjon'
    and x.nivaa = 'varegruppe' and x.kode = k);

-- ---------------------------------------------------------------------
-- 4. VIEWET
-- ---------------------------------------------------------------------
-- `security_invoker = true` staar i SAMME setning. Uten den nullstilles
-- flagget i stillhet, viewet leses som eier, og RLS er forbi - en diff
-- som ikke ser farlig ut. Vakthundens punkt 9 kaster paa det.
--
-- `create or replace`, ikke drop: seks migrasjoner leser dette viewet, og
-- en cascade ville tatt dem med seg.

create or replace view public.v_butikksalg
with (security_invoker = true) as
select d.*
from public.daglig_salg d
-- INNER JOIN er hele fail-close-mekanismen: ingen erklaering, ingen rader.
join public.retailer_kodeerklaering e
  on e.retailer_id = d.retailer_id and e.rolle = 'drivstoff'
where d.slettet_tid is null
  and (
    -- "Ingen drivstoff" aapner ALLE rader, og teller derfor foerst naar
    -- Sentiqa har kontrollert den.
    (e.gjelder = false and e.kontrollert_tid is not null)
    -- "Har drivstoff" aapner bare naar det finnes noe aa filtrere paa.
    -- Uten dette leddet ville en halvferdig konfigurasjon sluppet alt
    -- gjennom ufiltrert.
    or (e.gjelder = true and exists (
          select 1 from public.retailer_koderegel r
          where r.retailer_id = d.retailer_id and r.rolle = 'drivstoff'))
  )
  and not exists (
        select 1 from public.retailer_koderegel r
        where r.retailer_id = d.retailer_id
          and r.rolle = 'drivstoff' and r.nivaa = 'avdeling'
          and ((r.kode is not null and r.kode = d.avdeling_kode)
            or (r.navn is not null
                and upper(r.navn) = upper(coalesce(d.avdeling_navn, '')))));

comment on view public.v_butikksalg is
  'Butikkens salg: daglig_salg uten drivstoff, definert av '
  'retailer_koderegel. LES DENNE, ikke daglig_salg, i alt som summerer '
  'kroner eller antall. Fail-closed: en kjede uten drivstofferklaering '
  'ser null rader, fordi ufiltrert er verre enn tomt.';

grant select on public.v_butikksalg to authenticated;
revoke all on public.v_butikksalg from anon;

-- ---------------------------------------------------------------------
-- 5. STATUS - UTLEDET, IKKE LAGRET
-- ---------------------------------------------------------------------
-- Onboardingen leser dette viewet. Ingen hardkodet sjekkliste ved siden
-- av: blir mappingen endret, endres laasen i samme oeyeblikk, fordi de er
-- samme rad.

create or replace view public.v_retailer_kodestatus
with (security_invoker = true) as
select r.id as retailer_id, 'drivstoff'::text as rolle,
       case
         when e.retailer_id is null                        then 'ikke_konfigurert'
         when e.gjelder = false and e.kontrollert_tid is null
                                                           then 'ingen_oppgitt'
         when e.gjelder = false                            then 'ingen_kontrollert'
         when not exists (select 1 from public.retailer_koderegel g
                          where g.retailer_id = r.id and g.rolle = 'drivstoff')
                                                           then 'mangler_mapping'
         else 'mappet'
       end as status
from public.retailers r
left join public.retailer_kodeerklaering e
  on e.retailer_id = r.id and e.rolle = 'drivstoff'

union all

-- Produksjon har ingen erklaering: status ER reglene. Tom mapping gir
-- 'ikke_konfigurert', og ingen "vi har ingen produksjon"-semantikk er
-- bygget - den lages den dagen en ekte kjede trenger den.
select r.id, 'produksjon',
       case when exists (select 1 from public.retailer_koderegel g
                         where g.retailer_id = r.id and g.rolle = 'produksjon'
                           and g.nivaa = 'varegruppe')
            then 'mappet' else 'ikke_konfigurert' end
from public.retailers r;

grant select on public.v_retailer_kodestatus to authenticated;
revoke all on public.v_retailer_kodestatus from anon;

-- ---------------------------------------------------------------------
-- 6. TREFFER MAPPINGEN DATA?
-- ---------------------------------------------------------------------
-- "Mappet" skal ikke bety at noen skrev inn en kode. En regel paa 9999
-- som treffer null rader ser i statusviewet noeyaktig ut som en riktig
-- regel - og slipper drivstoffet rett inn i butikktallene.
--
-- LESER `daglig_salg` MED VILJE. `v_butikksalg` har alt fjernet
-- drivstoffet, saa der er svaret alltid null. For aa maale hva reglene
-- faktisk fjerner maa vi se radene de fjerner. Dette er unntaket
-- husreglene aapner for, og grunnen staar her.
--
-- Dette er en OBSERVASJON, ikke en laas. En fersk kjede kan ha drivstoff
-- uten aa ha lastet opp salg som inneholder det enda, og en laas der
-- ville vaert en heuristikk forkledd som bevis.

create or replace view public.v_retailer_drivstofftreff
with (security_invoker = true) as
select d.retailer_id,
       count(*) filter (where exists (
         select 1 from public.retailer_koderegel r
         where r.retailer_id = d.retailer_id
           and r.rolle = 'drivstoff' and r.nivaa = 'avdeling'
           and ((r.kode is not null and r.kode = d.avdeling_kode)
             or (r.navn is not null
                 and upper(r.navn) = upper(coalesce(d.avdeling_navn, ''))))
       ))                                                    as treff_rader,
       coalesce(sum(d.omsetning_eks_mva) filter (where exists (
         select 1 from public.retailer_koderegel r
         where r.retailer_id = d.retailer_id
           and r.rolle = 'drivstoff' and r.nivaa = 'avdeling'
           and ((r.kode is not null and r.kode = d.avdeling_kode)
             or (r.navn is not null
                 and upper(r.navn) = upper(coalesce(d.avdeling_navn, ''))))
       )), 0)                                                as treff_kr,
       count(*)                                              as rader_i_vindu,
       min(d.dato)                                           as fra,
       max(d.dato)                                           as til
from public.daglig_salg d
where d.slettet_tid is null
  and d.dato >= current_date - interval '90 days'
group by d.retailer_id;

comment on view public.v_retailer_drivstofftreff is
  'Treffer drivstoffmappingen faktisk data? treff_rader=0 med '
  'rader_i_vindu>0 er nesten alltid feil kode. Advarsel, ikke laas.';

grant select on public.v_retailer_drivstofftreff to authenticated;
revoke all on public.v_retailer_drivstofftreff from anon;

-- ---------------------------------------------------------------------
-- 7. KVITTERING
-- ---------------------------------------------------------------------
-- SQL Editor viser ikke `raise notice`, saa svaret maa komme som en rad.
-- Er `laaste_kjeder_med_salg` noe annet enn 0, staar en kjede med salg
-- uten konfigurasjon - og da ser den null rader i hele produktet.

select (select count(*) from public.retailer_kodeerklaering)          as erklaeringer,
       (select count(*) from public.retailer_koderegel
        where rolle = 'drivstoff')                                    as drivstoffregler,
       (select count(*) from public.retailer_koderegel
        where rolle = 'produksjon')                                   as produksjonsregler,
       (select count(*) from public.v_retailer_kodestatus
        where rolle = 'drivstoff' and status = 'mappet')              as mappet,
       (select count(*) from (
          select distinct d.retailer_id from public.daglig_salg d
          where d.slettet_tid is null
            and not exists (select 1 from public.v_retailer_kodestatus s
                            where s.retailer_id = d.retailer_id
                              and s.rolle = 'drivstoff'
                              and s.status in ('mappet', 'ingen_kontrollert'))
        ) x)                                                          as laaste_kjeder_med_salg;
