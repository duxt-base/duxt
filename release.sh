#!/bin/bash

# Duxt Release Script
# Usage: ./release.sh 0.4.5

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: ./release.sh <version>"
  echo "Example: ./release.sh 0.4.5"
  exit 1
fi

echo ""
echo "Releasing Duxt v$VERSION"
echo ""

# Update version in pubspec.yaml
sed -i '' "s/^version: .*/version: $VERSION/" pubspec.yaml
echo "  Updated pubspec.yaml"

# Update version in bin/duxt.dart
sed -i '' "s/const version = '.*'/const version = '$VERSION'/" bin/duxt.dart
echo "  Updated bin/duxt.dart"

echo ""
echo "Publishing to pub.dev..."
echo ""

dart pub publish --force

echo ""
echo "Released v$VERSION"
echo ""
