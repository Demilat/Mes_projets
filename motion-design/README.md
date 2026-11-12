# Boîte à outils motion design

Vidéos animées en HTML rendues en MP4 avec **HyperFrames** (HeyGen, open source),
pilotées par Claude Code.

## Contenu

| Élément | Emplacement | Rôle |
| --- | --- | --- |
| 9 skills HyperFrames | `.claude/skills/` | Chargés automatiquement par Claude Code quand ce dépôt est ouvert |
| Script d'installation | `scripts/setup-motion-design.sh` | Installe la CLI et les outils locaux |
| Projets vidéo | `motion-design/<nom-du-projet>/` | Un dossier par vidéo |

Skills : `hyperframes`, `hyperframes-cli`, `hyperframes-registry` (~450 blocs prêts à l'emploi),
`media-use`, `slideshow`, `style-sampling`, `reverse-any-video`, `remotion-to-hyperframes`, `figma`.

## Installation (nouvelle session ou nouvelle machine)

```bash
bash scripts/setup-motion-design.sh            # tout
bash scripts/setup-motion-design.sh --no-music # sans MusicGen (plus léger)
```

Prérequis : Node.js 22+, FFmpeg. Le script installe en plus :

- **whisper.cpp** → transcription et sous-titres hors ligne
- **Kokoro** → voix off hors ligne (si pas de crédits ElevenLabs)
- **MusicGen** → musique de fond générée hors ligne

## Créer une vidéo

```bash
cd motion-design
npx hyperframes init ma-video --skip-skills --skill=hyperframes
cd ma-video
npx hyperframes check --json   # vérifier
npx hyperframes snapshot       # voir des images clés
npx hyperframes render         # exporter en MP4 (dossier renders/)
```

Ou simplement demander à Claude : « Fais-moi une vidéo de 20 s en 9:16 sur … ».

## Mettre à jour les skills

```bash
npx -y skills add heygen-com/hyperframes --agent claude-code -y
```

## Commandes utiles hors ligne

```bash
npx hyperframes tts "Bonjour !" --voice ff_siwis -o assets/voix.wav          # voix FR (Kokoro)
npx hyperframes transcribe assets/voix.wav --model medium --language fr --to srt -o assets/voix.srt
node .claude/skills/media-use/audio/scripts/audio.mjs --request audio_request.json --hyperframes . --out audio_meta.json  # musique MusicGen
```

En session cloud, l'environnement **« Mes projets – motion design »** autorise Hugging Face,
les releases GitHub et PyTorch (nécessaires pour télécharger les modèles) et lance
ce script automatiquement au démarrage.

Note : les skills envoient une télémétrie d'usage à HeyGen (`npx hyperframes events`),
désactivable via `npx hyperframes telemetry disable`.
