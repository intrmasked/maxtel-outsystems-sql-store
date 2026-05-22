# Session: Repo Multi-Remote Setup - 2026-05-22

## What Was Done
Added a second git remote (`heziico`) pointing to `intrmasked/maxtel-outsystems-sql-store` so the repo is accessible from both the TrueNorthTeamsAI org and Abdul's personal GitHub account.

## Why
- heziico-team needs access to the SQL store
- TNT team still needs their copy
- Both remotes stay in sync — push to both when committing

## Remote Setup

| Remote | URL | Team |
|--------|-----|------|
| `origin` | `https://github.com/TrueNorthTeamsAI/maxtel-outsystems-sql-store` | TNT |
| `heziico` | `https://github.com/intrmasked/maxtel-outsystems-sql-store.git` | heziico / personal |

## Usage
```bash
# Push to both
git push origin main && git push heziico main

# Push to one
git push origin main
git push heziico main
```

## Status
- [X] Complete
