#!/bin/bash

# Duxt Release Script
# Usage: ./release.sh          (auto-bumps patch: 0.5.4 → 0.5.5)
#        ./release.sh 0.6.0    (explicit version)

set -e

cd "$(dirname "$0")"

# Read current version from pubspec.yaml
CURRENT=$(grep '^version:' pubspec.yaml | sed 's/version: //')
echo ""
echo "  Current version: $CURRENT"

if [ -n "$1" ]; then
  VERSION=$1
else
  # Auto-increment patch version
  MAJOR=$(echo "$CURRENT" | cut -d. -f1)
  MINOR=$(echo "$CURRENT" | cut -d. -f2)
  PATCH=$(echo "$CURRENT" | cut -d. -f3)
  PATCH=$((PATCH + 1))
  VERSION="$MAJOR.$MINOR.$PATCH"
fi

echo "  New version:     $VERSION"
echo ""

# Prompt for changelog entry
echo "  What changed?"
read -r -p "  > " CHANGELOG_MSG

if [ -z "$CHANGELOG_MSG" ]; then
  echo ""
  echo "  ✗ Changelog message required. Aborting."
  exit 1
fi

# Get today's date
TODAY=$(date +%Y-%m-%d)

# Insert changelog entry after header (line 4: "# Changelog\n\nAll notable...\n")
{
  head -4 CHANGELOG.md
  echo "## [$VERSION] - $TODAY"
  echo ""
  echo "- $CHANGELOG_MSG"
  echo ""
  tail -n +5 CHANGELOG.md
} > CHANGELOG.tmp && mv CHANGELOG.tmp CHANGELOG.md
echo "  ✓ CHANGELOG.md"

# Update version in pubspec.yaml
sed -i '' "s/^version: .*/version: $VERSION/" pubspec.yaml
echo "  ✓ pubspec.yaml"

# Update version in lib/src/version.dart (if it exists)
if [ -f lib/src/version.dart ]; then
  sed -i '' "s/const packageVersion = '.*'/const packageVersion = '$VERSION'/" lib/src/version.dart
  echo "  ✓ lib/src/version.dart"
fi

# Clear stale snapshot so duxt --version works immediately
rm -f .dart_tool/pub/bin/duxt/*.snapshot
echo "  ✓ Cleared stale snapshot"

# Reactivate globally
dart pub global activate --source path . > /dev/null 2>&1
echo "  ✓ Reactivated CLI globally"

echo ""
echo "  Publishing to pub.dev..."
echo ""

dart pub publish --force

# Git commit, tag, push
git add -A
git commit -m "release: v$VERSION — $CHANGELOG_MSG"
git tag "v$VERSION"
git push && git push --tags
echo "  ✓ Tagged v$VERSION"

echo ""
echo "  ✓ Released Duxt v$VERSION"
echo ""
