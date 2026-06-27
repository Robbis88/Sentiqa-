import type { Metadata } from 'next'
import Link from 'next/link'
import { InnloggingSkjema } from './skjema'

export const metadata: Metadata = { title: 'Logg inn – Sentiqa' }

export default async function LoggInnSide({
  searchParams,
}: {
  searchParams: Promise<{ retur?: string }>
}) {
  const { retur } = await searchParams

  return (
    <main className="logg-inn">
      <div className="kort">
        <div className="merke">Sentiqa</div>
        <h1>Logg inn</h1>
        <p className="undertittel">Fornemmer. Forstår. Forutser.</p>
        <InnloggingSkjema retur={retur} />
      </div>
      <footer className="auth-bunn">R-G Invest AS · Org.nr 937 861 621 · <Link href="/personvern">Personvern</Link></footer>
    </main>
  )
}
