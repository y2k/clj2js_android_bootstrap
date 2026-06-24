FROM debian:13-slim

RUN apt-get update && apt-get install -y --no-install-recommends qemu-user-static binfmt-support \
    && if [ "$(dpkg --print-architecture)" != "amd64" ]; then dpkg --add-architecture amd64; fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libc6:amd64 \
        libstdc++6:amd64 \
        openjdk-21-jdk \
        unzip \
        wget \
        zlib1g:amd64 \
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
        "build-tools;37.0.0"

### ### ### ### ### ### ### ### ### ### ###

WORKDIR /app

COPY android .

ENTRYPOINT [ "/bin/bash", "build.sh" ]
