if [ "$1" = "copy" ]; then
  cp -r /app/* /target
elif [ "$1" = "build" ]; then
  cd /target && ./gradlew assembleDebug --no-daemon
else
  echo "No target specified"
fi
