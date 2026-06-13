-- =====================================================================
-- Sentiqa - IK-mat som rutine i vaktskjemaet. En rutine kan merkes som en
-- IK-mat-kontroll for en frekvens-gruppe (daglig/2x/ukentlig). På tableten
-- vises den som et kort som lenker til måle-arket for den gruppen, og hakes av
-- når alle enhetene i gruppen er målt den dagen. Ukedager styres av rutinens
-- egne ukedager (som vanlig). Ingen endring på selve IK-kontrollpunktene.
-- =====================================================================
alter table public.rutiner add column if not exists ikmat_frekvens text;
comment on column public.rutiner.ikmat_frekvens is
  'null = vanlig rutine; daglig|to_ukentlig|ukentlig = IK-mat-kontroll som lenker til måle-arket';
