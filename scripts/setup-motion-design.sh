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

echo "==> Diagnostic"
npx -y hyperframes doctor || true
echo "Terminé."
