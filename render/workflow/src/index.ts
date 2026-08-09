import { task } from '@renderinc/sdk/workflows'

export type ReplyTone = 'warm' | 'direct' | 'light'

export interface WritingStyle {
  toneNotes?: string
  grammarPreferences?: string
  signaturePhrases?: string[]
  thingsToAvoid?: string[]
}

export interface ReplyWorkflowRequest {
  incomingMessage: string
  relationship: string
  context?: string
  goal?: string
  writingStyle?: WritingStyle
  memories?: string[]
}

export interface ReplyDraft {
  tone: ReplyTone
  text: string
  rationale: string
}

export interface ReplyWorkflowResult {
  drafts: ReplyDraft[]
}

const NIM_ENDPOINT = process.env.NVIDIA_API_BASE_URL?.trim()
  || 'https://integrate.api.nvidia.com/v1/chat/completions'
const DEFAULT_MODEL = 'meta/llama-3.1-8b-instruct'
const TONES: ReplyTone[] = ['warm', 'direct', 'light']

function requireText(value: string, field: string): string {
  const trimmed = value.trim()
  if (!trimmed) throw new Error(`${field} must not be empty`)
  return trimmed
}

function systemPrompt(request: ReplyWorkflowRequest): string {
  const lines = [
    'You are Wingman, a reply-drafting assistant.',
    'Draft a reply for the user to review and send themselves. Never send anything.',
    `This is a ${request.relationship.toLowerCase()} relationship.`,
  ]

  const style = request.writingStyle
  const toneNotes = style?.toneNotes?.trim()
  if (toneNotes) lines.push(`The user's writing style: ${toneNotes}`)

  const grammar = style?.grammarPreferences?.trim()
  if (grammar) lines.push(`Grammar preferences: ${grammar}`)

  const phrases = style?.signaturePhrases?.filter(Boolean) ?? []
  if (phrases.length) lines.push(`Phrases the user likes to use: ${phrases.join(', ')}`)

  const avoid = style?.thingsToAvoid?.filter(Boolean) ?? []
  if (avoid.length) lines.push(`Avoid: ${avoid.join(', ')}`)

  const memories = request.memories?.map((memory) => memory.trim()).filter(Boolean) ?? []
  if (memories.length) {
    lines.push(`Relevant context the user has saved:\n${memories.slice(0, 8).map((memory) => `- ${memory}`).join('\n')}`)
  }

  return lines.join('\n')
}

function toneInstruction(tone: ReplyTone): string {
  switch (tone) {
    case 'warm':
      return 'Warm and empathetic tone. Acknowledge feelings before anything else.'
    case 'direct':
      return 'Direct and clear tone. State intent plainly and propose a concrete next step.'
    case 'light':
      return 'Light and low-pressure tone. Keep it brief and easygoing.'
  }
}

export function buildUserPrompt(request: ReplyWorkflowRequest, tone: ReplyTone): string {
  const incoming = requireText(request.incomingMessage, 'incomingMessage')
  const relationship = requireText(request.relationship, 'relationship')
  const context = request.context?.trim() || 'none given'
  const goal = request.goal?.trim() || 'keep the conversation moving'

  return [
    `Relationship: ${relationship}`,
    `Incoming message: ${incoming}`,
    `Context: ${context}`,
    `Goal for this reply: ${goal}`,
    toneInstruction(tone),
    'Write ONLY the reply text the user could send, with no quotes, preamble, or explanation.',
  ].join('\n')
}

async function callNIM(request: ReplyWorkflowRequest, tone: ReplyTone): Promise<string> {
  const apiKey = process.env.NVIDIA_API_KEY?.trim()
  if (!apiKey) throw new Error('NVIDIA_API_KEY is not configured on the Render Workflow service')

  const response = await fetch(NIM_ENDPOINT, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: process.env.NVIDIA_MODEL?.trim() || DEFAULT_MODEL,
      messages: [
        { role: 'system', content: systemPrompt(request) },
        { role: 'user', content: buildUserPrompt(request, tone) },
      ],
      max_tokens: 220,
      temperature: 0.7,
    }),
  })

  if (!response.ok) {
    throw new Error(`NVIDIA NIM returned HTTP ${response.status}`)
  }

  const payload = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>
  }
  const text = payload.choices?.[0]?.message?.content?.trim()
  if (!text) throw new Error('NVIDIA NIM returned no draft text')
  return text.replace(/^['"]|['"]$/g, '').trim()
}

const draftReply = task(
  {
    name: 'draftReply',
    retry: { maxRetries: 2, waitDurationMs: 1_000, backoffScaling: 1.5 },
    timeoutSeconds: 60,
    plan: 'starter',
  },
  async function draftReply(request: ReplyWorkflowRequest, tone: ReplyTone): Promise<ReplyDraft> {
    const text = await callNIM(request, tone)
    return {
      tone,
      text,
      rationale: `Drafted by NVIDIA NIM in a ${tone} tone.`,
    }
  },
)

export const generateReplyDrafts = task(
  {
    name: 'generateReplyDrafts',
    retry: { maxRetries: 1, waitDurationMs: 1_000, backoffScaling: 2 },
    timeoutSeconds: 90,
    plan: 'standard',
  },
  async function generateReplyDrafts(request: ReplyWorkflowRequest): Promise<ReplyWorkflowResult> {
    requireText(request.incomingMessage, 'incomingMessage')
    requireText(request.relationship, 'relationship')

    const drafts = await Promise.all(TONES.map((tone) => draftReply(request, tone)))
    return { drafts }
  },
)
