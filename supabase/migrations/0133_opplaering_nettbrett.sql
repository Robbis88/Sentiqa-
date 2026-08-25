-- =====================================================================
-- Opplæringen naar nettbrettet
--
-- Modellen har staatt siden 0042: master-oppgaver, periode per nyansatt,
-- skift-kalender med `unique (periode_id, dato)`, og én rad per hake.
-- Butikksjefen kan alt planlegge og krysse av. Det som manglet var siste
-- ledd: skjemaet naadde aldri fram til stasjonen der opplaeringen skjer.
--
-- Tre ting maa til, og de er alle smaa.
--
-- ---------------------------------------------------------------------
-- 1  KLOKKESLETT PAA SKIFTET
--
-- «Opplaering 29. august, 16-23» er det butikksjefen planlegger. Skiftet
-- hadde bare `dato`.
--
-- TIDENE FORTELLER, DE GJEMMER IKKE. Sjekklista vises hele dagen paa
-- skiftdatoen, med klokkeslettene som tekst. Grunnen er at man haker av
-- ETTER at noe er laert bort - en liste som forsvinner 23:00 forsvinner
-- midt i jobben, og den siste oppgaven er som regel den som tar lengst
-- tid. Skal vinduet strammes senere, er tallene her allerede.
--
-- ---------------------------------------------------------------------
-- 2  HVEM LAERTE BORT
--
-- `bekreftet_av` peker paa `auth.users`. Paa nettbrettet er det
-- STASJONENS DELTE KONTO - ikke et menneske. Feltet lover da noe det
-- ikke kan holde, og for ranerutiner og drivstoffsoel er dette en
-- kvittering noen kan komme til aa lene seg paa.
--
-- `bekreftet_ansatt_id` peker paa `ansatte` - personen bak PIN-en, den
-- samme som allerede signerer rutiner og sjekkpunkter.
--
-- BEGGE, IKKE ÉN AV DEM. Kontoen sier hvilken enhet, ansatten sier
-- hvilket menneske. Det er to ulike identiteter i denne basen, og aa
-- slaa dem sammen ville vaert den fjerde varianten av den samme feilen.
--
-- ---------------------------------------------------------------------
-- 3  NETTBRETTET MAA FAA SKRIVE
--
-- `opp2_utfort_ins/upd/del` (0078) krever `retailer_admin` eller
-- `butikksjef`. Nettbrettet kan lese, men ikke hake av - og det er hele
-- poenget med at lista er der.
--
-- STASJONSGJERDET ROERES IKKE. `mine_stasjoner()` dekker allerede
-- `butikkbruker_tablet` via `butikksjef_stasjoner` (0077), saa
-- nettbrettet naar kun sin egen stasjons perioder. Det som utvides er
-- ROLLEN, ikke rekkevidden.
--
-- Kjor `supabase/tests/rls_vakthund.sql` etterpaa.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1  Klokkeslett
-- ---------------------------------------------------------------------
alter table public.opplaering_skift
  add column if not exists start_tid time,
  add column if not exists slutt_tid time;

-- BEGGE ELLER INGEN. Et skift med starttid og uten slutt er ikke et
-- halvt svar, det er et ubesvart spoersmaal - og visningen maatte da
-- gjettet paa den andre enden.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'opplaering_skift_tid_gyldig'
  ) then
    alter table public.opplaering_skift
      add constraint opplaering_skift_tid_gyldig check (
        (start_tid is null) = (slutt_tid is null)
        and (start_tid is null or slutt_tid > start_tid)
      );
  end if;
end $$;

comment on column public.opplaering_skift.start_tid is
  'Naar opplaeringen begynner. Null sammen med slutt_tid = hele dagen. '
  'Tidene VISES, de skjuler ikke: sjekklista staar hele skiftdatoen, '
  'fordi man haker av etter at noe er laert bort.';

-- ---------------------------------------------------------------------
-- 2  Hvem laerte bort
-- ---------------------------------------------------------------------
alter table public.opplaering_utfort
  add column if not exists bekreftet_ansatt_id uuid
    references public.ansatte(id) on delete set null;

comment on column public.opplaering_utfort.bekreftet_ansatt_id is
  'Personen bak PIN-en paa nettbrettet. `bekreftet_av` peker paa '
  'auth-kontoen, som paa nettbrettet er stasjonens DELTE konto - den '
  'sier hvilken enhet, ikke hvilket menneske. To identiteter, begge '
  'lagret, ingen av dem utledet av den andre.';

-- ---------------------------------------------------------------------
-- 3  Nettbrettet kan hake av paa egen stasjon
--
-- Ikke `for all`: USING i en for all-policy gjelder ogsaa SELECT, og
-- permissive policyer OR-es sammen. Delt per kommando, som resten.
-- Funksjonskallene er pakket i `(select ...)` saa de blir initplan og
-- ikke evalueres per rad.
-- ---------------------------------------------------------------------
drop policy if exists opp2_utfort_ins on public.opplaering_utfort;
create policy opp2_utfort_ins on public.opplaering_utfort for insert to authenticated
  with check ((select public.gjeldende_rolle())
                in ('retailer_admin', 'butikksjef', 'butikkbruker_tablet')
              and periode_id in (select p.id from public.opplaering_periode p
                                 where p.stasjon_id in (select public.mine_stasjoner())));

drop policy if exists opp2_utfort_upd on public.opplaering_utfort;
create policy opp2_utfort_upd on public.opplaering_utfort for update to authenticated
  using ((select public.gjeldende_rolle())
           in ('retailer_admin', 'butikksjef', 'butikkbruker_tablet')
         and periode_id in (select p.id from public.opplaering_periode p
                            where p.stasjon_id in (select public.mine_stasjoner())))
  with check ((select public.gjeldende_rolle())
                in ('retailer_admin', 'butikksjef', 'butikkbruker_tablet')
              and periode_id in (select p.id from public.opplaering_periode p
                                 where p.stasjon_id in (select public.mine_stasjoner())));

-- SLETTING BLIR STAAENDE HOS LEDEREN. Aa fjerne en hake er aa si at noe
-- likevel ikke er laert bort, og det er en vurdering - ikke en
-- registrering. Nettbrettet kan sette haken, ikke ta den bort igjen.
drop policy if exists opp2_utfort_del on public.opplaering_utfort;
create policy opp2_utfort_del on public.opplaering_utfort for delete to authenticated
  using ((select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
         and periode_id in (select p.id from public.opplaering_periode p
                            where p.stasjon_id in (select public.mine_stasjoner())));
