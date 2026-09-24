#!/usr/bin/env bash
# Ghostty 이미지 붙여넣기 설치 스크립트 (macOS)
# 사용법: curl -fsSL https://raw.githubusercontent.com/henryoon0/ghostty-image-paste/main/install.sh | bash
set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/henryoon0/ghostty-image-paste/main/ghostty-image-paste.lua"
HS_DIR="$HOME/.hammerspoon"
MODULE="$HS_DIR/ghostty-image-paste.lua"
INIT="$HS_DIR/init.lua"
REQUIRE_LINE='ghosttyImagePaste = require("ghostty-image-paste")'

if [ "$(uname)" != "Darwin" ]; then
  echo "이 도구는 macOS 전용입니다." >&2
  exit 1
fi

# 1. Hammerspoon 설치
if [ ! -d "/Applications/Hammerspoon.app" ] && [ ! -d "$HOME/Applications/Hammerspoon.app" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew가 없습니다. https://brew.sh 에서 설치하거나 https://www.hammerspoon.org 에서 Hammerspoon을 직접 설치한 뒤 다시 실행하세요." >&2
    exit 1
  fi
  echo "→ Hammerspoon 설치 중..."
  brew install --cask hammerspoon
fi

# 2. 모듈 복사 (저장소를 clone했으면 로컬 파일, 아니면 GitHub에서 받기)
mkdir -p "$HS_DIR"
# curl | bash로 실행하면 스크립트 파일이 없다. 이때 현재 폴더의 같은 이름 파일을 집어 오지 않도록
# 스크립트가 실제 파일로 실행된 경우에만 옆에 있는 모듈을 쓴다.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/ghostty-image-paste.lua" ]; then
  cp "$SCRIPT_DIR/ghostty-image-paste.lua" "$MODULE"
else
  curl -fsSL "$RAW_URL" -o "$MODULE"
fi
echo "→ $MODULE 설치됨"

# 3. init.lua에 불러오는 줄 추가 (이미 있으면 건너뜀)
touch "$INIT"
if ! grep -qF 'require("ghostty-image-paste")' "$INIT"; then
  printf '\n-- Ghostty에서 Cmd+V로 이미지 붙여넣기\n%s\n' "$REQUIRE_LINE" >> "$INIT"
  echo "→ $INIT 에 한 줄 추가됨"
else
  echo "→ $INIT 에 이미 설정돼 있음"
fi

# 4. Hammerspoon 다시 켜기
killall Hammerspoon >/dev/null 2>&1 || true
open -a Hammerspoon

cat <<'EOF'

설치 완료.

처음 설치했다면 한 번만 해주세요:
  1. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 → Hammerspoon 켜기
  2. Hammerspoon 메뉴바 아이콘 → Preferences → "Launch Hammerspoon at login" 체크

사용법: 이미지를 복사한 뒤 Ghostty에서 Cmd+V
EOF
