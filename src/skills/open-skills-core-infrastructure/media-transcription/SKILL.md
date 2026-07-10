---
name: media-transcription
description: Transcribe local audio or video files using the AssemblyAI API. Produces clean Markdown transcript, word-level timestamps, semantic chapters, and speaker labels. Use when given a media file and needing a transcript, captions, or chapters.
---

# Media Transcription

Take a local audio or video file and produce a complete transcription package using the AssemblyAI API. Getting the packaging right once -- consistent filenames, chapters, timestamps -- makes downstream skills composable.

## Trigger Conditions

- User gives a media file and asks for a transcript
- User asks for captions, subtitles, or chapters from a video
- User says "make this searchable" about a media file
- Any editing or research workflow that starts from media

## Setup

On first use, interview for:
- Where the AssemblyAI API key is stored (env file)
- Where transcription outputs should be saved (suggest a folder next to the source media: `source-media/_transcripts/`)

## Step 1: Extract Audio (Video Only)

If the input is a video file, extract audio first with ffmpeg:

```bash
ffmpeg -i "<input-video>" -vn -acodec mp3 "<output-audio>.mp3"
```

Check that ffmpeg is installed. If not, install it.

## Step 2: Transcribe

```bash
curl https://api.assemblyai.com/v2/transcript \
  -H "Authorization: $ASSEMBLYAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "audio_url": "<presigned-url-or-local-path>",
    "speaker_labels": true,
    "auto_chapters": true,
    "word_boost": [],
    "speech_model": "best"
  }'
```

Then poll for completion:

```bash
curl https://api.assemblyai.com/v2/transcript/<transcript-id> \
  -H "Authorization: $ASSEMBLYAI_API_KEY"
```

When `status` is `completed`, retrieve the results.

## Step 3: Output Package

Produce these artifacts with consistent filenames:

```
source-media/_transcripts/
├── <media-name>.transcript.md       # Clean readable Markdown transcript
├── <media-name>.timestamps.json     # Word-level timestamps
├── <media-name>.chapters.md         # Semantic chapters with timestamps
├── <media-name>.speakers.json       # Speaker labels and segments
└── <media-name>.full.json           # Raw API response (for debugging)
```

### Markdown Transcript Format
```markdown
# <media-name>

**Duration**: HH:MM:SS
**Speakers**: N detected
**Transcribed**: YYYY-MM-DD

---

## Chapters

1. [00:00] Introduction
2. [02:15] Main Topic
...

---

## Transcript

**Speaker A** [00:00:00]: <text>
**Speaker B** [00:00:05]: <text>
...
```

## Consistency Rule

These artifacts are inputs for editing and research skills. The format must stay consistent across all transcriptions so downstream skills can rely on it.

## Verification

Test on a short audio file. Show the output package with transcript, timestamps, chapters, and speaker labels.
