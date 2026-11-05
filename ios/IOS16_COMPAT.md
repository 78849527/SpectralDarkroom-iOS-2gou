# SpectralDarkroom iOS 16 compatibility branch

Source: `IsBEICHEN/SpectralDarkroom-iOS`. This branch targets **iOS 16.0** and retains the same C++/Metal film model and export pipeline.

Changes:
- Compile C++ and Swift for arm64 iOS 16; package `MinimumOSVersion=16.0`.
- Use the single-argument SwiftUI `.onChange` API; replace the iOS 26-only glass button styles with system materials that work on iOS 16.
- Compile runtime Metal shaders with MSL 3.0 and `fastMathEnabled=false` instead of the iOS 18+ `mathMode` selectors.
- Add a GitHub Actions cloud IPA build. The resulting unsigned/ad-hoc signed IPA is intended for authorized sideloading such as TrollStore; installation and rendering still require device testing.

**Test order:** install → open app → import JPEG/HEIC → select film and paper → render → export → compare original vs output colors. Only then test RAW.

This fork is experimental. `main` remains the unmodified upstream source (except for a workflow registration file, if needed). Do not claim iOS 16 device compatibility without testing.
