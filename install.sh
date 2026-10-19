#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Michael Maurer
# Installs zulip-status for the current user (no root needed).
#   ./install.sh            install or update
#   ./install.sh --remove   stop the service and remove the files (settings stay)
#   ./install.sh --nm-hook  optional, via sudo: NetworkManager hook that keeps the
#                           network up on suspend until the status is set
set -eu
cd "$(dirname "$0")"
NMHOOK=/etc/NetworkManager/dispatcher.d/pre-down.d/50-zulip-schlafwache

if [ "${1:-}" = "--nm-hook" ]; then
    sudo install -D -m 0755 -o root -g root nm/50-zulip-schlafwache "$NMHOOK"
    echo "NetworkManager hook installed: $NMHOOK"
    exit 0
fi
BIN="$HOME/.local/bin"
UNIT="$HOME/.config/systemd/user"
CONF="$HOME/.config/zulip-status"
AUTOSTART="$HOME/.config/autostart"
APPS="$HOME/.local/share/applications"

if [ "${1:-}" = "--remove" ]; then
    systemctl --user disable --now zulip-status.service 2>/dev/null || true
    rm -f "$BIN/zulip-status" "$BIN/zulip-tray" "$UNIT/zulip-status.service" \
          "$AUTOSTART/zulip-tray.desktop" "$APPS/zulip-tray.desktop"
    systemctl --user daemon-reload
    echo "Removed. Settings in $CONF and ~/.zuliprc were left in place."
    [ ! -e "$NMHOOK" ] || echo "Remove the NetworkManager hook with: sudo rm $NMHOOK"
    exit 0
fi

mkdir -p "$BIN" "$UNIT" "$CONF" "$AUTOSTART" "$APPS"
install -m 0755 zulip-status zulip-tray "$BIN/"
install -m 0644 systemd/zulip-status.service "$UNIT/"
sed "s|^Exec=.*|Exec=$BIN/zulip-tray|" desktop/zulip-tray.desktop > "$APPS/zulip-tray.desktop"
cp "$APPS/zulip-tray.desktop" "$AUTOSTART/zulip-tray.desktop"
[ -e "$CONF/config.env" ] || install -m 0600 config.env.example "$CONF/config.env"
[ -e "$HOME/.zuliprc" ] || install -m 0600 zuliprc.example "$HOME/.zuliprc"

systemctl --user daemon-reload
systemctl --user enable zulip-status.service
systemctl --user restart zulip-status.service

echo "Installed."
echo "1. Put your Zulip address, login and API key into ~/.zuliprc"
echo "2. Adjust $CONF/config.env"
echo "3. systemctl --user restart zulip-status.service"
echo "Log: journalctl --user -u zulip-status.service -f"
[ -e "$NMHOOK" ] || echo "Optional: ./install.sh --nm-hook (sudo) so the status is set reliably before suspend."
