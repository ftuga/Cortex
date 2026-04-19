# quarantine model — reflexion memory

reflexions become part of the agent's retrieved context. a poisoned reflexion is a poisoned prompt. the quarantine model defines how trust is established and revoked.

## default state: untrusted

every reflexion is stored with `trusted=false` by default. this includes:

- reflexions stored by the agent itself (e.g. from a `TodoWrite` after resolving an error)
- reflexions stored by automated post-incident hooks
- reflexions imported from external sources

## search behavior

| flag | sees trusted | sees untrusted |
|---|---|---|
| (default) | ✅ | ❌ |
| `--include-untrusted` | ✅ | ✅ |
| `--only-untrusted` | ❌ | ✅ |

untrusted reflexions can be **surfaced** (with explicit flag) but never match silently. an operator reviewing them explicitly is the promotion gate.

## promotion

```bash
cortex reflexion feedback <id> useful      # promotes to trusted=true
```

only a human (or an authenticated system) should ever run `feedback useful`. the act of promotion is the trust decision — the reflexion moves from "suggestion" to "operating memory."

## demotion

```bash
cortex reflexion feedback <id> stale       # marks stale=true; excluded from search
```

`stale` is one-way. to fully drop: `prune --include-stale`.

## decay

reflexions are never auto-promoted. but they *are* auto-demoted:

- `hits=0` for 60+ days → auto-`stale=true`
- `useful_hits=0` for 90+ days, regardless of trust → candidate for pruning

## attack vectors defended

| vector | defense |
|---|---|
| poisoned tool output stored as reflexion | untrusted by default — not retrieved |
| malicious MCP server pushing reflexions | same |
| compromised log → reflexion insert | same |
| jailbreak embedded in `fix` text | L5 of aegis (if installed) scans on retrieval path |

## attack vectors NOT defended

| vector | recommendation |
|---|---|
| operator promotes a poisoned reflexion | review the reflexion content before `feedback useful` |
| direct Qdrant API access with auth tokens | protect Qdrant access; run it on localhost only |
| collection deleted externally | snapshot backup of `reflexions` collection |

## audit trail

every `store`, `feedback`, `prune` writes to `~/.claude/memory/reflexion-audit.jsonl`:

```json
{"ts":"2026-04-18T22:11:03","op":"store","id":42,"category":"operatividad","trusted":false}
{"ts":"2026-04-18T22:14:41","op":"feedback","id":42,"to":"useful"}
```
