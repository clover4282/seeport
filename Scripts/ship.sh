#!/bin/zsh
set -euo pipefail

# ── Config ─────────────────────────────────────────────
APP_NAME="Seeport"
SOURCE_DIR="Sources/seeport"
PLIST="${SOURCE_DIR}/Resources/Info.plist"
DEV_PLIST="${SOURCE_DIR}/Resources/Info.dev.plist"
SIGN_TOOL=".build/artifacts/sparkle/Sparkle/bin/sign_update"
APPCAST="appcast.xml"
REPO="clover4282/seeport"

# ── Version ────────────────────────────────────────────
CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
if [[ -z "${VERSION:-}" ]]; then
    MAJOR="${CURRENT%%.*}"
    MINOR="${CURRENT#*.}"
    VERSION="${MAJOR}.$((MINOR + 1))"
fi

echo ""
echo "🚀 Shipping ${APP_NAME} v${VERSION} (current: v${CURRENT})"
echo ""

# ── 1. Collect release notes (before version commit) ──
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
RELEASE_LINES=()
if [[ -n "$LAST_TAG" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && RELEASE_LINES+=("$line")
    done < <(git log "${LAST_TAG}..HEAD" --pretty=format:"%s" --no-merges 2>/dev/null)
fi
(( ${#RELEASE_LINES[@]} == 0 )) && RELEASE_LINES=("Release v${VERSION}")

# ── 2. Bump version ───────────────────────────────────
echo "[1/7] Bumping version to ${VERSION}..."
for P in "$PLIST" "$DEV_PLIST"; do
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$P"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$P"
done

# ── 3. Commit all changes ─────────────────────────────
echo "[2/7] Committing..."
git add -A
git commit -m "Release v${VERSION}" || echo "  (nothing new to commit)"

# ── 4. Build release bundle ───────────────────────────
echo "[3/7] Building..."
make release-bundle 2>&1 | tail -1

# ── 5. ZIP & Sign ─────────────────────────────────────
echo "[4/7] Packaging & signing..."
ZIP="${APP_NAME}-v${VERSION}.zip"
rm -f "$ZIP"
(cd .build && zip -r "../${ZIP}" "${APP_NAME}.app" -q)

SIGN_OUTPUT=$("$SIGN_TOOL" "$ZIP" 2>&1)
SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*edSignature="\([^"]*\)".*/\1/p' | head -1)
LENGTH=$(stat -f%z "$ZIP")

if [[ -z "$SIGNATURE" ]]; then
    echo "❌ Signing failed. Output:"
    echo "$SIGN_OUTPUT"
    exit 1
fi
echo "  Signed (${LENGTH} bytes)"

# ── 6. GitHub Release ─────────────────────────────────
echo "[5/7] Creating GitHub release..."
gh release create "v${VERSION}" "$ZIP" \
    --title "${APP_NAME} v${VERSION}" \
    --generate-notes

# ── 7. Update appcast.xml ─────────────────────────────
echo "[6/7] Updating appcast.xml..."
PUBDATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
URL="https://github.com/${REPO}/releases/download/v${VERSION}/${ZIP}"

TMPFILE=$(mktemp)
{
    echo '        <item>'
    echo "            <title>Version ${VERSION}</title>"
    echo "            <sparkle:version>${VERSION}</sparkle:version>"
    echo "            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>"
    echo '            <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>'
    echo '            <description><![CDATA['
    echo '                <ul>'
    for line in "${RELEASE_LINES[@]}"; do
        echo "                    <li>${line}</li>"
    done
    echo '                </ul>'
    echo '            ]]></description>'
    echo "            <pubDate>${PUBDATE}</pubDate>"
    echo '            <enclosure'
    echo "                url=\"${URL}\""
    echo '                type="application/octet-stream"'
    echo "                sparkle:edSignature=\"${SIGNATURE}\""
    echo "                length=\"${LENGTH}\""
    echo '            />'
    echo '        </item>'
} > "$TMPFILE"

sed -i '' "/<language>en<\/language>/r ${TMPFILE}" "$APPCAST"
rm -f "$TMPFILE"

git add "$APPCAST"
git commit -m "Update appcast.xml for v${VERSION}"

# ── 8. Push & update gh-pages ─────────────────────────
echo "[7/7] Pushing..."
git push origin main

git checkout gh-pages 2>/dev/null || git checkout -b gh-pages origin/gh-pages
git checkout main -- appcast.xml
git commit -m "Update appcast for v${VERSION}" 2>/dev/null || true
git push origin gh-pages
git checkout main

# ── Done ───────────────────────────────────────────────
rm -f "$ZIP"
echo ""
echo "✅ ${APP_NAME} v${VERSION} shipped!"
echo "   📦 https://github.com/${REPO}/releases/tag/v${VERSION}"
echo "   📡 https://${REPO%%/*}.github.io/${REPO##*/}/appcast.xml"
