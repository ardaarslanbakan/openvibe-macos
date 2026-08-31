#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT_DIR="$ROOT_DIR/work/macos-port"
BUILD_DIR="$PORT_DIR/designer-build"
APP_NAME="openvibe-designer"
APP_BINARY="$BUILD_DIR/dist/bin/openvibe-designer-3.2.0"
APP_BUNDLE="$ROOT_DIR/outputs/OpenViBE Designer.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
ICONSET_DIR="$ROOT_DIR/work/OpenViBE.iconset"
ICON_SOURCE="$ROOT_DIR/work/designer-master/applications/platform/designer/share/designer.png"
DEMOS_SOURCE="$ROOT_DIR/work/openvibe/extras/applications/demos"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cmake -S "$PORT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF \
  -DBUILD_UNIT_TEST=OFF \
  -DBUILD_VALIDATION_TEST=OFF \
  -DPUBLISH_DOC_ASSETS=OFF \
  -DCMAKE_PREFIX_PATH=/opt/homebrew
cmake --build "$BUILD_DIR" --parallel 4
cmake --install "$BUILD_DIR"

rm -rf "$APP_BUNDLE" "$ICONSET_DIR"
mkdir -p "$APP_MACOS" "$APP_FRAMEWORKS" "$APP_RESOURCES" "$ICONSET_DIR"
mkdir -p "$APP_CONTENTS/lib"
ln -s Resources/share "$APP_CONTENTS/share"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
if ! iconutil -c icns "$ICONSET_DIR" -o "$APP_RESOURCES/OpenViBE.icns"; then
  echo "Warning: could not create OpenViBE.icns; continuing without a custom icon." >&2
fi

ditto "$APP_BINARY" "$APP_MACOS/$APP_NAME"
# The build-tree binary searches ../lib; the app bundle stores those libraries
# in Contents/Frameworks. Add the bundle-specific loader path after copying.
install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP_MACOS/$APP_NAME" 2>/dev/null || true
ditto "$ROOT_DIR/script/OpenViBE Designer" "$APP_MACOS/OpenViBE Designer"
ditto "$BUILD_DIR/dist/lib" "$APP_FRAMEWORKS"
# Portable-mode builds look for unversioned libraries in Contents/lib.
for lib in "$APP_FRAMEWORKS"/*.dylib; do
  [ -e "$lib" ] || continue
  name="$(basename "$lib")"
  short="${name%%.*}.dylib"
  ln -sf "../Frameworks/$name" "$APP_CONTENTS/lib/$short"
done
ditto "$BUILD_DIR/dist/share" "$APP_RESOURCES/share"
# Retain the complete source demo collection for browsing, and install its
# runnable scenarios/data where Designer resolves ordinary OpenViBE scenarios.
ditto "$DEMOS_SOURCE" "$APP_RESOURCES/share/openvibe/BCI Demos"
for demo in erp-recording neurofeedback p300 motor-imagery; do
  ditto "$DEMOS_SOURCE/$demo/bci-examples" "$APP_RESOURCES/share/openvibe/scenarios"
done
ditto "$DEMOS_SOURCE/neurofeedback/signals" "$APP_RESOURCES/share/openvibe/scenarios/signals"
ditto "$ROOT_DIR/script/Info.plist" "$APP_CONTENTS/Info.plist"
chmod +x "$APP_MACOS/OpenViBE Designer"

case "$MODE" in
  run)
    /usr/bin/open -n "$APP_BUNDLE"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs|--telemetry|telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    ;;
  --verify|verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
