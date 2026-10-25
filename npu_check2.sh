#!/usr/bin/env bash
# Camera/NPU check after SECOND reboot; displays live demos for human review.
# Does not install any packages or change system configuration.
set -u
pass=0; fail=0; manual=0
ok()   { printf '[PASS] %s\n' "$1"; pass=$((pass+1)); }
ng()   { printf '[FAIL] %s\n' "$1"; fail=$((fail+1)); }
info() { printf '[MANUAL] %s\n' "$1"; manual=$((manual+1)); }
echo '=== CHECK 2: Camera Module 3 + Hailo-8L + official demos ==='
if command -v rpicam-hello >/dev/null 2>&1; then
  cam=$(rpicam-hello --list-cameras 2>&1); rc=$?
  printf 'Camera list:\n%s\n' "$cam"
  if ((rc==0)) && grep -qi imx708 <<< "$cam"; then ok 'Camera Module 3 detected (imx708)'; else ng 'Camera imx708 not detected'; fi
else ng 'rpicam-hello missing'; fi
if [[ -s "$HOME/test.jpg" ]]; then
  ok "Photo exists: $HOME/test.jpg"
  if command -v xdg-open >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    echo 'Opening test.jpg in image viewer; close it after checking.'
    xdg-open "$HOME/test.jpg" >/dev/null 2>&1 || info 'Open ~/test.jpg manually if image viewer does not launch'
    read -r -p 'Close the photo viewer; press Enter to continue: ' _ || true
  fi
  info 'Visually check test.jpg content (not only file existence)'
else ng 'Photo file ~/test.jpg missing or empty'; fi
if command -v hailortcli >/dev/null 2>&1; then
  chip=$(hailortcli fw-control identify 2>&1); rc=$?
  printf 'NPU: %s\n' "$chip"
  if ((rc==0)) && grep -Eqi 'HAILO8L|HAILO-8L' <<< "$chip"; then ok 'HAILO8L detected'; else ng 'NPU identification failed'; fi
else ng 'hailortcli missing'; fi
[[ -e /dev/hailo0 ]] && ok '/dev/hailo0 present' || ng '/dev/hailo0 missing'
if command -v lspci >/dev/null 2>&1 && lspci | grep -qi hailo; then ok 'PCIe Hailo detected'; else ng 'PCIe Hailo not detected'; fi

preview() {
  local label="$1" cmd="$2" optional="$3"; shift 3
  printf "\n--- %s (up to 15 seconds) ---\n" "$label"
  info 'Watch camera window: correct picture and detection overlays; press Ctrl+C if needed'
  timeout -s INT -k 5s 15s "$cmd" "$@"
  local rc=$?
  case "$rc" in
    0|124) info "$label finished (screen judgment required)" ;;
    *) if [[ "$optional" == optional ]]; then info "$label optional demo could not run (code $rc)"; else ng "$label failed (exit code $rc)"; fi ;;
  esac
}
if (( fail == 0 )); then
  preview 'Camera preview' rpicam-hello required -t 5000
  detect_json='/usr/share/rpi-camera-assets/hailo_yolov8_inference.json'
  if [[ -f "$detect_json" ]]; then
    preview 'Official YOLO Detection' rpicam-hello required -t 0 --post-process-file "$detect_json"
  else ng "Official YOLO config missing: $detect_json"; fi
  pose_json='/usr/share/rpi-camera-assets/hailo_yolov8_pose.json'
  if [[ -f "$pose_json" ]]; then
    preview 'Optional official Pose' rpicam-hello optional -t 0 --post-process-file "$pose_json"
  else info "Optional official Pose config not present: $pose_json (Step 1 marks it optional)"; fi
else info 'Demo tests skipped because hardware check failed'; fi
printf '\nCHECK 2 SUMMARY: PASS=%d FAIL=%d MANUAL=%d\n' "$pass" "$fail" "$manual"
(( fail == 0 )) || exit 1
