// Speiler enum public.brukerrolle i databasen (0001_fundament.sql).
export type Brukerrolle =
  | 'retailer_admin'
  | 'butikksjef'
  | 'butikkbruker_tablet'
  | 'plattform_redaktor'

export type InnloggetBruker = {
  id: string
  rolle: Brukerrolle
  retailerId: string | null // null kun for plattform_redaktor
  fulltNavn: string | null
  epost: string | null
}

export const ROLLE_ETIKETT: Record<Brukerrolle, string> = {
  retailer_admin: 'Eier',
  butikksjef: 'Butikksjef',
  butikkbruker_tablet: 'Tablet',
  plattform_redaktor: 'Plattform-redaktør',
}
