#!/usr/bin/env bash
# Read-only checks after FIRST reboot. No package installation.
set -u
pass=0; fail=0; note=0
ok()   { printf '[PASS] %s\n' "$1"; pass=$((pass+1)); }
ng()   { printf '[FAIL] %s\n' "$1"; fail=$((fail+1)); }
info() { printf '[CHECK] %s\n' "$1"; note=$((note+1)); }
echo '=== CHECK 1: Raspberry Pi OS / hostname / network / EEPROM ==='
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  echo "OS: ${PRETTY_NAME:-unknown}"
  [[ "${VERSION_CODENAME:-}" == trixie ]] && ok 'OS Trixie' || ng "OS is ${VERSION_CODENAME:-unknown}; guide expects Trixie"
else ng '/etc/os-release missing'; fi
arch=$(uname -m)
[[ "$arch" == aarch64 ]] && ok '64-bit ARM (aarch64)' || ng "Architecture: $arch"
if [[ -r /proc/device-tree/model ]]; then
  model=$(tr -d '\0' </proc/device-tree/model)
  echo "Device: $model"
  [[ "$model" == *'Raspberry Pi 5'* ]] && ok 'Raspberry Pi 5' || ng 'Not Raspberry Pi 5'
else ng 'Device model missing'; fi
host=$(hostname)
echo "Hostname: $host"
[[ -n "$host" ]] && ok 'Hostname set' || ng 'Hostname empty'
info 'Compare the hostname with this board label (e.g. npu-01); uniqueness is not auto-verified'
if command -v nmcli >/dev/null 2>&1; then
  echo 'NetworkManager:'
  nmcli device status
  if nmcli -t -f STATE device | grep -q '^connected$'; then ok 'Network interface connected'; else ng 'No connected interface found'; fi
else ng 'nmcli not available'; fi
echo "IP: $(hostname -I 2>/dev/null || true)"
if ping -c 4 -W 3 google.com >/dev/null 2>&1; then
  ok 'Internet and DNS ping to google.com'
elif command -v curl >/dev/null 2>&1 && getent ahostsv4 github.com >/dev/null 2>&1 \
    && curl -fsSI --connect-timeout 5 --max-time 12 https://github.com/ >/dev/null 2>&1; then
  ok 'HTTPS internet connection works (ICMP ping may be blocked)'
  info 'Google ping was blocked/failed; HTTPS to GitHub succeeded'
else
  ng 'Internet check failed: google.com ping and github.com HTTPS'
fi
if command -v rpi-eeprom-update >/dev/null 2>&1; then
  echo 'EEPROM status:'
  rpi-eeprom-update || info 'EEPROM command returned nonzero; inspect above'
  info 'EEPROM version/pending update must be reviewed visually'
else ng 'rpi-eeprom-update not found'; fi
printf '\nCHECK 1 SUMMARY: PASS=%d FAIL=%d MANUAL=%d\n' "$pass" "$fail" "$note"
(( fail == 0 )) || exit 1
