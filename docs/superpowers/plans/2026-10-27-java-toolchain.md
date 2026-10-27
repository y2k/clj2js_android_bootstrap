# Java Toolchain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and execute Java lambdas with unnamed parameters without preview, then publish the verified Android image.

**Architecture:** Use one pinned Temurin JDK 25 installation for Gradle and javac. Target Java/Kotlin 22 and extend the existing smoke app to exercise an unnamed Java lambda at runtime.

**Tech Stack:** Docker, Debian 13, Temurin 25, Gradle 9.7.1, AGP 9.3.2, Java/Kotlin, Bash, adb.

**Spec:** `docs/superpowers/specs/2026-10-27-java-toolchain-design.md`

**User-requested revision (2026-10-28):** Install `openjdk-25-jdk` through the existing Debian 13 apt command. Official trixie package indexes confirm availability for both arm64 and amd64; neither backports nor a Debian upgrade is necessary. This supersedes the archive installation step below and the intermediate `COPY --from` approach. Repeat both architecture checks and physical-device execution. Leave changes uncommitted per `AGENTS.md`.

**Final revision verification:** `make test IMAGE=cljdroid-debian25-arm64 PLATFORM=linux/arm64` with `SMOKE_DEVICE=abf51f11` and `make test IMAGE=cljdroid-debian25-amd64 PLATFORM=linux/amd64` both exited 0. Debug/release, Groovy, command contracts, shrinking, signing, and negative-build checks passed on both architectures; the arm64-built release executed the unnamed lambda probe on the physical device. `git diff --check` passed. This apt-based revision remains uncommitted and unpublished; the earlier Docker Hub authorization blocker remains unresolved.

## Global Constraints

- Run Gradle and javac on JDK 25; Java source/target and Kotlin JVM target are 22.
- Preserve linux/amd64 and linux/arm64, existing build commands, and Android settings.
- No preview flags or source-generator changes.
- Verify the final image on a physical Android device before publication.

## Review Focus

- Architecture-specific JDK selection: both image architectures must build and execute their checks.
- Groovy overlays: `dependencies.gradle` must load under the same JVM as Gradle.
- Optimized release: the unnamed lambda result must survive R8 and be observed on device.
- Existing command failures: nonzero exits must still export no artifacts.
- Publication identity: report the remote multi-platform manifest digest, not a local image ID.

## Task 1: Upgrade toolchain and prove compatibility

**Files:** Modify `Dockerfile`, `android/app/build.gradle.kts`, `tests/smoke.sh`, `README.md`.

**Interfaces:** Preserve `build`, `build-release`, `IMAGE`, `PLATFORM`, and `SMOKE_DEVICE`. Extend the smoke runtime log to `release smoke: kept renamed unnamed-ok`.

- [ ] Extend `tests/smoke.sh` with `UnnamedProbe.java`: `public static String message()` applies `java.util.function.Function<Object, String> handler = (_) -> "unnamed-ok"` to a new object. Append the result in the existing Kotlin activity and require the full runtime log above.
- [ ] Generate an overlay `app/dependencies.gradle` containing `assert JavaVersion.current() == JavaVersion.VERSION_25` to exercise Groovy script loading and enforce the expected runtime.
- [ ] Confirm the regression evidence from the completed spike: the same Java probe failed `compileDebugJavaWithJavac` on JDK 21. Preserve that evidence in the implementation report; no repeat download is required.
- [ ] In `Dockerfile`, replace `openjdk-21-jdk` with Temurin 25.0.5+8 archives for Linux aarch64/x64 selected by `dpkg --print-architecture`. Obtain and pin each archive's official SHA-256, validate before extraction into `/opt/jdk25`, and set `JAVA_HOME` and `PATH` before running SDK tools. Retain Debian and existing SDK packages.
- [ ] Set `JavaVersion.VERSION_22` for both Java compatibility settings and `JvmTarget.JVM_22` for Kotlin in `android/app/build.gradle.kts`.
- [ ] Document the JDK and language target in `README.md`, including that overlays replacing the Gradle file control their own settings.
- [ ] Run `bash -n tests/smoke.sh tests/build-command.sh` and `git diff --check`; expect exit 0.
- [ ] Run `SMOKE_DEVICE=abf51f11 make test IMAGE=cljdroid-java25-arm64 PLATFORM=linux/arm64`; expect all command, artifact, signing, negative-build, and runtime checks to pass. Confirm the device is connected first.
- [ ] Run `make test IMAGE=cljdroid-java25-amd64 PLATFORM=linux/amd64`; expect the same container checks to pass, with device execution explicitly skipped.
- [ ] Review the diff against the spec and commit the tested implementation.

## Task 2: Publish and record digest

Task 1 verification (2026-10-28): both architecture-specific `make test` runs passed. The arm64 run also installed and executed the signed release probe on physical Android 13. Groovy overlay loading and the JDK 25 assertion passed. Self-review performed per `AGENTS.md`; no blocking findings. Installation retains pinned 25.0.5 archives: the investigated official Docker tag currently advertises 25.0.4.1.

**Files:** Update this plan with results; no new publication scripts.

**Interfaces:** Use existing `make publish`, publishing `y2khub/cljdroid` for linux/amd64 and linux/arm64.

- [ ] Run `SMOKE_DEVICE=abf51f11 make publish`; expect successful checks and registry push. If credentials or registry permissions block publication, report the blocker and retain the verified local images.
- [ ] Run `docker buildx imagetools inspect y2khub/cljdroid:latest`; require both platforms and record the remote manifest digest.
- [ ] Report `y2khub/cljdroid@sha256:...`, test evidence, and remaining limits (Argent itself was not built). Mark completed plan steps and commit the results.

Publication attempt (2026-10-28): `SMOKE_DEVICE=abf51f11 make publish` passed its tests and built the multi-platform image, but Docker Hub rejected the push with `insufficient_scope: authorization failed`. Publication is blocked on registry write access; no published digest is confirmed. Subsequent documentation changes remain uncommitted per the updated `AGENTS.md`.
