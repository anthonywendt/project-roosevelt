#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-apply}"  # apply | remove

SRC="/var/lib/k0s/kubelet"
DST="/var/lib/kubelet"
MARKER="# project-roosevelt:kubelet-bind"
LINE="${SRC} ${DST} none defaults,bind 0 0 ${MARKER}"

log() { echo "[kubelet-fix] $*"; }

apply() {
  mkdir -p "$SRC" "$DST"

  # Ensure fstab line exists (match by marker if possible)
  if ! grep -Fq "$MARKER" /etc/fstab && ! grep -Fq "${SRC} ${DST} none defaults,bind" /etc/fstab; then
    log "Adding fstab bind-mount entry"
    echo "$LINE" >> /etc/fstab
  fi

  # Mount if not mounted
  if ! mountpoint -q "$DST" 2>/dev/null; then
    log "Mounting ${DST}"
    mount "$DST" 2>/dev/null || mount -a >/dev/null 2>&1 || true
  fi
}

remove() {
  # Unmount if mounted (best-effort)
  if mountpoint -q "$DST" 2>/dev/null; then
    log "Unmounting ${DST}"
    umount "$DST" 2>/dev/null || true
    umount -R "$DST" 2>/dev/null || true
    umount -l "$DST" 2>/dev/null || true
  fi

  # Remove fstab entry (prefer marker; fallback to exact-ish match)
  if grep -Fq "$MARKER" /etc/fstab || grep -Fq "${SRC} ${DST} none defaults,bind" /etc/fstab; then
    log "Removing fstab bind-mount entry"
    tmp="$(mktemp)"
    # Drop either the marker line, or any line that matches the bind-mount signature
    grep -Fv "$MARKER" /etc/fstab | grep -Fv "${SRC} ${DST} none defaults,bind" > "$tmp"
    cat "$tmp" > /etc/fstab
    rm -f "$tmp"
  fi
}

case "$MODE" in
  apply) apply ;;
  remove) remove ;;
  *)
    echo "Usage: $0 [apply|remove]" >&2
    exit 1
    ;;
esac
