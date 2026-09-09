# SubDock

Native cross-platform runtime manager for Sub-Store. Phase 1 provides a Linux
runtime harness and a minimal backend dashboard.

## Linux development

Prepare the latest stable Backend, Frontend, and Linux runtime before building:

```sh
tool/prepare_backend.sh
tool/prepare_frontend.sh
tool/prepare_runtime.sh linux-x64
```

Then run the checks and Linux application through FVM:

```sh
fvm flutter analyze
fvm flutter test
fvm flutter run -d linux
```

Preparation downloads published Backend, Frontend, Node.js, and (where
available) Shoutrrr release assets; it does not clone or build the Frontend.
The Linux build is offline after preparation and always runs with its packaged
Node.js runtime selected by the Backend manifest. Set a `SUBDOCK_*_VERSION`
environment variable to pin a component for a release build. macOS is the
exception: Shoutrrr has no published macOS binary, so its helper is built from
the latest upstream source tag (or a pin) instead. Use
`tool/prepare_runtime.sh windows-x64`,
`darwin-arm64`, or `darwin-x64` to prepare the other desktop targets.
