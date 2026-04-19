# routing — catalog-bounded, quality-weighted

## the problem with frequency routing

most multi-agent frameworks route by "which agent was used most often for this domain." that's wrong because:

1. if a bad routing happened once and worked accidentally, frequency canonizes it
2. if a new, better agent exists, it can't displace the incumbent without manual intervention
3. quality (success rate, latency, token cost) is invisible to the router

## cortex approach: two signals

### signal 1 — `domain-catalog.json`

a hand-authored allow-list per domain:

```json
{
  "backend": ["python-pro", "backend-architect", "api-architect"],
  "database": ["database-architect", "sql-pro", "postgresql-dba"],
  "frontend": ["frontend-developer", "typescript-pro", "nextjs-architecture-expert"],
  "testing": ["test-automator", "test-engineer", "qa-expert"],
  "security": ["security-auditor", "security-engineer", "api-security-audit"]
}
```

the catalog is **a policy artifact**. it's version-controlled. changes are reviewed. it answers: "which agents are we willing to use for this domain?"

### signal 2 — `skill-quality.jsonl`

measured outcomes per (domain, agent):

```jsonl
{"domain":"backend","agent":"python-pro","n":23,"avg_quality":0.80,"last_used":"2026-04-18"}
{"domain":"backend","agent":"backend-architect","n":7,"avg_quality":0.78,"last_used":"2026-04-10"}
```

quality is `success_rate * (1 - normalized_latency) * (1 - normalized_cost)`. range [0,1].

## the ERL ranker

`erl update` combines the two:

```
for each domain:
  for each agent in catalog[domain]:
    weighted_score = n * avg_quality
  rank by weighted_score descending
```

output → `~/.claude/memory/routing-heuristics.md`:

```markdown
## domain: backend
1. python-pro           — ws=18.4  (n=23, q=0.80)
2. backend-architect    — ws=5.5   (n=7,  q=0.78)

## routing drift (agents used outside catalog)
- frontend-developer    → 4 uses on backend (last: 2026-04-12)
- general-purpose       → 3 uses on testing (last: 2026-04-15)
```

the drift section is **explicit**. the router sees where the system wants to deviate. the operator decides: update catalog, or retrain.

## the routing-check hook

`PreToolUse(Task)` hook. fires when the main agent is about to spawn a subagent.

```
detect domain from task description (keyword match, min 2 hits)
if domain not detected: pass (advisory only)
if agent ∈ catalog[domain]: pass
if agent ∉ catalog[domain]:
  high-confidence mismatch → exit 2 (block)
  low-confidence (1 keyword match) → advisory warning, pass
```

**why a hook and not a library:** the hook runs **before** the tool call. when blocked, the model sees the block reason in its next turn and has to re-plan. this is a hard constraint, not a suggestion.

## example block

```
🚫 ROUTING MISMATCH
   domain:  database
   agent:   python-pro
   catalog: database-architect, sql-pro, postgresql-dba

   → consider: spawn database-architect instead
   → to permit: add python-pro to catalog[database] in ~/.claude/config/domain-catalog.json
```

## latency

measured on helix deployment:
- p50: 29ms
- p99: 71ms
- false-positive rate (after catalog tuning): 0%
