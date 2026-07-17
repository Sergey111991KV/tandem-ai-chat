# TDLib native binaries (not committed for Linux/Windows until downloaded)

Place platform libraries here:

| Platform | File | Source |
|----------|------|--------|
| macOS | `macos/libtdjson.dylib` | `brew install tdlib` or copy from Cellar |
| Linux | `linux/libtdjson.so` | `./scripts/fetch-tdlib-prebuilt.sh linux` |
| Windows | `windows/tdjson.dll` (+ OpenSSL/zlib DLLs) | `./scripts/fetch-tdlib-prebuilt.sh windows` |

Run:

```bash
./scripts/setup-tdlib.sh
```

Or fetch prebuilts directly:

```bash
./scripts/fetch-tdlib-prebuilt.sh all
```

**Release builds** copy TDLib into the Flutter bundle (`lib/` on Linux, next to `.exe` on Windows). The app resolves the library from the executable directory first, then `desktop/native/tdlib/`, then system paths.

Prebuilt source: [ivk1800/td-json-client-prebuilt](https://github.com/ivk1800/td-json-client-prebuilt/releases) (override with `TDJSON_TAG` / `TDJSON_WIN_TAG` env vars).
