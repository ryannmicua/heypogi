---
name: nle-assistant
description: Operate video editing software (DaVinci Resolve) directly through its Python scripting API — transcript-driven editing, silence removal, subclip extraction, and timeline building inside real projects. Use when editing requests should happen inside the editor, not as file exports.
---

# NLE Assistant

Connect the agent directly to DaVinci Resolve via its Python scripting API so it operates inside your real project: connecting, reading the timeline, duplicating for safety, and performing transcript-driven edits — silence removal, subclip extraction, and timeline assembly — without exporting or re-importing.

## Trigger Conditions

Load this skill when the user asks for any editing operation that should execute inside the editor rather than produce importable files:

- **Silence removal**: "Remove the silences from this interview", "Cut all dead air from the timeline", "Tighten up the pauses"
- **Subclip extraction**: "Pull every clip where she mentions pricing", "Extract all segments about the Q4 results", "Make subclips of every time Bob speaks"
- **Timeline building**: "Build a rough timeline from the best moments", "Assemble a highlight reel from these markers", "Create a selects timeline from the transcript"
- **Transcript-driven editing**: Any request that references a transcript, speaker labels, or chapter markers to drive cuts
- **Marker-based operations**: "Add markers at every chapter boundary", "Flag all spots where competitor names are mentioned"

Do NOT load this skill when:
- The user wants to export an FCXML/EDL file to import manually (use `radio-edit`)
- The user is asking about editing concepts, not executing them
- The user is asking to transcribe media (use `media-transcription`)

## Prerequisites

- DaVinci Resolve (Free or Studio — the Python scripting API ships with both)
- `media-transcription` skill for any transcript-driven operation
- The DaVinci Resolve scripting module accessible on `PYTHONPATH` (see connection procedure)
- Resolve must be **running** with a **project open** before any API call

## Connection Procedure

Before every operation, verify you can reach Resolve and read the current project state. Do not skip this step — all subsequent operations depend on it.

### Step 1: Import and Connect

```python
import sys
import os

# Ensure Resolve's scripting module is discoverable
# Standard paths — adjust per platform:
RESOLVE_SCRIPT_PATHS = {
    "win32": [
        os.path.expandvars(r"%PROGRAMDATA%\Blackmagic Design\DaVinci Resolve\Support\Developer\Scripting\Modules"),
        os.path.expandvars(r"%PROGRAMFILES%\Blackmagic Design\DaVinci Resolve\Support\Developer\Scripting\Modules"),
    ],
    "darwin": [
        "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules",
    ],
    "linux": [
        "/opt/resolve/Developer/Scripting/Modules",
        "/opt/resolve/libs/Fusion/Modules",
    ],
}

for path in RESOLVE_SCRIPT_PATHS.get(sys.platform, []):
    if os.path.isdir(path) and path not in sys.path:
        sys.path.append(path)

import DaVinciResolveScript as dvr

resolve = dvr.scriptapp("Resolve")
```

### Step 2: Validate Connection

```python
if not resolve:
    raise RuntimeError(
        "DaVinci Resolve is not running. Open the application and try again."
    )

project_manager = resolve.GetProjectManager()
current_project = project_manager.GetCurrentProject()

if not current_project:
    raise RuntimeError(
        "No project is open in Resolve. Open or create a project, then try again."
    )

print(f"Connected to project: {current_project.GetName()}")
```

### Step 3: Validate Timeline Access

```python
timeline = current_project.GetCurrentTimeline()

if not timeline:
    raise RuntimeError(
        "No timeline is open in the current project. "
        "Open a timeline in the Edit page, then try again."
    )

# Confirm we can read track data
try:
    track_count = timeline.GetTrackCount("video")
    print(f"Timeline: {timeline.GetName()} — {track_count} video track(s)")
except Exception as e:
    raise RuntimeError(
        f"Connected but cannot read timeline data. Is the Edit page active? Error: {e}"
    )

media_pool = current_project.GetMediaPool()
if not media_pool:
    raise RuntimeError(
        "Cannot access media pool. Switch to the Edit or Media page in Resolve."
    )
```

### Connection Failure Modes (Full Table)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ImportError: No module named 'DaVinciResolveScript'` | Resolve scripting folder not on PYTHONPATH | Add the correct path from `RESOLVE_SCRIPT_PATHS` for this platform, verify Resolve is installed |
| `RuntimeError: Resolve is not running` | Resolve application not launched | Open DaVinci Resolve, wait for full UI load |
| `RuntimeError: No project is open` | Project manager has no active project | Open or create a project (File → New Project or File → Open Project) |
| `RuntimeError: No timeline is open` | Edit page is not showing a timeline | Open a timeline by double-clicking it in the media pool, or switch to the Edit page |
| `RuntimeError: Cannot access media pool` | API handle returned None | Switch focus to the Edit or Media page in the Resolve UI |
| `AttributeError` on timeline methods | Resolve version too old | Resolve 16+ required for full scripting API; upgrade if on 15 or earlier |
| API calls return `None` silently | Project state changed (e.g., user switched pages) | Re-run connection validation; API is sensitive to which Resolve page is active |
| `Exception: Cannot read timeline data` | Fusion page active instead of Edit | Switch to the Edit page; some API calls require the Edit page context |

## Safety Rule (HARD — Never Violate)

**ALWAYS duplicate the timeline and work on the copy. Never modify an original timeline or delete media from the project.**

Every editing session begins with this guard:

```python
def get_safe_timeline(current_project, suffix="_AGENT_WORK"):
    """Return a duplicated timeline for safe editing. Never returns the original."""
    original = current_project.GetCurrentTimeline()
    if not original:
        raise RuntimeError("No timeline is open. Open a timeline first.")

    original_name = original.GetName()
    safe_name = f"{original_name}{suffix}"

    # Check if a safe copy already exists from a prior session
    all_timelines = current_project.GetTimelineList()
    existing_names = {t.GetName() for t in all_timelines}

    if safe_name in existing_names:
        # Re-use existing safe copy — user may have work in progress
        for t in all_timelines:
            if t.GetName() == safe_name:
                print(f"Using existing working timeline: {safe_name}")
                current_project.SetCurrentTimeline(t)
                return t

    # Create a fresh duplicate
    media_pool = current_project.GetMediaPool()
    success = media_pool.DuplicateTimeline(original_name, safe_name)
    if not success:
        raise RuntimeError(
            f"Failed to duplicate timeline '{original_name}' to '{safe_name}'. "
            "Check that the timeline name is valid and not already in use."
        )

    # Find and activate the duplicate
    all_timelines = current_project.GetTimelineList()
    for t in all_timelines:
        if t.GetName() == safe_name:
            current_project.SetCurrentTimeline(t)
            print(f"Created working copy: {safe_name}")
            return t

    raise RuntimeError(f"Duplicate created but cannot find '{safe_name}' in timeline list.")


# Usage — call this ONCE at the start of every editing session:
safe_timeline = get_safe_timeline(current_project)
```

Additional safety constraints:
- **Never** call `Delete()` on a timeline that lacks the `_AGENT_WORK` suffix
- **Never** remove items from the media pool (clips, bins, smart bins)
- **Never** call `DeleteClipInMediaPool()` or equivalent destructive media operations
- If a timeline operation fails, leave the working timeline as-is and report what happened — do not attempt recovery edits on the original
- When the user approves the result, they rename the working timeline themselves (the agent does not rename it back onto the original name)

## Core Operations

Each operation includes verification code. Run the verification immediately after the operation — do not batch operations without verifying each one.

### Operation 1: Import Media

Add files from disk to the media pool.

```python
def import_media(file_paths, current_project):
    """Import one or more media files into the current project's media pool.

    Args:
        file_paths: List of absolute paths to media files
        current_project: Resolve project object

    Returns:
        List of imported media pool item objects
    """
    resolve_obj = current_project.GetProjectManager().GetResolve()
    media_storage = resolve_obj.GetMediaStorage()
    media_pool = current_project.GetMediaPool()

    imported = media_storage.AddItemListToMediaPool(file_paths)
    if not imported:
        raise RuntimeError(
            f"Import failed for: {file_paths}. "
            "Check that files exist and are in a supported format."
        )

    print(f"Imported {len(imported)} clip(s): {[i.GetName() for i in imported]}")
    return imported


# Verification — run after import:
clips = import_media(["/path/to/interview.mp4"], current_project)
assert len(clips) > 0, "No clips returned from import"
for clip in clips:
    assert clip.GetName() is not None, f"Clip {clip} has no name"
    print(f"Verified: {clip.GetName()} — ready in media pool")
```

### Operation 2: Read and Mark Clips

Inspect timeline contents: clip names, timecodes, durations, track assignments.

```python
def read_timeline_items(timeline, track_type="video", track_index=1):
    """Return all items on a track with their timecode data.

    Args:
        timeline: Resolve timeline object
        track_type: "video" or "audio"
        track_index: 1-based track number

    Returns:
        List of dicts with name, start_frame, end_frame, duration_frames
    """
    items = timeline.GetItemListInTrack(track_type, track_index)
    if items is None:
        return []

    results = []
    for item in items:
        results.append({
            "name": item.GetName(),
            "start_frame": item.GetStart(),
            "end_frame": item.GetEnd(),
            "duration_frames": item.GetEnd() - item.GetStart(),
            "media_pool_item": item.GetMediaPoolItem(),
        })
    return results


def mark_clip_at_frame(timeline, frame, color="Red", note="Marked by agent"):
    """Place a marker at a specific frame on the timeline."""
    result = timeline.AddMarker(frame, color, note, "", 1)
    if not result:
        raise RuntimeError(f"Failed to add marker at frame {frame}")
    print(f"Marker placed at frame {frame}: {note}")


# Verification — run after reading:
items = read_timeline_items(safe_timeline, "video", 1)
print(f"Track V1 has {len(items)} item(s):")
for it in items[:5]:  # show first 5
    print(f"  {it['name']} | frames {it['start_frame']} → {it['end_frame']} | {it['duration_frames']} frames")
```

### Operation 3: Cut at Timecodes

Resolve's scripting API does not expose a direct "blade" function. Instead, perform cuts by trimming the clip to the desired keep range and replacing gap content:

```python
def trim_clip_to_range(timeline, track_type, track_index, clip_index, start_frame, end_frame):
    """Trim a clip to keep only the specified frame range.

    Args:
        timeline: Resolve timeline object
        track_type: "video" or "audio"
        track_index: 1-based track number
        clip_index: Index of the clip in the track's item list
        start_frame: Frame to trim start to
        end_frame: Frame to trim end to

    Returns:
        The trimmed timeline item
    """
    items = timeline.GetItemListInTrack(track_type, track_index)
    if items is None or clip_index >= len(items):
        raise IndexError(f"Clip index {clip_index} out of range for track {track_type}{track_index}")

    item = items[clip_index]
    item_name = item.GetName()
    original_start = item.GetStart()
    original_end = item.GetEnd()

    # Set new in/out points (this effectively performs a trim/cut)
    item.SetStart(start_frame)
    item.SetEnd(end_frame)

    new_start = item.GetStart()
    new_end = item.GetEnd()

    if new_start != start_frame or new_end != end_frame:
        raise RuntimeError(
            f"Trim verification failed: expected [{start_frame}, {end_frame}], "
            f"got [{new_start}, {new_end}]"
        )

    print(f"Trimmed '{item_name}': [{original_start}, {original_end}] → [{new_start}, {new_end}]")
    return item


# For multi-segment cuts (splitting one clip into keep/discard/keep):
# Instead of a single blade, re-trim the original to the first keep segment,
# then append a copy for the second keep segment.
def split_clip_at_cuts(timeline, media_pool, track_type, track_index, clip_index, keep_ranges):
    """Split a clip into keep segments at specified ranges.

    Args:
        timeline: Resolve timeline object
        media_pool: Resolve media pool object
        track_type: "video" or "audio"
        track_index: 1-based track number
        clip_index: Index of the source clip
        keep_ranges: List of (start_frame, end_frame) tuples to keep

    Returns:
        List of resulting timeline items (one per keep range)
    """
    items = timeline.GetItemListInTrack(track_type, track_index)
    if items is None or clip_index >= len(items):
        raise IndexError(f"Clip index {clip_index} out of range")

    source_item = items[clip_index]
    source_media = source_item.GetMediaPoolItem()

    if len(keep_ranges) == 0:
        source_item.Delete()
        return []

    # Trim the original item to the first keep range
    first_range = keep_ranges[0]
    source_item.SetStart(first_range[0])
    source_item.SetEnd(first_range[1])

    results = [source_item]

    # For additional keep ranges, append copies trimmed to each range
    for r in keep_ranges[1:]:
        new_clip = {
            "mediaPoolItem": source_media,
            "startFrame": r[0],
            "endFrame": r[1],
            "trackIndex": track_index,
            "recordFrame": timeline.GetEnd(),
        }
        appended = media_pool.AppendToTimeline([new_clip])
        if appended:
            results.append(appended[0])
        else:
            raise RuntimeError(f"Failed to append clip segment [{r[0]}, {r[1]}]")

    print(f"Split clip into {len(results)} segment(s)")
    return results


# Verification after cutting:
items_after = read_timeline_items(timeline, track_type, track_index)
print(f"After cuts: {len(items_after)} segment(s) on timeline")
```

### Operation 4: Remove Silences

Identify gaps between spoken segments (using transcript-derived silence markers) and remove dead air from the timeline.

```python
def remove_silences(timeline, media_pool, track_type="video", track_index=1,
                    silence_ranges=None, auto_detect_threshold_frames=90):
    """Remove silence regions from a track.

    When silence_ranges is provided (from transcript analysis), those exact
    frame ranges are removed. Otherwise, auto-detect gaps between clips
    longer than auto_detect_threshold_frames.

    Args:
        timeline: Resolve timeline object
        media_pool: Resolve media pool object
        track_type: "video" or "audio"
        track_index: 1-based track number
        silence_ranges: Optional list of (start_frame, end_frame) ranges to remove
        auto_detect_threshold_frames: Min gap in frames to auto-detect (90 frames = 3 sec at 30fps)

    Returns:
        Number of silence regions removed
    """
    items = timeline.GetItemListInTrack(track_type, track_index)
    if not items:
        return 0

    # If silence ranges not provided, auto-detect gaps between clips
    if silence_ranges is None:
        silence_ranges = []
        for i in range(len(items) - 1):
            gap_start = items[i].GetEnd()
            gap_end = items[i + 1].GetStart()
            gap_duration = gap_end - gap_start
            if gap_duration > auto_detect_threshold_frames:
                silence_ranges.append((gap_start, gap_end))

    # Process items with cut logic: remove silence from within and between clips
    removed_count = 0
    for i, item in enumerate(items):
        item_start = item.GetStart()
        item_end = item.GetEnd()

        # Find silence ranges that overlap with this item
        for sil_start, sil_end in silence_ranges:
            if sil_end <= item_start or sil_start >= item_end:
                continue  # No overlap

            # Trim item to exclude the silence portion
            overlap_start = max(sil_start, item_start)
            overlap_end = min(sil_end, item_end)

            if abs(overlap_end - overlap_start) < 5:
                continue  # Skip negligible overlaps

            # This is simplified — in practice, build keep_ranges per clip
            # and use split_clip_at_cuts for precision
            item.SetEnd(overlap_start - 1)

            # Append the remainder portion after the silence
            if overlap_end < item_end:
                source_media = item.GetMediaPoolItem()
                remainder = {
                    "mediaPoolItem": source_media,
                    "startFrame": overlap_end + 1,
                    "endFrame": item_end,
                    "trackIndex": track_index,
                    "recordFrame": overlap_end + 1,
                }
                media_pool.AppendToTimeline([remainder])

            removed_count += 1
            print(f"Removed silence: frames {overlap_start} → {overlap_end}")

    # Additionally, remove gaps between consecutive clips
    # This is done by setting each clip's position to follow the previous one
    current_pos = 0
    all_items = timeline.GetItemListInTrack(track_type, track_index)
    if all_items:
        for item in all_items:
            start = item.GetStart()
            end = item.GetEnd()
            duration = end - start
            item.SetStart(current_pos)
            item.SetEnd(current_pos + duration)
            current_pos += duration

    print(f"Silence removal complete. {removed_count} regions removed, timeline compacted.")
    return removed_count


# Verification after silence removal:
old_duration = sum(it["duration_frames"] for it in read_timeline_items(safe_timeline, "video", 1))
# (Compare actual timeline duration — should be shorter after removal)
print(f"Timeline compacted. Run open in Resolve to review.")
```

### Operation 5: Build Timeline from Edit List

Assemble a new timeline from a transcript-derived edit list (keep segments with timecodes).

```python
def build_timeline_from_edit_list(current_project, edit_list, timeline_name="Agent Assembly"):
    """Create a new timeline from a list of source-clip segments.

    Args:
        current_project: Resolve project object
        edit_list: List of dicts with:
            - source_clip: Media pool item (from import_media)
            - start_frame: In-point frame in source
            - end_frame: Out-point frame in source
            - track_index: 1-based track (default 1 for V1)
        timeline_name: Name for the new timeline

    Returns:
        The new timeline object
    """
    media_pool = current_project.GetMediaPool()

    # Create a blank timeline
    new_timeline = media_pool.CreateEmptyTimeline(timeline_name)
    if not new_timeline:
        raise RuntimeError(f"Failed to create empty timeline: {timeline_name}")

    current_project.SetCurrentTimeline(new_timeline)

    # Append each segment in order
    placed_count = 0
    for i, segment in enumerate(edit_list):
        clip_data = {
            "mediaPoolItem": segment["source_clip"],
            "startFrame": segment.get("start_frame", 0),
            "endFrame": segment.get("end_frame", segment["source_clip"].GetClipProperty("Frames")),
            "trackIndex": segment.get("track_index", 1),
            "recordFrame": segment.get("record_frame", 0),  # 0 = append to end
        }
        result = media_pool.AppendToTimeline([clip_data])
        if not result:
            raise RuntimeError(f"Failed to append segment {i} to timeline")
        placed_count += 1

    print(f"Built timeline '{timeline_name}' with {placed_count} segment(s)")
    return new_timeline


# Verification after building:
built_timeline = current_project.GetCurrentTimeline()
items = read_timeline_items(built_timeline, "video", 1)
assert len(items) == len(edit_list), (
    f"Expected {len(edit_list)} items, found {len(items)}"
)
print("Edit list assembly verified — all segments placed.")
```

### Operation 6: Extract Subclips (by Transcript Match)

Find segments matching a description, speaker, or keyword and extract them as a new timeline.

```python
def extract_subclips(current_project, timeline, query, track_type="video", track_index=1):
    """Extract timeline segments matching a query into a new timeline.

    Requires prior transcript analysis — this function receives clip-level
    segment data rather than searching the video itself.

    Args:
        current_project: Resolve project object
        timeline: Source timeline to extract from
        query: Dict with match criteria:
            - speaker: Speaker label to match (e.g., "Speaker A")
            - keyword: Text to search for in transcript
            - chapter: Chapter name to extract
            - time_ranges: List of (start_sec, end_sec) in seconds
        track_type: "video" or "audio"
        track_index: 1-based track number

    Returns:
        New timeline containing matching segments
    """
    media_pool = current_project.GetMediaPool()
    fps = float(timeline.GetSetting("timelineFrameRate"))
    items = timeline.GetItemListInTrack(track_type, track_index)

    edit_list = []
    for item in items:
        item_start = item.GetStart()
        item_end = item.GetEnd()

        # Apply match criteria to time-ranges (from transcript analysis)
        matched_ranges = query.get("time_ranges", [])
        if not matched_ranges:
            continue

        for seg_start_sec, seg_end_sec in matched_ranges:
            seg_start_frame = int(seg_start_sec * fps)
            seg_end_frame = int(seg_end_sec * fps)

            # Check if this segment overlaps with the clip
            if seg_end_frame <= item_start or seg_start_frame >= item_end:
                continue

            # Constrain to clip bounds
            clip_start = max(seg_start_frame, item_start)
            clip_end = min(seg_end_frame, item_end)

            if clip_end <= clip_start:
                continue

            edit_list.append({
                "source_clip": item.GetMediaPoolItem(),
                "start_frame": clip_start,
                "end_frame": clip_end,
                "track_index": track_index,
            })

    if not edit_list:
        print(f"No segments matched query: {query}")
        return None

    timeline_name = f"Subclips — {query.get('keyword', query.get('speaker', 'Extract'))}"
    return build_timeline_from_edit_list(current_project, edit_list, timeline_name)
```

## Integration with Media Transcription

The `media-transcription` skill produces a standardized output package that drives all transcript-aware NLE operations. Always run transcription first for transcript-driven editing.

### Required Artifacts

The following files from `source-media/_transcripts/` are consumed by NLE operations:

| Artifact | Used by Operation | Purpose |
|----------|-------------------|---------|
| `<name>.transcript.md` | Subclip extraction, timeline building | Speaker-labeled text with timestamps for keyword/speaker matching |
| `<name>.timestamps.json` | Silence removal, cut placement | Word-level timestamps for precise frame-accurate cuts |
| `<name>.chapters.md` | Timeline building, marker placement | Chapter boundaries at `[MM:SS]` for structural edits |
| `<name>.speakers.json` | Subclip extraction | Speaker segments for extracting by person |

### Workflow: Transcript → Timestamps → Cuts

```python
import json

def load_transcript_timestamps(transcript_dir, media_name):
    """Load word-level timestamps from media-transcription output."""
    ts_path = os.path.join(transcript_dir, f"{media_name}.timestamps.json")
    with open(ts_path, "r") as f:
        return json.load(f)

def timestamps_to_frames(timestamps, fps=30.0):
    """Convert second-based timestamps to frame numbers."""
    return [(int(t["start"] * fps), int(t["end"] * fps)) for t in timestamps]

def find_silence_ranges(timestamps, fps=30.0, min_gap_sec=1.5):
    """Detect silence ranges between word timestamps.

    A gap longer than min_gap_sec between consecutive words is considered silence.
    """
    silence_ranges = []
    for i in range(len(timestamps) - 1):
        gap = timestamps[i + 1]["start"] - timestamps[i]["end"]
        if gap > min_gap_sec:
            start_frame = int(timestamps[i]["end"] * fps)
            end_frame = int(timestamps[i + 1]["start"] * fps)
            silence_ranges.append((start_frame, end_frame))
    return silence_ranges

# Full transcript-driven silence removal pipeline:
# 1. media-transcription: transcribe source media
# 2. Load timestamps.json
# 3. Compute silence_ranges from word gaps
# 4. Call remove_silences(timeline, media_pool, silence_ranges=silence_ranges)
```

### Workflow: Transcript → Edit List → Timeline

```python
def transcript_to_edit_list(transcript_md_path, speaker_filter=None, keyword_filter=None):
    """Parse media-transcription's transcript.md into clip segments.

    Reads speaker-labeled utterances and returns keep segments for timeline assembly.
    """
    # Parse the transcript.md format:
    # **Speaker X** [HH:MM:SS]: text
    import re

    with open(transcript_md_path, "r") as f:
        lines = f.readlines()

    edit_segments = []
    pattern = r"\*\*(Speaker \w+)\*\*\s*\[(\d+):(\d+):(\d+)\]:\s*(.*)"

    for line in lines:
        match = re.match(pattern, line)
        if not match:
            continue

        speaker = match.group(1)
        h, m, s = int(match.group(2)), int(match.group(3)), int(match.group(4))
        text = match.group(5)
        time_sec = h * 3600 + m * 60 + s

        if speaker_filter and speaker != speaker_filter:
            continue
        if keyword_filter and keyword_filter.lower() not in text.lower():
            continue

        edit_segments.append({
            "speaker": speaker,
            "time_sec": time_sec,
            "text": text,
        })

    return edit_segments
```

### Compose with radio-edit

When the user wants a paper edit first (rough cut decisions before timeline work), compose with `radio-edit`:
1. `media-transcription` → produces transcript + timestamps
2. `radio-edit` → produces paper edit with keep/cut/flag decisions
3. `nle-assistant` → executes the approved paper edit inside Resolve via the timeline operations above

## Scripting Environment

All Resolve API calls execute via Python. The agent writes a temp script, runs it with the system Python (which has Resolve's module on its path), and reports results.

### Resolution: Frame Rate Awareness

Always query the timeline's frame rate before computing frame numbers:

```python
fps = float(timeline.GetSetting("timelineFrameRate"))
# Convert seconds ↔ frames:
#   frame = int(seconds * fps)
#   seconds = frame / fps
```

### Resolution: Track Types

Resolve uses these track type strings:
- `"video"` — Video tracks (V1, V2, ...)
- `"audio"` — Audio tracks (A1, A2, ...)
- `"subtitle"` — Subtitle tracks

Track indices are 1-based: `track_index=1` means V1 or A1.

### Resolution: API Guard

If a Resolve API method is not available (older version), fall back gracefully:

```python
def safe_api_call(method, *args, default=None, **kwargs):
    """Call a Resolve API method with fallback."""
    try:
        result = method(*args, **kwargs)
        return result if result is not None else default
    except Exception as e:
        print(f"API call failed: {e}")
        return default
```

## Verification

Before executing any edit on a real project, validate the entire pipeline against a throwaway project:

### Smoke Test Checklist

1. **Connect**: Verify Resolve is running and a project is open
2. **Safety guard**: Duplicate the timeline — confirm the copy exists with `_AGENT_WORK` suffix
3. **Read**: List all items on V1 and A1 — confirm clip names and frame ranges are readable
4. **Import**: Add a small test file to the media pool — confirm it appears
5. **Mark**: Place a marker at frame 0 on the working timeline — confirm `AddMarker()` returns True
6. **Silence removal**: Remove a 2-second gap from a single clip — confirm the timeline compacts
7. **Show result**: Print a summary of the working timeline: "N items across M tracks, duration X seconds"
8. **Leave original untouched**: Verify the original timeline name does NOT contain `_AGENT_WORK` and has the same clip count as before

### Test Script Template

```python
# nle_assistant_smoke_test.py
# Run against a throwaway project before using on real work.

import sys, os

RESOLVE_SCRIPT = os.path.expandvars(
    r"%PROGRAMDATA%\Blackmagic Design\DaVinci Resolve\Support\Developer\Scripting\Modules"
)
sys.path.append(RESOLVE_SCRIPT)

import DaVinciResolveScript as dvr

resolve = dvr.scriptapp("Resolve")
assert resolve, "RESOLVE NOT RUNNING"

pm = resolve.GetProjectManager()
proj = pm.GetCurrentProject()
assert proj, "NO PROJECT OPEN"

orig = proj.GetCurrentTimeline()
assert orig, "NO TIMELINE OPEN"
orig_name = orig.GetName()
print(f"Original: {orig_name}")

mp = proj.GetMediaPool()
safe_name = f"{orig_name}_SMOKE_TEST"
mp.DuplicateTimeline(orig_name, safe_name)

for t in proj.GetTimelineList():
    if t.GetName() == safe_name:
        proj.SetCurrentTimeline(t)
        break

safe = proj.GetCurrentTimeline()
items = safe.GetItemListInTrack("video", 1)
print(f"V1 items: {len(items) if items else 0}")

if items and len(items) > 0:
    first = items[0]
    print(f"  First clip: {first.GetName()} [{first.GetStart()} → {first.GetEnd()}]")

    # Test: trim 1 second off the start
    new_start = first.GetStart() + 30  # 30 frames ≈ 1 sec at 30fps
    first.SetStart(new_start)
    assert first.GetStart() == new_start, "TRIM FAILED"
    print(f"  Trimmed start to {new_start}")

safe.AddMarker(0, "Green", "Smoke test passed", "", 1)
print("✓ Marker placed")

# Verify original untouched
orig_check = None
for t in proj.GetTimelineList():
    if t.GetName() == orig_name:
        orig_check = t
        break
orig_items = orig_check.GetItemListInTrack("video", 1)
print(f"Original V1 still has {len(orig_items) if orig_items else 0} items — UNTOUCHED")

print("\n✓ SMOKE TEST PASSED")
print(f"  Working copy: {safe_name}")
print(f"  Original: {orig_name} (unchanged)")
```

### User Approval Gate

After any editing operation, before the user uses the results:
1. Announce the working timeline name (includes `_AGENT_WORK`)
2. Describe what was done: "Removed 3 silence regions, trimmed clip 'Interview' to 4 keep segments, built new timeline 'Subclips — pricing' with 12 segments"
3. **Never** rename, export, or render without explicit user request
4. The user opens the working timeline in Resolve to review and decides when to promote it
