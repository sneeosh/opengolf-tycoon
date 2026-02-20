// Files stored in R2 due to size limits (>25MB)
const R2_FILES = ["index.wasm", "index.pck"];

// Desktop build downloads served from R2
const DOWNLOAD_FILES = {
	"/downloads/windows": { key: "downloads/OpenGolfTycoon-windows.zip", name: "OpenGolfTycoon-windows.zip" },
	"/downloads/macos": { key: "downloads/OpenGolfTycoon-macos.zip", name: "OpenGolfTycoon-macos.zip" },
	"/downloads/linux": { key: "downloads/OpenGolfTycoon-linux.zip", name: "OpenGolfTycoon-linux.zip" },
};

// Required headers for Godot WebAssembly (SharedArrayBuffer support)
const SECURITY_HEADERS = {
	"Cross-Origin-Opener-Policy": "same-origin",
	"Cross-Origin-Embedder-Policy": "require-corp",
};

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		let pathname = url.pathname;

		// Serve index.html for root path
		if (pathname === "/" || pathname === "") {
			pathname = "/index.html";
		}

		// Serve desktop build downloads from R2
		const download = DOWNLOAD_FILES[pathname];
		if (download) {
			const object = await env.R2_ASSETS.get(download.key);

			if (!object) {
				return new Response("Download not available yet", { status: 404 });
			}

			return new Response(object.body, {
				status: 200,
				headers: {
					"Content-Type": "application/zip",
					"Content-Disposition": `attachment; filename="${download.name}"`,
					"Cache-Control": "public, max-age=3600",
				},
			});
		}

		const filename = pathname.split("/").pop();

		// Serve large files from R2
		if (R2_FILES.includes(filename)) {
			const object = await env.R2_ASSETS.get(filename);

			if (!object) {
				return new Response("Not Found", { status: 404 });
			}

			// Set correct content types for Godot files
			let contentType = "application/octet-stream";
			if (filename.endsWith(".wasm")) {
				contentType = "application/wasm";
			}

			return new Response(object.body, {
				status: 200,
				headers: {
					"Content-Type": contentType,
					"Cache-Control": "public, max-age=31536000, immutable",
					...SECURITY_HEADERS,
				},
			});
		}

		// Serve other files from Workers assets
		// Create a new request with the modified pathname if needed
		const assetUrl = new URL(request.url);
		assetUrl.pathname = pathname;

		const response = await env.ASSETS.fetch(assetUrl.toString());

		// Build response with security headers
		const headers = {
			"Cross-Origin-Opener-Policy": "same-origin",
			"Cross-Origin-Embedder-Policy": "require-corp",
			"Cache-Control": "no-store",
		};

		// Preserve content-type from original response
		const contentType = response.headers.get("Content-Type");
		if (contentType) {
			headers["Content-Type"] = contentType;
		}

		return new Response(response.body, {
			status: response.status,
			statusText: response.statusText,
			headers,
		});
	},
};
