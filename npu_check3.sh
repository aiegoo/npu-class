#!/usr/bin/env bash
# After Stage 3: detect installed apps/models and run live Detection, Simple, Pose.
# Read-only except demo runtime cache/logs created by official programs.
set -u
pass=0; fail=0; manual=0
ok()   { printf '[PASS] %s\n' "$1"; pass=$((pass+1)); }
ng()   { printf '[FAIL] %s\n' "$1"; fail=$((fail+1)); }
info() { printf '[MANUAL] %s\n' "$1"; manual=$((manual+1)); }
echo '=== CHECK 3: Hailo Apps / HEF / class resources / 3 demos ==='
if [[ -f "$HOME/hailo-apps/setup_env.sh" ]]; then
  cd "$HOME/hailo-apps" || exit 1
  set +u
  if source ./setup_env.sh; then ok 'Hailo Apps environment enabled'; else ng 'Environment activation failed'; fi
  set -u
else ng '~/hailo-apps/setup_env.sh missing'; fi
if [[ -d "$HOME/hailo-apps/.git" ]]; then
  echo -n 'Hailo Apps commit: '
  git -C "$HOME/hailo-apps" rev-parse HEAD || ng 'Hailo Apps Git commit cannot be read'
else ng 'Hailo Apps Git checkout missing'; fi
pc_package=''
if pkg-config --exists hailo-apps-core; then
  pc_package='hailo-apps-core'
  ok 'pkg-config hailo-apps-core'
elif pkg-config --exists hailo-tappas-core; then
  pc_package='hailo-tappas-core'
  ok 'pkg-config hailo-tappas-core (valid installed alternative)'
else
  ng 'Neither hailo-apps-core nor hailo-tappas-core in pkg-config'
fi
if [[ -n "$pc_package" ]]; then
  post_dir=$(pkg-config --variable=tappas_postproc_lib_dir "$pc_package")
  if [[ -n "$post_dir" && -d "$post_dir" ]]; then
    ok "TAPPAS post-processing directory: $post_dir"
  else
    info "TAPPAS post-process directory must be checked: ${post_dir:-empty}"
  fi
fi
for cmd in hailo-detect hailo-detect-simple hailo-pose; do
  command -v "$cmd" >/dev/null 2>&1 && ok "$cmd available" || ng "$cmd missing"
done
for dir in 00_check 01_camera 02_inference 03_onnx 04_quantization 05_hailo 06_benchmark 07_project data/images data/videos models/pytorch models/onnx models/hailo results logs system_info; do
  [[ -d "$HOME/npu_course/$dir" ]] || ng "Directory missing: $dir"
done
[[ -d "$HOME/npu_course" ]] && ok 'Education folders present (missing subfolders shown above)'
for f in os.txt kernel.txt python.txt hailort.txt hailo_packages.txt; do
  [[ -s "$HOME/npu_course/system_info/$f" ]] && ok "System info: $f" || ng "Missing info: $f"
done
if [[ -s "$HOME/npu_course/system_info/hailo_apps_commit.txt" ]]; then
  ok 'Hailo Apps Git commit recorded'
else
  info 'Git commit info file missing on older installations; Git commit is shown above'
fi
[[ -L "$HOME/hailo-apps/resources" ]] && ok 'Hailo Apps resource symlink present' || info 'Resource path is not a symbolic link; inspect real resource directory'
if [[ -e "$HOME/hailo-apps/resources" ]]; then
  echo "Resource path: $(readlink -f "$HOME/hailo-apps/resources")"
fi
hef_list=()
for dir in "$HOME/hailo-apps/resources" /usr/local/hailo/resources; do
  if [[ -d "$dir" ]]; then
    while IFS= read -r -d '' file; do hef_list+=("$file"); done < <(find -L "$dir" -type f -name '*.hef' -print0 2>/dev/null)
  fi
done
if ((${#hef_list[@]}>0)); then
  printf 'HEF model examples:\n'; printf '%s\n' "${hef_list[@]:0:8}"
  ok "Found HEF files (${#hef_list[@]} hits; may include symlink duplicates)"
else ng 'HEF models not found in guide paths'; fi
run_demo() {
  local cmd="$1" rc
  printf "\n--- %s live demo (up to 20 seconds) ---\n" "$cmd"
  info 'Watch live video; detect bounding boxes/FPS or Pose skeleton/FPS'
  timeout -s INT -k 5s 20s "$cmd" --input rpi --show-fps
  rc=$?
  case "$rc" in
    0|124) info "$cmd ended; human visual check still required" ;;
    *) ng "$cmd error (exit code $rc)" ;;
  esac
}
if ((fail==0)); then
  run_demo hailo-detect
  run_demo hailo-detect-simple
  run_demo hailo-pose
else
  info 'Live demos skipped because one or more installation checks failed'
fi
printf '\nCHECK 3 SUMMARY: PASS=%d FAIL=%d MANUAL=%d\n' "$pass" "$fail" "$manual"
echo 'Manual: confirm Detection boxes, Simple Detection, Pose skeleton, FPS, actual image content.'
echo 'Classroom source images/videos: not supplied by Word guides; prepare separately.'
(( fail == 0 )) || exit 1
