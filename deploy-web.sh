#!/bin/bash
set -e

# Configuration
GODOT_PATH="${GODOT:-/Users/laurendeschner/Downloads/Godot.app/Contents/MacOS/Godot}"
R2_BUCKET="opengolf-assets"

echo "=== OpenGolf Tycoon Web Deployment ==="

# Step 1: Export from Godot
echo "1. Exporting web build from Godot..."
"$GODOT_PATH" --headless --export-release "Web" build/web/index.html

# Step 2: Move large files to R2 assets folder
echo "2. Moving large files for R2 upload..."
mkdir -p build/r2-assets
mv build/web/index.wasm build/web/index.pck build/r2-assets/

# Step 3: Upload to R2
echo "3. Uploading to R2..."
npx wrangler r2 object put "$R2_BUCKET/index.wasm" --file=build/r2-assets/index.wasm --remote
npx wrangler r2 object put "$R2_BUCKET/index.pck" --file=build/r2-assets/index.pck --remote

# Step 4: Deploy worker and assets
echo "4. Deploying to Cloudflare Workers..."
npm run deploy

echo ""
echo "=== Deployment complete! ==="
echo "URL: https://opengolf-tycoon.kennyatx1.workers.dev"
