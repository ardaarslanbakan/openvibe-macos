#!/usr/bin/env bash
set -euo pipefail

# One-command setup for the personal OpenViBE macOS port.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/work"
SOURCE_DIR="${OPENVIBE_SOURCE_DIR:-$WORK_DIR/openvibe-3.2.0-src}"
DESIGNER_DIR="${OPENVIBE_DESIGNER_DIR:-$WORK_DIR/designer-master}"
SDK_DIR="${OPENVIBE_SDK_DIR:-$WORK_DIR/sdk-master}"
INSTALL_DEPS=0
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: script/setup_macos.sh [--install-deps] [--check-only] [build options]

Prepares the expected source layout and runs the normal packaging build.
Set OPENVIBE_SOURCE_DIR, OPENVIBE_DESIGNER_DIR, and OPENVIBE_SDK_DIR to use
different checkouts. Build options are passed to build_and_run.sh.
EOF
}

while (($#)); do
  case "$1" in
    --install-deps) INSTALL_DEPS=1; shift ;;
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

for path in "$SOURCE_DIR/CMakeLists.txt" "$DESIGNER_DIR/CMakeLists.txt" "$SDK_DIR/CMakeLists.txt"; do
  if [[ ! -f "$path" ]]; then
    echo "Missing OpenViBE source checkout: $path" >&2
    echo "Place the matching OpenViBE 3.2.0 source trees in work/ or set the OPENVIBE_*_DIR variables." >&2
    exit 1
  fi
done

mkdir -p "$WORK_DIR/macos-port"
# Absolute links also support source checkouts located outside this repository.
ln -sfn "$SDK_DIR" "$WORK_DIR/macos-port/sdk"
ln -sfn "$DESIGNER_DIR" "$WORK_DIR/macos-port/designer"

if ((CHECK_ONLY)); then
  echo "OpenViBE macOS prerequisites and source layout look good."
  exit 0
fi

exec "$ROOT_DIR/script/build_and_run.sh" "$@"
