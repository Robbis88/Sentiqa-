-- =====================================================================
-- Sentiqa - 0079_avvik_lopenr.sql
-- Lopenummer paa avvik tildeles i databasen, ikke i app-laget.
-- Ren ASCII, idempotent.
--
-- Problemet: begge stedene som oppretter avvik regnet ut lopenr slik:
--   select count(*) from avvik where retailer_id = ...   -> lopenr = count + 1
-- (src/app/(beskyttet)/avvik/handlinger.ts:37 og
--  src/app/(beskyttet)/ikmat/handlinger.ts:85)
--
-- To feil i det:
--  1) Tellingen gaar gjennom RLS. En butikksjef ser bare sine egne
--     stasjoner, saa count blir for lav og gir et lopenr som allerede
--     er i bruk. To butikksjefer i samme kjede kolliderer systematisk.
--  2) Ingen laas. To samtidige avvik leser samme count og faar samme
--     nummer selv for en admin som ser alt.
--
-- Fiks: en BEFORE INSERT-trigger som tildeler nummeret. SECURITY DEFINER
-- saa den ser hele kjeden uavhengig av hvem som skriver, og en
-- transaksjons-advisory-lock per retailer saa samtidige innsettinger
-- serialiseres. Laasen slippes automatisk naar transaksjonen er ferdig.
--
-- App-laget skal etter dette IKKE sende lopenr i det hele tatt (kolonnen
-- har default 0, som trigger tildeling).
-- =====================================================================

create or replace function public.sett_avvik_lopenr()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Bare tildel naar app-laget ikke har satt et ekte nummer.
  if new.lopenr is null or new.lopenr = 0 then
    -- Serialiser per kjede. Uten dette kan to samtidige innsettinger
    -- lese samme max og faa samme nummer.
    perform pg_advisory_xact_lock(hashtextextended(new.retailer_id::text, 0));

    select coalesce(max(a.lopenr), 0) + 1
      into new.lopenr
      from public.avvik a
     where a.retailer_id = new.retailer_id;
  end if;
  return new;
end
$$;

drop trigger if exists avvik_lopenr_trigger on public.avvik;
create trigger avvik_lopenr_trigger
  before insert on public.avvik
  for each row
  execute function public.sett_avvik_lopenr();

-- Stotter max(lopenr) per kjede.
create index if not exists avvik_retailer_lopenr_idx
  on public.avvik (retailer_id, lopenr);


-- =====================================================================
-- KREVER MANUELL VURDERING:
--
-- A) Eksisterende duplikater ryddes IKKE av denne migrasjonen - a skrive
--    om lopenummer paa avvik som allerede er rapportert videre (marked@/
--    retail@st1.no) ville vaert feil uten at du bestemmer det. Se om det
--    finnes noen:
--      select retailer_id, lopenr, count(*)
--      from public.avvik where slettet_tid is null
--      group by retailer_id, lopenr having count(*) > 1
--      order by retailer_id, lopenr;
--
-- B) Naar A er tom, kan nummeret gjores garantert unikt:
--      create unique index concurrently avvik_retailer_lopenr_unik
--        on public.avvik (retailer_id, lopenr) where slettet_tid is null;
--    Den er bevisst utelatt her, siden den feiler paa duplikater og maa
--    kjores utenfor transaksjon (concurrently).
--
-- C) Nummer gjenbrukes ikke etter sletting: max()+1 hopper over hull fra
--    soft-slettede avvik. Det er med vilje - et lopenummer som er sendt
--    til St1 skal ikke dukke opp igjen paa et annet avvik.
-- =====================================================================
