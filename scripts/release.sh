#!/bin/zsh
# Builds a universal Release of Potion, signs it with the team's cloud-managed Developer ID certificate, has Apple
# notarize it, and packages the stapled app as build/Potion.dmg. Uses the Apple account signed in to Xcode, so no
# local certificate or notary password is needed.
set -euo pipefail
cd "$(dirname "$0")/.."
team=${POTION_TEAM:-72P6RBSM9C}
work=build/release
rm -rf "$work" build/Potion.dmg
mkdir -p "$work"
xcodegen generate
xcodebuild -project Potion.xcodeproj -scheme Potion -configuration Release -archivePath "$work/Potion.xcarchive" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates archive
cat > "$work/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>destination</key><string>upload</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>$team</string>
</dict></plist>
PLIST
# Uploads the signed app to Apple's notary service.
xcodebuild -exportArchive -archivePath "$work/Potion.xcarchive" -exportOptionsPlist "$work/export.plist" \
  -exportPath "$work/upload" -allowProvisioningUpdates
# Exporting the notarized app fails until Apple approves it, usually within a few minutes.
for attempt in {1..60}; do
  xcodebuild -exportNotarizedApp -archivePath "$work/Potion.xcarchive" -exportPath "$work/notarized" && break
  (( attempt == 60 )) && { print -u2 "Notarization did not finish in 15 minutes."; exit 1; }
  sleep 15
done
app="$work/notarized/Potion.app"
xcrun stapler validate "$app"
spctl --assess --type exec -vv "$app"
mkdir "$work/dmg"
ditto "$app" "$work/dmg/Potion.app"
ln -s /Applications "$work/dmg/Applications"
hdiutil create -volname Potion -srcfolder "$work/dmg" -format UDZO -ov build/Potion.dmg
printf '\nNotarized: %s/build/Potion.dmg\n' "$PWD"
