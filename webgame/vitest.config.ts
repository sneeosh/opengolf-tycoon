import { defineConfig } from 'vitest/config'
import { fileURLToPath } from 'node:url'

export default defineConfig({
	resolve: {
		alias: {
			'@sim': fileURLToPath(new URL('./src/sim', import.meta.url)),
		},
	},
	test: {
		include: ['src/sim/**/*.spec.ts', 'tools/**/*.spec.ts'],
		environment: 'node',
	},
})
