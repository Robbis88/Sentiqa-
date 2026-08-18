-- =====================================================================
-- 0106 - Avtalevokteren ut
--
-- Funksjonen skal vekk (bestemt 2026-08-18). Den var aldri i drift:
-- dekningssjekken i rls_vakthund.sql viste at `fakturaer` ikke finnes i
-- basen i det hele tatt, saa 0017 er trolig aldri kjort mot prod.
--
-- Siden var likevel synlig og feilet stille: sporringen mot en tabell som
-- ikke finnes ga en feil, `data` ble null, og sida falt tilbake paa
-- «Ingen fakturaer lest ennaa». Den saa ut som en tom funksjon i stedet
-- for en oedelagt en.
--
-- ALT HER ER VAKTET. Migrasjonssettet kjores av og til om igjen fra 0001,
-- og da kan 0017 ha lagd tabellen rett foer denne river den. Begge veier
-- skal virke.
--
-- Prislinja `premium_avtalevokter` roeres IKKE her. Den staar i
-- retailers og brukes av faktureringen (api/faktura, cron/rapporter-bruk).
-- Aa fjerne en kolonne som styrer hva kunder faktureres, er en
-- forretningsbeslutning og ikke en opprydding - og en migrasjon som
-- dropper den kan ikke angres naar den foerst har kjort.
-- =====================================================================

-- Storage-policyen fra 0080. `drop policy if exists` er trygg uansett.
drop policy if exists fakturaer_storage_eier on storage.objects;

-- Boetta og alt i den. Kun hvis den finnes.
do $$
begin
  if exists (select 1 from storage.buckets where id = 'fakturaer') then
    delete from storage.objects where bucket_id = 'fakturaer';
    delete from storage.buckets where id = 'fakturaer';
    raise notice '0106: fjernet storage-boetta fakturaer';
  end if;
end $$;

-- Tabellen. Policyen forsvinner med den.
drop table if exists public.fakturaer;

-- 0017 lager tabellen og boetta paa nytt ved en full gjenkjoring fra
-- 0001. Fila er derfor toemt for innhold i samme slengen - se
-- 0017_avtalevokter.sql, som na bare forklarer hvorfor den er tom.
