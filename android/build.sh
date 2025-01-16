if [ "$1" = "copy" ]; then
  cp -r /app/* /target
elif [ "$1" = "build" ]; then
  cd /target && ./gradlew assembleDebug --no-daemon -q
elif [ "$1" = "test" ]; then
  cd /target && ./gradlew test --no-daemon -q
else
  echo "No target specified"
fi
