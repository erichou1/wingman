import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http'
import { fileURLToPath } from 'node:url'
import { resolve } from 'node:path'
import { Render } from '@renderinc/sdk'
import { SqliteProfileStore, type SyncedProfile } from './profileStore.js'

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

export interface GatewayOptions {
  profileStore?: SqliteProfileStore
}

const PORT = Number.parseInt(process.env.PORT || '10000', 10)
const TASK_IDENTIFIER = process.env.RENDER_WORKFLOW_TASK || 'wingman-replies/generateReplyDrafts'
const MAX_BODY_BYTES = 128 * 1024
const MAX_PROFILE_TEXT_LENGTH = 1_000
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

class ClientInputError extends Error {}

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
  response.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
  response.end()
}

async function readBody(request: IncomingMessage): Promise<string> {
  const chunks: Buffer[] = []
  let size = 0
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
    size += buffer.length
    if (size > MAX_BODY_BYTES) throw new ClientInputError('Request body is too large')
    chunks.push(buffer)
  }
  return Buffer.concat(chunks).toString('utf8')
}

function isString(value: unknown): value is string {
  return typeof value === 'string'
}

function requiredText(value: unknown, field: string, maximumLength = MAX_PROFILE_TEXT_LENGTH): string {
  if (!isString(value)) throw new ClientInputError(`${field} must be a string`)
  const text = value.trim()
  if (!text) throw new ClientInputError(`${field} must be a non-empty string`)
  if (text.length > maximumLength) throw new ClientInputError(`${field} is too long`)
  return text
}

function optionalText(value: unknown, field: string): string | null {
  if (value === null || value === undefined || value === '') return null
  return requiredText(value, field)
}

function stringList(value: unknown, field: string): string[] {
  if (!Array.isArray(value) || value.some((item) => !isString(item))) {
    throw new ClientInputError(`${field} must be an array of strings`)
  }
  if (value.length > 32) throw new ClientInputError(`${field} has too many values`)
  return value.map((item) => requiredText(item, field, 200))
}

function parseProfile(value: unknown, expectedID: string): SyncedProfile {
  if (!value || typeof value !== 'object') throw new ClientInputError('Profile must be a JSON object')
  const body = value as Record<string, unknown>
  const id = requiredText(body.id, 'id', 64)
  if (!UUID_PATTERN.test(id)) throw new ClientInputError('id must be a UUID')
  if (id !== expectedID) throw new ClientInputError('Profile id must match the URL')
  const updatedAt = requiredText(body.updatedAt, 'updatedAt', 64)
  if (Number.isNaN(Date.parse(updatedAt))) throw new ClientInputError('updatedAt must be an ISO-8601 date')

  return {
    id,
    displayName: requiredText(body.displayName, 'displayName', 120),
    bio: optionalText(body.bio, 'bio'),
    lookingFor: stringList(body.lookingFor, 'lookingFor'),
    values: stringList(body.values, 'values'),
    interests: stringList(body.interests, 'interests'),
    lifestyle: stringList(body.lifestyle, 'lifestyle'),
    communicationStyle: optionalText(body.communicationStyle, 'communicationStyle'),
    boundaries: stringList(body.boundaries, 'boundaries'),
    updatedAt,
  }
}

function parseRequest(value: unknown): ReplyWorkflowRequest {
  if (!value || typeof value !== 'object') throw new ClientInputError('Request must be a JSON object')
  const body = value as Record<string, unknown>
  return {
    incomingMessage: requiredText(body.incomingMessage, 'incomingMessage'),
    relationship: requiredText(body.relationship, 'relationship'),
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

function requireAuthorization(request: IncomingMessage, response: ServerResponse): boolean {
  if (authorized(request)) return true
  writeJSON(response, 401, { error: 'Unauthorized' })
  return false
}

async function handleReplyDrafts(request: IncomingMessage, response: ServerResponse): Promise<void> {
  if (!requireAuthorization(request, response)) return
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
    writeJSON(response, error instanceof ClientInputError ? 400 : 502, { error: message })
  }
}

async function handleProfileUpsert(
  request: IncomingMessage,
  response: ServerResponse,
  profileStore: SqliteProfileStore,
  id: string
): Promise<void> {
  if (!requireAuthorization(request, response)) return
  try {
    const profile = parseProfile(JSON.parse(await readBody(request)), id)
    writeJSON(response, 200, { profile: profileStore.upsert(profile) })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Invalid profile payload'
    writeJSON(response, error instanceof ClientInputError || error instanceof SyntaxError ? 400 : 500, { error: message })
  }
}

function handleProfileFeed(
  request: IncomingMessage,
  response: ServerResponse,
  profileStore: SqliteProfileStore,
  url: URL
): void {
  if (!requireAuthorization(request, response)) return
  const excludedID = url.searchParams.get('exclude') ?? undefined
  if (excludedID && !UUID_PATTERN.test(excludedID)) {
    writeJSON(response, 400, { error: 'exclude must be a UUID' })
    return
  }
  writeJSON(response, 200, { profiles: profileStore.list(excludedID) })
}

export function createGatewayServer(options: GatewayOptions = {}): Server {
  const profileStore = options.profileStore ?? new SqliteProfileStore(
    process.env.WINGMAN_DATABASE_PATH || resolve(process.cwd(), 'data', 'wingman.sqlite')
  )

  return createServer(async (request, response) => {
    response.setHeader('Access-Control-Allow-Origin', allowedOrigin())

    if (request.method === 'OPTIONS') {
      writeOptions(response)
      return
    }

    const url = new URL(request.url || '/', 'http://localhost')
    if (request.method === 'GET' && url.pathname === '/healthz') {
      writeJSON(response, 200, { ok: true, workflow: TASK_IDENTIFIER, profileStore: 'sqlite' })
      return
    }

    if (request.method === 'POST' && url.pathname === '/v1/reply-drafts') {
      await handleReplyDrafts(request, response)
      return
    }

    if (request.method === 'GET' && url.pathname === '/v1/profiles') {
      handleProfileFeed(request, response, profileStore, url)
      return
    }

    const profileMatch = url.pathname.match(/^\/v1\/profiles\/([0-9a-f-]+)$/i)
    if (request.method === 'PUT' && profileMatch) {
      await handleProfileUpsert(request, response, profileStore, profileMatch[1])
      return
    }

    writeJSON(response, 404, { error: 'Not found' })
  })
}

const isMainModule = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)
if (isMainModule) {
  createGatewayServer().listen(PORT, '0.0.0.0', () => {
    console.log(`Wingman gateway listening on port ${PORT}`)
  })
}
