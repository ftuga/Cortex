---
description: Recompute routing-heuristics.md from skill-quality.jsonl + domain-catalog
allowed-tools: Bash(bash:*)
---

Refresh `~/.claude/memory/routing-heuristics.md` based on current skill-quality measurements, weighted by catalog. Emits drift section for agents used outside catalog.

Run:
```bash
bash ~/.claude/helpers/erl.sh update
```
