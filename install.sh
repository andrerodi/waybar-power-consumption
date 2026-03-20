#!/usr/bin/env bash
#
# install.sh - Install systemd service to fix RAPL permissions on boot
#
# This script will create /etc/systemd/system/rapl-perms.service with the
# following behavior:
#
# - On boot (oneshot) it will run:
#     /bin/chmod o+r /sys/class/powercap/intel-rapl:0/energy_uj
#
# - The service is enabled and started immediately.
#
# Usage:
#   sudo ./install.sh
#
set -euo pipefail

SERVICE_NAME="rapl-perms.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
ENERGY_PATH="/sys/class/powercap/intel-rapl:0/energy_uj"

service_unit_content() {
cat <<'UNIT'
[Unit]
Description=Fix RAPL permissions
After=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/bin/chmod o+r /sys/class/powercap/intel-rapl:0/energy_uj
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
}

require_root_or_sudo() {
  if [ "${EUID:-0}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      echo "Re-running with sudo..."
      exec sudo bash "$0" "$@"
    else
      echo "ERROR: This script must be run as root or with sudo." >&2
      exit 1
    fi
  fi
}

backup_existing() {
  local path="$1"
  if [ -f "$path" ]; then
    local ts
    ts=$(date -u +"%Y%m%dT%H%M%SZ")
    local backup="${path}.bak.${ts}"
    echo "Backing up existing ${path} -> ${backup}"
    cp -p "$path" "$backup"
  fi
}

install_service() {
  local tmp
  tmp=$(mktemp -t rapl-perms.service.XXXXXX) || { echo "Failed to create temp file"; exit 1; }
  trap 'rm -f "$tmp"' EXIT

  service_unit_content > "$tmp"

  if [ -f "$SERVICE_PATH" ]; then
    if cmp -s "$tmp" "$SERVICE_PATH"; then
      echo "Service file already up-to-date: ${SERVICE_PATH}"
      return 0
    else
      backup_existing "$SERVICE_PATH"
    fi
  fi

  echo "Installing service file to ${SERVICE_PATH}"
  mv "$tmp" "$SERVICE_PATH"
  chmod 644 "$SERVICE_PATH"
  systemctl daemon-reload
  echo "Enabling and starting ${SERVICE_NAME}"
  systemctl enable --now "$SERVICE_NAME"
  echo "Service installed and enabled."
}

apply_permission_now() {
  if [ -e "$ENERGY_PATH" ]; then
    echo "Setting permission on ${ENERGY_PATH}"
    /bin/chmod o+r "$ENERGY_PATH" || {
      echo "Warning: failed to chmod ${ENERGY_PATH} now. The service will apply it on next boot." >&2
    }
  else
    echo "Warning: ${ENERGY_PATH} does not exist on this system. The service will still be installed but may fail at runtime." >&2
  fi
}

main() {
  require_root_or_sudo "$@"
  echo "Installing ${SERVICE_NAME} to fix RAPL permissions..."

  # Ensure systemctl is available
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: systemctl not found. This script requires systemd." >&2
    exit 2
  fi

  install_service
  apply_permission_now

  echo "Done. You can check the service status with:"
  echo "  systemctl status ${SERVICE_NAME}"
  echo "And verify permissions on the energy file with:"
  echo "  ls -l ${ENERGY_PATH} || true"
}

main "$@"
