# Java 22 language support in the Android image

## Intent

Resolve issue #17: generated Java lambda parameters named `_` must compile without preview flags, and the resulting APK must run on a physical Android device. Publish an updated image and report its digest for Argent.

## Goals and constraints

- Run Gradle and javac on JDK 25; set Java source/target compatibility and Kotlin JVM target to 22.
- Preserve the existing Android template, debug/release commands, and amd64/arm64 image support.
- Extend the existing smoke test with a Java lambda using `_`, invoke it from the activity, and verify its result on the device.
- Keep existing command, shrinking, signing, and failure-propagation checks passing.
- Do not use preview flags or change the source generator. Updating Argent itself is outside this repository's implementation scope.

## Approaches

1. **One JDK 25 for Gradle and compilation (selected).** Simplest configuration, with Java/Kotlin targeting 22. The user approved proceeding after the successful spike.
2. **Separate Gradle runtime and newer javac.** A fallback if Gradle cannot run on the newer JDK; adds installation and configuration complexity. The successful JDK 25 spike makes this unnecessary.

## Evidence

A temporary arm64 image using Temurin 25.0.5 and Java/Kotlin 22 passed existing command checks and extended debug/release smoke builds. The same Java lambda failed compilation on the original JDK 21 image. The signed release APK ran on physical device `abf51f11` (Android 13), logging `release smoke: kept renamed unnamed-ok`.

## Implementation and verification

Replace the Docker image's JDK 21 installation with a reproducible JDK 25 installation supporting both image architectures. Exact distribution packaging and checksum pinning are implementer decisions. Update the template's three language targets and extend `tests/smoke.sh` with the demonstrated Java probe and runtime assertion.

Verify Groovy `dependencies.gradle` processing under JDK 25 as well as existing checks. Run container checks for both architectures and repeat the physical-device smoke check against the final image. Publish through the existing workflow or `make publish`, then record the published digest. Publishing requires available registry credentials; report any blocker rather than implying publication succeeded.

## Outstanding limits

The spike did not build Argent itself or verify amd64. Those results must not be inferred from the successful arm64 smoke test.
