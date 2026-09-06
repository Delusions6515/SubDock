# SubDock

Native cross-platform runtime manager for Sub-Store. Phase 1 provides a Linux
runtime harness and a minimal backend dashboard.

## Linux development

Prepare a matching Sub-Store bundle and runtime manifest from upstream PR #641:

```sh
tool/prepare_backend.sh
```

Then run the checks and Linux application through FVM:

```sh
fvm flutter analyze
fvm flutter test
fvm flutter run -d linux
```

The Linux build downloads a checksum-verified Node.js 24.15.0 fallback. At
runtime, a system `node` is preferred when its major version matches the
generated `runtime-manifest.json`.
