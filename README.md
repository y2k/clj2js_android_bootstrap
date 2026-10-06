# Android Docker bootstrap

Build Android APKs with `y2khub/cljdroid` and a project overlay.

## Build

From this repository, build the image locally to include release support; the
published `y2khub/cljdroid` image may not include it yet:

```sh
docker build -t y2khub/cljdroid .
```

Create the host mount directories, then build the bundled app (an empty overlay
is sufficient):

```sh
mkdir -p target output_apk
docker run --rm \
  -v "$PWD/target:/target:ro" \
  -v "$PWD/output_apk:/output_apk" \
  y2khub/cljdroid build
```

For a release:

```sh
docker run --rm \
  -v "$PWD/target:/target:ro" \
  -v "$PWD/output_apk:/output_apk" \
  y2khub/cljdroid build-release
```

| Command | Container outputs (also under host `output_apk/`) |
| --- | --- |
| `build` | `/output_apk/app-debug.apk` |
| `build-release` | `/output_apk/app-release-unsigned.apk`, `/output_apk/mapping.txt` |

Release enables R8 code optimization/obfuscation and resource shrinking. It is
unsigned, never silently signed with the debug key. Preserve `mapping.txt` with
the **exact APK from that build** for stack-trace retracing; subsequent builds
overwrite these output filenames.

## Project overlay and keep rules

Files in `/target` are copied over the bundled `/app` project before building.
Use matching relative paths, such as `target/app/src/main/AndroidManifest.xml`
or `target/app/src/main/java/...`. Supplied files replace their bundled versions,
including `app/proguard-rules.pro`.

For a class accessed through reflection, add a targeted keep rule (replace the
example class with your own):

```sh
mkdir -p target/app
cat >> target/app/proguard-rules.pro <<'EOF'
-keep class com.example.app.ReflectiveEntryPoint { *; }
EOF
```

## Sign a release externally

Use Android SDK Build Tools on the host. Set `BUILD_TOOLS` to their directory,
`KEYSTORE` to your release keystore path, and `KEY_ALIAS` to its signing alias.
Supply exported `KEYSTORE_PASSWORD` and `KEY_PASSWORD` through your shell or CI
secret environment, rather than embedding passwords in commands. Keep the
release key outside the image and overlay.

```sh
"${BUILD_TOOLS:?}/zipalign" -f -P 16 4 \
  output_apk/app-release-unsigned.apk output_apk/app-release-aligned.apk
"${BUILD_TOOLS:?}/apksigner" sign \
  --ks "${KEYSTORE:?}" --ks-key-alias "${KEY_ALIAS:?}" \
  --ks-pass env:KEYSTORE_PASSWORD --key-pass env:KEY_PASSWORD \
  --out output_apk/app-release.apk output_apk/app-release-aligned.apk
"${BUILD_TOOLS:?}/apksigner" verify --verbose output_apk/app-release.apk
```

Archive the signed `app-release.apk` together with that build's `mapping.txt`.

## Testing

`make test` requires Docker: it builds the local image, runs command contract
tests, and runs real debug/release smoke builds via `tests/smoke.sh`. The smoke
test signs its release APK with a temporary test key; normal `build-release`
outputs remain unsigned. Override the image/platform as needed, for example
`make test IMAGE=y2khub/cljdroid PLATFORM=linux/amd64`.

To also install and launch the signed smoke app on a connected device or emulator, put
Android platform-tools (`adb`) on the host's `PATH` and select its serial:

```sh
adb devices
SMOKE_DEVICE=YOUR_DEVICE_SERIAL make test
```

Replace `YOUR_DEVICE_SERIAL` with the serial from `adb devices`. The smoke app
(`im.y2k.cljdroid.smoke`) is removed afterward.
