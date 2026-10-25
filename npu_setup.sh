#!/usr/bin/env bash
# Raspberry Pi 5 + AI HAT+ Hailo-8L : Word-guide-based installation
# Usage: bash ~/npu_setup.sh 1 | 2 | 3
# Run as your normal Raspberry Pi user, NOT as 'sudo bash'.
# Deliberately no background services, auto-reboot, state machine or error recovery.
set -euo pipefail
if (( EUID == 0 )); then
  echo "ERROR: Run as a normal user: bash ~/npu_setup.sh {1|2|3} (not sudo bash)." >&2
  exit 1
fi

case "${1:-}" in
  1)
    echo '=== Step 1: OS + EEPROM update (Word Step1 40-42) ==='
    cat /etc/os-release
    uname -m
    sudo apt update
    sudo apt full-upgrade -y
    sudo rpi-eeprom-update -a
    echo 'Step 1 completed. Manually run: sudo reboot'
    ;;
  2)
    echo '=== Step 2: camera + Hailo system packages (Word Step1 44-48) ==='
    rpicam-hello --list-cameras
    rpicam-still -o "$HOME/test.jpg"
    ls -lh "$HOME/test.jpg"
    sudo apt install -y dkms
    sudo apt install -y hailo-all
    echo 'Step 2 completed. Manually run: sudo reboot'
    ;;
  3)
    echo '=== Step 3: Hailo Apps, models, education directories (Word Step1 50-60 + Step2) ==='
    hailortcli fw-control identify
    ls -l /dev/hailo*
    lspci | grep -i hailo

    sudo apt update
    sudo apt install -y git curl wget python3-full python3-pip python3-venv \
      build-essential cmake pkg-config ffmpeg gstreamer1.0-tools gir1.2-gtk-3.0

    if [[ ! -e "$HOME/hailo-apps" ]]; then
      git clone https://github.com/hailo-ai/hailo-apps.git "$HOME/hailo-apps"
    elif [[ ! -d "$HOME/hailo-apps/.git" ]]; then
      echo 'ERROR: ~/hailo-apps already exists but is not a Git repository.' >&2
      exit 1
    fi
    origin=$(git -C "$HOME/hailo-apps" remote get-url origin)
    case "$origin" in
      https://github.com/hailo-ai/hailo-apps|https://github.com/hailo-ai/hailo-apps.git|git@github.com:hailo-ai/hailo-apps.git)
        ;;
      *) echo "ERROR: Unexpected hailo-apps Git origin: $origin" >&2; exit 1 ;;
    esac
    cd "$HOME/hailo-apps"
    echo 'Hailo Apps commit:'
    git rev-parse HEAD
    # For deploying exactly the same Hailo Apps version to all 25 boards,
    # set HAILO_APPS_REF to the tested full Git commit SHA before running stage 3.
    if [[ -n "${HAILO_APPS_REF:-}" ]]; then
      if [[ ! "$HAILO_APPS_REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
        echo 'ERROR: HAILO_APPS_REF must be a 40-character Git commit SHA.' >&2
        exit 1
      fi
      git fetch origin "$HAILO_APPS_REF"
      git checkout --detach "$HAILO_APPS_REF"
      echo "Using selected Hailo Apps commit: $HAILO_APPS_REF"
    else
      echo 'NOTE: Hailo Apps Git commit is NOT pinned. Use the tested SHA for remaining boards.'
    fi
    ./install.sh
    # On some installs the 'hailo-apps-core' pkg-config alias is absent;
    # the documented Raspberry Pi package may instead be 'hailo-tappas-core'.
    if pkg-config --exists hailo-apps-core; then
      echo 'TAPPAS pkg-config: hailo-apps-core'
    elif pkg-config --exists hailo-tappas-core; then
      echo 'TAPPAS pkg-config: hailo-tappas-core (accepted alternative)'
    else
      echo 'WARNING: neither hailo-apps-core nor hailo-tappas-core is visible to pkg-config.' >&2
      echo 'Check install output and run the package verification commands before using apps.' >&2
    fi
    # setup_env.sh is provided by the official Hailo Apps repository.
    set +u
    source ./setup_env.sh
    set -u

    hailo-download-resources --list-models --arch hailo8l
    hailo-download-resources --group detection --arch hailo8l
    hailo-download-resources --group pose_estimation --arch hailo8l
    # Do NOT download the unsupported 'retrain' group (Step2 explicitly excludes it).

    mkdir -p "$HOME/npu_course"/{00_check,01_camera,02_inference,03_onnx,04_quantization,05_hailo,06_benchmark,07_project}
    mkdir -p "$HOME/npu_course"/data/{images,videos}
    mkdir -p "$HOME/npu_course"/models/{pytorch,onnx,hailo}
    mkdir -p "$HOME/npu_course"/{results,logs,system_info}

    cat /etc/os-release > "$HOME/npu_course/system_info/os.txt"
    uname -a > "$HOME/npu_course/system_info/kernel.txt"
    python3 --version > "$HOME/npu_course/system_info/python.txt" 2>&1
    hailortcli --version > "$HOME/npu_course/system_info/hailort.txt" 2>&1
    dpkg-query -W | grep -Ei 'hailo|tappas' > "$HOME/npu_course/system_info/hailo_packages.txt"
    git rev-parse HEAD > "$HOME/npu_course/system_info/hailo_apps_commit.txt"
    ls -lh "$HOME/npu_course/system_info"

    echo 'HEF models in available resource locations:'
    resource_found=0
    for dir in "$HOME/hailo-apps/resources" /usr/local/hailo/resources; do
      if [[ -d "$dir" ]]; then
        resource_found=1
        find -L "$dir" -type f -name '*.hef' -print 2>/dev/null || true
      fi
    done
    if (( resource_found == 0 )); then
      echo 'WARNING: No known Hailo resources directory found. Check model download results.' >&2
    fi
    echo 'Step 3 commands completed. Run: bash ~/npu_check3.sh'
    echo 'Note: classroom sample images/videos are NOT provided in the Word guides.'
    ;;
  *)
    echo 'Usage: bash ~/npu_setup.sh {1|2|3}' >&2
    exit 2
    ;;
esac
