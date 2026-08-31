# OpenViBE macOS Port

Build and packaging scripts for the OpenViBE 3.2.0 macOS port. This project
keeps the reproducible macOS configuration and launcher scripts; downloaded
upstream sources, dependency environments, build trees, and generated `.app`
bundles are intentionally excluded from Git.

## License

OpenViBE and the derived port are distributed under the GNU Affero General
Public License, version 3 (AGPLv3). Preserve the upstream copyright notices
and `COPYING` files when obtaining and distributing the OpenViBE source. Any
distributed binaries must be accompanied by the corresponding source and
these build/port changes. Third-party dependencies may have additional
licenses; review their notices before redistribution.

## Local build

1. Obtain the matching OpenViBE 3.2.0 upstream source trees and place them in
   `work/` as described by `script/build_and_run.sh`.
2. Install the macOS build dependencies (CMake, GTK2 compatibility/runtime,
   Homebrew libraries, and a C++ toolchain).
3. Run `script/build_and_run.sh` from this repository.

The script builds Designer, packages its framework/resources into an app
bundle, installs the icon and launcher, and signs the bundle ad hoc for local
execution. The resulting applications are written to `outputs/`.

## Included scripts

- `script/build_and_run.sh` — configure, build, package, and launch Designer
- `script/package_acquisition_server.sh` — package Acquisition Server
- `script/Info.plist` and launcher sources — app metadata and launchers

## Contributors

- **Arda Arslanbakan** — project direction, macOS testing, and release
  integration.
- **OpenAI Codex** — coding assistance, porting work, build automation, and
  troubleshooting support.
- **OpenViBE contributors** — upstream project and original application.

This is a personal macOS port and is not an official OpenViBE release.
