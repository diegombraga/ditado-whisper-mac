#!/usr/bin/env bash
# =====================================================================
#  Ditado por voz LOCAL no macOS — instalador
#  Whisper (whisper.cpp) + Hammerspoon, acionado por duplo toque no Ctrl.
#  Transcreve sua fala 100% offline e cola no app onde o cursor estiver.
#
#  Uso:   bash install.sh
#  Modelo alternativo:  WHISPER_MODEL=ggml-medium bash install.sh
#  Idioma:              WHISPER_LANG=en bash install.sh
# =====================================================================
set -euo pipefail

# ---------- cores ----------
B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'
say()  { echo "${C}▶${N} $*"; }
ok()   { echo "${G}✓${N} $*"; }
warn() { echo "${Y}!${N} $*"; }
die()  { echo "${R}✗ $*${N}" >&2; exit 1; }

MODEL_NAME="${WHISPER_MODEL:-ggml-large-v3-turbo}"
LANG_CODE="${WHISPER_LANG:-pt}"
MODEL_DIR="$HOME/Library/Application Support/whisper-dictation/models"
HS_DIR="$HOME/.hammerspoon"

echo "${B}"
echo "  ┌───────────────────────────────────────────────┐"
echo "  │   Ditado por voz LOCAL no Mac  ·  Whisper 🎤    │"
echo "  └───────────────────────────────────────────────┘"
echo "${N}"

# ---------- 0. Pre-checagens ----------
[[ "$(uname)" == "Darwin" ]] || die "Este instalador é só para macOS."

# ---------- 1. Homebrew ----------
if ! command -v brew >/dev/null 2>&1; then
  say "Homebrew não encontrado. Instalando…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # coloca o brew no PATH desta sessao (Apple Silicon x Intel)
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
fi
BREW_PREFIX="$(brew --prefix)"
ok "Homebrew: $BREW_PREFIX"

# ---------- 2. Dependencias ----------
say "Instalando dependências (whisper-cpp, sox, ffmpeg)…"
brew install whisper-cpp sox ffmpeg >/dev/null 2>&1 || brew install whisper-cpp sox ffmpeg
ok "Motor de transcrição e gravador instalados"

say "Instalando Hammerspoon…"
if [[ ! -d /Applications/Hammerspoon.app ]]; then
  brew install --cask hammerspoon
else
  ok "Hammerspoon já estava instalado"
fi

# ---------- 3. Modelo Whisper ----------
mkdir -p "$MODEL_DIR"
MODEL_PATH="$MODEL_DIR/$MODEL_NAME.bin"
if [[ -f "$MODEL_PATH" ]]; then
  ok "Modelo já presente: $MODEL_NAME ($(du -h "$MODEL_PATH" | cut -f1))"
else
  say "Baixando modelo $MODEL_NAME (pode levar alguns minutos)…"
  curl -L --fail --progress-bar \
    -o "$MODEL_PATH" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_NAME.bin" \
    || die "Falha ao baixar o modelo. Verifique o nome em huggingface.co/ggerganov/whisper.cpp"
  ok "Modelo baixado: $MODEL_NAME ($(du -h "$MODEL_PATH" | cut -f1))"
fi

# ---------- 4. Config do Hammerspoon ----------
mkdir -p "$HS_DIR"
WHISPER_BIN="$(command -v whisper-cli || echo "$BREW_PREFIX/bin/whisper-cli")"
REC_BIN="$(command -v rec || echo "$BREW_PREFIX/bin/rec")"

say "Escrevendo config do Hammerspoon…"
cat > "$HS_DIR/whisper_dictation.lua" <<'LUA'
-- Ditado local com Whisper — acionado por duplo toque no Ctrl.
-- github.com/diegombraga/ditado-whisper-mac
local M = {}
local HOME    = os.getenv("HOME")
local REC     = "__REC_BIN__"
local WHISPER = "__WHISPER_BIN__"
local MODEL   = HOME .. "/Library/Application Support/whisper-dictation/models/__MODEL_NAME__.bin"
local TMPDIR  = HOME .. "/Library/Application Support/whisper-dictation/tmp"
local WAV     = TMPDIR .. "/rec.wav"
local LANG    = "__LANG__"
local THREADS = "8"
local DOUBLE_TAP_WINDOW = 0.4

hs.execute("mkdir -p '" .. TMPDIR .. "'")
local recording, recTask, alertUUID = false, nil, nil

local function showIndicator(msg)
  if alertUUID then hs.alert.closeSpecific(alertUUID) end
  alertUUID = hs.alert.show(msg or "🎤  Gravando…  (Ctrl-Ctrl para parar)",
    { textSize = 20, radius = 12, strokeWidth = 0 }, hs.screen.mainScreen(), 999999)
end
local function hideIndicator()
  if alertUUID then hs.alert.closeSpecific(alertUUID); alertUUID = nil end
end
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
local function transcribe()
  showIndicator("⏳  Transcrevendo…")
  local args = { "-m", MODEL, "-f", WAV, "-l", LANG, "-nt", "-np", "-t", THREADS }
  local t = hs.task.new(WHISPER, function(exitCode, stdout, stderr)
    hideIndicator()
    if exitCode == 0 and stdout then
      local text = stdout:gsub("^%s+", ""):gsub("%s+$", "")
      if #text > 0 and not text:match("^%[") and not text:match("^%(") then
        pasteText(text)
      else hs.alert.show("🔇  Nada capturado") end
    else
      hs.alert.show("⚠️  Erro na transcrição"); print("whisper stderr: " .. (stderr or ""))
    end
  end, args)
  t:start()
end
local function startRecording()
  recording = true; os.remove(WAV)
  recTask = hs.task.new(REC, nil, { "-q", "-c", "1", "-r", "16000", "-b", "16", WAV })
  recTask:start(); showIndicator()
end
local function stopAndTranscribe()
  recording = false
  if recTask then recTask:terminate(); recTask = nil end
  showIndicator("⏳  Processando…"); hs.timer.doAfter(0.35, transcribe)
end
local function toggle() if recording then stopAndTranscribe() else startRecording() end end

local lastTapTime, ctrlDown, interrupted = 0, false, false
local keyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(_)
  if ctrlDown then interrupted = true end
  lastTapTime = 0; return false
end)
local flagWatcher = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(e)
  local f = e:getFlags()
  local onlyCtrl = f.ctrl and not (f.cmd or f.alt or f.shift or f.fn)
  if onlyCtrl then
    ctrlDown = true; interrupted = false
  elseif next(f) == nil then
    if ctrlDown and not interrupted then
      local now = hs.timer.secondsSinceEpoch()
      if (now - lastTapTime) < DOUBLE_TAP_WINDOW then lastTapTime = 0; toggle()
      else lastTapTime = now end
    end
    ctrlDown = false
  else
    if ctrlDown then interrupted = true end
  end
  return false
end)
function M.start()
  keyWatcher:start(); flagWatcher:start()
  hs.alert.show("✅  Ditado Whisper ativo (Ctrl-Ctrl)")
end
function M.stop() keyWatcher:stop(); flagWatcher:stop() end
return M
LUA

# substitui os placeholders pelos caminhos/valores reais
sed -i '' \
  -e "s|__REC_BIN__|$REC_BIN|g" \
  -e "s|__WHISPER_BIN__|$WHISPER_BIN|g" \
  -e "s|__MODEL_NAME__|$MODEL_NAME|g" \
  -e "s|__LANG__|$LANG_CODE|g" \
  "$HS_DIR/whisper_dictation.lua"
ok "Módulo escrito em ~/.hammerspoon/whisper_dictation.lua"

# init.lua — cria ou adiciona a chamada sem apagar config existente
INIT="$HS_DIR/init.lua"
if [[ -f "$INIT" ]] && grep -q "whisper_dictation" "$INIT"; then
  ok "init.lua já carrega o ditado"
else
  if [[ -f "$INIT" ]]; then
    cp "$INIT" "$INIT.bak.$(date +%s)"
    warn "init.lua existente — backup criado, adicionando ao final"
  fi
  cat >> "$INIT" <<'INITLUA'

-- Ditado por voz local (Whisper) — Ctrl-Ctrl
require("hs.ipc")
hs.autoLaunch(true)  -- abre o Hammerspoon sozinho ao ligar o Mac
local __whisper_dictation = require("whisper_dictation")
__whisper_dictation.start()
INITLUA
  ok "init.lua configurado"
fi

# ---------- 5. (Re)inicia o Hammerspoon ----------
osascript -e 'quit app "Hammerspoon"' >/dev/null 2>&1 || true
sleep 1
open -a Hammerspoon
ok "Hammerspoon iniciado"

# ---------- 6. Passos manuais ----------
cat <<EOF

${B}${G}Instalação concluída!${N} Faltam 3 passos manuais (o macOS exige clique):

${B}1) Acessibilidade${N}  — para capturar o Ctrl-Ctrl e colar o texto
   Ajustes do Sistema ▸ Privacidade e Segurança ▸ Acessibilidade
   Ligue o ${B}Hammerspoon${N}. (Se já estava ligado, ${B}reinicie o app${N} depois.)

${B}2) Microfone${N}  — clique em ${B}Permitir${N} na 1ª vez que ditar.

${B}3) Desligar o Ditado da Apple${N}  — para não conflitar
   Ajustes do Sistema ▸ Teclado ▸ Ditado ▸ Atalho ▸ ${B}Desligado${N}.

${B}Como usar:${N} clique num campo de texto → ${B}Ctrl-Ctrl${N} → fale → ${B}Ctrl-Ctrl${N} → o texto cola sozinho.

Vou abrir as telas de Acessibilidade e Ditado pra você agora…
EOF
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" >/dev/null 2>&1 || true
open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension" >/dev/null 2>&1 || true
