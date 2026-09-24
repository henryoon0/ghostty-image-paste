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

local function pasteImageAsPath()
  local image = hs.pasteboard.readImage()
  if not image then return false end

  hs.fs.mkdir(DIR)
  local path = string.format("%s/paste-%s-%03d.png", DIR, os.date("%Y%m%d-%H%M%S"), math.random(0, 999))
  if not image:saveToFile(path) then
    hs.alert.show("이미지 저장 실패")
    return false
  end

  -- 원래 클립보드(이미지)를 보관했다가 붙여넣은 뒤 되돌린다. 다른 앱에서는 계속 이미지로 붙는다.
  local original = hs.pasteboard.readAllData()
  hs.pasteboard.setContents(path)
  sendCmdV()
  hs.timer.doAfter(0.5, function()
    if original then hs.pasteboard.writeAllData(original) end
    cleanupOldFiles()
  end)
  return true
end

M.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  if bypass or e:getKeyCode() ~= KEY_V then return false end

  local flags = e:getFlags()
  if not flags.cmd or flags.ctrl or flags.alt or flags.shift then return false end

  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= GHOSTTY then return false end
  if not clipboardIsImageOnly() then return false end

  return pasteImageAsPath()
end)
M.tap:start()

return M
