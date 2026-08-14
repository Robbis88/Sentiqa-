-- ---------------------------------------------------------------------
-- 0092: stemplingene aggregert i basen
-- ---------------------------------------------------------------------
-- Bemanningssiden hentet raa stemplingsrader til klienten for aa regne
-- paa dem. PostgREST kutter paa 1000 rader, og Dale har flere tusen -
-- saa taket per time, helligdagsfaktorene, stillingsanslaget og plan-
-- mot-virkelighet har alle vaert bygget paa et tilfeldig utvalg.
--
-- Ingen av dem feilet. De ga bare litt gale svar, stille, og det er
-- verre. Symptomet dukket forst opp da stillingslisten ble tom.
--
-- Samme leksjon som 0090: telling og summering hoerer der radene er.
--
-- security_invoker paa begge, saa RLS gjelder som for kalleren.

-- ---------------------------------------------------------------------
-- Bemanning per klokketime. Grunnlaget for taket og for aa male planen
-- mot det som faktisk skjedde.
-- ---------------------------------------------------------------------
create or replace view public.v_stempling_time
with (security_invoker = true) as
select s.stasjon_id,
       -- Timer etter midnatt hoerer til dagen etter - det er da de jobbes.
       (s.dato + (h / 24))::date as dato,
       (h % 24)                  as time,
       count(*)                  as antall
from public.stempling s
cross join lateral generate_series(
  extract(hour from s.fra_tid)::int,
  (case
     -- Feilstempling paa null minutter: gir tom serie, ingen rader.
     when s.minutter <= 0 then extract(hour from s.fra_tid)::int
     -- 00:00 som sluttid betyr midnatt, altsaa slutten av dagen.
     when s.til_tid = time '00:00' then 24
     -- Vakt over midnatt.
     when s.til_tid <= s.fra_tid then extract(hour from s.til_tid)::int + 24
     else extract(hour from s.til_tid)::int
   end) - 1
) as h
where s.betalt
group by 1, 2, 3;

comment on view public.v_stempling_time is
  'Antall personer paa jobb per stasjon, dato og klokketime. Vakter over '
  'midnatt telles paa dagen timene faktisk jobbes.';

-- ---------------------------------------------------------------------
-- Timer per ansatt per maaned. Grunnlaget for stillingsanslaget.
-- ---------------------------------------------------------------------
create or replace view public.v_stempling_ansatt_mnd
with (security_invoker = true) as
select stasjon_id,
       ansatt_nr,
       -- Nyeste navn vinner. Folk gifter seg, og stemplingsnummeret er
       -- den stabile noekkelen.
       (array_agg(ansatt_navn order by dato desc))[1] as ansatt_navn,
       date_trunc('month', dato)::date                as maaned,
       sum(minutter) / 60.0                           as timer
from public.stempling
where betalt
group by stasjon_id, ansatt_nr, date_trunc('month', dato);

comment on view public.v_stempling_ansatt_mnd is
  'Arbeidede timer per ansatt per maaned. Mater stillingsanslaget - som '
  'maaler ARBEIDEDE timer, ikke kontrakt.';

grant select on public.v_stempling_time       to authenticated;
grant select on public.v_stempling_ansatt_mnd to authenticated;

-- ---------------------------------------------------------------------
-- Ukeprofilen: hvor ofte har stasjonen hatt N personer paa jobb en gitt
-- ukedag og klokketime?
-- ---------------------------------------------------------------------
-- v_stempling_time er per DATO og kan selv gi over tusen rader for to
-- aar. Taket trenger ikke datoene, bare fordelingen - og den er hoyst
-- 7 x 24 x en handfull nivaaer.
create or replace view public.v_stempling_ukeprofil
with (security_invoker = true) as
select stasjon_id,
       extract(isodow from dato)::int as ukedag,
       time,
       antall,
       count(*)                       as ganger
from public.v_stempling_time
group by 1, 2, 3, 4;

comment on view public.v_stempling_ukeprofil is
  'Hvor mange ganger stasjonen har hatt N personer paa jobb en gitt '
  'ukedag og klokketime. Grunnlaget for taket i bemanningsplanen.';

grant select on public.v_stempling_ukeprofil to authenticated;
