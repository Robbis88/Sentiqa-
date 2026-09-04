-- =====================================================================
-- 0108 - personlig_punkt slapp unna 0107
--
-- 0107 rettet seksten tabeller, blant dem personlig_kryss. Soskentabellen
-- personlig_punkt har NOYAKTIG samme policy - `for all` med upakket
-- auth.uid() - og ble ikke rettet.
--
-- Hvorfor: lista over varme tabeller i 0107 ble bygget fra en skanning av
-- migrasjonene, og personlig_punkt kom aldri inn i den. Sjekk 4 i
-- vakthunden fanget det etterpaa: tabellen hadde policy uten aa staa i
-- noen liste, og ble meldt som UTEN TILSYN.
--
-- Samme feilmonster som kontrolltiltak_bekreftelse tidligere samme dag:
-- to tabeller opprettet av samme migrasjon, og bare den ene ble fort opp.
-- Det er derfor dekningssjekken finnes.
--
-- personlig_punkt er punktene i den private sjekklista (0034);
-- personlig_kryss er avhukingene. Begge leses paa hver visning av
-- /rutiner/min.
-- =====================================================================

drop policy if exists personlig_punkt_egne on public.personlig_punkt;

drop policy if exists personlig_punkt_les on public.personlig_punkt;
create policy personlig_punkt_les on public.personlig_punkt for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists personlig_punkt_ins on public.personlig_punkt;
create policy personlig_punkt_ins on public.personlig_punkt for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists personlig_punkt_upd on public.personlig_punkt;
create policy personlig_punkt_upd on public.personlig_punkt for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
drop policy if exists personlig_punkt_del on public.personlig_punkt;
create policy personlig_punkt_del on public.personlig_punkt for delete to authenticated
  using (user_id = (select auth.uid()));

-- Kontroll: supabase/tests/rls_vakthund.sql skal na gaa gronn.
-- Star exchange_rates igjen som funn, er det fordi den er ukjent for
-- repoet og lagt i VARME med vilje - se kommentaren i vakthunden.
