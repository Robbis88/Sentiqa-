-- ---------------------------------------------------------------------
-- 0091: timeforbruk mot kunder og mat, per stasjon og maaned
-- ---------------------------------------------------------------------
-- Sammenligningen mellom stasjonene trenger fire tall per stasjon per
-- maaned: stemplede timer, innekunder, butikkomsetning og matomsetning.
-- De ligger i tre ulike tabeller med hver sin kornstorrelse.
--
-- Aggregeringen hoerer i basen. Klienten skal ikke hente 487 dager x 5
-- stasjoner x 24 timer for aa summere dem - det var noyaktig feilen som
-- gjorde at «hva mangler»-listen sto tom (se 0090).
--
-- Mat er avdeling 120. Den koden er lik i hele kjeden, og tilberedt mat
-- er den enkeltdriveren som best forklarer hvorfor to stasjoner med like
-- mange kunder trenger ulikt antall hender.
create or replace view public.v_stasjonsforbruk_mnd
with (security_invoker = true) as
with timer as (
  select stasjon_id,
         date_trunc('month', dato)::date as maaned,
         sum(minutter) / 60.0            as timer
  from public.stempling
  where betalt
  group by stasjon_id, date_trunc('month', dato)
),
kunder as (
  select stasjon_id,
         date_trunc('month', dato)::date as maaned,
         sum(inne_kunder)                as kunder
  from public.timesalg
  where slettet_tid is null and inne_kunder is not null
  group by stasjon_id, date_trunc('month', dato)
),
salg as (
  select stasjon_id,
         date_trunc('month', dato)::date as maaned,
         sum(omsetning_eks_mva)                                      as omsetning,
         sum(omsetning_eks_mva) filter (where avdeling_kode = '120') as mat
  from public.v_butikksalg
  group by stasjon_id, date_trunc('month', dato)
)
select coalesce(t.stasjon_id, k.stasjon_id, s.stasjon_id) as stasjon_id,
       coalesce(t.maaned, k.maaned, s.maaned)             as maaned,
       coalesce(t.timer, 0)                               as timer,
       coalesce(k.kunder, 0)                              as kunder,
       coalesce(s.omsetning, 0)                           as omsetning,
       coalesce(s.mat, 0)                                 as mat_omsetning
from timer t
full join kunder k on k.stasjon_id = t.stasjon_id and k.maaned = t.maaned
full join salg   s on s.stasjon_id = coalesce(t.stasjon_id, k.stasjon_id)
                 and s.maaned      = coalesce(t.maaned, k.maaned);

comment on view public.v_stasjonsforbruk_mnd is
  'Timer, kunder, omsetning og matomsetning per stasjon per maaned. '
  'Mater sammenligningen av stasjoner: hvem bruker flest timer per kunde, '
  'og har de maten som forklarer det.';

grant select on public.v_stasjonsforbruk_mnd to authenticated;
