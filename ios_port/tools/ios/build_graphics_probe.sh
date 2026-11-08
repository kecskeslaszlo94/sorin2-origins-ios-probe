#!/bin/bash
# Candidate ANGLE-only build gate. No app, rendering, signing or installation.
set -euo pipefail
export LC_ALL=C
ANGLE_PIN=686adbb2a39854ab687da009e534f6842a85f453
BUILD_PIN=868caa11a252da114e621f87042cc3dacb70ef2e
usage() {
    cat <<'HELP'
Usage: bash tools/ios/build_graphics_probe.sh simulator|device --angle-root PATH [--date YYYYMMDD]
       bash tools/ios/build_graphics_probe.sh --help

UNVERIFIED CANDIDATE: build only pinned ANGLE libEGL/libGLESv2 frameworks.
Requires macOS ARM64, system Xcode, a fully synced pinned standalone ANGLE
checkout under this ios_port workspace, and its pinned depot_tools on PATH.
No download, cleanup, signing, Apple login, app build or launch is performed
by this script. The separate manual CI proposal prepares the upstream tree.
Minimum free space at each platform start: 2 GiB (local attempt budget,
not an upstream size guarantee). Existing outputs are never overwritten.
HELP
}
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
if [ "$#" -eq 1 ] && { [ "$1" = --help ] || [ "$1" = -h ]; }; then usage; exit 0; fi
[ "$#" -ge 1 ] || { usage >&2; exit 2; }
platform=$1; shift
case "$platform" in simulator) sdk=iphonesimulator ;; device) sdk=iphoneos ;; *) die 'Target must be simulator or device.' ;; esac
angle_root=
build_date=$(date -u '+%Y%m%d')
while [ "$#" -gt 0 ]; do
    case "$1" in
        --angle-root) [ "$#" -ge 2 ] || die 'Missing --angle-root value.'; angle_root=$2; shift 2 ;;
        --date) [ "$#" -ge 2 ] || die 'Missing --date value.'; build_date=$2; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
case "$build_date" in ????????) case "$build_date" in *[!0-9]*) die 'Date must be eight digits.' ;; esac ;; *) die 'Date must be eight digits.' ;; esac
[ "$(uname -s)" = Darwin ] || die 'ANGLE iOS build requires macOS. No build was started.'
[ "$(uname -m)" = arm64 ] || die 'This candidate requires an ARM64 Mac.'
[ -n "$angle_root" ] && [ -d "$angle_root" ] || die 'Supply an existing --angle-root checkout.'
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/../.." && pwd -P)
angle_root=$(cd "$angle_root" && pwd -P)
case "$angle_root" in "$root/"*) ;; *) die 'ANGLE checkout must be inside this ios_port workspace.' ;; esac
for tool in git python3 xcrun xcodebuild gn autoninja gclient shasum tar tee df awk cmp; do
    command -v "$tool" >/dev/null 2>&1 || die "Missing existing prerequisite: $tool"
done
for ancestor in "$root/build" "$root/build/${build_date}_graphics_probe" "$angle_root/out"; do
    [ ! -L "$ancestor" ] || die "Symlinked output ancestor: $ancestor"
done
out="$root/build/${build_date}_graphics_probe/$platform"
gnout="$angle_root/out/iosprobe-${build_date}-$platform"
[ ! -e "$out" ] && [ ! -L "$out" ] && [ ! -e "$gnout" ] && [ ! -L "$gnout" ] || die 'Output already exists; preserve and review it before a separately dated attempt.'
mkdir -p "$root/build/${build_date}_graphics_probe"
mkdir "$out"
completed=no
on_exit() {
    status=$?
    if [ "$completed" != yes ]; then
        printf 'status=failed_or_incomplete\nexit_code=%s\nNo successful framework build or rendering is certified.\n' "$status" > "$out/BUILD_RECEIPT.txt"
    fi
}
trap on_exit EXIT
printf 'status=in_progress_candidate\n' > "$out/BUILD_RECEIPT.txt"
printf '# Recorded working directory: %s\n' "$angle_root" > "$out/COMMANDS.sh"
run() {
    printf '%q ' "$@" >> "$out/COMMANDS.sh"; printf '\n' >> "$out/COMMANDS.sh"
    "$@" 2>&1 | tee -a "$out/build.log"
}
cd "$angle_root"
run df -h /
free_bytes=$(df -Pk "$angle_root" | awk 'NR==2 {printf "%.0f", $4 * 1024}')
printf 'free_bytes_before=%s\nminimum_free_bytes=2147483648\n' "$free_bytes" > "$out/SPACE.txt"
[ "$free_bytes" -ge 2147483648 ] || die 'Less than the 2 GiB per-platform attempt budget remains; no GN/build started.'
[ "$(git rev-parse HEAD)" = "$ANGLE_PIN" ] || die 'ANGLE commit differs from the reviewed pin.'
[ "$(git -C build rev-parse HEAD)" = "$BUILD_PIN" ] || die 'Chromium build dependency differs from the reviewed DEPS pin.'
run git status --porcelain=v1 --untracked-files=all
run git diff --exit-code
run git diff --cached --exit-code
for input in .gn DEPS build/config/ios/ios_sdk.gni build/config/apple/mobile_config.gni build/toolchain/ios/BUILD.gn build/config/ios/rules.gni build/config/gclient_args.gni; do
    [ -f "$input" ] || die "Required standalone GN input is absent: $input"
done
[ -x third_party/cpython3/host/bin/python3 ] || die 'The .gn host Python dependency is missing; complete pinned gclient sync.'
[ -x third_party/llvm-build/Release+Asserts/bin/clang ] || die 'Pinned Chromium Clang is absent; complete reviewed upstream hooks.'
[ -x third_party/ninja/ninja ] || die 'Pinned Ninja dependency is missing.'
hash_inputs() {
    shasum -a 256 .gn DEPS BUILD.gn gni/angle.gni src/libANGLE/renderer/metal/BUILD.gn build/config/ios/ios_sdk.gni build/config/apple/mobile_config.gni build/toolchain/ios/BUILD.gn
    shasum -a 256 "$root/tools/ios/build_graphics_probe.sh"
}
hash_inputs > "$out/SOURCES.before.sha256"
run gclient revinfo
{
    sw_vers
    xcode-select -p
    xcodebuild -version
    xcrun --sdk "$sdk" --show-sdk-path
    xcrun --sdk "$sdk" --show-sdk-version
    third_party/llvm-build/Release+Asserts/bin/clang --version
    gn --version
    third_party/ninja/ninja --version
} 2>&1 | tee "$out/TOOLCHAIN.txt"
mkdir -p "$angle_root/out"
mkdir "$gnout"
cat > "$gnout/args.gn" <<ARGS
target_os = "ios"
target_cpu = "arm64"
target_environment = "$platform"
use_system_xcode = true
ios_enable_code_signing = false
ios_deployment_target = "18.0"
is_debug = false
is_component_build = false
angle_enable_metal = true
angle_enable_wgpu = false
angle_build_all = false
angle_build_tests = false
build_angle_deqp_tests = false
use_remoteexec = false
use_siso = false
ARGS
cp "$gnout/args.gn" "$out/args.gn"
run gn gen "$gnout"
run gn desc "$gnout" //:libEGL deps --all
run gn desc "$gnout" //:libGLESv2 deps --all
run autoninja -C "$gnout" libEGL libGLESv2
for library in libEGL libGLESv2; do
    bundle="$gnout/$library.framework"
    [ -f "$bundle/$library" ] && [ -f "$bundle/Info.plist" ] || die "Expected framework was not produced: $library"
    [ "$(xcrun lipo -archs "$bundle/$library")" = arm64 ] || die "Unexpected architecture: $library"
    [ ! -e "$bundle/_CodeSignature" ] && [ ! -e "$bundle/embedded.mobileprovision" ] || die 'Unexpected signing material in unsigned framework output.'
    run xcrun vtool -show-build "$bundle/$library"
    run xcrun otool -L "$bundle/$library"
done
hash_inputs > "$out/SOURCES.after.sha256"
cmp -s "$out/SOURCES.before.sha256" "$out/SOURCES.after.sha256" || die 'Reviewed build inputs changed during this attempt.'
mkdir "$out/artifacts"
run tar -czf "$out/artifacts/ANGLE-$platform-arm64-unsigned.tar.gz" -C "$gnout" libEGL.framework libGLESv2.framework
shasum -a 256 "$out/artifacts/ANGLE-$platform-arm64-unsigned.tar.gz" > "$out/ARTIFACTS.sha256"
run df -h /
printf 'status=framework_candidate_built\nangle_pin=%s\nchromium_build_pin=%s\nplatform=%s\narchitecture=arm64\nminimum_ios=18.0\nsigning=disabled\nNo app, ES3 render, framework embedding, sideload or device E2E verified.\nInspect vtool/otool output in build.log before reuse.\n' "$ANGLE_PIN" "$BUILD_PIN" "$platform" > "$out/BUILD_RECEIPT.txt"
completed=yes
printf 'Unsigned framework candidate only: %s\n' "$out/artifacts"
