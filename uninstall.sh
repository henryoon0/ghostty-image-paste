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

# 단축키 설정 읽기/쓰기. 실제 사용자 홈이면 macOS 설정(defaults)을, 가짜 홈 폴더(시험)면 그 안의 파일을 직접 다룬다.
# (가짜 홈에서 defaults를 쓰면 저장이 늦게 반영돼 시험 결과가 흔들리고, 진짜 설정을 건드릴 위험도 있다)
HK_FILE="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
hk_mode() {
  local real_home
  real_home="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  if [ "$HOME" = "$real_home" ]; then echo real; else echo file; fi
}
hk_read31() {
  if [ "$(hk_mode)" = real ]; then
    defaults export com.apple.symbolichotkeys - 2>/dev/null | plutil -extract AppleSymbolicHotKeys.31 xml1 -o - - 2>/dev/null || true
  elif [ -f "$HK_FILE" ]; then
    plutil -extract AppleSymbolicHotKeys.31 xml1 -o - "$HK_FILE" 2>/dev/null || true
  fi
}
hk_write31() {
  if [ "$(hk_mode)" = real ]; then
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 31 "$1"
  else
    mkdir -p "$(dirname "$HK_FILE")"
    [ -f "$HK_FILE" ] || printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict/></plist>\n' > "$HK_FILE"
    plutil -extract AppleSymbolicHotKeys xml1 -o /dev/null "$HK_FILE" 2>/dev/null || plutil -insert AppleSymbolicHotKeys -dictionary "$HK_FILE"
    plutil -remove AppleSymbolicHotKeys.31 "$HK_FILE" 2>/dev/null || true
    plutil -insert AppleSymbolicHotKeys.31 -xml "$1" "$HK_FILE"
  fi
}
hk_apply() {
  # 로그아웃 없이 바로 적용한다. 실제 사용자 홈에서만.
  local a="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
  if [ "$(hk_mode)" = real ] && [ -x "$a" ]; then "$a" -u >/dev/null 2>&1 || true; fi
}

# ⇧⌘S 스크린샷 단축키를 설치 전 값으로 되돌린다
BACKUP_DIR="$HOME/Library/Application Support/ghostty-image-paste"
MAC_DEFAULT_XML='<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>52</integer><integer>21</integer><integer>1441792</integer></array><key>type</key><string>standard</string></dict></dict>'
restored=0
if [ -f "$BACKUP_DIR/screenshot-shortcut.xml" ]; then
  # 백업은 plist 문서 전체라 앞 3줄(머리말)과 마지막 줄(</plist>)을 떼고 넣는다
  hk_write31 "$(sed '1,3d;$d' "$BACKUP_DIR/screenshot-shortcut.xml" | tr -d '\n\t')"
  restored=1
elif [ -f "$BACKUP_DIR/screenshot-shortcut.default" ]; then
  # 시험용 가짜 홈에서 설치 전에 파일이 없었고 지금도 우리 설정 하나뿐이면 파일째 지운다.
  # 실제 사용자는 파일을 직접 지우지 않고 macOS 기본값(⌃⇧⌘4)으로 되돌린다.
  entries="$( { plutil -convert json -o - "$HK_FILE" 2>/dev/null || true; } | { grep -o '"enabled"' || true; } | wc -l | tr -d ' ')"
  if [ "$(hk_mode)" = file ] && grep -q nofile "$BACKUP_DIR/screenshot-shortcut.default" && [ "$entries" = 1 ]; then
    rm -f "$HK_FILE"
  else
    hk_write31 "$MAC_DEFAULT_XML"
  fi
  restored=1
fi
rm -rf "$BACKUP_DIR"
if [ $restored = 1 ]; then
  hk_apply
  echo "→ 스크린샷 단축키를 설치 전 값으로 되돌림"
fi

if pgrep -x Hammerspoon >/dev/null; then
  killall Hammerspoon >/dev/null 2>&1 || true
  open -a Hammerspoon
fi

echo "제거 완료."
