import assert from 'node:assert/strict'
import { afterEach, test } from 'node:test'
import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createGatewayServer } from '../src/server.js'
import { SqliteProfileStore } from '../src/profileStore.js'

const temporaryDirectories: string[] = []

afterEach(() => {
  while (temporaryDirectories.length > 0) {
    const directory = temporaryDirectories.pop()
    if (directory) rmSync(directory, { recursive: true, force: true })
  }
})

function makeProfile(id: string, displayName: string) {
  return {
    id,
    displayName,
    bio: `${displayName} writes a profile`,
    lookingFor: ['dating', 'friendship'],
    values: ['Curiosity'],
    interests: ['Hiking'],
    lifestyle: ['Morning walks'],
    communicationStyle: 'Direct and kind',
    boundaries: ['No last-minute plans'],
    updatedAt: '2026-08-09T12:00:00.000Z',
  }
}

test('profile sync persists public profiles and excludes the requesting profile from the feed', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'wingman-gateway-test-'))
  temporaryDirectories.push(directory)
  const store = new SqliteProfileStore(join(directory, 'wingman.sqlite'))
  const server = createGatewayServer({ profileStore: store })
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  const address = server.address()
  assert.ok(address && typeof address !== 'string')
  const baseURL = `http://127.0.0.1:${address.port}`

  try {
    const alex = makeProfile('11111111-1111-4111-8111-111111111111', 'Alex')
    const jordan = makeProfile('22222222-2222-4222-8222-222222222222', 'Jordan')

    for (const profile of [alex, jordan]) {
      const response = await fetch(`${baseURL}/v1/profiles/${profile.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(profile),
      })
      assert.equal(response.status, 200)
    }

    const response = await fetch(`${baseURL}/v1/profiles?exclude=${alex.id}`)
    assert.equal(response.status, 200)
    const body = await response.json() as { profiles: Array<{ id: string; displayName: string }> }
    assert.equal(body.profiles.length, 1)
    assert.equal(body.profiles[0]?.id, jordan.id)
    assert.equal(body.profiles[0]?.displayName, 'Jordan')
  } finally {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()))
    store.close()
  }
})
