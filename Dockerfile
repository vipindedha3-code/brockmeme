# ROOT DIRECTORY OF GITHUB REPOSITORY: place this Dockerfile beside ARC_SIGNAL_RENDER_SOURCE.zip.
# This compiles the Android APK at Render Docker build time and serves it via a tiny Python web server.
FROM gradle:8.9-jdk17 AS apk-builder
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" /tmp/android-tools \
    && curl --fail --location --retry 3 --connect-timeout 30 \
       https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
       --output /tmp/android-commandline.zip \
    && unzip -q /tmp/android-commandline.zip -d /tmp/android-tools \
    && mv /tmp/android-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm -rf /tmp/android-tools /tmp/android-commandline.zip
# sdkmanager --licenses consumes yes; SIGPIPE from yes is harmless but install errors must fail.
RUN (yes | sdkmanager --sdk_root="${ANDROID_HOME}" --licenses >/dev/null 2>&1 || true) \
    && sdkmanager --sdk_root="${ANDROID_HOME}" "platform-tools" "platforms;android-35" "build-tools;35.0.0" \
    && test -s "${ANDROID_HOME}/platforms/android-35/android.jar"
# GitHub can store the original source ZIP without extracting it in the repo.
COPY ARC_SIGNAL_RENDER_SOURCE.zip /tmp/arc-source.zip
RUN mkdir -p /project && unzip -q /tmp/arc-source.zip -d /project && rm /tmp/arc-source.zip
WORKDIR /project/android
RUN gradle --no-daemon --console=plain :app:assembleDebug \
    && test -s app/build/outputs/apk/debug/app-debug.apk

FROM python:3.12-slim AS download-server
WORKDIR /app
COPY --from=apk-builder /project/android/app/build/outputs/apk/debug/app-debug.apk /app/ARC_SIGNAL_ARCUSDT.apk
COPY --from=apk-builder /project/server.py /app/server.py
ENV PYTHONUNBUFFERED=1 PORT=10000 APK_PATH=/app/ARC_SIGNAL_ARCUSDT.apk
EXPOSE 10000
CMD ["python", "-u", "/app/server.py"]
