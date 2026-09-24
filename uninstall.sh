#!/usr/bin/env bash
# Ghostty 이미지 붙여넣기 제거 스크립트 (Hammerspoon 자체는 지우지 않음)
set -euo pipefail

HS_DIR="$HOME/.hammerspoon"
INIT="$HS_DIR/init.lua"

rm -f "$HS_DIR/ghostty-image-paste.lua"
if [ -f "$INIT" ]; then
  sed -i '' -e '/-- Ghostty에서 Cmd+V로 이미지 붙여넣기/d' -e '/require("ghostty-image-paste")/d' "$INIT"
  # 설치가 새로 만든 파일이라 이제 비어 있으면 지운다
  if ! grep -q '[^[:space:]]' "$INIT"; then rm -f "$INIT"; fi
fi
rm -rf "$HOME/Library/Caches/ghostty-image-paste"

if pgrep -x Hammerspoon >/dev/null; then
  killall Hammerspoon >/dev/null 2>&1 || true
  open -a Hammerspoon
fi

echo "제거 완료."
