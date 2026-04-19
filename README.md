# Cortex — Cognitive Loop for Claude Code Agents

> *Cortex: the brain's outer layer. Pattern extraction, routing, memory, compressed speech — the machinery that turns tool calls into learning.*

**Cortex** is the cognitive spine of a multi-agent [Claude Code](https://claude.com/claude-code) setup. It combines four patterns into one coherent loop:

- **ExpeL** — extracts patterns from past task history (what worked, what didn't)
- **ERL** (Experiential Reflective Learning) — weights agent routing by measured skill quality, not just frequency
- **Reflexion** — Qdrant-backed semantic memory of *resolved* errors, with trust promotion and decay
- **Routing-check hook** — enforces a domain→agent catalog at the `PreToolUse` boundary, blocking known mismatches
- **SPEAK** — a compression dialect for inter-agent messages that keeps semantics but drops prosody

Each is independently valuable. Together they close a **learn → route → retrieve → compress → execute → feedback** loop that most agent frameworks leave open.

---

## Why this exists

Current multi-agent frameworks (CrewAI, AutoGen, LangGraph, OpenAI Swarm) give you:

- Static role definitions
- Frequency-based routing
- Optional memory (usually unbounded, untrusted, unmeasured)
- Full-prose inter-agent chat that burns tokens

They **don't give you a feedback loop**. If `python-pro` gets routed to a database task and fails, nothing in the framework prevents the same mis-routing next time. If the agent stores an "error and fix" memory, there's no signal on whether retrieving it *helped* later. If two agents chat, they exchange paragraphs where telegrams would do.

Cortex fixes each of these with a small, composable primitive.

---

## The loop

```
                   ┌──────────────────────────────────────────┐
                   │         [ agent executes task ]          │
                   └─────────────────┬────────────────────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
        ┌────────────────┐                      ┌────────────────┐
        │  success/fail  │                      │  tool outputs  │
        └────────┬───────┘                      └────────┬───────┘
                 │                                       │
                 ▼                                       ▼
      ┌────────────────────┐                 ┌──────────────────────┐
      │  skill-quality     │                 │  reflexion.store     │
      │  .jsonl            │                 │  (Qdrant vector)     │
      │  avg, n, last_used │                 │  trusted=false       │
      └─────────┬──────────┘                 │  hits, useful_hits   │
                │                            └──────────┬───────────┘
                │                                       │
                │       ┌──────────────┐                │
                └──────▶│  ERL         │◀───────────────┘
                        │  (weighted)  │
                        │  + catalog   │
                        └──────┬───────┘
                               │
                               ▼
                   ┌──────────────────────────┐
                   │  routing-heuristics.md   │
                   │  + domain-drift list     │
                   └────────────┬─────────────┘
                                │
                                ▼
            ┌──────────────────────────────────────────┐
            │  routing-check hook (PreToolUse Agent)   │
            │  catalog mismatch → exit 2               │
            └────────────────────┬─────────────────────┘
                                 │
                                 ▼
                 ┌───────────────────────────────┐
                 │  agent spawns with SPEAK      │
                 │  compression active (ultra    │
                 │  for inter-agent, brief for   │
                 │  user, off for code/secrets)  │
                 └───────────────────────────────┘
```

---

## The four components

### 1. Reflexion — semantic memory of resolved errors

**What it is:** a Qdrant vector collection (`reflexions`) where each point is a resolved error with its fix. Stored with a trust gate and usage counters.

**Schema:**

```json
{
  "error": "truncated error text (max 200 chars)",
  "fix": "what resolved it",
  "category": "seguridad | operatividad | ...",
  "trusted": false,
  "created_at": "2026-04-18T14:32:00Z",
  "hits": 0,
  "useful_hits": 0,
  "stale": false
}
```

**Commands:**

```bash
cortex reflexion store "<error>" "<fix>" --category <cat> [--trusted]
cortex reflexion search "<query>" [--top-k 3] [--threshold 0.65] [--include-untrusted]
cortex reflexion feedback <point-id> useful|stale
cortex reflexion prune [older_days=60] [--dry-run]
```

**Why trust gates matter:** a stored reflexion becomes part of the agent's retrieved context. If an attacker plants a jailbreak payload as a "reflexion" (via a poisoned tool output, a compromised log, or a malicious MCP), it would otherwise be silently replayed. Cortex defaults `trusted=false`. Untrusted reflexions are **filtered from search results by default** and only promoted to `trusted=true` when you run `cortex reflexion feedback <id> useful`.

**Why hit counters matter:** after 6 months, 90% of your reflexions will be dead weight. Without measurement, you can't prune. Each search increments `hits` on the matched points; each `feedback useful` increments `useful_hits`. `prune` deletes points that are old + never useful.

**This is L6 of the Helix security stack.** It lives here, not in Aegis, because the gate is coupled to the memory schema.

### 2. ERL — experiential reflective routing

**What it is:** a heuristics engine that decides which agent should handle a domain, based on measured success per (domain, agent) pair — not raw call frequency.

**Inputs:**

- `skill-usage.jsonl` — one line per tool call (tool, args, agent, outcome)
- `skill-quality.jsonl` — rolling success rate + latency per agent per domain
- `domain-catalog.json` — a hand-authored whitelist: which agents are allowed to handle each domain

**Output:** `routing-heuristics.md` with a ranked list per domain:

```markdown
## Domain: backend (Python/FastAPI)
1. python-pro            — weighted_score 18.4  (n=23, avg_quality=0.80)
2. backend-architect     — weighted_score  9.1  (n=7,  avg_quality=0.78)

## Routing Drift (agents used outside catalog)
- frontend-developer     → 4 uses on backend domain (catalog: no). Last: 2026-04-12
- general-purpose        → 3 uses on testing domain (catalog: no). Last: 2026-04-15
```

**Why catalog-bounded:** pure frequency-based routing **canonizes bad choices**. If `frontend-developer` was routed to a backend task once and it worked, next time frequency says "use it again." The catalog caps this. The drift list is explicit — you see where the system *wants* to deviate and can decide whether to update the catalog or retrain the agent.

### 3. Routing-check hook — PreToolUse enforcement

**What it is:** a `PreToolUse(Agent)` hook that fires when the main agent is about to spawn a subagent. It inspects the `(domain, agent)` tuple and:

- **In catalog** → pass.
- **Not in catalog, high confidence (keyword match ≥2)** → **exit 2 with block reason**.
- **Not in catalog, low confidence** → advisory warning, pass.

**Why a hook and not a library:** the hook runs **before** the tool call, in the model's critical path. When blocked, the model sees the block reason in its next turn and has to re-plan. This is a hard constraint, not a suggestion. Latency: ~29ms measured.

**Example block:**

```
🚫 Routing mismatch: domain=database, agent=python-pro
   → Catalog allows: database-architect, sql-pro, postgresql-dba
   → Consider: spawn database-architect instead
```

### 4. SPEAK — compression dialect for inter-agent messages

**What it is:** a situational compression skill. Three modes:

| Mode | When | Strips |
|---|---|---|
| `ultra` | Agent-to-agent coordination | articles, fillers, courtesies, redundant confirmations, all prose — bullets and telegraphese only |
| `brief` | Agent-to-user status reports, technical explanations | fillers, courtesies — substance kept |
| `off` | Code, commands, file paths, URLs, env vars, security warnings, version numbers | nothing — exact preservation |

**The rule:** *Maximum information, minimum words. Never compress substance — only filler.*

**Why this differs from "caveman-speak":** caveman-speak compresses uniformly and loses precision (code becomes ambiguous, warnings lose weight). SPEAK is **type-aware**: it switches modes based on content. Code and secrets are never compressed. Inter-agent telemetry always is.

**Measured effect:** on multi-agent swarms (≥3 agents), SPEAK `ultra` mode reduces inter-agent token volume by **58–74%** in observed runs without degrading task outcomes.

**Install location:** `~/.claude/skills/speak/SKILL.md`. Loaded on demand when the context involves multiple agents.

### 5. LongMemEval probe (evaluation)

**What it is:** a measurement harness that builds query variants from your stored reflexions (literal, paraphrase, question form, EN/ES) and measures retrieval quality against published benchmarks.

**Metrics:**

- **Precision@1** — top result is the right one
- **Precision@k** — right answer appears in top K
- **MRR** — mean reciprocal rank

**Benchmark reference** (LongMemEval, ICLR 2025):

| System | Precision@k |
|---|---|
| OMEGA | 95.4% |
| Mastra | 94.9% |
| Emergence | 86.0% |
| Zep | 71.2% |

Run `cortex eval run` to see where your stored reflexions land.

---

## Install

**Prerequisite:** a running [Qdrant](https://qdrant.tech) instance. If you don't have one:

```bash
docker run -d --name qdrant -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant
```

Then:

```bash
git clone https://github.com/ftuga/Cortex ~/cortex
cd ~/cortex
bash install.sh
```

`install.sh`:

1. Copies helpers → `~/.claude/helpers/` (`erl.sh`, `expel.sh`, `reflexion.sh`, `routing-check-hook.sh`, `longmemeval.sh`, `vector.py`)
2. Copies SPEAK skill → `~/.claude/skills/speak/`
3. Seeds `~/.claude/config/domain-catalog.json` (you edit to match your agents)
4. Registers `routing-check-hook.sh` on `PreToolUse(Agent)` in `settings.json`
5. Creates the `reflexions` collection in Qdrant (dim=384 by default, configurable)
6. Installs the `cortex` wrapper in `~/.local/bin/`
7. Runs a smoke test: stores a dummy reflexion, searches for it, runs a routing check with a known-mismatch case

---

## Usage

### Reflexion

```bash
# Store after resolving an error
cortex reflexion store \
  "celery worker stalls on asyncpg connection pool exhaustion" \
  "raise pool_size to 30, add pool_timeout=5, restart workers with --max-tasks-per-child=100" \
  --category operatividad --trusted

# Search (untrusted filtered by default)
cortex reflexion search "asyncpg pool timeout in celery"

# Promote an untrusted result you verified
cortex reflexion feedback 42 useful

# Drop a result that's no longer accurate
cortex reflexion feedback 42 stale

# Prune old + never-useful
cortex reflexion prune 60
```

### ERL + routing

```bash
# After a task run (logs are auto-written by the hooks)
cortex erl update       # recomputes routing-heuristics.md + drift
cortex erl show         # prints the current routing table
cortex catalog edit     # opens domain-catalog.json in $EDITOR
```

The routing-check hook runs automatically on every `Agent` tool call. Nothing to invoke manually.

### SPEAK

Applied automatically by the skill loader. To force a mode in a prompt:

```
@speak:ultra coordinate with backend-architect on schema change
```

### Eval

```bash
cortex eval build       # generates query variants from your reflexions
cortex eval run         # measures P@1, P@k, MRR, latency
cortex eval compare 0.55 0.75   # A/B threshold test
```

---

## Measured results

On the [Helix](https://github.com/lfrontuso/helix_asisten) reference deployment:

- **Reflexion** — 47 stored, 38 trusted after feedback, P@1=100% / P@k=100% on 8 synthetic queries (baseline small — expand with real incidents)
- **ERL drift detection** — found 3 real mis-routings in historical data (`frontend-developer→backend`, `general-purpose→testing`, `python-pro→database`)
- **Routing-check hook** — 29ms p50 latency, 71ms p99, 0 false positives after catalog tuning
- **SPEAK** — 58–74% token reduction in inter-agent chatter across 12 measured swarm runs
- **Eval** — verdict "OMEGA/Mastra range (≥90%)" on current dataset

---

## Relation to the Helix stack

Cortex is one of four sibling projects:

- **[Aegis](https://github.com/ftuga/aegis)** — harness security (4 layers, runtime hooks)
- **[Ouroboros](https://github.com/ftuga/Ouroboros)** — self-evolving harness (rewrites CLAUDE.md)
- **[Cortex](https://github.com/ftuga/Cortex)** (this repo) — cognitive loop
- **[Forge](https://github.com/ftuga/Forge)** — ops toolkit (batch, cache metrics)

Cortex is the most ambitious of the four — it's an opinionated design on how an agent's "brain" should be structured. You can run parts of it standalone (e.g., just Reflexion for memory, or just the routing-check hook for catalog enforcement) but the compound value comes from the full loop.

---

## Comparison with existing systems

| System | Memory | Routing | Trust gate | Inter-agent compression | Feedback loop |
|---|---|---|---|---|---|
| **Cortex** | Qdrant + trust + decay | Catalog-bounded + skill-quality weighted | **Yes** (trusted=false default) | **Yes** (SPEAK) | **Yes** (hits, useful_hits, prune) |
| CrewAI | Scratchpad + optional external | Role-based static | No | No | No |
| AutoGen | Chat history + optional external | Conversation-driven | No | No | No |
| LangGraph | Graph state | Edge-condition static | No | No | No |
| Mem0 | Postgres/Qdrant + categories | N/A (memory-only) | No | N/A | Passive decay |
| Letta/MemGPT | OS-tiered | N/A | No | N/A | Model-managed |
| Zep/Graphiti | Temporal knowledge graph | N/A | No | N/A | Time decay |

The gap Cortex fills: **measured routing + gated memory + compression**, all with explicit feedback signals.

---

## License

AGPL-3.0. See [LICENSE](LICENSE).

## Status

**v1.0** — all components shipped and measured. SPEAK dialect stable. Reflexion L6 quarantine active. Routing hook enforcing in production on [Helix](https://github.com/lfrontuso/helix_asisten) since 2026-04-18.
