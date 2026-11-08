#!/bin/bash
# Compatible with the Bash 3.2 shipped by macOS. No signing credentials are used.
set -euo pipefail
export LC_ALL=C

usage() {
    cat <<'HELP'
Usage: bash tools/ios/build_probe.sh simulator|device [--date YYYYMMDD]
       bash tools/ios/build_probe.sh --help

Requires macOS, full Xcode, the selected iOS SDK and CMake >= 3.24.
Builds Release / arm64 / minimum iOS 15.0, without code signing.
Output: build/<UTC-date>_minimal_probe/{simulator,device}/
An existing output directory is never reused or overwritten.

simulator: unsigned .app for an ARM64 iOS Simulator; no IPA.
device:    unsigned .app and unsigned IPA for later re-signing.
           The unsigned IPA cannot be installed directly.

No upload, signing, Apple login, installation or simulator launch occurs.
HELP
}
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

if [ "$#" -eq 1 ] && { [ "$1" = '--help' ] || [ "$1" = '-h' ]; }; then
    usage
    exit 0
fi
[ "$#" -ge 1 ] || { usage >&2; exit 2; }
platform=$1
shift
case "$platform" in
    simulator) sdk=iphonesimulator ;;
    device) sdk=iphoneos ;;
    *) die 'Target must be simulator or device. Use --help.' ;;
esac
build_date=$(date -u '+%Y%m%d')
if [ "$#" -gt 0 ]; then
    [ "$#" -eq 2 ] && [ "$1" = '--date' ] || die 'Only --date YYYYMMDD is accepted after the target.'
    build_date=$2
fi
case "$build_date" in
    ????????) case "$build_date" in *[!0-9]*) die 'Date must contain eight digits.' ;; esac ;;
    *) die 'Date must contain eight digits.' ;;
esac
[ "$(uname -s)" = 'Darwin' ] || die 'An actual iOS build requires macOS with full Xcode; this host is not macOS. No build was started.'

for tool in cmake xcode-select xcodebuild xcrun shasum ditto plutil sw_vers find sort cmp tee; do
    command -v "$tool" >/dev/null 2>&1 || die "Required tool is missing: $tool"
done
developer_dir=${DEVELOPER_DIR:-$(xcode-select -p)}
[ -d "$developer_dir/Platforms/iPhoneOS.platform" ] || die 'The active developer directory must be full Xcode, not Command Line Tools.'
export DEVELOPER_DIR="$developer_dir"
xcode_version=$(xcodebuild -version)
sdk_path=$(xcrun --sdk "$sdk" --show-sdk-path)
sdk_version=$(xcrun --sdk "$sdk" --show-sdk-version)
[ -d "$sdk_path" ] || die "Selected SDK directory does not exist: $sdk_path"
clang_path=$(xcrun --sdk "$sdk" --find clang)
clang_version=$("$clang_path" --version)
case "$clang_version" in *'Apple clang'*) ;; *) die 'The active compiler must be Apple Clang.' ;; esac
cmake_version=$(cmake --version)
cmake_numeric=$(printf '%s\n' "$cmake_version" | awk 'NR == 1 {print $3}')
cmake_major=${cmake_numeric%%.*}
cmake_rest=${cmake_numeric#*.}
cmake_minor=${cmake_rest%%.*}
case "$cmake_major:$cmake_minor" in *[!0-9:]*|:*) die 'Cannot read CMake version.' ;; esac
if [ "$cmake_major" -lt 3 ] || { [ "$cmake_major" -eq 3 ] && [ "$cmake_minor" -lt 24 ]; }; then
    die 'CMake 3.24 or newer is required.'
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/../.." && pwd -P)
source_dir="$root/source/ios/probe"
inputs=(source/ios/probe/main.mm source/ios/probe/Info.plist.in source/ios/probe/CMakeLists.txt source/ios/probe/README.md tools/ios/build_probe.sh)
for input in "${inputs[@]}"; do
    [ -f "$root/$input" ] && [ ! -L "$root/$input" ] || die "Missing or symlinked input: $input"
done
# Refuse symlinked output ancestors; mkdir of the final path acts as the lock.
for ancestor in "$root/build" "$root/build/${build_date}_minimal_probe"; do
    [ ! -L "$ancestor" ] || die "Output ancestor is a symlink: $ancestor"
done
out="$root/build/${build_date}_minimal_probe/$platform"
[ ! -e "$out" ] && [ ! -L "$out" ] || die "Output already exists. Preserve/review it; choose a new --date for a separate run: $out"
mkdir -p "$root/build/${build_date}_minimal_probe"
mkdir "$out" || die 'Cannot exclusively create output directory; another build may own it.'

completed=no
on_exit() {
    exit_code=$?
    if [ "$completed" != yes ]; then
        printf 'status=failed\nexit_code=%s\ncompleted_at_utc=%s\nNo successful iOS build is certified. Review build.log and partial files.\n' "$exit_code" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$out/BUILD_RECEIPT.txt"
    fi
}
trap on_exit EXIT
printf 'status=in_progress\n' > "$out/BUILD_RECEIPT.txt"
hash_inputs() { (cd "$root" && shasum -a 256 "${inputs[@]}"); }
hash_inputs > "$out/SOURCES.before.sha256"
{
    printf 'started_at_utc=%s\nplatform=%s\narchitecture=arm64\nminimum_ios=15.0\nconfiguration=Release\nsigning=disabled\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$platform"
    printf 'source_root=%s\noutput=%s\ndeveloper_dir=%s\nsdk=%s\nsdk_path=%s\nsdk_version=%s\n' "$root" "$out" "$developer_dir" "$sdk" "$sdk_path" "$sdk_version"
    sw_vers
    uname -m
    printf '%s\n%s\n%s\n' "$xcode_version" "$cmake_version" "$clang_version"
} > "$out/TOOLCHAIN.txt"
printf '#!/bin/bash\n# Recorded commands; review paths before any manual replay.\n' > "$out/COMMANDS.sh"
run() {
    printf '%q ' "$@" >> "$out/COMMANDS.sh"
    printf '\n' >> "$out/COMMANDS.sh"
    "$@" 2>&1 | tee -a "$out/build.log"
}
run cmake -S "$source_dir" -B "$out/cmake" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS "-DCMAKE_OSX_SYSROOT=$sdk" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
run cmake --build "$out/cmake" --config Release --target OriginsIOSProbe -- \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 'CODE_SIGN_IDENTITY='

app="$out/cmake/Release-$sdk/OriginsIOSProbe.app"
[ -d "$app" ] && [ -f "$app/OriginsIOSProbe" ] || die 'Expected app bundle/executable was not produced.'
run plutil -lint "$app/Info.plist"
[ "$(plutil -extract CFBundleIdentifier raw -o - "$app/Info.plist")" = 'eu.sorin2.origins.iosprobe' ] || die 'Unexpected bundle identifier.'
[ "$(plutil -extract MinimumOSVersion raw -o - "$app/Info.plist")" = '15.0' ] || die 'Unexpected rendered minimum iOS version.'
[ "$(xcrun lipo -archs "$app/OriginsIOSProbe")" = 'arm64' ] || die 'Expected only ARM64 in the app executable.'
[ ! -e "$app/_CodeSignature" ] && [ ! -e "$app/embedded.mobileprovision" ] || die 'Unexpected signing or provisioning material in unsigned output.'
mkdir "$out/artifacts"
run ditto "$app" "$out/artifacts/OriginsIOSProbe.app"
if [ "$platform" = device ]; then
    mkdir -p "$out/package/Payload"
    run ditto "$out/artifacts/OriginsIOSProbe.app" "$out/package/Payload/OriginsIOSProbe.app"
    run ditto -c -k --sequesterRsrc --keepParent "$out/package/Payload" "$out/artifacts/OriginsIOSProbe-unsigned.ipa"
fi
hash_inputs > "$out/SOURCES.after.sha256"
cmp -s "$out/SOURCES.before.sha256" "$out/SOURCES.after.sha256" || die 'Build inputs changed during the run; this output is not a verified candidate.'
(
    cd "$out/artifacts"
    find . -type f -print | sort | while IFS= read -r artifact; do
        shasum -a 256 "$artifact"
    done
) > "$out/ARTIFACTS.sha256"
[ -s "$out/ARTIFACTS.sha256" ] || die 'Artifact hash inventory is empty.'
{
    printf 'status=build_and_package_succeeded\ncompleted_at_utc=%s\nplatform=%s\narchitecture=arm64\nsigning=unsigned\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$platform"
    printf 'source_hashes=SOURCES.before.sha256\nsource_unchanged=SOURCES.after.sha256 (byte-identical)\nartifact_hashes=ARTIFACTS.sha256\ntoolchain=TOOLCHAIN.txt\nfull_commands=COMMANDS.sh\nlog=build.log\n'
    printf 'NOT VERIFIED: launch, touch, lifecycle, simulator E2E, physical iPhone E2E, signing, installation, AltStore compatibility.\n'
    if [ "$platform" = device ]; then
        printf 'IPA is unsigned and not directly installable; a separate authorized re-signing step is required.\n'
    fi
} > "$out/BUILD_RECEIPT.txt"
completed=yes
printf 'Build/package completed without signing: %s\nReceipt: %s/BUILD_RECEIPT.txt\n' "$out/artifacts" "$out"
