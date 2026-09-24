#!/usr/bin/env bash
# Ghostty 이미지 붙여넣기 설치 스크립트 (macOS)
# 사용법: curl -fsSL https://raw.githubusercontent.com/henryoon0/ghostty-image-paste/main/install.sh | bash
# 관리자 비밀번호나 Homebrew 없이 설치된다. 사람이 할 일은 "손쉬운 사용" 권한 켜기 하나뿐이다.
set -euo pipefail

# 본문 전체를 함수로 감싸고 마지막 줄에서 호출한다. curl | bash 도중 끊겨도 반쪽 스크립트가 실행되지 않는다.
main() {

RAW_URL="https://raw.githubusercontent.com/henryoon0/ghostty-image-paste/main/ghostty-image-paste.lua"
# 버전을 고정한 직접 주소. GitHub API("latest")는 같은 인터넷 주소에서 시간당 60번까지만 받아줘서
# 강의실처럼 여러 명이 같은 와이파이로 설치하면 막힌다.
HS_VERSION="1.1.1"
HS_ZIP_URL="https://github.com/Hammerspoon/hammerspoon/releases/download/${HS_VERSION}/Hammerspoon-${HS_VERSION}.zip"
HS_DIR="$HOME/.hammerspoon"
MODULE="$HS_DIR/ghostty-image-paste.lua"
INIT="$HS_DIR/init.lua"
REQUIRE_LINE='ghosttyImagePaste = require("ghostty-image-paste")'

case "$(uname -s)" in
  Darwin) ;;
  Linux)
    cat >&2 <<'EOF'
이 도구는 macOS 전용이라 설치하지 않았습니다.
리눅스에서는 이 도구가 필요 없어요. Claude Code가 클립보드 도구로 이미지를 직접 꺼냅니다.
  1. 클립보드 도구 설치: Wayland면 wl-clipboard, X11이면 xclip
     예) sudo apt install wl-clipboard xclip
  2. Claude Code 입력창에서 Ctrl+V
EOF
    exit 1 ;;
  MINGW*|MSYS*|CYGWIN*)
    cat >&2 <<'EOF'
이 도구는 macOS 전용이라 설치하지 않았습니다.
Windows에는 Ghostty가 없고, 이 도구도 필요 없어요.
Windows Terminal 등에서 Claude Code 입력창에 Alt+V를 누르면 이미지가 붙습니다.
EOF
    exit 1 ;;
  *)
    echo "이 도구는 macOS 전용입니다. (감지된 운영체제: $(uname -s))" >&2
    exit 1 ;;
esac

find_hammerspoon() {
  for d in /Applications "$HOME/Applications"; do
    if [ -d "$d/Hammerspoon.app" ]; then echo "$d/Hammerspoon.app"; return 0; fi
  done
  return 1
}

# 1. Hammerspoon 설치 (Homebrew가 있으면 사용, 없으면 공식 GitHub 배포 파일을 직접 받음)
if ! HS_APP="$(find_hammerspoon)"; then
  if command -v brew >/dev/null 2>&1 && brew install --cask hammerspoon; then
    HS_APP="$(find_hammerspoon)"
  else
    echo "→ Hammerspoon 내려받는 중..."
    TMP="$(mktemp -d)"
    if ! curl -fsSL "$HS_ZIP_URL" -o "$TMP/hs.zip"; then
      echo "Hammerspoon을 받지 못했습니다. 회사 네트워크가 GitHub을 막았을 수 있어요." >&2
      echo "https://www.hammerspoon.org 에서 직접 설치한 뒤 이 명령어를 다시 실행하세요." >&2
      exit 1
    fi
    ditto -x -k "$TMP/hs.zip" "$TMP"
    APP_DIR="/Applications"
    [ -w "$APP_DIR" ] || { APP_DIR="$HOME/Applications"; mkdir -p "$APP_DIR"; }
    ditto "$TMP/Hammerspoon.app" "$APP_DIR/Hammerspoon.app"
    rm -rf "$TMP"
    HS_APP="$APP_DIR/Hammerspoon.app"
  fi
  # "인터넷에서 받은 앱" 확인 창이 설치 흐름을 막지 않도록 격리 표시를 지운다
  xattr -dr com.apple.quarantine "$HS_APP" 2>/dev/null || true
fi
echo "→ Hammerspoon: $HS_APP"

# 2. 모듈 복사
# curl | bash로 실행하면 스크립트 파일이 없다. 이때 현재 폴더의 같은 이름 파일을 집어 오지 않도록
# 스크립트가 실제 파일로 실행된 경우에만 옆에 있는 모듈을 쓴다.
mkdir -p "$HS_DIR"
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

# 4. Hammerspoon 다시 켜기 (로그인 시 자동 실행은 모듈이 켠다)
killall Hammerspoon >/dev/null 2>&1 || true
open "$HS_APP"

# 5. 손쉬운 사용 설정 화면 열기
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

if [ ! -d /Applications/Ghostty.app ] && [ ! -d "$HOME/Applications/Ghostty.app" ]; then
  echo
  echo "참고: Ghostty가 설치돼 있지 않습니다. https://ghostty.org 에서 설치하세요."
fi

cat <<'EOF'

설치 완료. 마지막 한 단계만 직접 해주세요.

  방금 열린 "손쉬운 사용" 화면에서 Hammerspoon 스위치를 켜세요.
  (영어 macOS: Privacy & Security → Accessibility)
  (목록에 없으면 + 버튼으로 응용 프로그램 → Hammerspoon 추가)
  (회사 노트북에서 스위치가 잠겨 있으면 회사 보안 정책이 막은 것이라 IT 담당자 허용이 필요해요)

켜는 순간 화면에 "Ghostty 이미지 붙여넣기 준비 완료"가 뜹니다.
그다음부터 이미지를 복사하고 Ghostty에서 Cmd+V를 누르면 됩니다.
EOF
}

main "$@"
