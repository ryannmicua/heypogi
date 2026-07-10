---
name: nle-assistant
description: Operate video editing software (DaVinci Resolve) directly through its Python scripting API -- transcript-driven editing, silence removal, subclip extraction, and timeline building inside real projects. Use when editing requests should happen inside the editor, not as file exports.
---

# AI Editing Assistant (NLE Integration)

Connect the agent directly to your video editing software so it operates inside the editor: analyzing transcripts, removing silences, extracting subclips, making editorial decisions, and building timelines programmatically in your real project.

## Trigger Conditions

- Editing requests that should happen inside the editor:
  - "Remove the silences from this interview"
  - "Pull every clip where she mentions pricing"
  - "Build a rough timeline of the best moments"
- User wants the agent to manipulate their actual project, not produce importable files
- Transcript-driven editing that benefits from direct timeline access

## Prerequisites

- DaVinci Resolve (free version includes the Python scripting API) or other scriptable NLE
- `media-transcription` skill for transcript-driven edits
- Comfort letting an agent operate real software (this works on duplicated timelines only)

## Connection

Verify you can connect to a running Resolve instance:

```python
import DaVinciResolveScript as dvr

resolve = dvr.scriptapp("Resolve")
if not resolve:
    raise RuntimeError("Resolve is not running. Open the application first.")

project_manager = resolve.GetProjectManager()
current_project = project_manager.GetCurrentProject()
if not current_project:
    raise RuntimeError("No project is open. Open a project first.")

print(f"Connected to project: {current_project.GetName()}")
```

### Connection Failure Modes
| Symptom | Fix |
|---------|-----|
| "Resolve is not running" | Open DaVinci Resolve |
| "No project is open" | Open or create a project in Resolve |
| Import error for DaVinciResolveScript | Add Resolve's scripting folder to PATH/PYTHONPATH |
| API calls return None | Ensure media pool and timeline are loaded |

## Safety Rule (Hard)

**ALWAYS duplicate the timeline and work on the copy.** Never modify an original timeline or delete media.

```python
# Before any operation
timeline = current_project.GetCurrentTimeline()
timeline_name = timeline.GetName()
safe_timeline_name = f"{timeline_name}_AGENT_WORK"

# Check if copy already exists, create if not
existing = [t.GetName() for t in current_project.GetTimelineList()]
if safe_timeline_name not in existing:
    media_pool = current_project.GetMediaPool()
    media_pool.DuplicateTimeline(timeline_name, safe_timeline_name)

# Work on the copy
safe_timeline = current_project.GetTimelineByIndex(
    [t.GetName() for t in current_project.GetTimelineList()].index(safe_timeline_name) + 1
)
```

## Core Operations

### 1. Import Media
```python
media_storage = resolve.GetMediaStorage()
media_pool = current_project.GetMediaPool()
clips = media_storage.AddItemListToMediaPool(["/path/to/video.mp4"])
```

### 2. Read / Mark Clips
```python
timeline_items = timeline.GetItemListInTrack("video", 1)
for item in timeline_items:
    name = item.GetName()
    start = item.GetStart()
    end = item.GetEnd()
    duration = end - start
```

### 3. Cut at Timecodes
Apply cuts at transcript-derived timecodes:
```python
# For each cut point in the edit list
timeline.AddMarker(frame_index, "Red", "Cut", "Silence removal", 1)
# Or use the blade/cut operation
```

### 4. Remove Segments
```python
# Select the item between cut points and delete
item.Delete()
```

### 5. Build Timelines from Edit List
```python
# From transcript-derived edit list:
# { "keep": [(in_01, out_01), (in_02, out_02), ...] }
new_timeline = media_pool.CreateEmptyTimeline("Rough Cut")
# Add clips at specified timecodes
```

## Integration with Media Transcription

Transcripts drive the edits:
1. Transcribe source media via `media-transcription` skill
2. Identify cut points from transcript (silences, filler, tangents)
3. Map transcript timecodes to timeline frame positions
4. Execute cuts via Resolve API
5. Show the result for review

## Verification

Test against a throwaway project:
1. Duplicate a timeline
2. Remove silences from one clip
3. Show the result in the app before touching anything real
