-- ---------------------------------------------------------------------
-- 0099: lonnsform per ansatt
-- ---------------------------------------------------------------------
-- Den siste kjente feilen i lonnsfila. Avstemmingen av mai:
--
--   Laguneparken   stemte paa hundredelen mot easy@works egen fil
--   Bones          manglet 191,68 timer - 27 % av maaneden
--
-- To personer forklarte hele avviket: butikksjefen, som har fastlonn, og
-- Carmen, som er tilkallingsvikar. Begge stempler. Begge jobber. Ingen av
-- dem skal staa i fila.
--
-- Uten denne kolonnen finnes ikke forskjellen noe sted i systemet, og
-- fila blir 27 % for stor paa en stasjon og riktig paa en annen - uten at
-- noe varsler om det.
--
-- null betyr «ikke avklart», og det er ikke det samme som timelonn.
-- Lonnsfila lages ikke saa lenge noen med timer i perioden staar med
-- null. Det er den ene gangen det er riktig aa stoppe brukeren: en fil
-- som mangler en persons timer betyr at hun ikke faar lonn den maaneden,
-- og det oppdages forst paa kontoutskriften.
alter table public.ansatt_avtale
  add column if not exists lonnsform text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'ansatt_avtale_lonnsform_sjekk'
  ) then
    alter table public.ansatt_avtale
      add constraint ansatt_avtale_lonnsform_sjekk
      check (lonnsform is null
             or lonnsform in ('timelonn', 'fastlonn', 'tilkalling'));
  end if;
end $$;

comment on column public.ansatt_avtale.lonnsform is
  'timelonn = med i lonnsfila. fastlonn/tilkalling = holdes utenfor. '
  'null = ikke avklart, og da lages ingen fil.';

-- Ingen forhaandsutfylling her, med vilje. Det fristende ville vaert aa
-- sette alle med «butikksjef» i tittelen til fastlonn - men Dale sin
-- butikksjef er timelonnet, og stillingstittel er dessuten en fersk
-- kolonne som staar tom overalt. En update som ser ut som den gjor noe,
-- og ikke gjor det, er verre enn ingen update.
--
-- Lonnsformen settes i grensesnittet, en gang per ansatt.
