-- =====================================================================
-- 0204  BP-KOSTNADENE ER EIERENS
-- =====================================================================
-- `0192` stengte `driftskostnader` og `resultat` for butikksjefen. Den
-- gjorde det med en SVARTELISTE paa seksjon, og begrunnelsen sto skrevet
-- i fila:
--
--   «En hvitliste over SEKSJONER ville faatt en ny seksjon til aa
--    forsvinne i stillhet for butikksjefen.»
--
-- Avveiningen var riktig. Men den har en bakside, og den slo til:
-- **`bp_kostnad` er en seksjon som kom TIL etterpaa.** BP-importen
-- skriver hele stasjonens maanedsbudsjett inn i `regnskapslinjer` med
-- egne seksjonsnavn - og `bp_kostnad` baerer hver eneste BP-konto:
--
--   5010  Faste loenninger      <- butikksjefens egen loenn paa en
--   6312  Royalty                  stasjon med én fastloennet
--   husleie, forsikring, finans
--
-- Radene har `stasjon_id` satt, saa butikksjefarmen i `0192` slipper dem
-- rett gjennom. Over PostgREST er de lesbare.
--
-- ---------------------------------------------------------------------
-- DET ER IKKE ET TEORETISK HULL. DET ER EN REGEL SOM ER SAGT HOEYT
--
-- Robert, 2026-09-12: «butikksjefene skal aldri se noe annet enn total
-- loennsbudsjett. aldri budsjett paa fastloenn osv. jeg kan selvsagt se
-- det.»
--
-- Visningen foelger regelen - kontotabellen paa `/lonnskost` staar bak
-- `erAdmin &&`, med begrunnelsen skrevet ved siden av. Men det er et
-- VISNINGSFILTER, og det var noeyaktig samme tilstand `0192` ble skrevet
-- for aa rette for de andre radene: «regelen sto i regnskap-tilgang.ts
-- fra starten, men bare som visningsfilter; over PostgREST var hver rad
-- lesbar».
--
-- ---------------------------------------------------------------------
-- INGENTING GAAR I STYKKER, OG DET ER MAALT
--
-- Jeg trodde foerst dette krevde en `security definer`-funksjon som ga
-- butikksjefen SUMMEN, fordi `/lonnskost` viser aapne maaneder fra BP.
-- Det stemte ikke: den sida leser BP fra `bp_linje` (`0155`), ikke fra
-- `bp_kostnad` - og `bp_linje` er allerede eierens alene.
--
-- `grep` paa `'bp_kostnad'` i src/ gir tre treff, og alle tre er den
-- TS-stoepte formen fra `bp_linje`. Ingen flate leser seksjonen fra
-- `regnskapslinjer`.
--
-- `bp_omsetning` og `bp_bruttofortjeneste` roeres IKKE. Dem leser
-- butikksjefen ekte: `/salg` og ukebriefen henter
-- `seksjon in ('omsetning','bp_omsetning')`.
--
-- ---------------------------------------------------------------------
-- OG SAA VAKTEN, SIDEN SVARTELISTA HAR DENNE FEILMAATEN
--
-- En ny seksjon vil slippe gjennom paa nytt neste gang. Derfor krever
-- `src/lib/regnskap/seksjoner.test.ts` at HVER seksjon importen skriver
-- er klassifisert for haand - `ja`, `nei` eller `hvitlistet` - med en
-- skrevet begrunnelse. En seksjon som faller mellom stolene er et funn,
-- ikke en detalj. Samme regel som `tenant_dekning.sql` bruker for
-- tabeller.
--
-- Idempotent: `drop policy if exists` + `create policy`.
-- =====================================================================

drop policy if exists regnskapslinjer_les on public.regnskapslinjer;
create policy regnskapslinjer_les on public.regnskapslinjer for select to authenticated
  using (
    slettet_tid is null
    and retailer_id = (select public.gjeldende_retailer_id())
    and (
      (select public.gjeldende_rolle()) = 'retailer_admin'
      or (
        stasjon_id is not null
        and stasjon_id in (
          select bs.stasjon_id from public.butikksjef_stasjoner bs
          where bs.profil_id = (select auth.uid())
        )
        -- KONTOENE ER EIERENS.
        and seksjon <> 'resultat'
        -- BP-KOSTNADENE OGSAA. Hele stasjonens maanedsbudsjett per
        -- konto, inkludert 5010 Faste loenninger - som paa en stasjon
        -- med én fastloennet er én persons loenn.
        and seksjon <> 'bp_kostnad'
        and (
          seksjon <> 'driftskostnader'
          or (
            -- NULL = vi vet ikke hva raden er. Ukjent skal bety SKJULT.
            begrep is not null
            and begrep = any(array[
              -- Personal, samlet til en linje i visningen.
              -- refundert_sykelonn er refusjonen av sykelonn, foert
              -- negativt. Uten den ser butikksjefen sykeloennen som
              -- kostnad, men ikke pengene tilbake.
              'faste_lonninger', 'lonnstillegg', 'timelonn', 'sykelonn',
              'refundert_sykelonn', 'palopte_feriepenger', 'bonus',
              'arbeidsgiveravgift_lonn', 'arbeidsgiveravgift_feriepenger',
              'andre_personalkostnader',
              -- Paavirkbar drift, i visningsrekkefoelge.
              -- `renhold_og_renovasjon` er den SAMMENSLAATTE linja fra
              -- foer februar 2026, som St1 siden splittet i 627 Renhold
              -- og 628 Renovasjon. Begge delene staar her allerede, saa
              -- unionen aapner ingenting nytt - utelates den, forsvinner
              -- hele renholdskostnaden for butikksjefen paa hver maaned
              -- foer skiftet.
              'renhold', 'renhold_og_renovasjon', 'renovasjon', 'broyting',
              'utstyr_verktoy',
              'forbruksmateriell', 'rep_vedlikehold', 'pengehandtering',
              'kontorrekvisita', 'kassedifferanse'
            ])
          )
        )
      )
    )
  );

comment on policy regnskapslinjer_les on public.regnskapslinjer is
  'Butikksjefen ser sine stasjoner, men ikke RESULTAT-linja, ikke '
  'BP-kostnadene (0204 - de baerer 5010 Faste loenninger per maaned) og '
  'ikke de driftskostnadene hen ikke kan paavirke. Grensen inne i '
  'driftskostnader er skrevet i BEGREP og ikke i kode (0203): St1 '
  'renummererte rapportlinjene i februar 2026, og 628 betydde «Leie '
  'driftsmidler» foer det. Listene speiler BUTIKKSJEF_BEGREP og '
  'seksjonene er klassifisert i src/lib/regnskap/seksjoner.ts.';

-- ---------------------------------------------------------------------
-- Kvittering: hvor mye laa aapent.
-- ---------------------------------------------------------------------
do $$
declare
  rader     bigint;
  lonnsrader bigint;
begin
  select count(*), count(*) filter (where kode like '50%')
    into rader, lonnsrader
    from public.regnskapslinjer
   where seksjon = 'bp_kostnad' and stasjon_id is not null and slettet_tid is null;

  raise notice '0204: bp_kostnad-rader med stasjon: % (herav % loennskonti) - naa eierens alene',
    rader, lonnsrader;
end $$;
