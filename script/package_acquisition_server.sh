#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/work/openvibe-build"
ENV_DIR="$ROOT_DIR/work/openvibe-conda"
APP_BUNDLE="$ROOT_DIR/outputs/OpenViBE Acquisition Server.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

pkill -x openvibe-acquisition-server >/dev/null 2>&1 || true
cmake --build "$BUILD_DIR" --target openvibe-acquisition-server --parallel 4

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
ditto "$BUILD_DIR/bin/openvibe-acquisition-server" "$APP_MACOS/openvibe-acquisition-server.bin"
cc -O2 "$ROOT_DIR/script/AcquisitionServerLauncher.c" -o "$APP_MACOS/OpenViBE Acquisition Server"
ditto "$ROOT_DIR/outputs/OpenViBE Designer.app/Contents/Resources/OpenViBE.icns" "$APP_RESOURCES/OpenViBE.icns"
ditto "$ROOT_DIR/script/AcquisitionServer-Info.plist" "$APP_CONTENTS/Info.plist"
ditto "$BUILD_DIR/share" "$APP_RESOURCES/share"
ditto "$BUILD_DIR/bin/services" "$APP_MACOS/services"

"$ENV_DIR/lib/qt6/bin/macdeployqt" "$APP_BUNDLE" -always-overwrite \
  -executable="$APP_MACOS/openvibe-acquisition-server.bin" \
  -libpath="$BUILD_DIR/bin" \
  -libpath="$BUILD_DIR/bin/services" \
  -libpath="$BUILD_DIR/lib" \
  -libpath="$ENV_DIR/lib" \
  -qmldir="$ROOT_DIR/work/openvibe/extras/applications/platform/acquisition-server/ui" \
  -qmldir="$ROOT_DIR/work/openvibe/extras/applications/qml"

# Remove build/Conda rpaths so macOS cannot load a second copy of Qt beside
# the bundled frameworks. Duplicate Qt installations make Cocoa abort while
# QGuiApplication creates the platform integration.
SERVER_BIN="$APP_MACOS/openvibe-acquisition-server.bin"
for rpath in \
  "$BUILD_DIR/bin/python_runtime/lib" \
  "/Users/ardaarslanbakan/miniforge3/lib" \
  "$BUILD_DIR/bin/services" \
  "$BUILD_DIR/bin" \
  "$BUILD_DIR/lib" \
  "$ENV_DIR/lib"; do
  install_name_tool -delete_rpath "$rpath" "$SERVER_BIN" 2>/dev/null || true
done
install_name_tool -add_rpath '@executable_path/../Frameworks' "$SERVER_BIN" 2>/dev/null || true
install_name_tool -add_rpath '@executable_path/services' "$SERVER_BIN" 2>/dev/null || true

# KernelLoader opens this unversioned name explicitly, while macdeployqt only
# preserves the versioned dependency name used by the main executable.
ditto "$BUILD_DIR/lib/libopenvibe-kernel.dylib" "$APP_CONTENTS/Frameworks/libopenvibe-kernel.dylib"

# This import is referenced by the embedded OV.Parameters QML module and is
# not discoverable from the top-level server source alone.
ditto "$ENV_DIR/lib/qt6/qml/Qt/labs/platform" "$APP_RESOURCES/qml/Qt/labs/platform"

# The Action Bar and other controls use SVG icons; this format plugin is not
# detected by macdeployqt because the assets are loaded dynamically from QML.
mkdir -p "$APP_CONTENTS/PlugIns/imageformats"
ditto "$ENV_DIR/lib/qt6/plugins/imageformats/libqsvg.dylib" "$APP_CONTENTS/PlugIns/imageformats/libqsvg.dylib"

if [[ "${1:-run}" == "--verify" ]]; then
  /usr/bin/open -n "$APP_BUNDLE"
  sleep 3
  pgrep -x openvibe-acquisition-server >/dev/null
else
  /usr/bin/open -n "$APP_BUNDLE"
fi
