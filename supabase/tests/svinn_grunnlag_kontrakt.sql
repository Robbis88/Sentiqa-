-- =====================================================================
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
-- `rollback`. Fiksturradene bruker periodene 1999-01-01 og 1999-02-01,
-- som ikke finnes i ekte data.
--
-- Kvittering: siste `select` skal gi NULL rader. Hver rad er et avvik
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

  -- -------------------------------------------------------------------
  -- bare produktrader
  --
  -- Produksjonsbasen i dag: 588 rader, alle produkt, uten område.
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '12010',
    'kontrakt 12010', 'produkt', null,
    1000, 100, 50);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '12020',
    'kontrakt 12020', 'produkt', null,
    500, 40, -10);
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-01-01';

  if v_val.rader <> 2 then
    insert into kontraktsavvik values ('bare produktrader', 'a|1999-01-01', 'rader', '2', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 1500 then
    insert into kontraktsavvik values ('bare produktrader', 'a|1999-01-01', 'salg', '1500', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 140 then
    insert into kontraktsavvik values ('bare produktrader', 'a|1999-01-01', 'kast', '140', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 40 then
    insert into kontraktsavvik values ('bare produktrader', 'a|1999-01-01', 'usynlig', '40', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'eldre_grunnlag' then
    insert into kontraktsavvik values ('bare produktrader', 'a|1999-01-01', 'datastatus', 'eldre_grunnlag', v_val.datastatus);
  end if;

  -- -------------------------------------------------------------------
  -- komplett grupperad, gruppe og produkt sammen
  --
  -- Etter reimport. Gruppen eier totalen; produktene skal ikke legges til.
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '120',
    'kontrakt 120', 'gruppe', 'butikk',
    1500, 140, 40);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '12010',
    'kontrakt 12010', 'produkt', 'butikk',
    1000, 100, 50);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '12020',
    'kontrakt 12020', 'produkt', 'butikk',
    500, 40, -10);
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-01-01';

  if v_val.rader <> 1 then
    insert into kontraktsavvik values ('komplett grupperad, gruppe og produkt sammen', 'a|1999-01-01', 'rader', '1', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 1500 then
    insert into kontraktsavvik values ('komplett grupperad, gruppe og produkt sammen', 'a|1999-01-01', 'salg', '1500', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 140 then
    insert into kontraktsavvik values ('komplett grupperad, gruppe og produkt sammen', 'a|1999-01-01', 'kast', '140', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 40 then
    insert into kontraktsavvik values ('komplett grupperad, gruppe og produkt sammen', 'a|1999-01-01', 'usynlig', '40', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'gruppe' then
    insert into kontraktsavvik values ('komplett grupperad, gruppe og produkt sammen', 'a|1999-01-01', 'datastatus', 'gruppe', v_val.datastatus);
  end if;

  -- -------------------------------------------------------------------
  -- gruppe på én stasjon, produktfallback på en annen
  --
  -- Midt i en reimport kan to stasjoner ligge i ulik fase.
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '120',
    'kontrakt 120', 'gruppe', 'butikk',
    1500, 140, 40);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '12010',
    'kontrakt 12010', 'produkt', 'butikk',
    1500, 140, 40);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_b, date '1999-01-01', '13010',
    'kontrakt 13010', 'produkt', null,
    800, 0, 200);
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-01-01';

  if v_val.rader <> 1 then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'a|1999-01-01', 'rader', '1', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 1500 then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'a|1999-01-01', 'salg', '1500', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 140 then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'a|1999-01-01', 'kast', '140', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 40 then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'a|1999-01-01', 'usynlig', '40', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'gruppe' then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'a|1999-01-01', 'datastatus', 'gruppe', v_val.datastatus);
  end if;
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_b and periode = date '1999-01-01';

  if v_val.rader <> 1 then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'b|1999-01-01', 'rader', '1', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 800 then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'b|1999-01-01', 'salg', '800', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 0 then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'b|1999-01-01', 'kast', '0', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 200 then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'b|1999-01-01', 'usynlig', '200', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'eldre_grunnlag' then
    insert into kontraktsavvik values ('gruppe på én stasjon, produktfallback på en annen', 'b|1999-01-01', 'datastatus', 'eldre_grunnlag', v_val.datastatus);
  end if;

  -- -------------------------------------------------------------------
  -- ufullstendig grupperad
  --
  -- Bare én av gruppene har grupperad. VALGT ATFERD: gruppenivå brukes likevel, fordi gruppen eier totalen for de gruppene den dekker. Differansen mellom gruppe og produkt er et FUNN som vises, ikke en grunn til å falle tilbake — se de 64 gruppedifferansene.
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '120',
    'kontrakt 120', 'gruppe', 'butikk',
    1500, 140, 40);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '13010',
    'kontrakt 13010', 'produkt', 'butikk',
    800, 20, 5);
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-01-01';

  if v_val.rader <> 1 then
    insert into kontraktsavvik values ('ufullstendig grupperad', 'a|1999-01-01', 'rader', '1', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 1500 then
    insert into kontraktsavvik values ('ufullstendig grupperad', 'a|1999-01-01', 'salg', '1500', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 140 then
    insert into kontraktsavvik values ('ufullstendig grupperad', 'a|1999-01-01', 'kast', '140', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 40 then
    insert into kontraktsavvik values ('ufullstendig grupperad', 'a|1999-01-01', 'usynlig', '40', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'gruppe' then
    insert into kontraktsavvik values ('ufullstendig grupperad', 'a|1999-01-01', 'datastatus', 'gruppe', v_val.datastatus);
  end if;

  -- -------------------------------------------------------------------
  -- drivstoff og ukjent holdes ute
  --
  -- 19 drivstoffrader og 1 ukjent per måned. De lagres navngitt og blokkeres.
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '12010',
    'kontrakt 12010', 'produkt', 'butikk',
    1000, 100, 50);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '1490',
    'kontrakt 1490', 'produkt', 'drivstoff',
    900000, 0, 9999);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '99910',
    'kontrakt 99910', 'produkt', 'ukjent',
    72, 0, -45);
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-01-01';

  if v_val.rader <> 1 then
    insert into kontraktsavvik values ('drivstoff og ukjent holdes ute', 'a|1999-01-01', 'rader', '1', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 1000 then
    insert into kontraktsavvik values ('drivstoff og ukjent holdes ute', 'a|1999-01-01', 'salg', '1000', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 100 then
    insert into kontraktsavvik values ('drivstoff og ukjent holdes ute', 'a|1999-01-01', 'kast', '100', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 50 then
    insert into kontraktsavvik values ('drivstoff og ukjent holdes ute', 'a|1999-01-01', 'usynlig', '50', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'eldre_grunnlag' then
    insert into kontraktsavvik values ('drivstoff og ukjent holdes ute', 'a|1999-01-01', 'datastatus', 'eldre_grunnlag', v_val.datastatus);
  end if;

  -- -------------------------------------------------------------------
  -- kast uten salg — 16015 KAMPANJE
  --
  -- Laguneparken april: salg 0, usynlig 0, kast 3 655,42. Raden skal lagres og telle i gruppe 160. Kastprosenten er ikke beregnbar.
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '16015',
    'kontrakt 16015', 'produkt', 'butikk',
    0, 3655.42, 0);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '12010',
    'kontrakt 12010', 'produkt', 'butikk',
    1000, 100, 50);
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-01-01';

  if v_val.rader <> 2 then
    insert into kontraktsavvik values ('kast uten salg — 16015 KAMPANJE', 'a|1999-01-01', 'rader', '2', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 1000 then
    insert into kontraktsavvik values ('kast uten salg — 16015 KAMPANJE', 'a|1999-01-01', 'salg', '1000', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 3755.42 then
    insert into kontraktsavvik values ('kast uten salg — 16015 KAMPANJE', 'a|1999-01-01', 'kast', '3755.42', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 50 then
    insert into kontraktsavvik values ('kast uten salg — 16015 KAMPANJE', 'a|1999-01-01', 'usynlig', '50', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'eldre_grunnlag' then
    insert into kontraktsavvik values ('kast uten salg — 16015 KAMPANJE', 'a|1999-01-01', 'datastatus', 'eldre_grunnlag', v_val.datastatus);
  end if;

  -- -------------------------------------------------------------------
  -- gruppe 120 Mat og gruppe 160 side om side
  --
  -- Kampanjeraden hører til 160. Den skal ikke røre Mat 120, og Mat 120 skal fortsatt avstemme til 0 differanse.
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '120',
    'kontrakt 120', 'gruppe', 'butikk',
    1500, 140, 40);
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-01-01', '160',
    'kontrakt 160', 'gruppe', 'butikk',
    0, 3655.42, 0);
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-01-01';

  if v_val.rader <> 2 then
    insert into kontraktsavvik values ('gruppe 120 Mat og gruppe 160 side om side', 'a|1999-01-01', 'rader', '2', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 1500 then
    insert into kontraktsavvik values ('gruppe 120 Mat og gruppe 160 side om side', 'a|1999-01-01', 'salg', '1500', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 3795.42 then
    insert into kontraktsavvik values ('gruppe 120 Mat og gruppe 160 side om side', 'a|1999-01-01', 'kast', '3795.42', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 40 then
    insert into kontraktsavvik values ('gruppe 120 Mat og gruppe 160 side om side', 'a|1999-01-01', 'usynlig', '40', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'gruppe' then
    insert into kontraktsavvik values ('gruppe 120 Mat og gruppe 160 side om side', 'a|1999-01-01', 'datastatus', 'gruppe', v_val.datastatus);
  end if;

  -- -------------------------------------------------------------------
  -- desember uten nødvendige felter
  --
  -- Eldre rapportformat, ingen svinnrader i det hele tatt. Perioden er utilgjengelig — ikke 0, og ikke et startpunkt for en retning.
  -- -------------------------------------------------------------------
  delete from public.regnskap_usynlig_svinn
   where retailer_id = v_ret and periode in (date '1999-01-01', date '1999-02-01');
  insert into public.regnskap_usynlig_svinn
    (retailer_id, stasjon_id, periode, kode, navn, nivaa, analyseomraade, salg, kast, usynlig_kr)
  values (v_ret, v_a, date '1999-02-01', '12010',
    'kontrakt 12010', 'produkt', null,
    1000, 100, 50);
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-01-01';

  if v_val.rader <> 0 then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-01-01', 'rader', '0', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 0 then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-01-01', 'salg', '0', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 0 then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-01-01', 'kast', '0', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 0 then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-01-01', 'usynlig', '0', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'utilgjengelig' then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-01-01', 'datastatus', 'utilgjengelig', v_val.datastatus);
  end if;
  select count(*)::int as rader,
         coalesce(sum(salg), 0)       as salg,
         coalesce(sum(kast), 0)       as kast,
         coalesce(sum(usynlig_kr), 0) as usynlig,
         coalesce(min(datastatus), 'utilgjengelig') as datastatus
    into v_val
    from public.v_svinn_grunnlag
   where retailer_id = v_ret and stasjon_id = v_a and periode = date '1999-02-01';

  if v_val.rader <> 1 then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-02-01', 'rader', '1', v_val.rader::text);
  end if;
  if round(v_val.salg, 2) <> 1000 then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-02-01', 'salg', '1000', v_val.salg::text);
  end if;
  if round(v_val.kast, 2) <> 100 then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-02-01', 'kast', '100', v_val.kast::text);
  end if;
  if round(v_val.usynlig, 2) <> 50 then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-02-01', 'usynlig', '50', v_val.usynlig::text);
  end if;
  if v_val.datastatus <> 'eldre_grunnlag' then
    insert into kontraktsavvik values ('desember uten nødvendige felter', 'a|1999-02-01', 'datastatus', 'eldre_grunnlag', v_val.datastatus);
  end if;
end $kontrakt$;

-- KVITTERING. Null rader = TypeScript og SQL er enige.
select * from kontraktsavvik order by tilfelle, noekkel, felt;

select count(*) as avvik,
       8 as tilfeller,
       case when count(*) = 0 then 'KONTRAKT HOLDER' else 'DRIFT - se raderne over' end as dom
  from kontraktsavvik;

rollback;
