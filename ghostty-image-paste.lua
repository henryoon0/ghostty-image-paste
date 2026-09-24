-- ~/.hammerspoon/ghostty-image-paste.lua
-- Ghostty에서 Cmd+V를 눌렀는데 클립보드가 "이미지만" 있으면
-- 이미지를 PNG 파일로 저장하고 그 파일 경로를 붙여넣는다.
-- Claude Code는 붙여넣은 이미지 경로를 [Image #N]으로 바꾼다(끌어다 놓기와 같은 원리).
-- 경로는 평범한 글자라서 herdr·한글 입력기를 거쳐도 깨지지 않는다.

local M = {}

local GHOSTTY = "com.mitchellh.ghostty"
local KEY_V = 9 -- 물리 V 키(한글 입력 상태에서도 같은 값)
local DIR = os.getenv("HOME") .. "/Library/Caches/ghostty-image-paste"
local KEEP_SECONDS = 24 * 60 * 60

local bypass = false

local function clipboardIsImageOnly()
  local types = hs.pasteboard.contentTypes() or {}
  local hasImage, hasText = false, false
  for _, t in ipairs(types) do
    if t == "public.png" or t == "public.tiff" or t == "public.jpeg" then hasImage = true end
    if t == "public.utf8-plain-text" or t == "public.file-url" then hasText = true end
  end
  return hasImage and not hasText
end

local function cleanupOldFiles()
  local now = os.time()
  for file in hs.fs.dir(DIR) do
    local path = DIR .. "/" .. file
    local attr = hs.fs.attributes(path)
    if attr and attr.mode == "file" and now - attr.modification > KEEP_SECONDS then
      os.remove(path)
    end
  end
end

local function sendCmdV()
  bypass = true
  hs.eventtap.event.newKeyEvent({ "cmd" }, KEY_V, true):post()
  hs.eventtap.event.newKeyEvent({ "cmd" }, KEY_V, false):post()
  hs.timer.doAfter(0.1, function() bypass = false end)
end

-- 경로처럼 잠깐 쓰는 글자를 클립보드에 넣는다.
-- TransientType 표시를 붙여 Raycast 같은 클립보드 기록 앱이 저장하지 않게 한다.
local function setTransientText(text)
  hs.pasteboard.writeAllData({
    ["public.utf8-plain-text"] = text,
    ["org.nspasteboard.TransientType"] = "",
  })
end

-- 우리가 클립보드를 쓰고 되돌리는 동안은 Raycast 감지를 쉰다(자기 쓰기를 Raycast로 착각해 반복하지 않게).
local quietUntil = 0
local function quietFor(seconds)
  quietUntil = hs.timer.secondsSinceEpoch() + seconds
end

local function pasteImageAsPath(image)
  image = image or hs.pasteboard.readImage()
  if not image then return false end
  quietFor(1.5)

  hs.fs.mkdir(DIR)
  local path = string.format("%s/paste-%s-%03d.png", DIR, os.date("%Y%m%d-%H%M%S"), math.random(0, 999))
  if not image:saveToFile(path) then
    hs.alert.show("이미지 저장 실패")
    return false
  end

  -- 원래 클립보드(이미지)를 보관했다가 붙여넣은 뒤 되돌린다. 다른 앱에서는 계속 이미지로 붙는다.
  local original = hs.pasteboard.readAllData()
  setTransientText(path)
  sendCmdV()
  hs.timer.doAfter(0.5, function()
    if original then hs.pasteboard.writeAllData(original) end
    cleanupOldFiles()
  end)
  return true
end

-- Raycast 클립보드 기록의 "Paste to Ghostty" 처리.
-- Raycast가 흉내 낸 Cmd+V는 Ghostty에서 한글 입력기에 먹혀 "ㅍ"가 되고, 이미지는 키 없이 넣어서 붙지 않는다.
-- 그래서 Raycast가 클립보드에 넣은 내용을 잡아 두었다가, 잘 작동하는 우리 방식으로 대신 붙인다.
local RAYCAST = "com.raycast.macos"
local KEY_DELETE = 51
local raycastJob = nil
local raycastSwallowedAt = 0 -- Raycast가 보낸 V를 우리가 가로챈 마지막 시각

local function clipboardTypeSet()
  local set = {}
  for _, t in ipairs(hs.pasteboard.contentTypes() or {}) do set[t] = true end
  return set
end

local function isRaycastInjection(set)
  if not set["org.nspasteboard.TransientType"] or set["com.raycast.RestoredType"] then return false end
  return set["com.raycast.snippets.clipboardInjected"]
    or hs.pasteboard.readDataForUTI(nil, "org.nspasteboard.source") == RAYCAST
end

local function pasteCaptured(captured)
  if captured.image then
    pasteImageAsPath(captured.image)
  elseif captured.text then
    quietFor(1.5)
    local original = hs.pasteboard.readAllData()
    setTransientText(captured.text)
    sendCmdV()
    hs.timer.doAfter(0.5, function()
      if original then hs.pasteboard.writeAllData(original) end
    end)
  end
end

local function finishRaycastPaste(captured)
  quietFor(1.5)
  -- Raycast의 V를 가로채지 못했다면 Ghostty에 "ㅍ"(영어 입력이면 "v")가 한 글자 들어가 있다.
  -- 붙이기 전에 그 한 글자를 지운다.
  if hs.timer.secondsSinceEpoch() - raycastSwallowedAt > 2 then
    hs.eventtap.event.newKeyEvent({}, KEY_DELETE, true):post()
    hs.eventtap.event.newKeyEvent({}, KEY_DELETE, false):post()
    hs.timer.doAfter(0.05, function() pasteCaptured(captured) end)
  else
    pasteCaptured(captured)
  end
end

local function handleRaycastPaste()
  if raycastJob then return end
  local started = hs.timer.secondsSinceEpoch()
  local captured, capturedAt = nil, nil
  raycastJob = hs.timer.doEvery(0.02, function()
    local now = hs.timer.secondsSinceEpoch()
    local set = clipboardTypeSet()
    if not captured and isRaycastInjection(set) then
      captured = { image = hs.pasteboard.readImage() }
      if not captured.image then captured.text = hs.pasteboard.getContents() end
      capturedAt = now
    end
    -- Raycast가 원래 클립보드를 되돌린 뒤(또는 0.6초 뒤) 붙인다
    if captured and (set["com.raycast.RestoredType"] or now - capturedAt > 0.6) then
      raycastJob:stop(); raycastJob = nil
      finishRaycastPaste(captured)
    elseif not captured and now - started > 1.0 then
      raycastJob:stop(); raycastJob = nil
    end
  end)
end

local function senderBundle(e)
  local pid = e:getProperty(hs.eventtap.event.properties.eventSourceUnixProcessID)
  local app = pid and pid > 0 and hs.application.applicationForPID(pid)
  return app and app:bundleID()
end

local function ghosttyIsFront()
  local app = hs.application.frontmostApplication()
  return app and app:bundleID() == GHOSTTY
end

local function onKeyDown(e)
  if bypass or e:getKeyCode() ~= KEY_V then return false end

  -- Raycast는 Cmd 표시가 빠진 V 키를 보내기도 한다. 그러면 한글 입력기가 "ㅍ"로 바꾸므로
  -- 수정키와 상관없이 Raycast가 보낸 V는 가로채고 우리가 대신 붙인다.
  if senderBundle(e) == RAYCAST and ghosttyIsFront() then
    raycastSwallowedAt = hs.timer.secondsSinceEpoch()
    handleRaycastPaste()
    return true
  end

  local flags = e:getFlags()
  if not flags.cmd or flags.ctrl or flags.alt or flags.shift then return false end

  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= GHOSTTY then return false end

  if not clipboardIsImageOnly() then return false end

  return pasteImageAsPath()
end

local function startTap()
  if M.tap then M.tap:stop() end
  M.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, onKeyDown)
  M.tap:start()

  -- Raycast가 Ghostty에 붙여넣으려고 클립보드에 넣은 순간을 잡는다(이미지·글자 모두).
  -- 키 가로채기가 실패해도 이 경로로 붙인다. Raycast는 넣고 약 0.3초 뒤 되돌리므로 자주 확인한다.
  hs.pasteboard.watcher.interval(0.05)
  if M.clipWatcher then M.clipWatcher:stop() end
  M.clipWatcher = hs.pasteboard.watcher.new(function()
    if hs.timer.secondsSinceEpoch() < quietUntil or not ghosttyIsFront() then return end
    if isRaycastInjection(clipboardTypeSet()) then
      handleRaycastPaste()
    end
  end)
end

-- 맥을 다시 켜도 계속 작동하게 로그인 시 Hammerspoon 자동 실행
hs.autoLaunch(true)

-- 손쉬운 사용 권한이 없으면 키를 못 받는다. 권한이 켜질 때까지 기다렸다가 스스로 다시 시작한다.
if hs.accessibilityState() then
  startTap()
else
  hs.alert.show("Ghostty 이미지 붙여넣기: 손쉬운 사용에서 Hammerspoon을 켜주세요", 6)
  M.permissionTimer = hs.timer.doEvery(2, function()
    if hs.accessibilityState() then
      M.permissionTimer:stop()
      startTap()
      hs.alert.show("Ghostty 이미지 붙여넣기 준비 완료")
    end
  end)
end

return M
