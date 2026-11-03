# Spectral Darkroom for iPhone (unofficial prototype)

This iOS 18+ prototype uses the SpektraLab C++/Metal engine and its original
film and paper profiles. It imports images from the system Photos picker, renders a preview with
selectable film and paper, and exports a Display P3 JPEG through the system share sheet. It has a new SwiftUI
phone interface and a different name; it is not the full desktop application.
Imported images are currently limited to a 4096-pixel long edge.

Build on an Apple silicon Mac with Xcode and the iOS SDK:

```sh
./ios/build-iphone.sh /path/to/output-directory
```

The script creates `SpectralDarkroom-unsigned.ipa`. It has an ad-hoc signature,
which **does not permit direct installation on an iPhone**. Sign the app using
your own Apple development team and an appropriate provisioning profile before
installing. Do not share credentials or private signing keys. If Xcode's Metal
Toolchain is not available, the iOS build bundles MSL source files for runtime
compilation. This runtime path must be checked on a real device.

Licenses: app and engine GPL-3.0-or-later, film profiles and LUTs CC BY-SA 4.0,
metal-cpp Apache-2.0. Keep the notices when redistributing source or binaries.
