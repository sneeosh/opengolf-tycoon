// Copies the repo's data/*.json (single source of truth shared with the Godot
// build) into public/data/ so Vite serves them.
import { cp, mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const src = join(here, '..', '..', 'data')
const dest = join(here, '..', 'public', 'data')

await mkdir(dest, { recursive: true })
await cp(src, dest, { recursive: true })
console.log(`copied ${src} -> ${dest}`)
