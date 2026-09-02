-- =====================================================================
-- Sentiqa 0167 - nettbrettet skriver ett tall, ikke en rad
--
-- SISTE POST I CAPABILITY-GJELDA
--
-- `produksjonsplan_upd` (0136) slipper ALLE med stasjonen til paa HELE
-- raden. Nettbrettets ene operative handling, `loggLagd`, trenger
-- `lagd_hittil` og `oppdatert_tid`. Raden baerer ogsaa `planlagt` - det
-- butikksjefen har bestemt at skal lages - og `start_antall` og
-- `ekskludert`.
--
-- En klient med nettbrettsesjon kunne altsaa skrive over planen. UI-et
-- tilbyr det ikke, men RLS er det som avgjoer hva som ER mulig, ikke hva
-- skjermen viser.
--
-- HVORFOR IKKE KOLONNEGRANT
--
-- `grant update (lagd_hittil)` treffer hele `authenticated`, og
-- butikksjefen ER i den rollen. Hun skal kunne sette `planlagt` gjennom
-- `setLinje`. Et grant kan ikke skille de to.
--
-- SAMME FORM SOM 0165: en `security definer`-funksjon som baerer
-- tenantpredikatet selv, og som bare roerer de to kolonnene. Deretter
-- strammes policyen til lederne.
--
-- FOERST FUNKSJONEN, SAA STRAMMINGEN. I den rekkefoelgen, saa nettbrettet
-- aldri staar uten skrivevei. Og migrasjonen maa kjoeres FOER koden
-- deployes - `loggLagd` kaller funksjonen, og en `maaLykkes` paa noe som
-- ikke finnes stopper nettbrettet midt i en vakt.
-- =====================================================================

create or replace function public.logg_lagd(
  p_stasjon_id uuid,
  p_dato       date,
  p_varenavn   text,
  p_lagd       integer
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  -- TENANTPREDIKATET STAAR HER. `security definer` gaar forbi RLS; uten
  -- denne kunne enhver innlogget skrive paa enhver stasjon i enhver
  -- kjede. `mine_stasjoner()` leser kallerens sesjon, ogsaa herfra.
  -- `mine_stasjoner()` er `returns setof uuid`, ikke en array - derfor et
  -- `exists` mot funksjonen og ikke `unnest`.
  if p_stasjon_id is null or not exists (
    select 1 from public.mine_stasjoner() m where m = p_stasjon_id
  ) then
    return 0;
  end if;

  -- ALDRI NEGATIVT. Samme klemme som klienten gjoer i dag; her fordi
  -- funksjonen er skrivepunktet og ikke skal stole paa den som kaller.
  update public.produksjonsplan_linjer
     set lagd_hittil  = greatest(0, p_lagd),
         oppdatert_tid = now()
   where stasjon_id = p_stasjon_id
     and dato       = p_dato
     and varenavn   = p_varenavn;

  get diagnostics n = row_count;
  return n;
end;
$$;

comment on function public.logg_lagd(uuid, date, text, integer) is
  'Nettbrettets ene skrivevei inn i produksjonsplanen: setter kun '
  'lagd_hittil og oppdatert_tid. Baerer tenantpredikatet selv - se '
  'migrasjon 0167.';

revoke all on function public.logg_lagd(uuid, date, text, integer) from public, anon;
grant execute on function public.logg_lagd(uuid, date, text, integer) to authenticated;

-- ---------------------------------------------------------------------
-- OG SAA STRAMMES DEN BREDE VEIEN
-- ---------------------------------------------------------------------
-- Butikksjefen og eieren beholder UPDATE uendret: `setLinje` er en
-- upsert, og en upsert som treffer en eksisterende rad ER en UPDATE.
-- Uten dem kunne ingen endre en plan som alt er laget.

drop policy if exists produksjonsplan_upd on public.produksjonsplan_linjer;
create policy produksjonsplan_upd on public.produksjonsplan_linjer
  for update to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
  with check (stasjon_id in (select public.mine_stasjoner())
              and retailer_id = (select public.gjeldende_retailer_id())
              and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on policy produksjonsplan_upd on public.produksjonsplan_linjer is
  'Lederflate. Nettbrettet skriver lagd_hittil gjennom logg_lagd() og '
  'naar ikke planlagt - se migrasjon 0167.';
