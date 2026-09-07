-- ---------------------------------------------------------------------
-- 0182: grunnlaget for loennsrommet
-- ---------------------------------------------------------------------
-- LOENNSBUDSJETTET ER IKKE EN FAST SUM. Det er en andel av
-- bruttofortjenesten. Kommer det mindre inn enn BP-en trodde, er det
-- mindre aa bruke - uansett hva som staar i budsjettet.
--
-- For en AVLAGT maaned staar bruttofortjenesten i regnskapet. For den
-- inneVAERENDE gjoer den ikke det: regnskapsrapporten kommer midt i
-- neste maaned, og da er beslutningen tatt for lenge siden. Derfor
-- anslaas brutto av omsetningen, som finnes daglig, ganget med en margin
-- laert av de maanedene regnskapet HAR lukket - minus svinnet, som ogsaa
-- finnes daglig. Kastet vare er brutto som aldri ble til noe.
--
-- Dette viewet baerer de to daglige stoerrelsene, summert per maaned.
--
-- HVORFOR ET VIEW OG IKKE EN SUMMERING I KLIENTEN.
--
-- `v_salg_omraade_maaned` (0175) har en rad per avdeling og vareomraade.
-- Tretten maaneder blir flere hundre rader for én stasjon, og PostgREST
-- avkorter et for stort svar UTEN aa feile - en avkortet spoerring ser ut
-- som en liten stasjon, ikke som en feil. Den fella har kostet tre
-- ganger (0090, 0166, 0175). Her blir det tretten rader.
create or replace view public.v_lonnsrom_grunnlag
with (security_invoker = true) as
select
  v.retailer_id,
  v.stasjon_id,
  to_char(v.maned, 'YYYY-MM')      as maaned,
  sum(v.omsetning_kr)::numeric(14,2) as omsetning_kr,
  sum(v.svinn_kr)::numeric(14,2)     as svinn_kr
from public.v_salg_omraade_maaned v
group by v.retailer_id, v.stasjon_id, v.maned;

comment on view public.v_lonnsrom_grunnlag is
  'Omsetning og synlig svinn per stasjon og maaned. Grunnlag for aa anslaa '
  'bruttofortjenesten i en maaned regnskapet ikke har lukket enda. '
  'Drivstoff er allerede holdt utenfor - 0175 leser v_butikksalg.';

-- SECURITY_INVOKER ER IKKE NOK ALENE. Supabase-standarden treffer ogsaa
-- hvert nytt view med grant til anon, og anon er rollen bak den
-- offentlige noekkelen i hver sidelast (0130, 0134).
grant select on public.v_lonnsrom_grunnlag to authenticated;
revoke all on public.v_lonnsrom_grunnlag from anon;

-- Kvittering.
select
  (select count(*) from pg_views
    where schemaname = 'public' and viewname = 'v_lonnsrom_grunnlag')       as viewet_finnes,
  (select count(*) from pg_class c
    where c.relname = 'v_lonnsrom_grunnlag'
      and c.reloptions::text like '%security_invoker=true%')                as invoker,
  (select count(*) from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'v_lonnsrom_grunnlag'
      and grantee = 'anon')                                                 as anon;
