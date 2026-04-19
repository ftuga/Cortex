---
description: Force SPEAK compression mode for the next inter-agent exchange
---

Force a SPEAK compression mode for the next message. Modes:

- **`ultra`** — agent-to-agent coordination. Bullets, telegraphese, zero prose.
- **`brief`** — agent-to-user. Fillers and courtesies stripped, substance kept.
- **`off`** — code, commands, secrets, version numbers. Exact preservation.

**usage:** `/speak <ultra|brief|off> "<message>"`

Skill loads from `~/.claude/skills/speak/SKILL.md` — see that file for the full rule set.
