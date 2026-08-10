import { mkdirSync } from 'node:fs'
import { dirname } from 'node:path'
import { DatabaseSync } from 'node:sqlite'

export interface SyncedProfile {
  id: string
  displayName: string
  bio: string | null
  lookingFor: string[]
  values: string[]
  interests: string[]
  lifestyle: string[]
  communicationStyle: string | null
  boundaries: string[]
  updatedAt: string
}

interface ProfileRow {
  id: string
  display_name: string
  bio: string | null
  looking_for: string
  values_json: string
  interests_json: string
  lifestyle_json: string
  communication_style: string | null
  boundaries_json: string
  updated_at: string
}

export class SqliteProfileStore {
  private readonly database: DatabaseSync

  constructor(databasePath: string) {
    mkdirSync(dirname(databasePath), { recursive: true })
    this.database = new DatabaseSync(databasePath)
    this.database.exec(`
      CREATE TABLE IF NOT EXISTS profiles (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        bio TEXT,
        looking_for TEXT NOT NULL,
        values_json TEXT NOT NULL,
        interests_json TEXT NOT NULL,
        lifestyle_json TEXT NOT NULL,
        communication_style TEXT,
        boundaries_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      ) STRICT;
      CREATE INDEX IF NOT EXISTS profiles_updated_at_idx ON profiles(updated_at DESC);
    `)
  }

  upsert(profile: SyncedProfile): SyncedProfile {
    this.database.prepare(`
      INSERT INTO profiles (
        id, display_name, bio, looking_for, values_json, interests_json,
        lifestyle_json, communication_style, boundaries_json, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        display_name = excluded.display_name,
        bio = excluded.bio,
        looking_for = excluded.looking_for,
        values_json = excluded.values_json,
        interests_json = excluded.interests_json,
        lifestyle_json = excluded.lifestyle_json,
        communication_style = excluded.communication_style,
        boundaries_json = excluded.boundaries_json,
        updated_at = excluded.updated_at
    `).run(
      profile.id,
      profile.displayName,
      profile.bio,
      JSON.stringify(profile.lookingFor),
      JSON.stringify(profile.values),
      JSON.stringify(profile.interests),
      JSON.stringify(profile.lifestyle),
      profile.communicationStyle,
      JSON.stringify(profile.boundaries),
      profile.updatedAt
    )
    return profile
  }

  list(excludingID?: string): SyncedProfile[] {
    const rows = excludingID
      ? this.database.prepare(`
          SELECT * FROM profiles WHERE id != ? ORDER BY updated_at DESC, id ASC
        `).all(excludingID) as unknown as ProfileRow[]
      : this.database.prepare(`
          SELECT * FROM profiles ORDER BY updated_at DESC, id ASC
        `).all() as unknown as ProfileRow[]
    return rows.map((row) => this.decode(row))
  }

  close(): void {
    this.database.close()
  }

  private decode(row: ProfileRow): SyncedProfile {
    return {
      id: row.id,
      displayName: row.display_name,
      bio: row.bio,
      lookingFor: JSON.parse(row.looking_for) as string[],
      values: JSON.parse(row.values_json) as string[],
      interests: JSON.parse(row.interests_json) as string[],
      lifestyle: JSON.parse(row.lifestyle_json) as string[],
      communicationStyle: row.communication_style,
      boundaries: JSON.parse(row.boundaries_json) as string[],
      updatedAt: row.updated_at,
    }
  }
}
