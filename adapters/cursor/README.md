# cursor adapter

**status:** community port welcome — currently not maintained by this repo.

cursor doesn't expose `PreToolUse` hooks at the platform level, so the routing-check can't run as-is. but the other 3 primitives work standalone:

- **reflexion memory** — runs as `cortex reflexion store|search|feedback|prune` CLI commands. not coupled to cursor.
- **ERL + routing-heuristics** — pure bash + jsonl analysis. emits `routing-heuristics.md` as a cursor rule.
- **SPEAK skill** — copy `skills/speak/SKILL.md` content into your `.cursorrules` file.
- **LongMemEval** — measures qdrant quality; cursor-agnostic.

open an issue with `adapter: cursor` tag if you want to contribute native routing enforcement.
