-- ---------------------------------------------------------------------
-- 0100: signerte arbeidsavtaler
-- ---------------------------------------------------------------------
-- BankID skal kjopes, ikke bygges. Til det er paa plass er veien denne:
-- last ned kontrakten, faa den signert paa papir eller i Word, og last
-- det signerte eksemplaret tilbake.
--
-- Da har systemet BEGGE deler: det som ble generert (verdier +
-- malversjon, som gjenskaper dokumentet noeyaktig) og det hun faktisk
-- skrev under paa. Uten det siste er «signert» bare et hakebok noen har
-- satt.
--
-- Kolonnene finnes allerede fra 0098 - status, signert_tid,
-- signert_metode og storage_sti. Det som mangler er tilgangen: raa-filer
-- er eiers bucket (0080), og butikksjefen er den som faktisk henter
-- signaturen.

-- ---------------------------------------------------------------------
-- Storage: {retailer_id}/kontrakt-signert/...
-- ---------------------------------------------------------------------
-- Smale policyer, ikke en utvidelse av eierpolicyen: bare den ene mappa,
-- bare i egen kjede. Permissive policyer OR-es sammen, saa dette apner
-- kun dette prefikset.
--
-- Segmentene sammenlignes som tekst. Aldri cast av stien til uuid - en
-- fil med et ikke-uuid forste segment ville felt HELE spoerringen for
-- alle (se 0080).
--
-- Delt i select og insert. Aldri "for all": USING i en for all-policy
-- gjelder ogsaa SELECT, og da trekkes skrivereglene inn i hver leseplan.
drop policy if exists kontrakt_signert_les on storage.objects;
create policy kontrakt_signert_les on storage.objects
  for select to authenticated
  using (
    bucket_id = 'raa-filer'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
    and (storage.foldername(name))[2] = 'kontrakt-signert'
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
  );

drop policy if exists kontrakt_signert_ins on storage.objects;
create policy kontrakt_signert_ins on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'raa-filer'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
    and (storage.foldername(name))[2] = 'kontrakt-signert'
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
  );

-- Et signert eksemplar skal ikke kunne byttes ut i stillhet. Det finnes
-- derfor ingen update- eller delete-policy for denne mappa: hver
-- opplasting faar sin egen uuid i filnavnet, og retting skjer ved aa
-- laste opp paa nytt - da staar begge.

comment on column public.ansatt_kontrakt.storage_sti is
  'Det SIGNERTE eksemplaret. Det genererte dokumentet lagres ikke - det '
  'gjenskapes fra verdier + mal_versjon.';
comment on column public.ansatt_kontrakt.signert_metode is
  'bekreftelse = signert utenfor systemet og lastet opp. bankid = signert '
  'elektronisk (ikke i bruk enda).';
