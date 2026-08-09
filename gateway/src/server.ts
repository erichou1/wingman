import { createServer, type IncomingMessage, type ServerResponse } from 'node:http'
import { Render } from '@renderinc/sdk'

interface WritingStyle {
  toneNotes?: string
  grammarPreferences?: string
  signaturePhrases?: string[]
  thingsToAvoid?: string[]
}

interface ReplyWorkflowRequest {
  incomingMessage: string
  relationship: string
  context?: string
  goal?: string
  writingStyle?: WritingStyle
  memories?: string[]
}

interface ReplyDraft {
  tone: 'warm' | 'direct' | 'light'
  text: string
  rationale: string
}

const PORT = Number.parseInt(process.env.PORT || '10000', 10)
const TASK_IDENTIFIER = process.env.RENDER_WORKFLOW_TASK || 'wingman-replies/generateReplyDrafts'
const MAX_BODY_BYTES = 128 * 1024

function allowedOrigin(): string {
  return process.env.CORS_ORIGIN?.trim() || '*'
}

function writeJSON(response: ServerResponse, status: number, body: unknown): void {
  response.statusCode = status
  response.setHeader('Content-Type', 'application/json; charset=utf-8')
  response.setHeader('Cache-Control', 'no-store')
  response.setHeader('Access-Control-Allow-Origin', allowedOrigin())
  response.end(JSON.stringify(body))
}

function writeOptions(response: ServerResponse): void {
  response.statusCode = 204
  response.setHeader('Access-Control-Allow-Origin', allowedOrigin())
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
  response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
  response.end()
}

async function readBody(request: IncomingMessage): Promise<string> {
  const chunks: Buffer[] = []
  let size = 0
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
    size += buffer.length
    if (size > MAX_BODY_BYTES) throw new Error('Request body is too large')
    chunks.push(buffer)
  }
  return Buffer.concat(chunks).toString('utf8')
}

function isString(value: unknown): value is string {
  return typeof value === 'string'
}

function parseRequest(value: unknown): ReplyWorkflowRequest {
  if (!value || typeof value !== 'object') throw new Error('Request must be a JSON object')
  const body = value as Record<string, unknown>
  if (!isString(body.incomingMessage) || !body.incomingMessage.trim()) {
    throw new Error('incomingMessage must be a non-empty string')
  }
  if (!isString(body.relationship) || !body.relationship.trim()) {
    throw new Error('relationship must be a non-empty string')
  }

  return {
    incomingMessage: body.incomingMessage,
    relationship: body.relationship,
    context: isString(body.context) ? body.context : undefined,
    goal: isString(body.goal) ? body.goal : undefined,
    writingStyle: body.writingStyle as WritingStyle | undefined,
    memories: Array.isArray(body.memories) ? body.memories.filter(isString) : undefined,
  }
}

function extractDrafts(results: unknown): ReplyDraft[] {
  if (!Array.isArray(results)) throw new Error('Workflow returned an invalid result')
  const first = results[0]
  const value = first && typeof first === 'object' && 'drafts' in first
    ? (first as { drafts: unknown }).drafts
    : first
  if (!Array.isArray(value)) throw new Error('Workflow returned no drafts')
  return value as ReplyDraft[]
}

function authorized(request: IncomingMessage): boolean {
  const expected = process.env.WINGMAN_GATEWAY_TOKEN?.trim()
  if (!expected) return true
  return request.headers.authorization === `Bearer ${expected}`
}

async function handleReplyDrafts(request: IncomingMessage, response: ServerResponse): Promise<void> {
  if (!authorized(request)) {
    writeJSON(response, 401, { error: 'Unauthorized' })
    return
  }

  try {
    const body = JSON.parse(await readBody(request)) as unknown
    const workflowRequest = parseRequest(body)
    const render = new Render()
    const run = await render.workflows.runTask(TASK_IDENTIFIER, [workflowRequest])
    if (run.status !== 'completed') {
      writeJSON(response, 502, { error: 'Reply workflow failed', taskRunId: run.id, status: run.status })
      return
    }
    writeJSON(response, 200, { drafts: extractDrafts(run.results), taskRunId: run.id })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown gateway error'
    writeJSON(response, 502, { error: message })
  }
}

const server = createServer(async (request, response) => {
  response.setHeader('Access-Control-Allow-Origin', allowedOrigin())

  if (request.method === 'OPTIONS') {
    writeOptions(response)
    return
  }

  if (request.method === 'GET' && request.url === '/healthz') {
    writeJSON(response, 200, { ok: true, workflow: TASK_IDENTIFIER })
    return
  }

  if (request.method === 'POST' && request.url === '/v1/reply-drafts') {
    await handleReplyDrafts(request, response)
    return
  }

  writeJSON(response, 404, { error: 'Not found' })
})

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Wingman Render gateway listening on port ${PORT}`)
})
