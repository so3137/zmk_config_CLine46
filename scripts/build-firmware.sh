#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-zmkfirmware/zmk-build-arm:stable}"
WORKDIR_IN_CONTAINER="/workspaces/zmk-config"
OUTPUT_DIR="${OUTPUT_DIR:-firmware/local}"
UPDATE_WEST="${UPDATE_WEST:-1}"
CLEAN="${CLEAN:-0}"
COMMON_CMAKE_ARGS=(
  -DBOARD_ROOT="$WORKDIR_IN_CONTAINER"
  -DZMK_CONFIG="$WORKDIR_IN_CONTAINER/config"
)

usage() {
  cat <<'EOF'
Usage: scripts/build-firmware.sh [options]

Build CLine46 ZMK firmware in Docker.

Options:
  --skip-update     Skip west update
  --clean           Remove build directories before building
  --output DIR      Copy UF2 files to DIR (default: firmware/local)
  -h, --help        Show this help

Environment:
  IMAGE             Docker image to use
                   (default: zmkfirmware/zmk-build-arm:stable)
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-update)
      UPDATE_WEST=0
      ;;
    --clean)
      CLEAN=1
      ;;
    --output)
      if [ "$#" -lt 2 ]; then
        echo "error: --output requires a directory" >&2
        exit 1
      fi
      OUTPUT_DIR="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ "${CLINE46_IN_DOCKER:-0}" != "1" ]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker command was not found" >&2
    echo "Install Docker Desktop or OrbStack, then try again." >&2
    exit 1
  fi

  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  DOCKER_TTY_FLAG=""
  if [ -t 0 ]; then
    DOCKER_TTY_FLAG="-it"
  fi

  exec docker run --rm $DOCKER_TTY_FLAG \
    -e CLINE46_IN_DOCKER=1 \
    -e OUTPUT_DIR="$OUTPUT_DIR" \
    -e UPDATE_WEST="$UPDATE_WEST" \
    -e CLEAN="$CLEAN" \
    -v "$REPO_ROOT:$WORKDIR_IN_CONTAINER" \
    -w "$WORKDIR_IN_CONTAINER" \
    "$IMAGE" \
    bash "$WORKDIR_IN_CONTAINER/scripts/build-firmware.sh"
fi

echo "==> Building CLine46 firmware"
echo "    output: $OUTPUT_DIR"

echo "==> Configuring Git safe directories"
git config --global --add safe.directory "$WORKDIR_IN_CONTAINER"
while IFS= read -r git_dir; do
  git config --global --add safe.directory "$(dirname "$git_dir")"
done < <(find "$WORKDIR_IN_CONTAINER" -type d -name .git -prune)

if [ ! -d .west ]; then
  echo "==> Initializing west workspace"
  west init -l config
fi

if [ "$UPDATE_WEST" = "1" ]; then
  echo "==> Updating west projects"
  west update
else
  echo "==> Skipping west update"
fi

echo "==> Exporting Zephyr CMake package"
west zephyr-export

if [ "$CLEAN" = "1" ]; then
  echo "==> Removing build directories"
  rm -rf build/CLine46_R build/CLine46_L build/settings_reset
fi

echo "==> Building right half"
west build -d build/CLine46_R \
  -s zmk/app \
  -b seeeduino_xiao_ble \
  -S studio-rpc-usb-uart \
  -- \
  "${COMMON_CMAKE_ARGS[@]}" \
  -DSHIELD="CLine46_R rgbled_adapter"

echo "==> Building left half"
west build -d build/CLine46_L \
  -s zmk/app \
  -b seeeduino_xiao_ble \
  -- \
  "${COMMON_CMAKE_ARGS[@]}" \
  -DSHIELD="CLine46_L rgbled_adapter"

echo "==> Building settings_reset"
west build -d build/settings_reset \
  -s zmk/app \
  -b seeeduino_xiao_ble \
  -- \
  "${COMMON_CMAKE_ARGS[@]}" \
  -DSHIELD="settings_reset"

echo "==> Copying UF2 files"
mkdir -p "$OUTPUT_DIR"

cp build/CLine46_R/zephyr/zmk.uf2 \
  "$OUTPUT_DIR/CLine46_R-rgbled_adapter-seeeduino_xiao_ble-zmk.uf2"

cp build/CLine46_L/zephyr/zmk.uf2 \
  "$OUTPUT_DIR/CLine46_L-rgbled_adapter-seeeduino_xiao_ble-zmk.uf2"

cp build/settings_reset/zephyr/zmk.uf2 \
  "$OUTPUT_DIR/settings_reset-seeeduino_xiao_ble-zmk.uf2"

echo "==> Done"
ls -lh "$OUTPUT_DIR"/*.uf2
