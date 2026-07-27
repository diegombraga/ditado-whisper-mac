#!/usr/bin/env bash
# Remove o ditado por voz local (nao desinstala Homebrew nem apps de sistema).
set -euo pipefail
G=$'\033[32m'; N=$'\033[0m'

echo "Removendo ditado por voz local…"

# para o Hammerspoon
osascript -e 'quit app "Hammerspoon"' >/dev/null 2>&1 || true

# remove o modulo e a linha do init.lua
rm -f "$HOME/.hammerspoon/whisper_dictation.lua"
if [[ -f "$HOME/.hammerspoon/init.lua" ]]; then
  # remove o bloco do ditado
  sed -i '' '/Ditado por voz local (Whisper)/d; /require("whisper_dictation")/d; /__whisper_dictation/d' \
    "$HOME/.hammerspoon/init.lua" 2>/dev/null || true
fi

# remove modelos e temporarios
rm -rf "$HOME/Library/Application Support/whisper-dictation"

echo "${G}✓${N} Removido."
echo "Opcional (se não usar em mais nada):"
echo "  brew uninstall whisper-cpp sox"
echo "  brew uninstall --cask hammerspoon"
echo "Reative o Ditado da Apple em Ajustes ▸ Teclado ▸ Ditado, se quiser."
