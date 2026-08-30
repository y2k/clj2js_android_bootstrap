FROM debian:13-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        openjdk-21-jdk \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools

RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-15641748_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm cmdline-tools.zip

RUN yes | sdkmanager --licenses && \
    sdkmanager \
        "platform-tools" \
        "platforms;android-34" \
        "platforms;android-35" \
        "platforms;android-36" \
        "platforms;android-37.0" \
        "build-tools;34.0.0" \
        "build-tools;35.0.0" \
        "build-tools;36.0.0" \
        "build-tools;37.0.0" \
    && if [ "$(dpkg --print-architecture)" = "arm64" ]; then \
        release="https://github.com/Commit451/android-arm-build-tools/releases/download/platform-tools-36.0.0"; \
        cd "$ANDROID_SDK_ROOT/build-tools/36.0.0"; \
        for tool in aapt2 aidl zipalign split-select; do \
            wget -q "$release/$tool" -O "$tool"; \
            chmod +x "$tool"; \
        done; \
        wget -q "$release/SHA256SUMS" -O SHA256SUMS; \
        sha256sum -c SHA256SUMS; \
        rm SHA256SUMS; \
    fi

RUN mkdir -p /root/.android
COPY android/debug.keystore /root/.android/debug.keystore

### ### ### ### ### ### ### ### ### ### ###

WORKDIR /app

COPY android .

ENTRYPOINT [ "/bin/bash", "build.sh" ]
