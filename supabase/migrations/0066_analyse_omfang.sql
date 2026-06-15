-- =====================================================================
-- Sentiqa - Regnskapsanalyse kan na vaere MAANED eller HITTIL I AAR. omfang
-- skiller dem, saa maaneds- og aars-analyse lever side om side for samme periode.
-- =====================================================================
alter table public.regnskapsanalyser
  add column if not exists omfang text not null default 'maaned'
    check (omfang in ('maaned', 'hittil'));
