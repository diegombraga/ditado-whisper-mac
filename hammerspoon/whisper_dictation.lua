-- =====================================================================
--  Ditado local com Whisper (whisper.cpp) — acionado por duplo toque Ctrl
--  Fluxo: Ctrl-Ctrl inicia a gravacao -> Ctrl-Ctrl de novo para/transcreve
--         e cola o texto no app onde o cursor estiver. Tudo local.
--  https://github.com/diegombraga/ditado-whisper-mac
-- =====================================================================

local M = {}

-- ---------- Configuracao (ajuste aqui se quiser) ----------
local HOME    = os.getenv("HOME")
local REC     = "/opt/homebrew/bin/rec"          -- gravador (sox)
local WHISPER = "/opt/homebrew/bin/whisper-cli"  -- motor de transcricao
local MODEL_NAME = "ggml-large-v3-turbo.bin"     -- nome do modelo baixado
local MODEL   = HOME .. "/Library/Application Support/whisper-dictation/models/" .. MODEL_NAME
local TMPDIR  = HOME .. "/Library/Application Support/whisper-dictation/tmp"
local WAV     = TMPDIR .. "/rec.wav"
local LANG    = "pt"        -- idioma da fala ("auto" para detectar)
local THREADS = "8"         -- nucleos usados na transcricao
local DOUBLE_TAP_WINDOW = 0.4  -- segundos entre os dois toques no Ctrl

hs.execute("mkdir -p '" .. TMPDIR .. "'")

-- ---------- Estado ----------
local recording   = false
local recTask     = nil
local alertUUID   = nil

-- ---------- Indicador visual ----------
local function showIndicator(msg)
  if alertUUID then hs.alert.closeSpecific(alertUUID) end
  alertUUID = hs.alert.show(
    msg or "🎤  Gravando…  (Ctrl-Ctrl para parar)",
    { textSize = 20, radius = 12, strokeWidth = 0 },
    hs.screen.mainScreen(),
    999999
  )
end

local function hideIndicator()
  if alertUUID then hs.alert.closeSpecific(alertUUID); alertUUID = nil end
end

-- ---------- Colar texto no app ativo ----------
local function pasteText(text)
  local prev = hs.pasteboard.getContents()
  hs.pasteboard.setContents(text)
  hs.timer.doAfter(0.05, function()
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    hs.timer.doAfter(0.6, function()
      if prev ~= nil then hs.pasteboard.setContents(prev) end
    end)
  end)
end

-- ---------- Transcricao ----------
local function transcribe()
  showIndicator("⏳  Transcrevendo…")
  local args = { "-m", MODEL, "-f", WAV, "-l", LANG, "-nt", "-np", "-t", THREADS }
  local t = hs.task.new(WHISPER, function(exitCode, stdout, stderr)
    hideIndicator()
    if exitCode == 0 and stdout then
      local text = stdout:gsub("^%s+", ""):gsub("%s+$", "")
      if #text > 0 and not text:match("^%[") and not text:match("^%(") then
        pasteText(text)
      else
        hs.alert.show("🔇  Nada capturado")
      end
    else
      hs.alert.show("⚠️  Erro na transcrição")
      print("whisper stderr: " .. (stderr or ""))
    end
  end, args)
  t:start()
end

-- ---------- Gravacao ----------
local function startRecording()
  recording = true
  os.remove(WAV)
  recTask = hs.task.new(REC, nil, { "-q", "-c", "1", "-r", "16000", "-b", "16", WAV })
  recTask:start()
  showIndicator()
end

local function stopAndTranscribe()
  recording = false
  if recTask then recTask:terminate(); recTask = nil end
  showIndicator("⏳  Processando…")
  hs.timer.doAfter(0.35, transcribe)
end

local function toggle()
  if recording then stopAndTranscribe() else startRecording() end
end

-- ---------- Detector de duplo toque no Ctrl ----------
-- Conta dois "toques limpos" no Ctrl (pressiona e solta sem outra tecla),
-- ignorando combos como Ctrl+C, Ctrl+Seta, Ctrl+Shift etc.
local lastTapTime = 0
local ctrlDown    = false
local interrupted = false

local keyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(_)
  if ctrlDown then interrupted = true end
  lastTapTime = 0
  return false
end)

local flagWatcher = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
  local f = e:getFlags()
  local onlyCtrl = f.ctrl and not (f.cmd or f.alt or f.shift or f.fn)

  if onlyCtrl then
    ctrlDown = true
    interrupted = false
  elseif next(f) == nil then
    if ctrlDown and not interrupted then
      local now = hs.timer.secondsSinceEpoch()
      if (now - lastTapTime) < DOUBLE_TAP_WINDOW then
        lastTapTime = 0
        toggle()
      else
        lastTapTime = now
      end
    end
    ctrlDown = false
  else
    if ctrlDown then interrupted = true end
  end
  return false
end)

function M.start()
  keyWatcher:start()
  flagWatcher:start()
  hs.alert.show("✅  Ditado Whisper ativo (Ctrl-Ctrl)")
end

function M.stop()
  keyWatcher:stop()
  flagWatcher:stop()
end

return M
