set -e

if [ "$1" = "copy" ]; then
  cp -r /app/* /target
elif [ "$1" = "build" ] || [ "$1" = "build-release" ]; then
  variant=debug
  apk=app-debug.apk
  if [ "$1" = "build-release" ]; then
    variant=release
    apk=app-release-unsigned.apk
  fi
  cp -a /target/. /app/
  cd /app
  ./gradlew "assemble${variant^}" --no-daemon --no-watch-fs -q
  test -s "app/build/outputs/apk/$variant/$apk"
  if [ "$variant" = "release" ]; then
    test -s app/build/outputs/mapping/release/mapping.txt
    cp app/build/outputs/mapping/release/mapping.txt /output_apk/
  fi
  cp "app/build/outputs/apk/$variant/$apk" /output_apk/
elif [ "$1" = "test" ]; then
  cd /target && ./gradlew test --no-daemon --no-watch-fs -q
else
  echo "No target specified"
fi
