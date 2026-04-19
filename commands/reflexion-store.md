---
description: Store a resolved error → fix into the reflexion memory (Qdrant)
allowed-tools: Bash(bash:*)
---

Store a pair (error, fix) into the `reflexions` Qdrant collection. Stored with `trusted=false` by default. Add `--trusted` if you've verified the fix yourself.

**usage:** `/reflexion-store "<error>" "<fix>" --category <cat> [--trusted]`

Run:
```bash
bash ~/.claude/helpers/reflexion.sh store $ARGUMENTS
```
