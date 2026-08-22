-- =====================================================================
-- Faste vakter med periode: historikken skal slutte aa skrive seg om
--
-- Kjores i CI etter migrasjonene. Kaster exception ved funn.
--
-- FOER 0123 beskrev `bemanning_fast_vakt` hvordan det er NAA. Endres en
-- vakt fra timeloenn til fastloenn 1. november, forsvant justeringen i
-- timeregnskapet for januar til oktober ogsaa - Dales overforbruk hoppet
-- ~1 350 timer den dagen, uten at noe faktisk skjedde.
--
-- Testen beviser tre ting, og alle tre er ting som var galt for:
--
--   1. En vakt teller for maaneden hvis perioden OVERLAPPER den.
--   2. En vakt som ble fastloennet foerst i november gjor IKKE oktober
--      fastloennet.
--   3. Rader fra for perioder fantes gjelder fortsatt - de fikk
--      2020-01-01, ikke dagens dato.
-- =====================================================================
do $$
declare
  feil   int := 0;
  RET    constant uuid := 'cccccccc-0000-4000-8000-000000000001';
  STASJ  constant uuid := 'cccccccc-1111-4000-8000-000000000001';
  r      record;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'bemanning_fast_vakt'
      and column_name = 'gjelder_fra'
  ) then
    raise exception 'BLIND TEST: bemanning_fast_vakt mangler gjelder_fra - er 0123 kjort?';
  end if;

  begin
    insert into public.retailers (id, navn) values (RET, 'Periodetest');
    insert into public.stasjoner (id, retailer_id, butikknummer, navn, stasjonstype)
      values (STASJ, RET, '0004', 'Periodebutikken', 'pendler');

    -- Rammer for hele 2026, saa viewet har en rad per maaned aa vurdere.
    insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer)
    select STASJ, 2026, m, 1000 from generate_series(1, 12) m;

    -- --- 3) STANDARDEN ER 2020-01-01, IKKE I DAG --------------------
    -- En rad uten periode skal gjelde bakover. Settes dagens dato som
    -- standard, staar hele fjoraaret plutselig uten faste vakter - og
    -- timeregnskapet gir hver stasjon 141 timer i maaneden for et helt
    -- aar som allerede er lagt bak seg.
    insert into public.bemanning_fast_vakt
      (stasjon_id, navn, ukedag, fra_time, til_time, timelonnet)
    values (STASJ, 'butikksjef', 1, 7, 15, true);

    select gjelder_fra into r from public.bemanning_fast_vakt
    where stasjon_id = STASJ and ukedag = 1;
    if r.gjelder_fra <> date '2020-01-01' then
      raise warning 'standard gjelder_fra er % - ventet 2020-01-01. Rader '
                    'fra for perioder fantes har alltid gjeldt.', r.gjelder_fra;
      feil := feil + 1;
    end if;

    -- Med bare en timeloennet vakt skal januar faa justering.
    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = date '2026-01-01';
    if r.lederdekning <> 'ikke_fastlonnet' then
      raise warning 'januar: lederdekning er % - ventet ikke_fastlonnet',
        r.lederdekning;
      feil := feil + 1;
    end if;

    -- --- 1) og 2) PERIODEN AVGJOER PER MAANED -----------------------
    -- Ny butikksjef paa fastloenn fra 1. november. Den forrige perioden
    -- lukkes 31. oktober, slik serverhandlingen gjor det.
    update public.bemanning_fast_vakt
       set gjelder_til = date '2026-10-31'
     where stasjon_id = STASJ and ukedag = 1;

    insert into public.bemanning_fast_vakt
      (stasjon_id, navn, ukedag, fra_time, til_time, timelonnet, gjelder_fra)
    values (STASJ, 'butikksjef', 1, 7, 15, false, date '2026-11-01');

    -- Oktober skal fortsatt vaere timeloennet. DETTE ER HELE POENGET:
    -- for 0123 ville november-raden gjort oktober fastloennet med
    -- tilbakevirkende kraft.
    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = date '2026-10-01';
    if r.lederdekning <> 'ikke_fastlonnet' then
      raise warning 'HISTORIKKEN SKREV SEG OM: oktober er % etter at en ny '
                    'fastloennet vakt ble lagt inn fra 1. november. '
                    'Perioden skal avgjore per maaned.', r.lederdekning;
      feil := feil + 1;
    end if;

    -- ... og november skal vaere fastloennet.
    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = date '2026-11-01';
    if r.lederdekning <> 'fastlonnet' then
      raise warning 'november er % - ventet fastlonnet', r.lederdekning;
      feil := feil + 1;
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      raise warning 'november fikk % timer justering med fastloennet vakt',
        r.ramme_justering_timer;
      feil := feil + 1;
    end if;

    -- --- OVERLAPP MAA VAERE MULIG AA OPPDAGE ------------------------
    -- Skranken tillater to rader for samme vakt, saa lenge gjelder_fra
    -- er ulik. Det er med vilje - historikk krever det - men to GYLDIGE
    -- samtidig ville dobbelttelt dekningen i planleggeren.
    -- Serverhandlingen lukker den forrige; her kontrolleres bare at
    -- basen faktisk holder begge radene, saa historikken finnes.
    if (select count(*) from public.bemanning_fast_vakt
        where stasjon_id = STASJ and ukedag = 1) <> 2 then
      raise warning 'begge periodene skal ligge lagret - fant %',
        (select count(*) from public.bemanning_fast_vakt
         where stasjon_id = STASJ and ukedag = 1);
      feil := feil + 1;
    end if;

    -- En periode kan ikke slutte for den begynner.
    begin
      insert into public.bemanning_fast_vakt
        (stasjon_id, navn, ukedag, fra_time, til_time, gjelder_fra, gjelder_til)
      values (STASJ, 'nk', 2, 7, 15, date '2026-06-01', date '2026-05-01');
      raise warning 'en periode som slutter for den begynner ble godtatt';
      feil := feil + 1;
    exception
      when check_violation then null;
    end;

    raise exception 'RULL_TILBAKE';
  exception
    when others then
      if sqlerrm <> 'RULL_TILBAKE' then raise; end if;
  end;

  if feil > 0 then
    raise exception 'fast_vakt_periode: % funn. Se advarslene over.', feil;
  end if;
  raise notice '--- fast_vakt_periode: historikken skriver seg ikke om ---';
end $$;
