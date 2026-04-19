<div align="center">

# 🧠 cortex

**the thinking layer. compressed speech, gated memory, measured routing.**

[![License: AGPL v3](https://img.shields.io/badge/license-AGPL%20v3-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/claude%20code-plugin-orange)](.claude-plugin/plugin.json)
[![SPEAK](https://img.shields.io/badge/SPEAK-58--74%25%20compression-purple)](docs/speak.md)
[![LongMemEval](https://img.shields.io/badge/LongMemEval-OMEGA%20band-green)](benchmarks/longmemeval/)
[![Qdrant](https://img.shields.io/badge/qdrant-required-red)](#prerequisites)

*the brain's outer layer. pattern extraction, routing, memory, compressed speech — the machinery that turns tool calls into learning.*

</div>

---

```
INTER-AGENT TOKENS   ████████████████░░░░  58–74% reduction (ultra mode)
REFLEXION P@1        ████████████████████  100% (8 synthetic, n=47)
ROUTING DRIFT        ·                     0 cases after catalog enforcement
HOOK LATENCY p50     ██                    29ms
TRUST GATE           ✓                     untrusted-by-default, feedback-promoted
```

**the problem.** multi-agent frameworks (CrewAI, AutoGen, LangGraph, Swarm) give you static roles, frequency-based routing, unbounded memory, and full-prose inter-agent chat that burns tokens. they don't give you a **feedback loop**. if `python-pro` gets routed to a database task and fails, nothing prevents the same mis-routing next time. if memory stores a "fix," there's no signal on whether retrieving it *helped* later. if two agents chat, they exchange paragraphs where telegrams would do.

**cortex** closes the loop with four composable primitives: **reflexion** (gated semantic memory), **ERL** (quality-weighted routing), **routing-check** (hard catalog enforcement), **SPEAK** (type-aware compression).

each is independently valuable. together they form: **learn → route → retrieve → compress → execute → feedback**.

---

## before / after

**before — naked multi-agent setup:**
```
main agent → spawn python-pro for database task (bad routing, works by luck)
python-pro → "Hey, I want to let you know I've finished analyzing the schema
              and I think the main issue is that the users table doesn't
              have an index on the email column..." (52 tokens of fluff)
memory    → stores "fix: add index" (no trust gate, no hit counter,
              poisoned entries retrieved silently)
```

**after — cortex:**
```
main agent → wants to spawn python-pro for "database" domain
           → routing-check hook fires: ❌ catalog mismatch
           → re-plans: spawn database-architect instead
database-architect → @speak:ultra "users.email no index · slow queries · confirm?" (10 tokens)
memory    → stores reflexion trusted=false; search only returns it
              if operator runs `feedback useful`; hit counters drive prune
```

---

## the 4 primitives

| # | primitive | what | how it surfaces |
|---|---|---|---|
| **1** | **reflexion** | qdrant-backed semantic memory of resolved errors with trust gate + hit counters | `cortex reflexion store/search/feedback/prune` |
| **2** | **ERL** | quality-weighted routing: `n × avg_quality` per (domain, agent), bounded by catalog | `cortex erl update` → `routing-heuristics.md` |
| **3** | **routing-check hook** | `PreToolUse(Task)` enforcement of domain-catalog | auto-blocks catalog mismatches (exit 2) |
| **4** | **SPEAK** | type-aware compression: ultra / brief / off based on content | skill `~/.claude/skills/speak/` |

plus **LongMemEval** — an evaluation harness that measures your reflexion retrieval against published benchmarks.

full specs → [`docs/speak.md`](docs/speak.md) · [`docs/routing.md`](docs/routing.md) · [`evals/quarantine-model.md`](evals/quarantine-model.md)

---

## prerequisites

a running qdrant instance:

```bash
docker run -d --name qdrant -p 6333:6333 \
    -v qdrant_storage:/qdrant/storage qdrant/qdrant
```

## install

### claude code (primary target)

```bash
git clone https://github.com/ftuga/Cortex.git ~/cortex
bash ~/cortex/install.sh
```

the installer checks qdrant, copies helpers, seeds the domain catalog, registers the routing-check hook, creates the `reflexions` collection, installs the `cortex` CLI, and runs a smoke test.

### other platforms

| platform | status | path |
|---|---|---|
| **claude code** | ✅ first-class | [`adapters/claude-code/`](adapters/claude-code/) |
| **cursor** | 🟡 community port welcome (routing enforcement needs platform hook) | [`adapters/cursor/`](adapters/cursor/) |
| **cline** | 🟡 planned v1.1 | [`adapters/cline/`](adapters/cline/) |
| **windsurf** | 🟡 planned v1.1 | — |

reflexion + ERL + SPEAK are platform-agnostic. routing-check needs a `PreToolUse`-equivalent hook.

---

## what you get

```
✓ 5 slash commands: /reflexion-store /reflexion-search /erl-update /eval-run /speak
✓ Qdrant collection `reflexions` with trust gate + hit counters
✓ ~/.claude/skills/speak/ — SPEAK compression skill (ultra/brief/off)
✓ ~/.claude/config/domain-catalog.json — hand-authored routing allow-list
✓ ~/.claude/memory/routing-heuristics.md — auto-generated routing table + drift
✓ routing-check hook on PreToolUse(Task) — blocks catalog mismatches
✓ LongMemEval harness — P@1 / P@k / MRR against published benchmarks
✓ global `cortex` CLI (~/.local/bin/cortex)
```

---

## benchmarks

### reflexion retrieval (LongMemEval)

```
⬡ LongMemEval · 8 synthetic queries · reflexions n=47

  Precision@1:    100.0%  (8/8)
  Precision@3:    100.0%
  MRR:              1.000
  p50 latency:     42ms

verdict: within OMEGA/Mastra band (≥90%)
caveat: dataset is small — expand with real incidents for robust measurement
```

### routing quality

| metric | before catalog | after catalog |
|---|---|---|
| drift cases / session | 0.6 | 0 |
| routing-check p50 | — | 29ms |
| routing-check p99 | — | 71ms |
| false-positive rate | — | 0% |

### SPEAK compression

| mode | measured reduction | task outcome impact |
|---|---|---|
| `ultra` (agent↔agent) | **58–74%** token reduction | none (within noise) |
| `brief` (agent→user) | 22–38% token reduction | none |
| `off` (code/secrets) | 0% (by design) | N/A |

reproduce → [`benchmarks/`](benchmarks/)

---

## the trust gate — why it matters

reflexions become part of the agent's retrieved context. a poisoned reflexion is a poisoned prompt.

cortex defaults every reflexion to `trusted=false`. search filters untrusted by default. promotion to `trusted=true` requires an explicit `cortex reflexion feedback <id> useful` — a human (or authenticated system) decision.

this is **L6 of the helix security stack**. it lives in cortex because the gate is coupled to the memory schema, not a generic hook.

full model → [`evals/quarantine-model.md`](evals/quarantine-model.md)

---

## comparison with existing systems

| system | memory | routing | trust gate | inter-agent compression | feedback loop |
|---|---|---|---|---|---|
| **cortex** | qdrant + trust + decay | catalog-bounded + quality-weighted | **yes** (untrusted default) | **yes** (SPEAK) | **yes** (hits, useful_hits, prune) |
| crewAI | scratchpad | role-based static | no | no | no |
| autoGen | chat history | conversation-driven | no | no | no |
| langGraph | graph state | edge-condition static | no | no | no |
| mem0 | postgres/qdrant + categories | N/A (memory-only) | no | N/A | passive decay |
| letta / memgpt | OS-tiered | N/A | no | N/A | model-managed |
| zep / graphiti | temporal knowledge graph | N/A | no | N/A | time decay |

the gap cortex fills: **measured routing + gated memory + compression**, with explicit feedback signals.

---

## what cortex does NOT do

- **not a chat framework.** you bring the agents (claude code's `Task` or any spawn mechanism). cortex measures, routes, remembers.
- **not a replacement for evaluation.** LongMemEval measures retrieval. you still need downstream task eval.
- **not a runtime sandbox.** if reflexions are edited externally by a malicious process, use [aegis L4 integrity-manifest](https://github.com/ftuga/aegis).
- **not infinite scale.** qdrant handles millions, but reflexion decay + prune assume a `useful_hits` signal. if nobody runs `feedback useful`, the trust gate never lifts.

---

## ecosystem

cortex is one of four tools extracted from [**helix**](https://github.com/ftuga/helix_asisten) — an auto-evolving agent framework.

| repo | icon | focus |
|---|---|---|
| **[aegis](https://github.com/ftuga/aegis)** | 🛡️ | harness security (6 runtime hooks) |
| **[ouroboros](https://github.com/ftuga/Ouroboros)** | 🐍 | self-evolving agent rules |
| **[cortex](https://github.com/ftuga/Cortex)** | 🧠 | agent cognition (you are here) |
| **[forge](https://github.com/ftuga/Forge)** | 🔨 | multi-agent ops |
| **[helix](https://github.com/ftuga/helix_asisten)** | 🧬 | the umbrella: all four wired together |

cortex is the most ambitious of the four — it's opinionated on how an agent's "brain" should be structured. run parts of it standalone (e.g. just reflexion for memory, or just the routing hook for catalog enforcement) or the full loop.

---

## status

**v1.0** — all 4 primitives shipped and measured. SPEAK dialect stable. reflexion L6 quarantine active. routing hook enforcing in production on [helix](https://github.com/ftuga/helix_asisten) since 2026-04-18.
**license:** AGPL-3.0 — if you run it as a service, share your changes.
**contributions:** adapters for cursor/cline/windsurf welcome. open an issue with `adapter:<platform>` tag.
