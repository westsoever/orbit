#!/usr/bin/env bash
# Shared helpers for assembling Orbit Access .app bundle resources.
# Used by run_orbit_access_app.sh and build-app-bundle.sh.

compile_orbit_app_icon_icns() {
  local appiconset="$1"
  local icns_out="$2"
  local iconset
  iconset="$(mktemp -d)/AppIcon.iconset"

  [[ -d "$appiconset" ]] || { echo "Missing AppIcon.appiconset: $appiconset" >&2; return 1; }

  mkdir -p "$iconset"
  cp "$appiconset/icon_16.png" "$iconset/icon_16x16.png"
  cp "$appiconset/icon_32.png" "$iconset/icon_16x16@2x.png"
  cp "$appiconset/icon_32.png" "$iconset/icon_32x32.png"
  cp "$appiconset/icon_64.png" "$iconset/icon_32x32@2x.png"
  cp "$appiconset/icon_128.png" "$iconset/icon_128x128.png"
  cp "$appiconset/icon_256.png" "$iconset/icon_128x128@2x.png"
  cp "$appiconset/icon_256.png" "$iconset/icon_256x256.png"
  cp "$appiconset/icon_512.png" "$iconset/icon_512x512.png"
  cp "$appiconset/icon_1024.png" "$iconset/icon_512x512@2x.png"

  iconutil -c icns -o "$icns_out" "$iconset"
}

find_orbit_access_resource_bundle() {
  local app_dir="$1"
  local swift_config="${2:-debug}"
  local bundle
  bundle="$(find "$app_dir/.build" -path "*/$swift_config/OrbitAccessApp_OrbitAccessApp.bundle" -type d 2>/dev/null | head -1)"
  if [[ -z "$bundle" ]]; then
    bundle="$(find "$app_dir/.build" -name "OrbitAccessApp_OrbitAccessApp.bundle" -type d 2>/dev/null | head -1)"
  fi
  [[ -n "$bundle" ]] || { echo "OrbitAccessApp resource bundle not found under $app_dir/.build" >&2; return 1; }
  printf '%s' "$bundle"
}

write_orbit_access_resource_bundle_plist() {
  local resource_bundle="$1"
  cat >"$resource_bundle/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.orbit.access.OrbitAccessApp.resources</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
EOF
}

install_orbit_access_bundle_resources() {
  local app_dir="$1"
  local bundle_root="$2"
  local swift_config="${3:-debug}"

  local resources="$bundle_root/Contents/Resources"
  local macos="$bundle_root/Contents/MacOS"
  local appiconset="$app_dir/Resources/Assets.xcassets/AppIcon.appiconset"
  local resource_bundle_dest="$macos/OrbitAccessApp_OrbitAccessApp.bundle"

  mkdir -p "$resources" "$macos"

  rm -rf "$resources/Assets.xcassets"
  compile_orbit_app_icon_icns "$appiconset" "$resources/AppIcon.icns"

  local resource_bundle
  resource_bundle="$(find_orbit_access_resource_bundle "$app_dir" "$swift_config")"
  rm -rf "$resource_bundle_dest"
  cp -R "$resource_bundle" "$resource_bundle_dest"
  write_orbit_access_resource_bundle_plist "$resource_bundle_dest"
}

codesign_orbit_access_bundle() {
  local bundle_root="$1"
  local executable_name="$2"
  local entitlements="$3"

  local executable="$bundle_root/Contents/MacOS/$executable_name"
  local resource_bundle="$bundle_root/Contents/MacOS/OrbitAccessApp_OrbitAccessApp.bundle"
  local lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

  [[ -f "$executable" ]] || { echo "Missing executable: $executable" >&2; return 1; }
  [[ -f "$entitlements" ]] || { echo "Missing entitlements: $entitlements" >&2; return 1; }

  xattr -cr "$bundle_root"
  rm -rf "$bundle_root/Contents/_CodeSignature"

  codesign --force --sign - "$resource_bundle"
  codesign --force --sign - --entitlements "$entitlements" "$executable"
  codesign --force --sign - "$bundle_root"

  if [[ -x "$lsregister" ]]; then
    "$lsregister" -f "$bundle_root" >/dev/null 2>&1 || true
  fi
}
