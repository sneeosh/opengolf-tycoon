import { defineConfig } from 'vite'
import { fileURLToPath } from 'node:url'

export default defineConfig({
	base: './',
	resolve: {
		alias: {
			'@sim': fileURLToPath(new URL('./src/sim', import.meta.url)),
			'@render': fileURLToPath(new URL('./src/render', import.meta.url)),
			'@ui': fileURLToPath(new URL('./src/ui', import.meta.url)),
		},
	},
	server: {
		port: 5173,
	},
})
