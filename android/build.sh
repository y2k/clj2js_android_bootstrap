if [ "$1" = "copy" ]; then
  cp -r /app/* /target
elif [ "$1" = "build" ]; then
  cp -a /target/. /app/ && \
    cd /app && \
    ./gradlew assembleDebug --no-daemon --no-watch-fs -q && \
    find /app -path '*/build/outputs/apk/*.apk' -exec cp {} /output_apk/ \;
elif [ "$1" = "test" ]; then
  cd /target && ./gradlew test --no-daemon --no-watch-fs -q
else
  echo "No target specified"
fi
