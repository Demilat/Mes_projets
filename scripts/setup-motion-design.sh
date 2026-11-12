#!/usr/bin/env bash
# Installe la boîte à outils motion design (HyperFrames + outils locaux).
# Idempotent : on peut le relancer sans risque.
#   bash scripts/setup-motion-design.sh            # tout installer
#   bash scripts/setup-motion-design.sh --no-music # sans MusicGen (torch, ~1 Go)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WITH_MUSIC=1
[[ "${1:-}" == "--no-music" ]] && WITH_MUSIC=0
PIP="python3 -m pip install --quiet --break-system-packages"

echo "==> Vérification de Node.js (>= 22) et FFmpeg"
node -e 'process.exit(+process.versions.node.split(".")[0] >= 22 ? 0 : 1)' \
  || { echo "Node.js 22+ requis"; exit 1; }
command -v ffmpeg >/dev/null || { echo "FFmpeg requis (apt-get install -y ffmpeg)"; exit 1; }

echo "==> Skills HyperFrames (copie globale dans ~/.claude/skills)"
mkdir -p "$HOME/.claude/skills"
cp -r "$REPO_DIR/.claude/skills/." "$HOME/.claude/skills/"

echo "==> CLI HyperFrames (mise en cache npx)"
npx -y hyperframes --version >/dev/null

echo "==> whisper.cpp (transcription locale / sous-titres)"
if ! command -v whisper-cli >/dev/null; then
  for t in git cmake g++; do
    command -v "$t" >/dev/null || { apt-get update -qq && apt-get install -y -qq git cmake build-essential; break; }
  done
  [[ -d /opt/whisper.cpp ]] || git clone --depth 1 https://github.com/ggml-org/whisper.cpp /opt/whisper.cpp
  cmake -S /opt/whisper.cpp -B /opt/whisper.cpp/build -DCMAKE_BUILD_TYPE=Release >/dev/null
  cmake --build /opt/whisper.cpp/build -j"$(nproc)" --config Release >/dev/null
  ln -sf /opt/whisper.cpp/build/bin/whisper-cli /usr/local/bin/whisper-cli
fi

echo "==> Kokoro (voix off locale)"
$PIP kokoro-onnx soundfile

if [[ $WITH_MUSIC == 1 ]]; then
  echo "==> MusicGen (musique de fond locale, torch CPU)"
  # torch CPU (léger) ; à défaut, la version PyPI (plus lourde).
  python3 -c "import torch" 2>/dev/null \
    || $PIP torch --index-url https://download.pytorch.org/whl/cpu \
    || $PIP torch
  $PIP transformers soundfile numpy
fi

# Derrière un proxy HTTPS, Node (fetch) a besoin de NODE_USE_ENV_PROXY=1
# pour télécharger les modèles (définie dans l'environnement cloud).
export NODE_USE_ENV_PROXY=1

echo "==> chrome-headless-shell (capture rapide HeadlessExperimental.beginFrame)"
# Hôtes requis : googlechromelabs.github.io, storage.googleapis.com.
# Non bloquant : sans lui, HyperFrames retombe sur le Chrome système (plus lent).
CHS_DIR=/opt/chrome-headless-shell
CHS_LINK=/usr/local/bin/chrome-headless-shell
if [[ ! -x $CHS_LINK ]]; then
  if CHS_OUT=$(npx -y @puppeteer/browsers install chrome-headless-shell --path "$CHS_DIR" 2>/dev/null | tail -1); then
    ln -sf "${CHS_OUT#* }" "$CHS_LINK"
  else
    echo "   (téléchargement impossible : on garde le Chrome système)"
  fi
fi
# HyperFrames ne le détecte pas seul : HYPERFRAMES_BROWSER_PATH=$CHS_LINK
# est défini dans les variables de l'environnement cloud.
[[ -x $CHS_LINK ]] && export HYPERFRAMES_BROWSER_PATH=$CHS_LINK

echo "==> Démon Docker (rendus HyperFrames dans Docker)"
# `service docker start` échoue dans le conteneur cloud (ulimit interdit) :
# on lance dockerd directement, détaché. Non bloquant.
if command -v dockerd >/dev/null && ! docker info >/dev/null 2>&1; then
  setsid nohup dockerd >/var/log/dockerd.log 2>&1 < /dev/null &
  for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
  docker info >/dev/null 2>&1 \
    || echo "   (dockerd n'a pas démarré : voir /var/log/dockerd.log)"
fi

echo "==> Diagnostic"
npx -y hyperframes doctor || true
echo "Terminé."
