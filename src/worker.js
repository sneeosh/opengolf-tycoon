// Files stored in R2 due to size limits (>25MB)
const R2_FILES = ["index.wasm", "index.pck"];

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
