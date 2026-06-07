-- =====================================================================
-- Sentiqa — Døp om rapporttype 'visma_resultat' → 'regnskap_resultat'
-- Den månedlige resultatrapporten kommer fra regnskapskontor (Azets m.fl.),
-- ikke nødvendigvis Visma. Leverandør-nøytralt navn (§6/§18). Idempotent.
-- =====================================================================
do $$
begin
  if exists (
    select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
    where t.typname = 'rapporttype' and e.enumlabel = 'visma_resultat'
  ) and not exists (
    select 1 from pg_enum e join pg_type t on t.oid = e.enumtypid
    where t.typname = 'rapporttype' and e.enumlabel = 'regnskap_resultat'
  ) then
    alter type public.rapporttype rename value 'visma_resultat' to 'regnskap_resultat';
  end if;
end $$;
