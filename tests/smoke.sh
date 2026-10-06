#!/bin/bash
set -euo pipefail

image=${IMAGE:-y2khub/cljdroid}
docker=(docker run --rm --platform "${PLATFORM:-linux/arm64}")
work=$(mktemp -d "${TMPDIR:-/tmp}/cljdroid-smoke.XXXXXX")
cache=$(docker volume create)
installed=false
cleanup() {
  if [ "$installed" = true ]; then
    adb -s "$SMOKE_DEVICE" uninstall im.y2k.cljdroid.smoke >/dev/null
  fi
  docker volume rm "$cache" >/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/target/app/src/main/java/im/y2k/fixme" \
  "$work/target/app/src/main/res/values" "$work/debug" "$work/release" "$work/failed"
"${docker[@]}" --entrypoint cat "$image" /app/app/build.gradle.kts |
  sed 's/applicationId = "im.y2k.fixme"/applicationId = "im.y2k.cljdroid.smoke"/' \
    > "$work/target/app/build.gradle.kts"
cat > "$work/target/app/src/main/java/im/y2k/fixme/MainActivity.kt" <<'KOTLIN'
package im.y2k.fixme

class MainActivity : android.app.Activity() {
    override fun onCreate(state: android.os.Bundle?) {
        super.onCreate(state)
        val kept = Class.forName("im.y2k.fixme.KeptProbe")
        val message = kept.getMethod("message").invoke(kept.getDeclaredConstructor().newInstance())
        setContentView(android.widget.TextView(this).apply {
            text = "release smoke: $message ${ObfuscationProbe().message()}"
            android.util.Log.i("CljdroidSmoke", text.toString())
        })
    }
}

class KeptProbe { fun message() = "kept" }
class ObfuscationProbe { fun message() = "renamed" }
KOTLIN
cat > "$work/target/app/proguard-rules.pro" <<'RULES'
-keep class im.y2k.fixme.KeptProbe { *; }
-keep,allowobfuscation class im.y2k.fixme.ObfuscationProbe { *; }
RULES
cat > "$work/target/app/src/main/res/values/smoke.xml" <<'XML'
<resources><string name="smoke_unused">This resource should be removed.</string></resources>
XML

build() {
  "${docker[@]}" -v "$cache:/root/.gradle" \
    -v "$work/target:/target:ro" -v "$work/$2:/output_apk" "$image" "$1"
}
build build debug
build build-release release
test "$(ls -A "$work/debug")" = app-debug.apk
test "$(ls -A "$work/release")" = "$(printf 'app-release-unsigned.apk\nmapping.txt')"

"${docker[@]}" -i -v "$work:/artifacts" --entrypoint /bin/bash "$image" -s <<'VERIFY'
set -euo pipefail
tools=$ANDROID_SDK_ROOT/build-tools/37.0.0
debug=/artifacts/debug/app-debug.apk
release=/artifacts/release/app-release-unsigned.apk
mapping=/artifacts/release/mapping.txt
test -s "$debug"
test -s "$release"
test -s "$mapping"
grep -q '^im.y2k.fixme.KeptProbe -> im.y2k.fixme.KeptProbe:' "$mapping"
awk '$1 == "im.y2k.fixme.ObfuscationProbe" && $2 == "->" && $3 != "im.y2k.fixme.ObfuscationProbe:" { renamed = 1 } END { exit !renamed }' "$mapping"
test "$(apkanalyzer manifest debuggable "$debug")" = true
test "$(apkanalyzer manifest debuggable "$release")" = false
"$tools/aapt2" dump resources "$debug" > /artifacts/debug-resources.txt
"$tools/aapt2" dump resources "$release" > /artifacts/release-resources.txt
grep -q 'string/smoke_unused' /artifacts/debug-resources.txt
if grep -q 'string/smoke_unused' /artifacts/release-resources.txt; then
  echo 'FAIL: unused resource survived release shrinking' >&2
  exit 1
fi
"$tools/apksigner" verify "$debug"
if "$tools/apksigner" verify "$release" > /artifacts/unsigned.log 2>&1; then
  echo 'FAIL: release APK was already signed' >&2
  exit 1
fi
keytool -genkeypair -keystore /artifacts/smoke.jks -storepass smoke-password \
  -keypass smoke-password -alias smoke -keyalg RSA -keysize 2048 -validity 1 -dname CN=Smoke
"$tools/zipalign" -P 16 -f 4 "$release" /artifacts/aligned.apk
"$tools/apksigner" sign --ks /artifacts/smoke.jks --ks-key-alias smoke \
  --ks-pass pass:smoke-password --key-pass pass:smoke-password \
  --out /artifacts/app-release.apk /artifacts/aligned.apk
"$tools/apksigner" verify /artifacts/app-release.apk
echo 'PASS: APKs, mapping, keep rules, resource shrinking, and external signing'
VERIFY

printf 'deliberately invalid Kotlin\n' > "$work/target/app/src/main/java/im/y2k/fixme/Broken.kt"
if build build-release failed > "$work/failed-build.log" 2>&1; then
  echo 'FAIL: invalid source produced a successful container exit' >&2
  exit 1
fi
grep -q 'Broken.kt' "$work/failed-build.log"
test -z "$(ls -A "$work/failed")"
echo 'PASS: real compilation failure returns non-zero and exports nothing'

if [ -n "${SMOKE_DEVICE:-}" ]; then
  adb -s "$SMOKE_DEVICE" install "$work/app-release.apk"
  installed=true
  adb -s "$SMOKE_DEVICE" shell am start -W \
    -n im.y2k.cljdroid.smoke/im.y2k.fixme.MainActivity > "$work/launch.txt"
  grep -q 'Status: ok' "$work/launch.txt"
  pid=$(adb -s "$SMOKE_DEVICE" shell pidof im.y2k.cljdroid.smoke)
  adb -s "$SMOKE_DEVICE" logcat -d --pid="$pid" -s CljdroidSmoke:I '*:S' > "$work/runtime.log"
  grep -q 'release smoke: kept renamed' "$work/runtime.log"
  echo 'PASS: signed release installed, launched, and executed the runtime probes'
else
  echo 'SKIP: install/launch check (set SMOKE_DEVICE to a connected device serial)'
fi
