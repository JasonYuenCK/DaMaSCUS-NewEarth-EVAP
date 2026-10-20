#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" \
        && pwd -P
)"

PROJECT_ROOT="${PROJECT_ROOT:-$(
    git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null \
        || echo /lustre/project/kennyng/damascus-earth/DaMaSCUS-NewEarth-EVAP
)}"

BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
BUILD_JOBS="${BUILD_JOBS:-${SLURM_CPUS_ON_NODE:-2}}"

REBUILD=0

usage() {
    echo "Usage: compile.sh [--rebuild] [--build-dir DIR] [--jobs N]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild)
            REBUILD=1
            shift
            ;;
        --build-dir)
            BUILD_DIR="${2:?--build-dir requires a path}"
            shift 2
            ;;
        --jobs)
            BUILD_JOBS="${2:?--jobs requires a number}"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ "$BUILD_JOBS" =~ ^[1-9][0-9]*$ ]] || {
    echo "BUILD_JOBS must be a positive integer: $BUILD_JOBS" >&2
    exit 2
}

[[ "$BUILD_DIR" == /* ]] || {
    BUILD_DIR="$PROJECT_ROOT/$BUILD_DIR"
}

CMAKE_BIN="${CMAKE_BIN:-cmake}"

command -v "$CMAKE_BIN" >/dev/null 2>&1 || {
    echo "CMake not found: $CMAKE_BIN" >&2
    exit 2
}

echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "BUILD_DIR=$BUILD_DIR"
echo "BUILD_JOBS=$BUILD_JOBS"
echo "CMAKE_BIN=$(command -v "$CMAKE_BIN")"

CMAKE_OPTIONS=(
    -DCMAKE_BUILD_TYPE=Release
    -DBUILD_TESTING=OFF
    -DCODE_COVERAGE=OFF
)

if [[ -n "${LIBCONFIG_PREFIX:-}" ]]; then
    LIBCONFIG_LIBDIR="$LIBCONFIG_PREFIX/lib"

    [[ -f "$LIBCONFIG_LIBDIR/libconfig++.so" ]] || {
        LIBCONFIG_LIBDIR="$LIBCONFIG_PREFIX/lib64"
    }

    [[ -f "$LIBCONFIG_LIBDIR/libconfig++.so" ]] || {
        echo "libconfig++.so not found under LIBCONFIG_PREFIX" >&2
        exit 2
    }

    CMAKE_OPTIONS+=(
        "-DLIBCONFIG_INCLUDE_DIRs=$LIBCONFIG_PREFIX/include"
        "-DLIBCONFIGPP_LIBRARY=$LIBCONFIG_LIBDIR/libconfig++.so"
        "-DCMAKE_BUILD_RPATH=$LIBCONFIG_LIBDIR"
    )

    export LD_LIBRARY_PATH="$LIBCONFIG_LIBDIR:${LD_LIBRARY_PATH:-}"
fi

mkdir -p "$BUILD_DIR"

if [[ "$REBUILD" -eq 1 ]]; then
    echo "Cleaning previous build files..."
    rm -rf "$BUILD_DIR"/*
fi

cd "$BUILD_DIR"

echo "Configuring with old-style CMake syntax..."

"$CMAKE_BIN" "$PROJECT_ROOT" "${CMAKE_OPTIONS[@]}"

echo "Building with $BUILD_JOBS job(s)..."

"$CMAKE_BIN" --build . -- -j"$BUILD_JOBS"

echo "Executable: $BUILD_DIR/src/DaMaSCUS-SUN"
