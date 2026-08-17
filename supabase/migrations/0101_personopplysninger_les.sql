-- ---------------------------------------------------------------------
-- 0101: lesetilgang til personopplysninger foelger ROLLE, ikke bare stasjon
-- ---------------------------------------------------------------------
-- Fire tabeller har til naa hatt lese-policyer som bare sjekker
-- stasjonstilgang:
--
--   using (stasjon_id in (select public.mine_stasjoner()))
--
-- Skrivingen har vaert laast til leder hele tiden. Lesingen har ikke.
--
-- Og mine_stasjoner() gir ogsaa 'butikkbruker_tablet' tilgang til sin
-- stasjon. Nettbrettet staar i butikken, anon-noekkelen er offentlig, og
-- sesjonen er ekte - saa hvem som helst som naar nettbrettets nettleser
-- kunne lese kollegenes fodselsdatoer, timesatser, sykefravaer og hele
-- verdier-objektet i kontraktene. Altsaa lonna.
--
-- Sidene sperret for det. Men sidene er ikke sikkerheten; policyen er.
--
-- Monsteret var arvet fra 0089, og det passer for salgstall: der gir
-- stasjonstilgang mening. For fodselsdato og lonn gjor den det ikke.
--
-- Kontrollert for at ingenting paa nettbrettet leser disse tabellene
-- eller visningene over dem: alle lesere er /bemanning, /lonn,
-- /kontrakt (leder) og /import (kun eier).
--
-- MERK for senere: strammingen av stempling gjelder ogsaa de
-- security_invoker-visningene som ligger over den (v_stempling_time,
-- v_stempling_ansatt_mnd, v_stempling_ukeprofil, v_stasjonsforbruk_mnd,
-- v_datadekning). Skal nettbrettet en dag vise «hvem er paa jobb naa»,
-- maa det gaa gjennom en egen visning som ikke lekker navn og timer -
-- ikke ved aa apne denne policyen igjen.

-- Samme rolle-sjekk overalt. (select ...) rundt funksjonskallet, ellers
-- evalueres det per rad og tar ned spoerringen paa store tabeller.
-- for select alene - aldri "for all".

-- --- ansatt_avtale: fodselsdato, timesats, stillingsprosent -----------
drop policy if exists ansatt_avtale_les on public.ansatt_avtale;
create policy ansatt_avtale_les on public.ansatt_avtale
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

-- --- ansatt_kontrakt: verdier-objektet er hele arbeidsavtalen --------
drop policy if exists ansatt_kontrakt_les on public.ansatt_kontrakt;
create policy ansatt_kontrakt_les on public.ansatt_kontrakt
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

-- --- bemanning_fravaer: arsak kan vaere sykdom, altsaa helseopplysning
drop policy if exists bemanning_fravaer_les on public.bemanning_fravaer;
create policy bemanning_fravaer_les on public.bemanning_fravaer
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

-- --- stempling: hvem jobbet naar, med navn ---------------------------
drop policy if exists stempling_les on public.stempling;
create policy stempling_les on public.stempling
  for select to authenticated
  using (stasjon_id in (select public.mine_stasjoner())
         and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'));

comment on table public.ansatt_avtale is
  'Kontraktsfestet stilling per ansatt. null = ikke bekreftet, bruk anslaget. '
  'Leses kun av leder (0101) - inneholder fodselsdato og timesats.';
