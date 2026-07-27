# 🎤 Ditado por voz **local** no Mac (Whisper)

Transcrição de voz de alta qualidade, **100% offline**, acionada por **dois toques no Ctrl**, funcionando em **qualquer app** do macOS. Você fala, e o texto **cola sozinho** onde o cursor estiver — sem copiar e colar, sem mensalidade, e **o áudio nunca sai do seu Mac**.

Usa o mesmo motor de transcrição do ChatGPT (o modelo **Whisper**, da OpenAI, de código aberto), rodando localmente via [`whisper.cpp`](https://github.com/ggerganov/whisper.cpp), com o [Hammerspoon](https://www.hammerspoon.org/) cuidando do atalho e da colagem.

> **Por que local?** Nada de nuvem, nada de assinatura (apps equivalentes cobram ~US$8–17/mês), e privacidade total — ideal pra quem lida com informação sensível (advogados, saúde, etc.).

---

## ✅ Requisitos

- **Mac com Apple Silicon** (M1/M2/M3/M4) — recomendado. Roda em Intel, mas mais devagar.
- **macOS 13+**
- ~2 GB livres (modelo de transcrição)

---

## 🚀 Instalação automática (recomendada)

Abra o **Terminal** e cole:

```bash
curl -fsSL https://raw.githubusercontent.com/diegombraga/ditado-whisper-mac/main/install.sh | bash
```

O script instala tudo (Homebrew, whisper.cpp, Hammerspoon, o modelo) e configura o atalho. Ao final, ele te mostra os **3 cliques manuais** que o macOS exige (abaixo).

**Opções:**
```bash
# usar português por padrão já é o default; para inglês:
WHISPER_LANG=en curl -fsSL .../install.sh | bash

# Mac mais fraco? use um modelo menor (mais rápido, um pouco menos preciso):
WHISPER_MODEL=ggml-medium curl -fsSL .../install.sh | bash
```

---

## 🖱️ Os 3 passos manuais (obrigatórios)

O macOS não deixa um script conceder essas permissões — são cliques seus:

1. **Acessibilidade** — *Ajustes do Sistema ▸ Privacidade e Segurança ▸ Acessibilidade* → ligue o **Hammerspoon**. Se ele já estava aberto, **reinicie o app** depois de ligar.
2. **Microfone** — na **primeira vez** que ditar, clique em **Permitir**.
3. **Desligar o Ditado da Apple** — *Ajustes do Sistema ▸ Teclado ▸ Ditado ▸ Atalho ▸ **Desligado*** (senão ele dispara junto no Ctrl-Ctrl).

---

## 🎙️ Como usar

1. Clique num campo de texto qualquer (e-mail, Word, WhatsApp Web, etc.).
2. Aperte **Ctrl-Ctrl** → aparece **🎤 Gravando…** → **fale**.
3. Aperte **Ctrl-Ctrl** de novo → **⏳ Transcrevendo…** → o texto **cola sozinho**.

---

## 🔧 Instalação manual (passo a passo)

Prefere fazer na mão? É isto que o script automatiza:

```bash
# 1. Homebrew (se ainda não tiver)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Dependências
brew install whisper-cpp sox ffmpeg
brew install --cask hammerspoon

# 3. Modelo Whisper (~1,5 GB)
mkdir -p ~/Library/Application\ Support/whisper-dictation/models
curl -L -o ~/Library/Application\ Support/whisper-dictation/models/ggml-large-v3-turbo.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
```

4. Copie [`hammerspoon/whisper_dictation.lua`](hammerspoon/whisper_dictation.lua) para `~/.hammerspoon/`.
5. Adicione ao seu `~/.hammerspoon/init.lua`:
   ```lua
   require("hs.ipc")
   require("whisper_dictation").start()
   ```
6. Abra o Hammerspoon e faça os **3 passos manuais** acima.

---

## ⚙️ Ajustes finos

Edite `~/.hammerspoon/whisper_dictation.lua` (ele recarrega sozinho ao salvar):

| Variável | O que faz | Padrão |
|---|---|---|
| `LANG` | Idioma da fala (`"pt"`, `"en"`, `"auto"`) | `"pt"` |
| `DOUBLE_TAP_WINDOW` | Janela entre os dois toques no Ctrl (s) | `0.4` |
| `THREADS` | Núcleos usados na transcrição | `8` |
| `MODEL_NAME` | Modelo Whisper usado | `ggml-large-v3-turbo.bin` |

**Modelos disponíveis** (troque em `MODEL_NAME` e baixe o `.bin` correspondente): `ggml-base`, `ggml-small`, `ggml-medium`, `ggml-large-v3-turbo`, `ggml-large-v3`. Maiores = mais precisos e mais lentos.

---

## 🧹 Desinstalar

```bash
bash uninstall.sh
```

Ou na mão: remova `~/.hammerspoon/whisper_dictation.lua`, a linha do `require` no `init.lua`, e a pasta `~/Library/Application Support/whisper-dictation/`.

---

## ❓ Problemas comuns

- **Nada acontece no Ctrl-Ctrl** → Acessibilidade não concedida, ou o Hammerspoon precisa ser reiniciado após conceder.
- **Abre o Ditado da Apple junto** → falta desligar o atalho do Ditado (passo 3).
- **Cola texto errado / vazio ("Obrigado.")** → gravação em silêncio; é uma "alucinação" conhecida do Whisper em áudio mudo. Fale antes de parar.
- **Disparando sem querer ao digitar** → aumente `DOUBLE_TAP_WINDOW` para `0.3`, ou troque o gatilho.

---

## 🙏 Créditos

Este projeto é apenas a "cola" que amarra ferramentas de código aberto incríveis — todo o mérito da transcrição e da automação é delas:

- [**whisper.cpp**](https://github.com/ggerganov/whisper.cpp) (MIT) — motor de transcrição
- [**Whisper**](https://github.com/openai/whisper) da OpenAI (MIT) — o modelo de fala-para-texto
- [**Hammerspoon**](https://github.com/Hammerspoon/hammerspoon) (MIT) — automação do macOS
- [**SoX**](https://sourceforge.net/projects/sox/) e [**FFmpeg**](https://ffmpeg.org/) — captura de áudio
- [**Homebrew**](https://brew.sh/) — gerenciador de pacotes

Este repositório **não redistribui** nenhum desses softwares: o instalador baixa cada um da fonte oficial.

## 📄 Licença

MIT — use, modifique e compartilhe à vontade.
