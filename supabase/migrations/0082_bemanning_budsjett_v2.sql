-- =====================================================================
-- Sentiqa - 0082_bemanning_budsjett_v2.sql
-- Utvider bemanningsoppsettet fra 0081 etter at BP-en og timebudsjettet
-- fra St1 er lest:
--
--   1) Ny rapporttype for BP-fila (retailer laster den opp en gang i aaret).
--   2) bemanning_vindu faar gjelder_fra - aapningstider endres permanent
--      (Dale gikk fra 07-22 til 06-24 i juni 2026), og historikken foer
--      endringen kan ikke brukes til aa planlegge timene etter den.
--   3) bemanning_aar - aarstimebudsjettet og satsene, pr stasjon.
--   4) bemanning_maned - DISPONIBLE timer, det eneste butikksjefen ser.
--
-- Punkt 4 er en tilgangsregel, ikke bare en tabell. Raatallet minus
-- sykefravaersreserve og sikkerhetsmargin skal ikke kunne regnes ut av
-- butikksjefen; hen skal se ett tall - "du har 790 timer i januar".
-- Derfor blir bemanning_budsjett og bemanning_aar retailer_admin-only,
-- og bemanning_maned er den publiserte, lesbare siden av det.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Rapporttype for BP-fila
-- ---------------------------------------------------------------------
alter type public.rapporttype add value if not exists 'st1_bp';


-- ---------------------------------------------------------------------
-- 2) Retailer-standard for sikkerhetsmargin
-- ---------------------------------------------------------------------
-- Butikksjefer bemanner erfaringsmessig over budsjett. Marginen holdes
-- tilbake sentralt. Satsen maa vaere en innstilling og ikke en konstant -
-- neste retailer har et annet tall.
alter table public.retailers
  add column if not exists bemanning_sikkerhet_pst numeric not null default 3
    check (bemanning_sikkerhet_pst >= 0 and bemanning_sikkerhet_pst < 100);

comment on column public.retailers.bemanning_sikkerhet_pst is
  'Andel av timebudsjettet som holdes tilbake sentralt. Overstyres pr stasjon i bemanning_aar.';


-- ---------------------------------------------------------------------
-- 3) bemanning_vindu: gyldig fra
-- ---------------------------------------------------------------------
alter table public.bemanning_vindu
  add column if not exists gjelder_fra date not null default date '2000-01-01';

comment on column public.bemanning_vindu.gjelder_fra is
  'Vinduet gjelder fra denne datoen til neste rad for samme stasjon/ukedag. '
  'Kundehistorikk foer datoen skal ikke brukes til aa planlegge timer etter den.';

-- Noekkelen maa utvides fra (stasjon, ukedag) til (stasjon, ukedag, gjelder_fra).
-- Constraint-navnet er autogenerert av 0081, saa vi leter det opp i katalogen.
do $$
declare
  c text;
begin
  select conname into c
  from pg_constraint
  where conrelid = 'public.bemanning_vindu'::regclass
    and contype = 'u'
    and pg_get_constraintdef(oid) = 'UNIQUE (stasjon_id, ukedag)';
  if c is not null then
    execute format('alter table public.bemanning_vindu drop constraint %I', c);
  end if;
end $$;

create unique index if not exists bemanning_vindu_unik
  on public.bemanning_vindu (stasjon_id, ukedag, gjelder_fra);


-- ---------------------------------------------------------------------
-- 4) bemanning_aar - aarsbudsjett og satser pr stasjon
-- ---------------------------------------------------------------------
-- timer_aar er den VARIABLE rammen (timeloenn, konto 503). St1 trekker ett
-- aarsverk fra foer de oppgir den, fordi butikksjefen gaar paa fastloenn -
-- men de timene er ekte dekning paa gulvet og maa legges inn igjen som
-- faste vakter. Derfor lagres fast_arsverk_timer ved siden av.
create table if not exists public.bemanning_aar (
  id                 uuid primary key default gen_random_uuid(),
  stasjon_id         uuid not null references public.stasjoner(id) on delete cascade,
  ar                 int  not null check (ar between 2020 and 2100),
  timer_aar          numeric not null check (timer_aar >= 0),
  fast_arsverk_timer numeric not null default 0 check (fast_arsverk_timer >= 0),
  reserve_pst        numeric check (reserve_pst >= 0 and reserve_pst < 100),
  sikkerhet_pst      numeric check (sikkerhet_pst >= 0 and sikkerhet_pst < 100),
  kilde              text,
  oppdatert_tid      timestamptz not null default now(),
  unique (stasjon_id, ar)
);
create index if not exists bemanning_aar_stasjon_idx
  on public.bemanning_aar (stasjon_id, ar);

comment on table public.bemanning_aar is
  'Aarstimebudsjett pr stasjon, fra St1s BP. IKKE synlig for butikksjef - se bemanning_maned.';
comment on column public.bemanning_aar.fast_arsverk_timer is
  'Timene St1 trekker fra for butikksjefens fastloenn (1695 = ett aarsverk). Legges inn igjen som faste vakter.';
comment on column public.bemanning_aar.reserve_pst is
  'Null = bruk clusterets poolede sykefravaerssats. Sett pr stasjon naar den ligger vedvarende hoyere.';
comment on column public.bemanning_aar.sikkerhet_pst is
  'Null = arv retailers.bemanning_sikkerhet_pst.';


-- ---------------------------------------------------------------------
-- 5) bemanning_maned - det butikksjefen ser
-- ---------------------------------------------------------------------
create table if not exists public.bemanning_maned (
  id               uuid primary key default gen_random_uuid(),
  stasjon_id       uuid not null references public.stasjoner(id) on delete cascade,
  ar               int  not null check (ar between 2020 and 2100),
  maned            int  not null check (maned between 1 and 12),
  disponible_timer numeric not null check (disponible_timer >= 0),
  beregnet_tid     timestamptz not null default now(),
  unique (stasjon_id, ar, maned)
);
create index if not exists bemanning_maned_stasjon_idx
  on public.bemanning_maned (stasjon_id, ar, maned);

comment on table public.bemanning_maned is
  'Disponible timer pr maaned - aarsrammen fordelt etter BP-ens bruttokurve, '
  'minus sykefravaersreserve og sikkerhetsmargin. Dette er tallet butikksjefen planlegger mot.';


-- =====================================================================
-- RLS
-- Samme moenster som 0081: aldri "for all", gjeldende_rolle() pakket i
-- (select ...), stasjonstilgang via mine_stasjoner().
--
-- Forskjellen her er HVEM som leser: bemanning_aar og bemanning_budsjett
-- er retailer_admin-only, bemanning_maned leses av alle med stasjonstilgang.
-- =====================================================================

alter table public.bemanning_aar   enable row level security;
alter table public.bemanning_maned enable row level security;

-- --- bemanning_aar + bemanning_budsjett: kun retailer_admin -----------
do $$
declare
  t text;
begin
  foreach t in array array['bemanning_aar', 'bemanning_budsjett']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_les', t);
    execute format('drop policy if exists %I on public.%I', t || '_ins', t);
    execute format('drop policy if exists %I on public.%I', t || '_upd', t);
    execute format('drop policy if exists %I on public.%I', t || '_del', t);

    execute format($f$
      create policy %I on public.%I for select to authenticated
        using (stasjon_id in (select public.mine_stasjoner())
               and (select public.gjeldende_rolle()) = 'retailer_admin')
    $f$, t || '_les', t);

    execute format($f$
      create policy %I on public.%I for insert to authenticated
        with check (stasjon_id in (select public.mine_stasjoner())
                    and (select public.gjeldende_rolle()) = 'retailer_admin')
    $f$, t || '_ins', t);

    execute format($f$
      create policy %I on public.%I for update to authenticated
        using (stasjon_id in (select public.mine_stasjoner())
               and (select public.gjeldende_rolle()) = 'retailer_admin')
        with check (stasjon_id in (select public.mine_stasjoner())
                    and (select public.gjeldende_rolle()) = 'retailer_admin')
    $f$, t || '_upd', t);

    execute format($f$
      create policy %I on public.%I for delete to authenticated
        using (stasjon_id in (select public.mine_stasjoner())
               and (select public.gjeldende_rolle()) = 'retailer_admin')
    $f$, t || '_del', t);

    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- --- bemanning_maned: leses av alle med stasjonstilgang ---------------
drop policy if exists bemanning_maned_les on public.bemanning_maned;
create policy bemanning_maned_les on public.bemanning_maned for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner()));

drop policy if exists bemanning_maned_ins on public.bemanning_maned;
create policy bemanning_maned_ins on public.bemanning_maned for insert to authenticated
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists bemanning_maned_upd on public.bemanning_maned;
create policy bemanning_maned_upd on public.bemanning_maned for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin')
  with check (stasjon_id in (select public.mine_stasjoner())
              and (select public.gjeldende_rolle()) = 'retailer_admin');

drop policy if exists bemanning_maned_del on public.bemanning_maned;
create policy bemanning_maned_del on public.bemanning_maned for delete to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) = 'retailer_admin');

grant select, insert, update, delete on public.bemanning_maned to authenticated;
