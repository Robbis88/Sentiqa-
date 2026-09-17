import { expect, it } from 'vitest'
import { lytt } from '../../../e2e/oppfriskningslogg'

it('kobler fullfoering til rett forespoersel naar samme RSC-URL kjoeres samtidig', () => {
  const handlers: Record<string, (value: unknown) => void> = {}
  const side = { on: (event: string, fn: (value: unknown) => void) => { handlers[event] = fn } }
  const { rsc } = lytt(side as never, () => 0)
  const request = () => ({ method: () => 'GET', headers: () => ({}), url: () => 'http://localhost/maanedsplan?_rsc=samme' })
  const forste = request(); const andre = request()
  handlers.request(forste); handlers.request(andre)
  handlers.response({ request: () => forste, status: () => 200 })
  handlers.requestfailed(andre)
  handlers.requestfinished(forste)
  expect(rsc).toHaveLength(2)
  expect(rsc[0].status).toBe(200)
  expect(rsc[0].ferdig).not.toBeNull()
  expect(rsc[0].feilet).toBeNull()
  expect(rsc[1].ferdig).toBeNull()
  expect(rsc[1].feilet).not.toBeNull()
  expect(rsc.filter(k => k.ferdig === null && k.feilet === null)).toHaveLength(0)
})
