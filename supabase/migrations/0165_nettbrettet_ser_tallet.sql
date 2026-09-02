-- =====================================================================
-- Sentiqa 0165 - nettbrettet ser tallet, ikke vurderingen
--
-- CAPABILITY-GJELD, KLASSIFISERT I PORT 1, IKKE BYGGET FOER NAA
--
-- Nettbrettet trenger to tall til hjemskjermen (`hentHjemData`):
--
--   skills_score.prosent        stasjonens skills-score
--   pengepremie_bruk.belop_kr   hvor mye av premien som er brukt
--
-- Det fikk HELE RADEN. Med `prosent` fulgte `kommentar` - butikksjefens
-- skriftlige vurdering av stasjonen - og `registrert_av`. Med `belop_kr`
-- fulgte `beskrivelse`, altsaa hva pengene gikk til, og `opprettet_av`.
-- Nettbrettet er en DELT enhet i butikken. Lederens vurdering hoerer ikke
-- hjemme der.
--
-- HVORFOR IKKE ET ROLLEPREDIKAT ALENE, OG HVORFOR IKKE EN VIEW
--
-- Et rollepredikat paa tabellen tar bort nettbrettets legitime lesing av
-- tallet sammen med resten. Kolonnegrant duger ikke: butikksjefen SKAL se
-- kommentaren, og granten treffer hele `authenticated`.
--
-- Kontrakten foreslo en `security_invoker`-view. Den loeser det ikke: en
-- slik view leser med KALLERENS rettigheter, saa et rollepredikat paa
-- tabellen ville stengt viewet ogsaa. Og en view UTEN `security_invoker`
-- er nettopp det vakthundens punkt 9 kaster paa.
--
-- En `security definer`-FUNKSJON er formen som virker, og den finnes alt
-- flere steder her (`mine_stasjoner`, `svinn_sum`, `malekort_stasjoner`).
-- Den maa da baere tenantpredikatet selv - RLS gjelder ikke inni den.
--
-- FLATEN ER TO TALL OG EN STASJON. Ingen kolonne mer, ingen historikk,
-- ingen navn.
-- =====================================================================

create or replace function public.hjem_stasjonstall(p_stasjon_id uuid)
returns table (skills_prosent numeric, premie_brukt_kr numeric)
language sql
stable
security definer
set search_path = public
as $$
  -- TENANTPREDIKATET STAAR HER, IKKE I EN POLICY. `security definer`
  -- kjoerer som eier og gaar forbi RLS; uten denne linja ville enhver
  -- innlogget kunne lese tallene til enhver stasjon i enhver kjede.
  -- `mine_stasjoner()` leser kallerens sesjon, ogsaa herfra.
  select
    (select s.prosent
       from public.skills_score s
      where s.stasjon_id = p_stasjon_id
      order by s.registrert_tid desc
      limit 1),
    (select coalesce(sum(b.belop_kr), 0)
       from public.pengepremie_bruk b
      where b.stasjon_id = p_stasjon_id)
  where p_stasjon_id in (select public.mine_stasjoner());
$$;

comment on function public.hjem_stasjonstall(uuid) is
  'De to tallene nettbrettets hjemskjerm trenger, uten kolonnene rundt: '
  'skills-prosent og brukt pengepremie. security definer med eget '
  'tenantpredikat - se migrasjon 0165.';

revoke all on function public.hjem_stasjonstall(uuid) from public, anon;
grant execute on function public.hjem_stasjonstall(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- OG SAA STENGES DEN BREDE VEIEN
-- ---------------------------------------------------------------------
-- Foerst naa, ikke foer: funksjonen over er den eneste veien nettbrettet
-- har igjen til disse tallene.
--
-- Butikksjefen og eieren beholder lesingen uendret - de skal se
-- kommentaren, det er deres eget arbeidsverktoey.

drop policy if exists skills_les on public.skills_score;
create policy skills_les on public.skills_score
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy skills_les on public.skills_score is
  'Lederflate. Nettbrettet leser prosenten gjennom hjem_stasjonstall() '
  'og skal ikke se kommentaren - se migrasjon 0165.';

drop policy if exists pengepremie_bruk_les on public.pengepremie_bruk;
create policy pengepremie_bruk_les on public.pengepremie_bruk
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy pengepremie_bruk_les on public.pengepremie_bruk is
  'Lederflate. Nettbrettet leser summen gjennom hjem_stasjonstall() og '
  'skal ikke se hva pengene gikk til - se migrasjon 0165.';
