-- =====================================================================
-- «St sund» FINNES IKKE, OG «Test Boenes» ER EN TESTRAD
--
-- Stasjonslista hadde sju rader; delingsfila fra St1 kjenner fem. Robert
-- bekreftet 2026-09-06 at Sund ikke finnes.
--
-- En stasjonsrad er ikke gratis. Den dukker opp i hver stasjonsvelger, i
-- `mine_stasjoner()`, og i enhver sum som ikke filtrerer eksplisitt - og
-- et aggregat over «alle stasjoner» blir da et snitt over noe som ikke
-- er der.
--
-- ---------------------------------------------------------------------
-- SER FOERST, LUKKER SAA. I SAMME SETNING.
--
-- Den teller rader i HVER tabell som har en `stasjon_id`, og lukker bare
-- de stasjonene som ikke har noen. Har en av dem data, roeres den ikke -
-- da er spoersmaalet et annet: hvor hoerer de radene hjemme, og er de
-- kanskje en av de fem ekte stasjonenes?
--
-- Tabellene finnes fra KATALOGEN, ikke fra hukommelsen min. En tabell
-- jeg hadde glemt aa liste opp ville sett ut som en tabell uten rader,
-- og da hadde vakten sagt «trygt aa lukke» om noe den ikke saa. Samme
-- grunn som `tenant_dekning.sql` starter fra `pg_class`.
--
-- Partisjoner utelates gjennom `relispartition`, ikke gjennom et
-- navnemoenster: radene deres telles i forelderen, og et moenster som
-- `not like '%_2%'` ville i tillegg truffet en helt vanlig tabell med 2
-- i navnet.
--
-- ---------------------------------------------------------------------
-- SOFT DELETE, IKKE DELETE
--
-- `slettet_tid`, ikke `delete`. Hele kodebasen filtrerer alt paa den,
-- fremmednoeklene holder, og en rad som viser seg aa vaere i bruk kan
-- hentes tilbake med én setning. En `delete` med `on delete cascade` bak
-- seg kan ikke det - og `stasjoner` har cascade paa flere barn.
--
-- Idempotent: `where slettet_tid is null` gjoer andre kjoering til en
-- no-op, og paa en base uten disse radene gjoer den ingenting i det hele
-- tatt. Navnene matches eksakt, saa en fremtidig ekte stasjon som
-- begynner paa «Test» ikke rives med.
-- =====================================================================

create temp table if not exists rydd_stasjoner (
  navn text, rader bigint, handling text
);
truncate rydd_stasjoner;

do $$
declare
  s record;
  t record;
  n bigint;
  totalt bigint;
begin
  for s in
    select id, navn from public.stasjoner
    where (navn = 'St sund' or navn ilike 'Test B_nes')
      and slettet_tid is null
  loop
    totalt := 0;
    for t in
      select c.table_name
      from information_schema.columns c
      join information_schema.tables tt
        on tt.table_schema = c.table_schema and tt.table_name = c.table_name
      where c.table_schema = 'public'
        and c.column_name = 'stasjon_id'
        and tt.table_type = 'BASE TABLE'
        and not exists (
          select 1 from pg_class pc
          join pg_namespace pn on pn.oid = pc.relnamespace
          where pn.nspname = 'public'
            and pc.relname = c.table_name
            and pc.relispartition
        )
    loop
      execute format('select count(*) from public.%I where stasjon_id = %L',
                     t.table_name, s.id)
        into n;
      totalt := totalt + n;
    end loop;

    if totalt = 0 then
      update public.stasjoner
         set slettet_tid = now()
       where id = s.id and slettet_tid is null;
      insert into rydd_stasjoner values (s.navn, 0, 'LUKKET - ingen rader noe sted');
    else
      insert into rydd_stasjoner
        values (s.navn, totalt, 'ROERT IKKE - det henger data i den');
    end if;
  end loop;
end $$;

-- KVITTERINGEN ER EN SELECT, ikke en `raise notice`: SQL Editor viser
-- ikke notices. Se `0145`, der opprydningstallet forsvant av nettopp den
-- grunnen.
--
-- Tom tabell betyr at ingen av de to fantes aapne - ogsaa et gyldig svar.
select navn, rader, handling from rydd_stasjoner order by navn;
