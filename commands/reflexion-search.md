---
description: Semantic search across past resolved errors — untrusted filtered by default
allowed-tools: Bash(bash:*)
---

Semantic search of the `reflexions` collection. Untrusted reflexions are **filtered out by default** (add `--include-untrusted` to see them).

**usage:** `/reflexion-search "<query>" [--top-k 3] [--threshold 0.65]`

Run:
```bash
bash ~/.claude/helpers/reflexion.sh search $ARGUMENTS
```
