#!/bin/bash
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
docker run --rm -i --platform "${PLATFORM:-linux/arm64}" \
  -v "$root/android/build.sh:/build-under-test.sh:ro" \
  --entrypoint /bin/bash "${IMAGE:-y2khub/cljdroid}" -s <<'TEST'
set -eu

prepare() {
  rm -rf /app/app/build /target /output_apk /gradle-call
  mkdir -p /target /output_apk /app/app/build/outputs/apk/{debug,release} \
    /app/app/build/outputs/mapping/release
  printf 'debug APK\n' > /app/app/build/outputs/apk/debug/app-debug.apk
  printf 'release APK\n' > /app/app/build/outputs/apk/release/app-release-unsigned.apk
  printf 'original -> renamed:\n' > /app/app/build/outputs/mapping/release/mapping.txt
  cat > /target/gradlew <<'GRADLE'
#!/bin/bash
printf '%s\n' "$*" > /gradle-call
exit "${GRADLE_STATUS:-0}"
GRADLE
  chmod +x /target/gradlew
}

expect_failure() {
  if bash /build-under-test.sh "$1"; then
    echo "FAIL: $1 unexpectedly succeeded" >&2
    exit 1
  fi
}

prepare
bash /build-under-test.sh build-release
test "$(cat /gradle-call)" = 'assembleRelease --no-daemon --no-watch-fs -q'
cmp /app/app/build/outputs/apk/release/app-release-unsigned.apk /output_apk/app-release-unsigned.apk
cmp /app/app/build/outputs/mapping/release/mapping.txt /output_apk/mapping.txt
test "$(ls -A /output_apk | wc -l)" -eq 2

prepare
bash /build-under-test.sh build
test "$(cat /gradle-call)" = 'assembleDebug --no-daemon --no-watch-fs -q'
cmp /app/app/build/outputs/apk/debug/app-debug.apk /output_apk/app-debug.apk
test "$(ls -A /output_apk | wc -l)" -eq 1

for command in build build-release; do
  prepare
  GRADLE_STATUS=17 expect_failure "$command"
  test -z "$(ls -A /output_apk)"

  prepare
  rm /app/app/build/outputs/apk/debug/app-debug.apk \
    /app/app/build/outputs/apk/release/app-release-unsigned.apk
  expect_failure "$command"

  prepare
  rm -rf /output_apk
  expect_failure "$command"
done

prepare
rm /app/app/build/outputs/mapping/release/mapping.txt
expect_failure build-release
test -z "$(ls -A /output_apk)"

prepare
: > /app/app/build/outputs/mapping/release/mapping.txt
expect_failure build-release
test -z "$(ls -A /output_apk)"

prepare
mkdir /output_apk/mapping.txt
expect_failure build-release

for command in build build-release; do
  for source_dir in java kotlin; do
    prepare
    mkdir -p /app/app/src/main/{java,kotlin} /target/app/src/main/"$source_dir"
    printf 'template\n' > /app/app/src/main/java/Template.java
    printf 'template\n' > /app/app/src/main/kotlin/Template.kt
    printf 'custom\n' > /target/app/src/main/"$source_dir"/Custom.kt
    bash /build-under-test.sh "$command"
    test ! -e /app/app/src/main/java/Template.java || { echo 'FAIL: template Java source survived replacement' >&2; exit 1; }
    test ! -e /app/app/src/main/kotlin/Template.kt
    cmp /target/app/src/main/"$source_dir"/Custom.kt /app/app/src/main/"$source_dir"/Custom.kt
  done
done

prepare
mkdir -p /app/app/src/main/java
printf 'template\n' > /app/app/src/main/java/Template.java
bash /build-under-test.sh build
test -s /app/app/src/main/java/Template.java

echo 'PASS: variant selection, artifact export, failure propagation, and source replacement'
TEST
