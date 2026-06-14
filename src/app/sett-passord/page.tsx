import type { Metadata } from 'next'
import { SettPassordSkjema } from './skjema'

export const metadata: Metadata = { title: 'Sett passord – Sentiqa' }

export default function SettPassordSide() {
  return (
    <main className="logg-inn">
      <div className="kort">
        <div className="merke">Sentiqa</div>
        <h1>Velkommen</h1>
        <p className="undertittel">Velg et passord for kontoen din, så er du i gang.</p>
        <SettPassordSkjema />
      </div>
    </main>
  )
}
