-- =====================================================================
-- Hvem staar med to loennsformer samtidig?
--
-- En fast vakt legges inn per ukedag, og hver rad har sitt eget
-- loennsform-valg. Lone man-fre er fem rader. Rettes fire av dem og den
-- femte glemmes, sier ingenting paa skjermen fra.
--
-- HVA DET KOSTER, BEGGE VEIER:
--   Glemt «Timeloenn» paa en fastloennet: de timene trekkes fra
--   timerammen selv om loennen er fast. Stasjonen ser ut til aa ha
--   brukt flere timer enn den gjorde.
--   Glemt «Fastloenn» paa en timeloennet: aarsverket/12 (141,25 t)
--   legges IKKE tilbake i rammen. Regelen er «ingen av dem er
--   fastloennet», og én rad gjoer den usann.
--
-- LESER KUN. Trygg i produksjon, endrer ingenting.
--
-- Navnet brukes til aa SPOERRE. Er «Ola Nordmann» og «ola nordmann» to
-- ulike personer, er svaret nei - og ingenting er skjedd.
-- =====================================================================
with g as (
  select s.navn as stasjon, lower(btrim(f.navn)) as person,
         min(f.navn) as vist,
         count(*) filter (where f.timelonnet is true)  as timelonn,
         count(*) filter (where f.timelonnet is not true) as fastlonn,
         sum(f.til_time - f.fra_time) filter (where f.timelonnet is true)  as t_timer,
         sum(f.til_time - f.fra_time) filter (where f.timelonnet is not true) as f_timer
  from public.bemanning_fast_vakt f
  join public.stasjoner s on s.id = f.stasjon_id
  where btrim(coalesce(f.navn, '')) <> ''
    and (f.gjelder_til is null or f.gjelder_til >= current_date)
  group by 1, 2
)
select stasjon, vist, timelonn, fastlonn, t_timer, f_timer
from g where timelonn > 0 and fastlonn > 0
order by least(t_timer, f_timer) desc;
