#!/bin/bash
# macOS Bash 3.2 compatible. Upstream-only diagnostic; never an iOS Python PASS.
set -euo pipefail
export LC_ALL=C
export GIT_TERMINAL_PROMPT=0

usage() {
    cat <<'HELP'
Usage: bash tools/ios/build_python_probe.sh --run-id NEW_IDENTIFIER
       bash tools/ios/build_python_probe.sh --help

Requires macOS, full Xcode, Apple Clang, both iOS SDKs, Git and Make.
Measures device and simulator ABIs before the stock CPython host/target probe.
Exit 2: expected Darwin cross-configure blocker. Exit 1: another failure.
Exit 0: diagnostic completed; still NOT an iOS interpreter validation.
No packages, patches, signing, publishing or CI runs are initiated by this script.
HELP
}
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run_id=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help) usage; exit 0 ;;
        --run-id)
            [ "$#" -ge 2 ] || die '--run-id requires a value.'
            [ -z "$run_id" ] || die '--run-id may be supplied only once.'
            run_id=$2; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
case "$run_id" in ''|*[!A-Za-z0-9._-]*|.|..) die 'Supply a safe, new run identifier.' ;; esac
[ "${#run_id}" -le 80 ] || die 'Run identifier is too long.'
[ "$(uname -s)" = Darwin ] || die 'This diagnostic requires macOS; no build was attempted.'

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(cd "$script_dir/../.." && pwd -P)
inputs=(
    source/ios/python_probe/abi_probe.c
    source/ios/python_probe/UPSTREAM.json
    source/ios/python_probe/README.md
    source/ios/python_probe/NOTICE
    tools/ios/build_python_probe.sh
)
# The local template is mirrored to the public repository's one canonical
# workflow path. Hash the actual fixed-path workflow without duplicating it.
if [ -f "$root/tools/ios/github-actions-python-probe.yml" ]; then
    inputs+=(tools/ios/github-actions-python-probe.yml)
elif [ -f "$root/../.github/workflows/ios-python-probe.yml" ]; then
    inputs+=(../.github/workflows/ios-python-probe.yml)
else
    die 'Neither the local template nor the canonical public workflow exists.'
fi
for input in "${inputs[@]}"; do
    [ -f "$root/$input" ] && [ ! -L "$root/$input" ] || die "Missing or symlinked input: $input"
done
for ancestor in "$root/build" "$root/build/python_probe"; do
    [ ! -L "$ancestor" ] || die "Output ancestor is a symlink: $ancestor"
done
out="$root/build/python_probe/$run_id"
[ ! -e "$out" ] && [ ! -L "$out" ] || die "Output already exists; preserve it and choose a new --run-id: $out"
mkdir -p "$root/build/python_probe"
mkdir "$out" || die 'Cannot exclusively create the output directory.'
mkdir -p "$out/evidence/logs" "$out/evidence/abi" "$out/host" "$out/iphoneos"
evidence="$out/evidence"
printf '# Recorded diagnostic commands; not an automatic retry script.\n' > "$evidence/COMMANDS.sh"
printf 'step\tstarted_utc\tfinished_utc\texit_code\n' > "$evidence/COMMAND_STATUS.tsv"

pin=8d21aa21f2cbc6d50aab3f420bb23be1d081dac4
expected_tree=8133f47ade097d9fa33954a0211ea16b9088bfd3
upstream_repo=https://github.com/python/cpython.git
started_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
abi_device=not-run
abi_simulator=not-run
upstream_status=not-run
host_status=not-run
target_status=not-run
source_status=not-checked
overall=incomplete
last_rc=0
device_sdk=
device_clang=
device_ready=no
host_python=
curated_logs=()

# This wrapper always returns 0 so independent diagnostics can continue.
# The actual command status is retained explicitly and examined by each caller.
run_capture() {
    local step=$1 cwd=$2 begin end command_rc
    shift 2
    begin=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    {
        printf '(cd %q && ' "$cwd"
        printf '%q ' "$@"
        printf ')\n'
    } >> "$evidence/COMMANDS.sh"
    if (cd "$cwd" && "$@") > "$evidence/logs/$step.log" 2>&1; then
        command_rc=0
    else
        command_rc=$?
    fi
    end=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    printf '%s\t%s\t%s\t%s\n' "$step" "$begin" "$end" "$command_rc" >> "$evidence/COMMAND_STATUS.tsv"
    curated_logs+=("logs/$step.log")
    last_rc=$command_rc
    printf '%s: exit=%s\n' "$step" "$command_rc"
    return 0
}

finalize() {
    local incoming_rc=$1 final_rc=$1 file destination
    trap - EXIT HUP INT TERM
    set +e
    if [ "$overall" = incomplete ]; then
        overall=interrupted-or-unexpected-script-failure
        [ "$final_rc" -ne 0 ] || final_rc=1
    fi

    run_capture inputs-after "$root" shasum -a 256 "${inputs[@]}"
    if [ "$last_rc" -eq 0 ]; then
        cp "$evidence/logs/inputs-after.log" "$evidence/INPUTS.after.sha256"
        run_capture inputs-unchanged "$root" cmp "$evidence/INPUTS.before.sha256" "$evidence/INPUTS.after.sha256"
        if [ "$last_rc" -eq 0 ]; then source_status=unchanged; else source_status=changed; fi
    else
        source_status=hash-check-failed
    fi
    if [ "$source_status" != unchanged ]; then
        overall=input-drift-or-hash-failure
        final_rc=1
    fi

    if [ "$upstream_status" = verified ]; then
        run_capture upstream-final-head "$root" git -C "$out/upstream" rev-parse HEAD
        if [ "$last_rc" -ne 0 ] || [ "$(cat "$evidence/logs/upstream-final-head.log")" != "$pin" ]; then
            upstream_status=changed; overall=upstream-drift; final_rc=1
        fi
        run_capture upstream-final-status "$root" git -C "$out/upstream" status --porcelain --untracked-files=all
        if [ "$last_rc" -ne 0 ] || [ -s "$evidence/logs/upstream-final-status.log" ]; then
            upstream_status=changed; overall=upstream-drift; final_rc=1
        fi
    fi

    # Only these configure diagnostics may cross into the curated payload.
    for file in host/config.log host/pyconfig.h iphoneos/config.log iphoneos/pyconfig.h; do
        if [ -f "$out/$file" ] && [ ! -L "$out/$file" ]; then
            destination=${file//\//-}
            cp "$out/$file" "$evidence/$destination" || final_rc=1
        fi
    done
    if [ -f "$out/upstream/LICENSE" ] && [ ! -L "$out/upstream/LICENSE" ] && [ "$upstream_status" = verified ]; then
        cp "$out/upstream/LICENSE" "$evidence/CPYTHON_LICENSE.txt" || final_rc=1
    fi

    printf 'status=%s\nexit_code=%s\nabi_device=%s\nabi_simulator=%s\nupstream=%s\nhost=%s\ntarget_configure=%s\nios_interpreter_pass=false\n' \
        "$overall" "$final_rc" "$abi_device" "$abi_simulator" "$upstream_status" "$host_status" "$target_status" > "$evidence/STATUS.txt"
    cat > "$evidence/RECEIPT.json" <<JSON
{
  "schema_version": 1,
  "started_utc": "$started_utc",
  "finished_utc": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "run_id": "$run_id",
  "status": "$overall",
  "exit_code": $final_rc,
  "entry_exit_code": $incoming_rc,
  "cpython_commit": "$pin",
  "cpython_tree": "$expected_tree",
  "upstream": "$upstream_status",
  "inputs": "$source_status",
  "abi_device": "$abi_device",
  "abi_simulator": "$abi_simulator",
  "host_bootstrap": "$host_status",
  "iphoneos_configure": "$target_status",
  "ios_interpreter_pass": false,
  "game_or_android_sources": false,
  "patches_applied": false,
  "signing_or_device_run": false
}
JSON

    # A newly created publish directory is an allowlisted copy, never a wildcard
    # upload of the checkout, host interpreter, library or working directory.
    mkdir "$out/publish" || exit 1
    local payload=(
        RECEIPT.json STATUS.txt COMMANDS.sh COMMAND_STATUS.tsv
        INPUTS.before.sha256 INPUTS.after.sha256 CPYTHON_LICENSE.txt
        host-config.log host-pyconfig.h iphoneos-config.log iphoneos-pyconfig.h
        abi/device-predefined.txt abi/device.ll
        abi/simulator-predefined.txt abi/simulator.ll
    )
    payload+=("${curated_logs[@]}")
    local published=()
    for file in "${payload[@]}"; do
        if [ -f "$evidence/$file" ] && [ ! -L "$evidence/$file" ]; then
            mkdir -p "$out/publish/$(dirname "$file")" || exit 1
            cp "$evidence/$file" "$out/publish/$file" || exit 1
            published+=("$file")
        fi
    done
    [ "${#published[@]}" -gt 0 ] || exit 1
    (cd "$out/publish" && shasum -a 256 "${published[@]}" > ARTIFACTS.sha256) || exit 1
    printf 'Diagnostic status: %s; exit=%s; iOS interpreter PASS=false\n' "$overall" "$final_rc"
    printf 'Curated evidence: %s/publish\n' "$out"
    exit "$final_rc"
}
trap 'finalize $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

run_capture inputs-before "$root" shasum -a 256 "${inputs[@]}"
[ "$last_rc" -eq 0 ] || die 'Cannot hash the standalone inputs.'
cp "$evidence/logs/inputs-before.log" "$evidence/INPUTS.before.sha256"
run_capture pin-json-commit "$root" plutil -extract commit raw -o - "$root/source/ios/python_probe/UPSTREAM.json"
[ "$last_rc" -eq 0 ] && [ "$(cat "$evidence/logs/pin-json-commit.log")" = "$pin" ] || die 'UPSTREAM.json commit differs from the reviewed pin.'
run_capture pin-json-tree "$root" plutil -extract tree raw -o - "$root/source/ios/python_probe/UPSTREAM.json"
[ "$last_rc" -eq 0 ] && [ "$(cat "$evidence/logs/pin-json-tree.log")" = "$expected_tree" ] || die 'UPSTREAM.json tree differs from the reviewed pin.'

run_capture macos "$root" sw_vers
run_capture machine "$root" uname -m
run_capture xcode-select "$root" xcode-select -p
run_capture xcode "$root" xcodebuild -version
run_capture git-version "$root" git --version
run_capture make-version "$root" make --version

# Both target measurements are attempted before any network/host build action.
for platform in device simulator; do
    if [ "$platform" = device ]; then
        sdk=iphoneos; triple=arm64-apple-ios15.0
    else
        sdk=iphonesimulator; triple=arm64-apple-ios15.0-simulator
    fi
    ready=yes
    run_capture "$platform-sdk-version" "$root" xcrun --sdk "$sdk" --show-sdk-version
    [ "$last_rc" -eq 0 ] || ready=no
    run_capture "$platform-sdk-path" "$root" xcrun --sdk "$sdk" --show-sdk-path
    sdk_path=$(cat "$evidence/logs/$platform-sdk-path.log")
    [ "$last_rc" -eq 0 ] && [ -d "$sdk_path" ] || ready=no
    run_capture "$platform-clang-path" "$root" xcrun --sdk "$sdk" --find clang
    clang_path=$(cat "$evidence/logs/$platform-clang-path.log")
    [ "$last_rc" -eq 0 ] && [ -x "$clang_path" ] || ready=no
    if [ "$ready" = yes ]; then
        run_capture "$platform-clang-version" "$root" "$clang_path" --version
        [ "$last_rc" -eq 0 ] || ready=no
        grep -q 'Apple clang' "$evidence/logs/$platform-clang-version.log" || ready=no
    fi
    if [ "$ready" = yes ]; then
        if [ "$platform" = device ]; then
            device_sdk=$sdk_path; device_clang=$clang_path; device_ready=yes
        fi
        run_capture "$platform-predefined" "$root" "$clang_path" -target "$triple" -isysroot "$sdk_path" -dM -E -x c /dev/null
        macros_rc=$last_rc
        if [ "$macros_rc" -eq 0 ]; then
            cp "$evidence/logs/$platform-predefined.log" "$evidence/abi/$platform-predefined.txt"
        fi
        run_capture "$platform-abi-ir" "$root" "$clang_path" -target "$triple" -isysroot "$sdk_path" -std=c11 -S -emit-llvm \
            "$root/source/ios/python_probe/abi_probe.c" -o "$evidence/abi/$platform.ll"
        if [ "$macros_rc" -eq 0 ] && [ "$last_rc" -eq 0 ] && [ -s "$evidence/abi/$platform.ll" ]; then
            abi_status=measured-not-executed
        else
            abi_status=failed
        fi
    else
        abi_status=toolchain-unavailable
    fi
    if [ "$platform" = device ]; then abi_device=$abi_status; else abi_simulator=$abi_status; fi
done

run_capture upstream-init "$root" git init "$out/upstream"
if [ "$last_rc" -eq 0 ]; then
    run_capture upstream-remote "$root" git -C "$out/upstream" remote add origin "$upstream_repo"
fi
if [ "$last_rc" -eq 0 ]; then
    run_capture upstream-fetch "$root" git -c credential.helper= -C "$out/upstream" fetch --depth=1 origin "$pin"
fi
if [ "$last_rc" -eq 0 ]; then
    run_capture upstream-checkout "$root" git -C "$out/upstream" checkout --detach FETCH_HEAD
fi
if [ "$last_rc" -eq 0 ]; then
    run_capture upstream-head "$root" git -C "$out/upstream" rev-parse HEAD
    if [ "$last_rc" -eq 0 ] && [ "$(cat "$evidence/logs/upstream-head.log")" = "$pin" ]; then
        run_capture upstream-tree "$root" git -C "$out/upstream" rev-parse 'HEAD^{tree}'
        if [ "$last_rc" -eq 0 ] && [ "$(cat "$evidence/logs/upstream-tree.log")" = "$expected_tree" ]; then
            upstream_status=verified
        fi
    fi
fi

if [ "$upstream_status" = verified ]; then
    run_capture upstream-source-objects "$root" git -C "$out/upstream" ls-tree -r --full-tree HEAD
    [ "$last_rc" -eq 0 ] || upstream_status=inventory-failed
else
    upstream_status=fetch-or-pin-failed
fi

if [ "$upstream_status" = verified ]; then
    src="$out/upstream"
    run_capture host-sdk-path "$root" xcrun --sdk macosx --show-sdk-path
    host_sdk=$(cat "$evidence/logs/host-sdk-path.log")
    host_ready=yes
    [ "$last_rc" -eq 0 ] && [ -d "$host_sdk" ] || host_ready=no
    run_capture host-clang-path "$root" xcrun --sdk macosx --find clang
    host_clang=$(cat "$evidence/logs/host-clang-path.log")
    [ "$last_rc" -eq 0 ] && [ -x "$host_clang" ] || host_ready=no
    if [ "$host_ready" = yes ]; then
        run_capture host-clang-version "$root" "$host_clang" --version
        [ "$last_rc" -eq 0 ] || host_ready=no
        grep -q 'Apple clang' "$evidence/logs/host-clang-version.log" || host_ready=no
    fi
    if [ "$host_ready" = yes ]; then
        run_capture host-configure "$out/host" env CC="$host_clang" CFLAGS="-isysroot $host_sdk" LDFLAGS="-isysroot $host_sdk" \
            "$src/configure" --without-ensurepip --disable-shared
        if [ "$last_rc" -eq 0 ]; then
            run_capture host-make "$out/host" make -j2 python Parser/pgen
            if [ "$last_rc" -eq 0 ]; then
                host_python="$out/host/python"
                run_capture host-smoke "$out/host" env -u PYTHONHOME -u PYTHONSTARTUP PYTHONPATH="$src/Lib" \
                    "$host_python" -B -S -c 'import sys, codecs, encodings; assert sys.version_info[:3] == (2,7,18); assert codecs.decode("\xc5\x91", "utf-8") == u"\u0151"; print(sys.version); print("host-codecs-ok")'
                if [ "$last_rc" -eq 0 ]; then host_status=bootstrapped-host-only; else host_status=smoke-failed; fi
            else
                host_status=make-failed
            fi
        else
            host_status=configure-failed
        fi
    else
        host_status=toolchain-unavailable
    fi
fi

if [ "$host_status" = bootstrapped-host-only ] && [ "$device_ready" = yes ]; then
    run_capture build-triplet "$root" sh "$src/config.guess"
    if [ "$last_rc" -eq 0 ]; then
        build_triplet=$(cat "$evidence/logs/build-triplet.log")
        run_capture iphoneos-configure "$out/iphoneos" env PYTHON_FOR_BUILD="$host_python" PYTHONPATH="$src/Lib" \
            CC="$device_clang" CFLAGS="-target arm64-apple-ios15.0 -isysroot $device_sdk" \
            LDFLAGS="-target arm64-apple-ios15.0 -isysroot $device_sdk" \
            "$src/configure" --build="$build_triplet" --host=aarch64-apple-darwin --without-ensurepip --disable-shared \
            ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no
        if [ "$last_rc" -eq 0 ]; then
            target_status=configured-not-built-or-executed
        elif grep -q 'cross build not supported for aarch64-apple-darwin' "$evidence/logs/iphoneos-configure.log"; then
            target_status=expected-blocked-darwin-cross-configure
        else
            target_status=unexpected-configure-failure
        fi
    else
        target_status=build-triplet-failed
    fi
else
    target_status=not-attempted-prerequisite-failed
fi

if [ "$abi_device" != measured-not-executed ] || [ "$abi_simulator" != measured-not-executed ]; then
    overall=abi-measurement-failed
    exit 1
elif [ "$upstream_status" != verified ]; then
    overall=upstream-fetch-or-pin-failed
    exit 1
elif [ "$host_status" != bootstrapped-host-only ]; then
    overall=host-bootstrap-failed
    exit 1
elif [ "$target_status" = expected-blocked-darwin-cross-configure ]; then
    overall=expected-blocked
    exit 2
elif [ "$target_status" = configured-not-built-or-executed ]; then
    overall=diagnostic-complete-target-configured
    exit 0
else
    overall=unexpected-target-configure-failure
    exit 1
fi
