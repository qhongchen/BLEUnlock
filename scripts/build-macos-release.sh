#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_ROOT}/flutter/packages/bleunlock_app"
APP_BUNDLE="${APP_DIR}/build/macos/Build/Products/Release/bleunlock_app.app"
APP_BINARY="${APP_BUNDLE}/Contents/MacOS/bleunlock_app"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS release build must run on macOS." >&2
  exit 1
fi

if ! command -v "${FLUTTER_BIN}" >/dev/null 2>&1; then
  echo "Flutter was not found. Set FLUTTER_BIN=/path/to/flutter or add flutter to PATH." >&2
  exit 1
fi

if [[ ! -d "${APP_DIR}" ]]; then
  echo "Flutter app directory was not found: ${APP_DIR}" >&2
  exit 1
fi

export DART_SUPPRESS_ANALYTICS="${DART_SUPPRESS_ANALYTICS:-true}"
export PUB_CACHE="${PUB_CACHE:-${HOME}/.pub-cache}"

echo "Building BLEUnlock macOS release..."
echo "App directory: ${APP_DIR}"
echo "Flutter: $("${FLUTTER_BIN}" --version | head -n 1)"
echo

pushd "${APP_DIR}" >/dev/null
if [[ "${SKIP_PUB_GET:-0}" != "1" ]]; then
  "${FLUTTER_BIN}" pub get
fi
"${FLUTTER_BIN}" build macos --release
popd >/dev/null

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "macOS release app was not found: ${APP_BUNDLE}" >&2
  exit 1
fi

echo
echo "macOS release app:"
echo "${APP_BUNDLE}"
echo

du -sh "${APP_BUNDLE}"
lipo -info "${APP_BINARY}"
file "${APP_BINARY}"
codesign -dv "${APP_BUNDLE}" 2>&1
