import { hentInnloggetBruker } from '@/lib/auth/dal'
import { Samtale } from './samtale'

export default async function AssistentSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' && bruker.rolle !== 'butikksjef') {
    return <p>Du har ikke tilgang til AI-assistenten.</p>
  }

  return (
    <>
      <h1>Assistent</h1>
      <p className="undertittel">Svar fra dine egne tall — den finner aldri på noe.</p>
      <Samtale />
    </>
  )
}
