-- =====================================================================
-- 0209  EN MISLYKKET IMPORT SKAL IKKE FJERNE FUNGERENDE DATA
-- =====================================================================
-- Importen erstatter en maaned ved aa slette og sette inn paa nytt:
--
--   await supabase.from('regnskapslinjer').delete().eq(retailer).eq(periode)
--   if (rader.length > 0) await skrivBatch(supabase, 'regnskapslinjer', rader)
--
-- Det er TO separate kall, og innsettingen er selv flere - feilmeldingen
-- navngir det: «Lagring feilet (batch 3 av 5)». Batch 1 og 2 er da alt
-- commitet.
--
--   parserfeil                  trygt, skjer foer slettingen
--   nettverksfeil etter delete  maaneden staar TOM
--   delvis insert               maaneden staar DELVIS, umerket
--   to samtidige importer       ingen laas i det hele tatt
--
-- Den siste er verdt aa dvele ved: `vurderDublett` sperrer bare paa samme
-- sha256. To ULIKE filer for samme periode - utkast og vol 2 - har ingen
-- sperre. Begge sletter, begge setter inn, rekkefoelgen avgjoeres av
-- nettverket.
--
-- Og ingenting verifiseres foer den nye importen blir synlig, for det
-- finnes ikke noe «blir synlig»-steg: innsettingen ER publiseringen.
--
-- ---------------------------------------------------------------------
-- MODELLEN
--
--   1  Parseren skriver rader med `kilde_jobb_id`. INGEN delete.
--   2  Avstemming mot den nye jobben: radantall, kontrollsummer,
--      gruppe mot produkt, identiteten for usynlig svinn.
--   3  Ikke komplett eller ikke godkjent? Jobben blir staaende som
--      `parset`, og produksjonsdata er UROERT.
--   4  Aktivering i ÉN transaksjon: `aktiver_import()`.
--   5  Viewene leser bare aktiv import.
--   6  Forrige jobb beholdes. Rollback er aa flytte flagget tilbake.
--
-- `kilde_jobb_id` staar allerede paa hver rad. Det som mangler er at
-- noen LESER det - i dag er den ren proveniens, med null treff utenfor
-- skrivestedene.
--
-- ---------------------------------------------------------------------
-- ÉN ÆRLIG BEGRENSNING
--
-- Den parsede historikken som alt er slettet, finnes ikke. Bare
-- raafilene i Storage og jobbmetadataen overlevde. Versjonering begynner
-- ved foerste aktivering - denne migrasjonen kan ikke gi tilbake det
-- slettemoensteret alt har tatt.
--
-- Derfor markeres den SISTE vellykkede jobben per periode som aktiv, saa
-- viewene ser noeyaktig det de ser i dag. Ingen tall endrer seg av denne
-- migrasjonen.
--
-- Idempotent: `add column if not exists`, `or replace`, vaktet update.
-- =====================================================================

alter table public.import_jobber
  add column if not exists aktiv         boolean not null default false,
  add column if not exists parserversjon text;

comment on column public.import_jobber.aktiv is
  'Er dette jobben viewene skal lese for sin periode? Byttes atomisk av '
  'public.aktiver_import(). Forrige jobb beholdes for rollback.';
comment on column public.import_jobber.parserversjon is
  'Hvilken parser som produserte radene. Samme fil med ulik parser gir '
  'ulikt radantall: januarfila ga 324 rader i juni og 384 i september - '
  '+55 noekkeltall og +5 stasjons-RESULTAT. Uten dette feltet ser det ut '
  'som to ulike filer.';

-- ---------------------------------------------------------------------
-- ÉN AKTIV JOBB PER PERIODE OG RAPPORTTYPE.
--
-- Skranken er hele poenget: uten den er «aktiv» en merkelapp, ikke en
-- grense, og to aktive jobber ville blandet to filversjoner i samme tall.
-- ---------------------------------------------------------------------
create unique index if not exists import_jobber_aktiv_unik
  on public.import_jobber (retailer_id, rapporttype, gjelder_dato)
  where aktiv;

-- ---------------------------------------------------------------------
-- Etterfylling: siste vellykkede jobb per periode blir aktiv.
--
-- VAKTET paa at ingen er aktiv fra foer, saa den ikke overskriver et
-- valg noen har tatt naar hele settet kjoeres om igjen.
-- ---------------------------------------------------------------------
update public.import_jobber ij
   set aktiv = true
 where ij.status = 'parset'
   and ij.gjelder_dato is not null
   and not exists (
     select 1 from public.import_jobber a
      where a.retailer_id = ij.retailer_id
        and a.rapporttype = ij.rapporttype
        and a.gjelder_dato = ij.gjelder_dato
        and a.aktiv
   )
   and ij.id = (
     select j.id from public.import_jobber j
      where j.retailer_id = ij.retailer_id
        and j.rapporttype = ij.rapporttype
        and j.gjelder_dato = ij.gjelder_dato
        and j.status = 'parset'
      order by j.parset_tid desc nulls last, j.opprettet_tid desc
      limit 1
   );

-- ---------------------------------------------------------------------
-- AKTIVERINGEN. Atomisk, og den avviser en jobb som ikke er avstemt.
--
-- `security definer` fordi den maa kunne kalles fra importen uansett
-- noekkel, men den baerer tenantpredikatet selv: jobben maa tilhoere den
-- retaileren kalleren oppgir. Se AGENTS.md - en definer-funksjon som
-- ikke sjekker tenant er en omvei rundt RLS.
-- ---------------------------------------------------------------------
create or replace function public.aktiver_import(
  p_retailer uuid,
  p_jobb     uuid
) returns table (forrige uuid, ny uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type  public.rapporttype;
  v_dato  date;
  v_gammel uuid;
begin
  select rapporttype, gjelder_dato into v_type, v_dato
    from public.import_jobber
   where id = p_jobb and retailer_id = p_retailer and status = 'parset';

  if v_type is null then
    raise exception
      'aktiver_import: jobb % finnes ikke for retailer %, eller er ikke «parset». '
      'En jobb som ikke er ferdig avstemt skal ikke kunne aktiveres.',
      p_jobb, p_retailer;
  end if;
  if v_dato is null then
    raise exception
      'aktiver_import: jobb % mangler gjelder_dato. Uten periode kan ingen '
      'vite hva den skulle erstatte.', p_jobb;
  end if;

  select id into v_gammel
    from public.import_jobber
   where retailer_id = p_retailer and rapporttype = v_type
     and gjelder_dato = v_dato and aktiv and id <> p_jobb;

  -- ÉN setning, saa det aldri finnes et oeyeblikk med to aktive eller
  -- ingen aktive. Den partielle unike indeksen ville ellers avvist
  -- rekkefoelgen «sett ny aktiv, deretter gammel inaktiv».
  update public.import_jobber
     set aktiv = (id = p_jobb),
         oppdatert_tid = now()
   where retailer_id = p_retailer
     and rapporttype = v_type
     and gjelder_dato = v_dato
     and (aktiv or id = p_jobb);

  return query select v_gammel, p_jobb;
end $$;

revoke all on function public.aktiver_import(uuid, uuid) from public;
grant execute on function public.aktiver_import(uuid, uuid) to authenticated;

comment on function public.aktiver_import(uuid, uuid) is
  'Bytter aktiv import for én periode i ÉN setning. Avviser en jobb som '
  'ikke er «parset» eller mangler periode: en jobb som ikke er avstemt '
  'skal ikke kunne bli synlig. Rollback er aa kalle den med den gamle '
  'jobb-iden.';

-- ---------------------------------------------------------------------
-- Kvittering: hva som ble aktivt, per periode.
-- ---------------------------------------------------------------------
select ij.rapporttype,
       ij.gjelder_dato,
       count(*)                               as jobber,
       count(*) filter (where ij.aktiv)       as aktive,
       max(rf.filnavn) filter (where ij.aktiv) as aktiv_fil,
       max(ij.antall_rader) filter (where ij.aktiv) as aktiv_rader
  from public.import_jobber ij
  join public.raa_filer rf on rf.id = ij.raa_fil_id
 where ij.status = 'parset' and ij.gjelder_dato is not null
 group by ij.rapporttype, ij.gjelder_dato
 order by ij.rapporttype, ij.gjelder_dato;
