#!/bin/bash

# 1. Load variables from .env file
if [ -f .env ]; then
    # This export command handles the .env parsing safely
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ Error: .env file not found!"
    exit 1
fi

# 2. Validate variables
if [ -z "$GH_PAGES_REPO_URL" ]; then
    echo "❌ Error: GH_PAGES_REPO_URL is not set in .env"
    exit 1
fi

if [ -z "$BASE_HREF" ]; then
    echo "⚠️ Warning: BASE_HREF is not set. Defaulting to /"
    BASE_HREF="/"
fi

echo "🚀 Starting build..."
echo "📍 Base HREF: $BASE_HREF"
echo "🌐 Remote:    $GH_PAGES_REPO_URL"

# 3. Build the flutter app with the specified base-href
# The --base-href flag ensures the PWA and service workers route correctly
flutter build web --release --base-href "$BASE_HREF"

# 4. Enter build directory
cd build/web || { echo "❌ Error: build/web directory not found!"; exit 1; }

# 5. Initialize a fresh git environment
# We wipe the local .git inside build/web to keep it a pure "artifact" push
rm -rf .git
git init
git checkout -b main
git remote add origin "$GH_PAGES_REPO_URL"

# 6. Add, commit, and force push
git add .
git commit -m "Deploy: $(date)"
git push origin main --force

# 7. Clean up and return
cd ../..
echo "✅ Deployment Complete! Your PWA should now be live at the correct path."
