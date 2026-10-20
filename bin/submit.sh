#!/usr/bin/env bash
#SBATCH --job-name=damascus-sun
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --output=/lustre/project/kennyng/damascus-earth/DaMaSCUS-NewEarth-EVAP/bin/job-%x-%j.out
#SBATCH --error=/lustre/project/kennyng/damascus-earth/DaMaSCUS-NewEarth-EVAP/bin/job-%x-%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=1155234222@link.cuhk.edu.hk
#run ./bin/submit.sh ./bin/config.cfg

set -Eeuo pipefail

# 硬编码项目根目录，不依赖 git / BASH_SOURCE（SLURM spool 会破坏它们）
PROJECT_ROOT="${PROJECT_ROOT:-/lustre/project/kennyng/damascus-earth/DaMaSCUS-NewEarth-EVAP}"
export PROJECT_ROOT
SCRIPT_DIR="$PROJECT_ROOT/bin"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
ORIGINAL_ARGS=("$@")
REBUILD=0

usage() {
    echo "Usage: submit.sh [--rebuild] [--build-dir DIR] <config.cfg>"
    echo "Run directly to submit, or use: sbatch [Slurm options] bin/submit.sh ..."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild) REBUILD=1; shift ;;
        --build-dir) BUILD_DIR="${2:?--build-dir requires a path}"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        --*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *) break ;;
    esac
done

[[ $# -eq 1 ]] || { usage >&2; exit 2; }
CONFIG_FILE="$1"

if [[ -z "${SLURM_JOB_ID:-}" ]]; then
    command -v sbatch >/dev/null 2>&1 || {
        echo "sbatch is unavailable; run this script on a Slurm login node." >&2
        exit 2
    }
    exec sbatch "$SCRIPT_DIR/submit.sh" "${ORIGINAL_ARGS[@]}"
fi

# ---- Entering the Slurm job: project-local runtime environment ----
# Use exactly the same environment verified during the successful build.
source "$PROJECT_ROOT/env_chpc.sh"

# All relative paths such as Output/... are now rooted in this repository.
cd "$PROJECT_ROOT"

[[ "$BUILD_DIR" == /* ]] || BUILD_DIR="$PROJECT_ROOT/$BUILD_DIR"
[[ "$CONFIG_FILE" == /* ]] || CONFIG_FILE="${SLURM_SUBMIT_DIR:-$PWD}/$CONFIG_FILE"
[[ -f "$CONFIG_FILE" ]] || {
    echo "Configuration file not found: $CONFIG_FILE" >&2
    exit 2
}

BINARY="$BUILD_DIR/src/DaMaSCUS-SUN"

# Normal simulation jobs must not modify the shared build directory.
# A rebuild is performed only when --rebuild was explicitly requested.
if [[ "$REBUILD" -eq 1 ]]; then
    echo '===== Explicit rebuild requested ====='

    module load cmake/3.12.0-rc2

    "$SCRIPT_DIR/compile.sh" \
        --rebuild \
        --build-dir "$BUILD_DIR"

    echo '===== Explicit rebuild completed ====='
fi

[[ -x "$BINARY" ]] || {
    echo "ERROR: prebuilt executable is unavailable: $BINARY" >&2
    echo 'Rebuild separately before submitting simulation jobs.' >&2
    exit 2
}

export OMP_NUM_THREADS="${OMP_NUM_THREADS:-${SLURM_CPUS_PER_TASK:-1}}"

echo '===== Running prebuilt executable ====='
echo "Executable: $BINARY"
echo "Config:     $CONFIG_FILE"

mpirun --mca btl ^openib "$BINARY" "$CONFIG_FILE"

echo '===== Simulation completed ====='
