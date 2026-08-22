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
-- FUNNENE STAAR I SELVE FEILMELDINGEN, ikke i en teller.
-- `supabase db query` svelger `raise warning`, saa foerste utgave meldte
-- «1 funn» og lot deg gjette hvilket. Det er samme sykdom som en
-- serverhandling som svelger `{ error }` - og den kostet en runde her
-- ogsaa.
--
-- VIEWET STARTER FRA `regnskapslinjer`. Uten BP-rader gir det ingen rad
-- i det hele tatt, og da blir `r` null - `null is distinct from 0` er
-- SANT, saa testen felte paa en rad som ikke fantes. Det var funnet.
-- =====================================================================
do $$
declare
  funn   text[] := '{}';
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

    -- BP for hele 2026. Viewet starter fra `regnskapslinjer`, saa uten
    -- disse finnes stasjonen ikke i det hele tatt.
    insert into public.regnskapslinjer
      (retailer_id, stasjon_id, periode, seksjon, kode, post, regnskap, budsjett,
       avvik, index_pct, regnskap_hittil, budsjett_hittil)
    select RET, STASJ, make_date(2026, m, 1), 'bp_bruttofortjeneste',
           '120', '120 Mat', 0, 100000, 0, 0, 0, 0
    from generate_series(1, 12) m;

    -- Rammer for hele 2026, saa viewet har en rad per maaned aa vurdere.
    insert into public.bemanning_maned (stasjon_id, ar, maned, disponible_timer)
    select STASJ, 2026, m, 1000 from generate_series(1, 12) m;

    -- --- STANDARDEN ER 2020-01-01, IKKE I DAG -----------------------
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
      funn := funn || format(
        'standard gjelder_fra er %s - ventet 2020-01-01. Rader fra for '
        'perioder fantes har alltid gjeldt.', r.gjelder_fra);
    end if;

    -- Med bare en timeloennet vakt skal januar faa justering.
    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = date '2026-01-01';
    if r.stasjon_id is null then
      funn := funn || 'viewet ga ingen rad for januar - mangler BP eller ramme';
    elsif r.lederdekning <> 'ikke_fastlonnet' then
      funn := funn || format(
        'januar: lederdekning er %s - ventet ikke_fastlonnet', r.lederdekning);
    end if;

    -- --- PERIODEN AVGJOER PER MAANED --------------------------------
    -- Ny butikksjef paa fastloenn fra 1. november. Den forrige perioden
    -- lukkes 31. oktober, slik serverhandlingen gjor det.
    update public.bemanning_fast_vakt
       set gjelder_til = date '2026-10-31'
     where stasjon_id = STASJ and ukedag = 1;

    insert into public.bemanning_fast_vakt
      (stasjon_id, navn, ukedag, fra_time, til_time, timelonnet, gjelder_fra)
    values (STASJ, 'butikksjef', 1, 7, 15, false, date '2026-11-01');

    -- OKTOBER SKAL FORTSATT VAERE TIMELOENNET. Dette er hele poenget:
    -- for 0123 ville november-raden gjort oktober fastloennet med
    -- tilbakevirkende kraft.
    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = date '2026-10-01';
    if r.lederdekning is distinct from 'ikke_fastlonnet' then
      funn := funn || format(
        'HISTORIKKEN SKREV SEG OM: oktober er %s etter at en ny fastloennet '
        'vakt ble lagt inn fra 1. november. Perioden skal avgjore per maaned.',
        coalesce(r.lederdekning, '(ingen rad)'));
    end if;

    -- ... og november skal vaere fastloennet.
    select * into r from public.v_timeregnskap
    where stasjon_id = STASJ and maned = date '2026-11-01';
    if r.lederdekning is distinct from 'fastlonnet' then
      funn := funn || format('november er %s - ventet fastlonnet',
        coalesce(r.lederdekning, '(ingen rad)'));
    end if;
    if r.ramme_justering_timer is distinct from 0 then
      funn := funn || format(
        'november fikk %s timer justering med fastloennet vakt',
        coalesce(r.ramme_justering_timer::text, '(ingen rad)'));
    end if;

    -- --- BEGGE PERIODENE SKAL LIGGE LAGRET --------------------------
    -- Skranken tillater to rader for samme vakt saa lenge gjelder_fra er
    -- ulik. Det er med vilje: historikk krever det. To GYLDIGE samtidig
    -- ville dobbelttelt dekningen i planleggeren, og det hindrer
    -- serverhandlingen ved aa lukke den forrige.
    if (select count(*) from public.bemanning_fast_vakt
        where stasjon_id = STASJ and ukedag = 1) <> 2 then
      funn := funn || format('begge periodene skal ligge lagret - fant %s',
        (select count(*) from public.bemanning_fast_vakt
         where stasjon_id = STASJ and ukedag = 1));
    end if;

    -- En periode kan ikke slutte for den begynner.
    begin
      insert into public.bemanning_fast_vakt
        (stasjon_id, navn, ukedag, fra_time, til_time, gjelder_fra, gjelder_til)
      values (STASJ, 'nk', 2, 7, 15, date '2026-06-01', date '2026-05-01');
      funn := funn || 'en periode som slutter for den begynner ble godtatt';
    exception
      when check_violation then null;
    end;

    raise exception 'RULL_TILBAKE';
  exception
    when others then
      if sqlerrm <> 'RULL_TILBAKE' then raise; end if;
  end;

  if array_length(funn, 1) > 0 then
    raise exception 'fast_vakt_periode: % funn:%',
      array_length(funn, 1), chr(10) || array_to_string(funn, chr(10));
  end if;
  raise notice '--- fast_vakt_periode: historikken skriver seg ikke om ---';
end $$;
