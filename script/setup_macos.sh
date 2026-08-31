#!/usr/bin/env bash
set -euo pipefail

# One-command setup for the personal OpenViBE macOS port.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/work"
SOURCE_DIR="${OPENVIBE_SOURCE_DIR:-$WORK_DIR/openvibe-3.2.0-src}"
DESIGNER_DIR="${OPENVIBE_DESIGNER_DIR:-$WORK_DIR/designer-master}"
SDK_DIR="${OPENVIBE_SDK_DIR:-$WORK_DIR/sdk-master}"
OPENVIBE_REPO_URL="${OPENVIBE_REPO_URL:-https://github.com/dioptre/openvibe.git}"
PATCH_FILE="$ROOT_DIR/patches/designer-macos-complete.patch"
ACQUISITION_PATCH_FILE="$ROOT_DIR/patches/acquisition-server-macos.patch"
INSTALL_DEPS=0
CHECK_ONLY=0
DOWNLOAD_SOURCES=0

usage() {
  cat <<'EOF'
Usage: script/setup_macos.sh [--download-sources] [--install-deps] [--check-only] [build options]

Optionally downloads the upstream OpenViBE repository, prepares the expected
source layout, and runs the normal packaging build.
Set OPENVIBE_SOURCE_DIR, OPENVIBE_DESIGNER_DIR, and OPENVIBE_SDK_DIR to use
different checkouts. Set OPENVIBE_REPO_URL to use a different upstream mirror.
Build options are passed to build_and_run.sh.
EOF
}

while (($#)); do
  case "$1" in
    --install-deps) INSTALL_DEPS=1; shift ;;
    --download-sources) DOWNLOAD_SOURCES=1; shift ;;
    --check-only) CHECK_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) break ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This setup script is for macOS only." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install it from https://brew.sh/ and run this again." >&2
  exit 1
fi

if ((INSTALL_DEPS)); then
  brew install cmake pkg-config gtk+ boost eigen expat xerces-c tinyxml2 fftw
fi

for tool in cmake pkg-config sips iconutil; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Missing required tool: $tool. Re-run with --install-deps or install it manually." >&2
    exit 1
  }
done

if ((DOWNLOAD_SOURCES)) && [[ ! -f "$SOURCE_DIR/CMakeLists.txt" ]]; then
  command -v git >/dev/null 2>&1 || {
    echo "Git is required to download OpenViBE sources." >&2
    exit 1
  }
  mkdir -p "$(dirname "$SOURCE_DIR")"
  echo "Downloading OpenViBE sources from $OPENVIBE_REPO_URL"
  git clone --depth 1 "$OPENVIBE_REPO_URL" "$SOURCE_DIR"
  DESIGNER_DIR="$SOURCE_DIR/designer"
  SDK_DIR="$SOURCE_DIR/sdk"
fi

for path in "$SOURCE_DIR/CMakeLists.txt" "$DESIGNER_DIR/CMakeLists.txt" "$SDK_DIR/CMakeLists.txt"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing OpenViBE source checkout: $path" >&2
    echo "Place the matching OpenViBE 3.2.0 source trees in work/, set the OPENVIBE_*_DIR variables, or re-run with --download-sources." >&2
    exit 1
  fi
done

PATCH_TARGET="$DESIGNER_DIR/applications/platform/designer/src/CInterfacedScenario.cpp"
if [[ -f "$PATCH_FILE" ]]; then
  if [[ ! -f "$PATCH_TARGET" ]]; then
    echo "The downloaded Designer source does not contain the expected legacy Designer layout." >&2
    echo "Use a matching OpenViBE 3.2.0 Designer checkout via OPENVIBE_DESIGNER_DIR." >&2
    exit 1
  fi
  if patch --batch --dry-run -l -p1 -d "$DESIGNER_DIR" < "$PATCH_FILE" >/dev/null 2>&1; then
    patch --batch -l -p1 -d "$DESIGNER_DIR" < "$PATCH_FILE"
  elif patch --batch --dry-run -l -R -p1 -d "$DESIGNER_DIR" >/dev/null 2>&1 < "$PATCH_FILE"; then
    echo "Designer macOS patch is already applied."
  else
    echo "Designer source does not match the expected revision for patches/designer-macos.patch." >&2
    exit 1
  fi
fi

# Apply the small cross-platform Acquisition Server fixes when the downloaded
# source tree contains the current server implementation. Older split
# checkouts may not contain these paths, so leave them unchanged and let the
# normal source compatibility checks report the limitation.
ACQUISITION_ROOT=""
if [[ -f "$SOURCE_DIR/extras/applications/platform/acquisition-server/CInitApp.cpp" ]]; then
  ACQUISITION_ROOT="$SOURCE_DIR"
elif [[ -f "$DESIGNER_DIR/extras/applications/platform/acquisition-server/CInitApp.cpp" ]]; then
  ACQUISITION_ROOT="$DESIGNER_DIR"
fi
if [[ -n "$ACQUISITION_ROOT" && -f "$ACQUISITION_PATCH_FILE" ]]; then
  if patch --batch --dry-run -l -p1 -d "$ACQUISITION_ROOT" < "$ACQUISITION_PATCH_FILE" >/dev/null 2>&1; then
    patch --batch -l -p1 -d "$ACQUISITION_ROOT" < "$ACQUISITION_PATCH_FILE"
  elif patch --batch --dry-run -l -R -p1 -d "$ACQUISITION_ROOT" >/dev/null 2>&1 < "$ACQUISITION_PATCH_FILE"; then
    echo "Acquisition Server macOS patch is already applied."
  else
    echo "Acquisition Server source does not match the expected patch revision; continuing without it." >&2
  fi
fi

mkdir -p "$WORK_DIR/macos-port"
# Absolute links also support source checkouts located outside this repository.
ln -sfn "$SDK_DIR" "$WORK_DIR/macos-port/sdk"
ln -sfn "$DESIGNER_DIR" "$WORK_DIR/macos-port/designer"

if ((CHECK_ONLY)); then
  echo "OpenViBE macOS prerequisites and source layout look good."
  exit 0
fi

exec "$ROOT_DIR/script/build_and_run.sh" "$@"
