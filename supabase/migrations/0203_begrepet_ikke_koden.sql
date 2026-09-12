-- =====================================================================
-- 0203  BEGREPET, IKKE KODEN, STYRER HVEM SOM SER REGNSKAPSLINJA
-- =====================================================================
-- `0192` gjorde `BUTIKKSJEF_KOSTNAD_KODER` til en RLS-grense. Lista er
-- skrevet i RAAKODER, og det er der problemet ligger:
--
--   628  betydde «Leie driftsmidler»  foer februar 2026
--   628  betyr   «Renovasjon»         i dag
--
-- `kontoregister.ts` (#255) loeste det for IMPORTEN ved aa avvise filer
-- fra den gamle epoken. Det virker - men det betyr ogsaa at januar 2026
-- og alt eldre IKKE KAN LASTES OPP. Robert fikk beskjeden 2026-09-12:
--
--   «627 627 Renhold-renovasj» er fra rapportformatet FOER februar 2026
--
-- Avvisningen var riktig gitt grensen. Men grensen er feil sted aa lose
-- det: en kode er en ADRESSE, ikke en identitet. `bilagssum` (0199)
-- skrev grensen i `Kontobegrep` fra foerste dag, nettopp fordi
-- bilagsbufferen baerer tolv maaneder bakover og de eldste radene alltid
-- er fra det gamle skjemaet.
--
-- Denne migrasjonen gir `regnskapslinjer` det samme.
--
-- ---------------------------------------------------------------------
-- ETTERFYLLINGEN STOPPER VED FEBRUAR 2026, OG DET ER POENGET
--
-- `begrep` etterfylles fra `kode` - men BARE for perioder fra
-- 2026-02-01. For eldre rader sier koden ingenting sikkert, og da er
-- «vi vet ikke» det eneste aerlige svaret.
--
-- Det er ikke en forsiktighetsregel. Rader fra foer #255 ble navngitt ut
-- av koden alene, med DAGENS betydning. En rad fra 2025 med kode 628
-- staar altsaa i basen som «Renovasjon» mens den er leasing - feil navn,
-- og synlig for butikksjefen gjennom 0192-policyen. Aa etterfylle den
-- med `renovasjon` ville stoepet feilen fast.
--
-- `begrep is null` betyr derfor SKJULT for butikksjef, ikke synlig. En
-- slik rad blir riktig naar maaneden lastes opp paa nytt - og med denne
-- migrasjonen kan den endelig lastes opp.
--
-- Kvitteringen nederst teller radene som staar igjen uten begrep, saa
-- det ikke blir en stille tilstand.
--
-- ---------------------------------------------------------------------
-- RETNINGEN PAA FEILEN ER DEN SAMME SOM FOER
--
-- 0192 hvitlistet koder inne i `driftskostnader`: en ukjent konto falt
-- utenfor og havnet paa eierens side. Hvitlista er naa skrevet i begrep,
-- og `begrep is null` faller utenfor paa noeyaktig samme maate.
-- Svartelista paa seksjon staar urort - en NY seksjon skal ikke kunne
-- forsvinne i stillhet for butikksjefen.
--
-- Lista under skal vaere identisk med `BUTIKKSJEF_BEGREP` i
-- `src/lib/regnskap-tilgang.ts`, i samme rekkefoelge.
-- `src/lib/parsere/begrepliste.test.ts` binder dem sammen - en policy
-- kan ikke importere en TypeScript-modul, saa lista finnes to steder og
-- ville ellers drevet fra hverandre.
--
-- Idempotent: `add column if not exists`, `drop policy if exists`, og en
-- etterfylling som er vaktet med `begrep is null`.
-- =====================================================================

alter table public.regnskapslinjer
  add column if not exists begrep text;

comment on column public.regnskapslinjer.begrep is
  'Kanonisk kontobegrep fra parsere/kontoregister.ts. Stabilt over St1s '
  'renummerering i februar 2026, der koden ikke er det. Null = raden ble '
  'skrevet foer 0203 og fra en periode vi ikke kan tolke koden for; '
  'skjult for butikksjef til maaneden er importert paa nytt.';

-- ---------------------------------------------------------------------
-- Etterfylling. Kun fra 2026-02-01: se begrunnelsen over.
--
-- Kartet maa stemme med registeret i `parsere/kontoregister.ts` for
-- epokene `fra_feb_2026` og `null` (uendret over skiftet).
-- `src/lib/regnskap/begrepkart.test.ts` binder dem sammen.
-- ---------------------------------------------------------------------
update public.regnskapslinjer l
set begrep = k.begrep
from (values
  ('501', 'faste_lonninger'),
  ('502', 'lonnstillegg'),
  ('503', 'timelonn'),
  ('505', 'sykelonn'),
  ('506', 'refundert_sykelonn'),
  ('508', 'palopte_feriepenger'),
  ('509', 'bonus'),
  ('540', 'arbeidsgiveravgift_lonn'),
  ('541', 'arbeidsgiveravgift_feriepenger'),
  ('590', 'andre_personalkostnader'),
  ('621', 'markedsbidrag'),
  ('622', 'royalty'),
  ('623', 'fsa'),
  ('624', 'franchiseavgift'),
  ('627', 'renhold'),
  ('628', 'renovasjon'),
  ('629', 'broyting'),
  ('630', 'leie_driftsmidler'),
  ('631', 'leie_utstyr_utleie'),
  ('632', 'utstyr_verktoy'),
  ('633', 'forbruksmateriell'),
  ('634', 'rep_vedlikehold'),
  ('635', 'data_kortsystem'),
  ('636', 'pengehandtering'),
  ('637', 'fremmedtjenester_vakthold'),
  ('638', 'kontorrekvisita'),
  ('639', 'telefon'),
  ('740', 'bilutgifter'),
  ('741', 'reise_moter_kurs'),
  ('742', 'reklame'),
  ('743', 'diverse'),
  ('744', 'forsikringer'),
  ('745', 'erstatning_tyveri'),
  ('746', 'kassedifferanse'),
  ('771', 'bank_kortprovisjon'),
  ('780', 'ekstraordinaert'),
  ('790', 'avskrivninger'),
  ('810', 'finanskostnader'),
  ('840', 'ikke_driftsrelatert')
) as k(kode, begrep)
where l.begrep is null
  and l.seksjon = 'driftskostnader'
  and l.periode >= date '2026-02-01'
  and l.kode = k.kode;

-- ---------------------------------------------------------------------
-- Policyen. Samme form som 0192, men hvitlista er skrevet i begrep.
--
-- Hjelpefunksjonene er pakket i `(select ...)` saa de blir initplan.
-- Ingen `for all`. `har_stasjonstilgang(stasjon_id)` kan aldri bli
-- initplan - derfor underspoerringen mot `butikksjef_stasjoner`,
-- uendret fra 0067/0192. Se AGENTS.md.
-- ---------------------------------------------------------------------
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
  'Butikksjefen ser sine stasjoner, men ikke RESULTAT-linja og ikke de '
  'driftskostnadene hen ikke kan paavirke. Grensen er skrevet i BEGREP '
  'og ikke i kode (0203): St1 renummererte rapportlinjene i februar 2026, '
  'og 628 betydde «Leie driftsmidler» foer det. En grense i koder ville '
  'vist leasingkostnaden som renovasjon paa hver rad fra den gamle '
  'epoken. Lista speiler BUTIKKSJEF_BEGREP og er bundet til den av '
  'src/lib/parsere/begrepliste.test.ts.';

-- ---------------------------------------------------------------------
-- Kvittering. En stille tilstand er den dyreste formen dette huset har.
-- ---------------------------------------------------------------------
do $$
declare
  med_begrep   bigint;
  uten_begrep  bigint;
  eldste       date;
begin
  select count(*) filter (where begrep is not null),
         count(*) filter (where begrep is null),
         min(periode) filter (where begrep is null)
    into med_begrep, uten_begrep, eldste
    from public.regnskapslinjer
   where seksjon = 'driftskostnader' and slettet_tid is null;

  raise notice '0203: driftskostnadslinjer med begrep: %', med_begrep;
  raise notice '0203: uten begrep (skjult for butikksjef): % - eldste periode %',
    uten_begrep, eldste;
  if uten_begrep > 0 then
    raise notice '0203: last opp disse maanedene paa nytt. Naa gaar det: '
      'importen godtar det gamle rapportformatet.';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- BILAGSSUM FAAR DEN SAMME LISTA
--
-- `0199` skrev grensen i begrep fra foerste dag, men uten
-- `renhold_og_renovasjon`. Bilagsbufferen baerer TOLV MAANEDER bakover i
-- hver fil, saa de eldste radene er alltid fra det gamle skjemaet - og
-- der er renhold og renovasjon EN linje. Uten den i lista ser
-- butikksjefen ingen renholdskostnad i det hele tatt for de maanedene,
-- og en kostnad som mangler ser ut som en kostnad som er null.
--
-- 0199 er kjoert og roeres ikke. Lista defineres paa nytt her, og
-- `begrepliste.test.ts` leser fra DENNE fila.
-- ---------------------------------------------------------------------
drop policy if exists bilagssum_les_butikksjef on public.bilagssum;
create policy bilagssum_les_butikksjef on public.bilagssum for select to authenticated
  using (
    retailer_id = (select public.gjeldende_retailer_id())
    and (select public.gjeldende_rolle()) = 'butikksjef'
    and stasjon_id in (select public.mine_stasjoner())
    and begrep is not null
    and begrep = any (array[
      'faste_lonninger','lonnstillegg','timelonn','sykelonn',
      'refundert_sykelonn','palopte_feriepenger','bonus',
      'arbeidsgiveravgift_lonn','arbeidsgiveravgift_feriepenger',
      'andre_personalkostnader',
      'renhold','renhold_og_renovasjon','renovasjon','broyting','utstyr_verktoy',
      'forbruksmateriell','rep_vedlikehold','pengehandtering',
      'kontorrekvisita','kassedifferanse'
    ])
  );

-- ---------------------------------------------------------------------
-- `regnskap_sum` MAA BAERE BEGREPET VIDERE
--
-- Butikksjefvisningen leser ikke tabellen direkte - den kaller denne.
-- Uten `begrep` i retursettet ville visningen ha begrepet i basen og
-- ingenting aa filtrere paa i appen, og kostnadslista hadde blitt tom.
--
-- Funksjonen faar EN NY KOLONNE, den mister ingen. Derfor er det trygt
-- aa kjoere denne migrasjonen FOER deployen: gammel kode leser feltene
-- sine ved navn og merker ikke at det kom et til. (Motsatt vei - en
-- migrasjon som TAR noe bort - skal kjoeres etter. Se AGENTS.md.)
--
-- `security invoker` staar som foer: blir den definer, leser den forbi
-- RLS og hele grensen over er borte.
--
-- Grupperingen utvides med `begrep`. Det splitter ingen rad som var
-- samlet: for en gitt (kode, post) er begrepet entydig, og naar en
-- hittil-sum spenner over februar 2026 sto linjene fra hver sin epoke
-- allerede hver for seg - de har ulikt `post`.
-- ---------------------------------------------------------------------
drop function if exists public.regnskap_sum(date, date);
create function public.regnskap_sum(p_fra date, p_til date)
returns table(
  stasjon_id uuid, seksjon text, kode text, begrep text, post text,
  sortering integer, regnskap numeric, budsjett numeric
)
language sql
security invoker
set search_path = public
as $$
  select
    stasjon_id, seksjon, kode, begrep, post,
    min(sortering)::int as sortering,
    sum(regnskap)        as regnskap,
    sum(budsjett)        as budsjett
  from public.regnskapslinjer
  where periode between p_fra and p_til and slettet_tid is null
  group by stasjon_id, seksjon, kode, begrep, post
$$;

grant execute on function public.regnskap_sum(date, date) to authenticated;
