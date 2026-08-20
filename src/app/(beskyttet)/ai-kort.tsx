'use client'
import { Gnist } from './ikoner'

// Inngangskort til AI-assistenten — åpner chat-bobla (lytter i ai-boble.tsx).
export function AiKort() {
  return (
    <button type="button" className="ai-kort" onClick={() => window.dispatchEvent(new Event('sentiqa-ai-open'))}>
      <span className="ai-kort-ikon"><Gnist /></span>
      <span className="ai-kort-tekst">
        <strong>Sentiqa AI-assistent</strong>
        <span>Spør på vanlig norsk — tall, regnskap, svinn, konkurranser …</span>
      </span>
      <span className="ai-kort-pil">→</span>
    </button>
  )
}
