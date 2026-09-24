# Ghostty 이미지 붙여넣기

Ghostty 터미널에서 Claude Code에 이미지를 `Cmd+V`로 붙여넣을 수 있게 해주는 도구입니다.

글자는 잘 붙는데 스크린샷만 안 붙는 분들을 위해 만들었어요. 한글 입력 상태여도 되고, herdr 같은 터미널 관리 도구 안에서도 됩니다.

## 설치 (1분)

터미널에 아래 한 줄을 붙여넣고 Enter를 누르세요.

```bash
curl -fsSL https://raw.githubusercontent.com/henryoon0/ghostty-image-paste/main/install.sh | bash
```

Homebrew나 관리자 비밀번호는 필요 없어요. Hammerspoon이 없으면 공식 배포 파일을 받아 설치하고, 맥을 켤 때 자동으로 실행되게도 설정합니다.

설치가 끝나면 **손쉬운 사용** 설정 화면이 자동으로 열려요. 거기서 **Hammerspoon 스위치 하나만 켜주세요.** 키 입력을 받으려면 이 권한이 필요하고, macOS는 이 권한을 사람만 켤 수 있게 막아두었어요.

켜는 순간 화면에 "Ghostty 이미지 붙여넣기 준비 완료"가 뜹니다. 앱을 다시 켤 필요는 없어요.

## AI 에이전트에게 설치를 맡길 때

Claude Code 같은 AI에게 이 링크를 주고 "설치해줘"라고 하면 됩니다. 아래는 에이전트가 따를 절차예요.

> **For AI agents:**
> 1. Run: `curl -fsSL https://raw.githubusercontent.com/henryoon0/ghostty-image-paste/main/install.sh | bash`
> 2. It needs no sudo and no Homebrew. It installs Hammerspoon if missing, installs the module, and opens System Settings → Privacy & Security → Accessibility.
> 3. Tell the user to turn on the Hammerspoon switch in that pane. You cannot do this step for the user. macOS allows only a person to grant this permission.
> 4. When the user turns it on, the alert "Ghostty 이미지 붙여넣기 준비 완료" shows. The user does not need to restart anything.
> 5. To test: the user copies an image (for example `Cmd+Shift+Ctrl+4`), then presses `Cmd+V` in Ghostty. `[Image #1]` shows in Claude Code.

## 사용법

1. 스크린샷을 찍거나 이미지를 복사합니다. (`Cmd+Shift+Ctrl+4`로 찍으면 바로 클립보드에 들어가요.)
2. Ghostty에서 Claude Code 입력창에 `Cmd+V`를 누릅니다.
3. `[Image #1]`이 붙으면 끝이에요.

## 왜 안 붙었나요

터미널은 원래 글자만 주고받아요. 이미지를 붙이려면 Claude Code가 `Ctrl+V` 신호를 받고 클립보드를 직접 열어야 합니다.

그런데 이 신호가 중간에서 자주 망가져요.

- 한글 입력 상태에서는 입력기가 `V`를 `ㅍ`로 바꿔버립니다.
- herdr, tmux 같은 도구가 중간에 있으면 키 신호가 한 번 더 변환됩니다.

## 어떻게 해결했나요

이미지를 **파일로 저장하고 그 경로를 붙여넣습니다.** Finder에서 이미지를 끌어다 놓을 때와 같은 방식이에요.

1. Ghostty에서 `Cmd+V`를 누르면 Hammerspoon(맥 자동화 앱)이 먼저 받습니다.
2. 클립보드에 이미지만 있으면 PNG 파일로 저장합니다.
3. 그 파일 경로를 대신 붙여넣습니다. Claude Code가 경로를 보고 이미지로 바꿔요.
4. 0.5초 뒤 클립보드를 원래 이미지로 되돌립니다. 다른 앱에서는 계속 이미지로 붙어요.

경로는 평범한 글자라서 한글 입력기나 중간 도구를 거쳐도 깨지지 않습니다.

클립보드에 글자가 있거나 Ghostty가 아닌 앱에서는 아무것도 바꾸지 않아요. 평소 `Cmd+V` 그대로 작동합니다.

## 알아두면 좋은 점

- 저장된 이미지는 `~/Library/Caches/ghostty-image-paste/`에 쌓이고, 하루가 지나면 자동으로 지워집니다.
- Claude Code에서 확인했습니다. 붙여넣은 이미지 경로를 이미지로 인식하는 다른 도구에서도 작동할 수 있지만 확인하지는 않았어요.
- macOS 전용입니다.

## 제거

```bash
curl -fsSL https://raw.githubusercontent.com/henryoon0/ghostty-image-paste/main/uninstall.sh | bash
```

Hammerspoon 앱 자체는 지우지 않아요. 필요 없으면 `brew uninstall --cask hammerspoon`으로 지우세요.

## 파일 구성

| 파일 | 하는 일 |
| --- | --- |
| `ghostty-image-paste.lua` | 실제 동작 코드 (Hammerspoon 모듈) |
| `install.sh` | Hammerspoon 설치, 코드 복사, 설정 추가 |
| `uninstall.sh` | 코드와 설정 제거 |

## 라이선스

MIT
