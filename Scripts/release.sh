#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

DRY_RUN=0
INSTALL=0
BUMP=patch
EXPLICIT_VERSION=""

usage() {
  cat <<'EOF'
Usage: ./Scripts/release.sh [options]

Build, sign, package, tag, push, and publish a Hunch GitHub release locally.

Options:
  --dry-run          Build everything but do not commit, tag, push, or publish
  --install          Install the exact locally built release to /Applications
  --version X.Y.Z    Release an explicit version
  --major            Bump the major version
  --minor            Bump the minor version
  --patch            Bump the patch version (default)
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --install) INSTALL=1 ;;
    --version)
      [[ $# -ge 2 ]] || { echo "ERROR: --version needs X.Y.Z" >&2; exit 2; }
      EXPLICIT_VERSION=$2
      shift
      ;;
    --major) BUMP=major ;;
    --minor) BUMP=minor ;;
    --patch) BUMP=patch ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

fail() { echo "ERROR: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

command -v git >/dev/null || fail "git is required"
[[ -f version.env ]] || fail "version.env is missing"
[[ -z "$(git status --porcelain)" ]] || fail "working tree is dirty; commit or stash changes first"
if [[ "$DRY_RUN" == 0 ]]; then
  command -v gh >/dev/null || fail "GitHub CLI (gh) is required"
  [[ -n "$(git remote get-url origin 2>/dev/null)" ]] || fail "git remote 'origin' is missing"
  gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated; run: gh auth login"
fi

# shellcheck disable=SC1091
source version.env
CURRENT=${MARKETING_VERSION:?MARKETING_VERSION is missing from version.env}
BUILD=${BUILD_NUMBER:?BUILD_NUMBER is missing from version.env}

IFS=. read -r MAJOR MINOR PATCH <<<"$CURRENT"
[[ "$MAJOR" =~ ^[0-9]+$ && "$MINOR" =~ ^[0-9]+$ && "$PATCH" =~ ^[0-9]+$ ]] \
  || fail "version.env contains invalid semver: $CURRENT"

if [[ -n "$EXPLICIT_VERSION" ]]; then
  NEXT=$EXPLICIT_VERSION
else
  case "$BUMP" in
    major) NEXT="$((MAJOR + 1)).0.0" ;;
    minor) NEXT="${MAJOR}.$((MINOR + 1)).0" ;;
    patch) NEXT="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
  esac
fi
[[ "$NEXT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid release version: $NEXT"

TAG="v$NEXT"
git rev-parse "$TAG" >/dev/null 2>&1 && fail "local tag already exists: $TAG"
if [[ "$DRY_RUN" == 0 ]]; then
  git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 \
    && fail "remote tag already exists: $TAG"
  gh release view "$TAG" >/dev/null 2>&1 && fail "GitHub release already exists: $TAG"
fi

printf 'Current version: %s (%s)\n' "$CURRENT" "$BUILD"
printf 'Release version: %s (%s)\n' "$NEXT" "$((BUILD + 1))"
if [[ "$DRY_RUN" == 0 ]]; then
  read -r -p "Build and publish $TAG from this Mac? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
fi

NEXT_BUILD=$((BUILD + 1))
sed -i '' -E "s/^MARKETING_VERSION=.*/MARKETING_VERSION=$NEXT/" version.env
sed -i '' -E "s/^BUILD_NUMBER=.*/BUILD_NUMBER=$NEXT_BUILD/" version.env

step "Running tests"
swift test

step "Building signed app"
HUNCH_VERSION="$NEXT" HUNCH_BUILD="$NEXT_BUILD" ./Scripts/package_app.sh release

step "Creating release ZIP"
./Scripts/dist.sh
ARTIFACT="$ROOT/build/Hunch.app.zip"
[[ -f "$ARTIFACT" ]] || fail "release artifact missing: $ARTIFACT"
SHA256=$(shasum -a 256 "$ARTIFACT" | awk '{print $1}')
printf 'Artifact: %s\nSHA-256: %s\n' "$ARTIFACT" "$SHA256"

if [[ "$DRY_RUN" == 1 ]]; then
  cat <<EOF

Dry run complete. Nothing was committed or published.
version.env now contains the proposed version; restore it with:
  git restore version.env

To publish manually:
  git add version.env
  git commit -m "Release $TAG"
  git tag "$TAG"
  git push origin "$(git branch --show-current)" "$TAG"
  gh release create "$TAG" "$ARTIFACT" --title "$TAG" --generate-notes
EOF
else
  BRANCH=$(git branch --show-current)
  [[ -n "$BRANCH" ]] || fail "detached HEAD; releases require a branch"

  step "Committing version and pushing tag"
  git add version.env
  git commit -m "Release $TAG"
  git tag "$TAG"
  git push origin "$BRANCH" "$TAG"

  step "Publishing GitHub release"
  gh release create "$TAG" "$ARTIFACT" --title "$TAG" --generate-notes
  echo "Published $TAG"
fi

if [[ "$INSTALL" == 1 ]]; then
  step "Installing the exact locally built app"
  SOURCE_APP="$ROOT/build/dist/Hunch.app"
  [[ -d "$SOURCE_APP" ]] || fail "signed release app missing: $SOURCE_APP"
  pkill -x Hunch 2>/dev/null || true
  if [[ -d /Applications/Hunch.app ]]; then
    BACKUP="$HOME/.Trash/Hunch-$NEXT_BUILD.app"
    [[ ! -e "$BACKUP" ]] || BACKUP="$HOME/.Trash/Hunch-$NEXT_BUILD-$(date +%s).app"
    mv /Applications/Hunch.app "$BACKUP"
    echo "Previous app moved to $BACKUP"
  fi
  ditto "$SOURCE_APP" /Applications/Hunch.app
  open /Applications/Hunch.app
  echo "Installed /Applications/Hunch.app"
fi
