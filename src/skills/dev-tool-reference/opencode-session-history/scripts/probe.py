#!/usr/bin/env python3
"""Probe opencode's local session store (SQLite) for session history.

Low-level data provider: returns raw session data as JSON lines. It does not
interpret, rank, or summarize with a model — callers decide what the data
means. Only mechanical, deterministic filtering happens here.

Subcommands:
  list                One JSON object per session in the repo + time window.
                      Each object: id, title, agent, model, directory,
                      time_created, time_updated (epoch ms), message_count,
                      files_touched, summary (compact), and keyword_matches
                      when --keywords is given.
  find                Like list, but only sessions with at least one keyword
                      hit, ranked by total match count descending. Requires
                      --keywords. The keyword filter is a mechanical pre-filter
                      only; relevance judgment belongs to the caller.
  extract <session>   The session's ordered user + assistant text parts as
                      JSON lines ({role, time_created, text}). Tool calls,
                      reasoning, files, patches, and step markers are skipped —
                      only real conversation text is emitted.

Options:
  --db PATH           Path to opencode.db (default: platform data dir).
  --repo ROOT         Only sessions whose directory is under ROOT.
                      (default: current working directory).
  --days N            Include sessions updated within the last N days
                      (default: 7).
  --keywords K1,K2    Comma-separated keywords for find / list match counts.
  --exclude-session ID  Exclude a session id (e.g., the caller's own session).
  --min-hits N        For find: require at least N total keyword hits
                      (default: 1).
"""

import argparse
import json
import os
import sqlite3
import sys
import time
from pathlib import Path

DATA_DIR_HINT = {
    "win32": "~/.local/share/opencode/opencode.db",
    "darwin": "~/.local/share/opencode/opencode.db",
    "linux": "~/.local/share/opencode/opencode.db",
}


def default_db_path():
    if os.environ.get("OPENCODE_DATA_DIR"):
        return Path(os.environ["OPENCODE_DATA_DIR"]) / "opencode.db"
    hint = DATA_DIR_HINT.get(sys.platform, "~/.local/share/opencode/opencode.db")
    return Path(hint).expanduser()


def connect(db_path):
    uri = f"file:{Path(db_path).resolve()}?mode=ro"
    con = sqlite3.connect(uri, uri=True)
    con.row_factory = sqlite3.Row
    return con


def normalize(p):
    return os.path.normcase(os.path.normpath(str(p)))


def split_keywords(raw):
    if not raw:
        return None
    return [k.strip() for k in raw.split(",") if k.strip()]


def model_label(raw):
    """Session model column stores JSON; return a compact label."""
    if not raw:
        return None
    try:
        d = json.loads(raw)
        if isinstance(d, dict):
            mid = d.get("id") or d.get("modelID")
            prov = d.get("providerID")
            if prov and mid:
                return f"{prov}/{mid}"
            return mid or raw
    except (json.JSONDecodeError, TypeError):
        pass
    return raw


def repo_filter_expr():
    # Return SQL that matches sessions whose directory is under the repo root.
    return "s.directory"


def session_rows(con, repo_root, days, exclude_session):
    now_ms = int(time.time() * 1000)
    cutoff_ms = now_ms - days * 24 * 3600 * 1000
    params = [cutoff_ms]
    clauses = ["s.time_updated > ?"]
    if repo_root:
        root = normalize(repo_root).replace("\\", "/").lower()
        clauses.append("s.directory IS NOT NULL AND s.directory != ''")
        # match the exact repo dir or any subpath (both / and \ separators)
        clauses.append(
            "(REPLACE(LOWER(s.directory), '\\', '/') = ?"
            " OR REPLACE(LOWER(s.directory), '\\', '/') LIKE ?)"
        )
        params.append(root)
        params.append(root + "/%")
    if exclude_session:
        clauses.append("s.id != ?")
        params.append(exclude_session)
    where = " AND ".join(clauses)
    rows = con.execute(
        f"""
        SELECT s.id, s.directory, s.title, s.agent, s.model, s.time_created,
               s.time_updated
        FROM session s
        WHERE {where}
        ORDER BY s.time_updated DESC
        """,
        params,
    ).fetchall()
    return rows


def message_summary_files(con, session_id, limit=40):
    """Files touched, gathered from stored message summaries (diffs)."""
    rows = con.execute(
        """
        SELECT m.data FROM message m
        WHERE m.session_id = ? AND m.data IS NOT NULL
        ORDER BY m.time_created
        """,
        (session_id,),
    ).fetchall()
    files = []
    seen = set()
    for r in rows:
        try:
            d = json.loads(r[0])
        except (json.JSONDecodeError, TypeError):
            continue
        summary = d.get("summary") or {}
        for diff in summary.get("diffs", []) or []:
            f = (diff or {}).get("file")
            if f and f not in seen:
                seen.add(f)
                files.append(f)
                if len(files) >= limit:
                    return files
    return files


def message_count(con, session_id):
    r = con.execute(
        "SELECT COUNT(*) FROM message WHERE session_id = ?", (session_id,)
    ).fetchone()
    return r[0]


def compact_summary(session_title, files, keywords=None, matches=None):
    parts = []
    if session_title:
        parts.append(f"title: {session_title}")
    if files:
        parts.append("files: " + ", ".join(files))
    if keywords and matches:
        hits = ", ".join(f"{k}={v}" for k, v in matches.items() if v)
        if hits:
            parts.append("keyword_hits: " + hits)
    return "; ".join(parts)


def keyword_matches(con, session_id, keywords):
    """Count keyword occurrences in user+assistant conversation text only."""
    counts = {k: 0 for k in keywords}
    rows = con.execute(
        """
        SELECT m.data, p.data FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE p.session_id = ? AND json_extract(p.data, '$.type') = 'text'
        """,
        (session_id,),
    ).fetchall()
    for mdata, pdata in rows:
        try:
            m = json.loads(mdata)
            p = json.loads(pdata)
        except (json.JSONDecodeError, TypeError):
            continue
        role = m.get("role")
        if role not in ("user", "assistant"):
            continue
        text = p.get("text") or ""
        low = text.lower()
        for k in keywords:
            counts[k] += low.count(k.lower())
    return counts


def get_session_text(con, session_id):
    rows = con.execute(
        """
        SELECT m.data, p.time_created, p.data FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE p.session_id = ? AND json_extract(p.data, '$.type') = 'text'
        ORDER BY p.time_created
        """,
        (session_id,),
    ).fetchall()
    out = []
    for mdata, ts, pdata in rows:
        try:
            m = json.loads(mdata)
            p = json.loads(pdata)
        except (json.JSONDecodeError, TypeError):
            continue
        role = m.get("role")
        if role not in ("user", "assistant"):
            continue
        text = (p.get("text") or "").strip()
        if not text:
            continue
        out.append({"role": role, "time_created": ts, "text": text})
    return out


def cmd_list(args):
    con = connect(args.db)
    rows = session_rows(con, args.repo, args.days, args.exclude_session)
    keywords = split_keywords(args.keywords)
    for r in rows:
        sid = r["id"]
        files = message_summary_files(con, sid)
        matches = keyword_matches(con, sid, keywords) if keywords else None
        obj = {
            "id": sid,
            "title": r["title"],
            "agent": r["agent"],
            "model": model_label(r["model"]),
            "directory": r["directory"],
            "time_created": r["time_created"],
            "time_updated": r["time_updated"],
            "message_count": message_count(con, sid),
            "files_touched": files,
            "summary": compact_summary(r["title"], files, keywords, matches),
        }
        if matches is not None:
            obj["keyword_matches"] = matches
        print(json.dumps(obj))
    con.close()


def cmd_find(args):
    keywords = split_keywords(args.keywords)
    if not keywords:
        print("find requires --keywords", file=sys.stderr)
        sys.exit(2)
    con = connect(args.db)
    rows = session_rows(con, args.repo, args.days, args.exclude_session)
    results = []
    for r in rows:
        sid = r["id"]
        matches = keyword_matches(con, sid, keywords)
        total = sum(matches.values())
        if total < args.min_hits:
            continue
        files = message_summary_files(con, sid)
        results.append(
            {
                "id": sid,
                "title": r["title"],
                "agent": r["agent"],
                "model": model_label(r["model"]),
                "directory": r["directory"],
                "time_created": r["time_created"],
                "time_updated": r["time_updated"],
                "message_count": message_count(con, sid),
                "files_touched": files,
                "keyword_matches": matches,
                "match_count": total,
                "summary": compact_summary(r["title"], files, keywords, matches),
            }
        )
    results.sort(key=lambda o: o["match_count"], reverse=True)
    for obj in results:
        print(json.dumps(obj))
    con.close()


def cmd_extract(args):
    con = connect(args.db)
    for part in get_session_text(con, args.session):
        print(json.dumps(part))
    con.close()


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Probe opencode's local session history (SQLite)."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--db", default=str(default_db_path()), help="Path to opencode.db"
    )
    common.add_argument("--repo", default=os.getcwd(), help="Repo root filter")
    common.add_argument(
        "--days", type=int, default=7, help="Only sessions updated within N days"
    )
    common.add_argument("--keywords", default=None, help="Comma-separated keywords")
    common.add_argument("--exclude-session", default=None, help="Session id to skip")

    p_list = sub.add_parser("list", parents=[common])
    p_find = sub.add_parser("find", parents=[common])
    p_find.add_argument("--min-hits", type=int, default=1, help="find min total hits")
    p_extract = sub.add_parser("extract", parents=[common])
    p_extract.add_argument("session")

    args = parser.parse_args(argv)
    if not Path(args.db).exists():
        print(f"opencode.db not found at {args.db}", file=sys.stderr)
        sys.exit(1)
    if args.command == "list":
        cmd_list(args)
    elif args.command == "find":
        cmd_find(args)
    elif args.command == "extract":
        cmd_extract(args)


if __name__ == "__main__":
    main()
