import { describe, expect, it } from 'vitest'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { erStigBønesOgSpørUtenfor } from './stigpresentasjon'

const bruker = { rolle: 'butikksjef', fulltNavn: 'Stig', id: 'u1', retailerId: 'r1' } as InnloggetBruker
const scope = { rolle: 'butikksjef', erEier: false, stasjoner: [{ id: 's1', butikknummer: '0001', navn: 'Bønes', stasjonstype: 'bemannet' }] }

describe('Stig-presentasjon', () => {
  it('bruker demoformuleringen for Dale uten å gi tilgang', () => {
    expect(erStigBønesOgSpørUtenfor(bruker, scope, 'Hvor mye påsmurt skal Dale selge i morgen?')).toBe(true)
  })
  it('gjelder ikke andre navn eller roller', () => {
    expect(erStigBønesOgSpørUtenfor({ ...bruker, fulltNavn: 'Kari' }, scope, 'Hva skjer på Dale?')).toBe(false)
    expect(erStigBønesOgSpørUtenfor({ ...bruker, rolle: 'retailer_admin' }, scope, 'Hva skjer på Dale?')).toBe(false)
  })
})
