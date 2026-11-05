#!/bin/bash
set -euo pipefail
mode="${1:?Usage: build-probe.sh uikit|swiftui OUTPUT_DIR}"
destination="${2:?Missing output directory}"
case "$mode" in
  uikit|swiftui) ;;
  *) echo "Unknown probe mode: $mode" >&2; exit 2 ;;
esac

root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
build="$RUNNER_TEMP/spectral-startup-probe-$mode"
app="$build/Payload/SpectralDarkroom.app"
mkdir -p "$app" "$destination"
cp "$root/ios/SpectralDarkroom/Info.plist" "$app/Info.plist"
/usr/libexec/PlistBuddy -c "Set :MinimumOSVersion 16.0" "$app/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.spectraldarkroom.mobile.ios16probe.$mode" "$app/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName 启动测试-$mode" "$app/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName StartupProbe-$mode" "$app/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.3" "$app/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 3" "$app/Info.plist"
# A boot test should not demand GPU features before testing its UI stack.
/usr/libexec/PlistBuddy -c "Delete :UIRequiredDeviceCapabilities" "$app/Info.plist" || true
xcrun actool --compile "$app" --platform iphoneos \
   --minimum-deployment-target 16.0 --target-device iphone \
   --app-icon AppIcon \
   --output-partial-info-plist "$build/app-icon-info.plist" \
   "$root/ios/SpectralDarkroom/Assets.xcassets" >/dev/null
/usr/libexec/PlistBuddy -c "Merge '$build/app-icon-info.plist'" "$app/Info.plist"
if [[ "$mode" == swiftui ]]; then
   src="$root/ios/StartupProbe/SwiftUIProbe.swift"
   extra=(-framework SwiftUI -framework UIKit)
else
   src="$root/ios/StartupProbe/UIKitProbe.swift"
   extra=(-framework UIKit)
fi
xcrun --sdk iphoneos swiftc -parse-as-library \
  -target arm64-apple-ios16.0 -sdk "$sdk" \
  "$src" "${extra[@]}" -o "$app/SpectralDarkroom"
codesign --force --sign - "$app"
(cd "$build" && /usr/bin/zip -qry "$destination/SpectralStartup-$mode-iOS16.ipa" Payload)
echo "$destination/SpectralStartup-$mode-iOS16.ipa"
