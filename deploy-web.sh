#!/bin/bash
set -e

# Configuration
GODOT_PATH="${GODOT:-/Users/laurendeschner/Downloads/Godot.app/Contents/MacOS/Godot}"
R2_BUCKET="opengolf-assets"
PROJECT_NAME="OpenGolfTycoon"

echo "=== OpenGolf Tycoon Web Deployment ==="

# Step 1: Export web build (required)
echo "1. Exporting web build from Godot..."
mkdir -p build/web
"$GODOT_PATH" --headless --export-release "Web" build/web/index.html

# Step 2: Export desktop builds (optional — requires export templates)
echo "2. Exporting desktop builds..."
DESKTOP_OK=true
mkdir -p build/windows build/macos build/linux
for preset in "Windows Desktop" "macOS" "Linux"; do
    if "$GODOT_PATH" --headless --export-release "$preset" 2>&1; then
        echo "   $preset: OK"
    else
        echo "   $preset: SKIPPED (missing export template)"
        DESKTOP_OK=false
    fi
done

if [ "$DESKTOP_OK" = false ]; then
    echo ""
    echo "   Some desktop exports failed. Install templates via:"
    echo "   Godot → Editor → Manage Export Templates → Download and Install"
    echo ""
fi

# Step 3: Move large web files to R2 assets folder
echo "3. Moving large files for R2 upload..."
mkdir -p build/r2-assets
mv build/web/index.wasm build/web/index.pck build/r2-assets/

# Step 4: Package desktop builds
echo "4. Packaging desktop builds..."
for platform in windows macos linux; do
    if [ -d "build/${platform}" ] && [ "$(ls -A "build/${platform}" 2>/dev/null)" ]; then
        (cd "build/${platform}" && zip -r "../../${PROJECT_NAME}-${platform}.zip" .)
    fi
done

# Step 5: Upload to R2
echo "5. Uploading to R2..."
npx wrangler r2 object put "$R2_BUCKET/index.wasm" --file=build/r2-assets/index.wasm --remote
npx wrangler r2 object put "$R2_BUCKET/index.pck" --file=build/r2-assets/index.pck --remote
for platform in windows macos linux; do
    if [ -f "${PROJECT_NAME}-${platform}.zip" ]; then
        npx wrangler r2 object put "$R2_BUCKET/downloads/${PROJECT_NAME}-${platform}.zip" --file="${PROJECT_NAME}-${platform}.zip" --remote
        echo "   Uploaded ${platform} download"
    fi
done

# Step 6: Deploy worker and assets
echo "6. Deploying to Cloudflare Workers..."
npm run deploy

echo ""
echo "=== Deployment complete! ==="
echo "URL: https://golf.kennyatx.com"
if [ "$DESKTOP_OK" = true ]; then
    echo "Downloads: https://golf.kennyatx.com/downloads/{windows,macos,linux}"
else
    echo "Downloads: Some platforms skipped (install export templates to enable)"
fi
