# benchmarks

cortex measures four things:

1. **retrieval quality** — [LongMemEval](longmemeval/) on stored reflexions (P@1, P@k, MRR)
2. **routing quality** — catalog compliance + skill-quality weighted scoring
3. **SPEAK compression** — token reduction in inter-agent messages
4. **hook latency** — routing-check hook overhead

## measured on helix deployment

### reflexion memory
- 47 stored reflexions
- 38 trusted after feedback promotion
- P@1=100%, P@k=100%, MRR=1.000 (on 8 synthetic queries — caveat: small dataset)

### routing (ERL)
- 3 historical mis-routings detected in drift analysis:
  - `frontend-developer` → backend domain (4 times)
  - `general-purpose` → testing domain (3 times)
  - `python-pro` → database domain (2 times)
- after catalog enforcement: 0 drift cases in 14 sessions

### SPEAK compression
- inter-agent token volume reduced **58–74%** in `ultra` mode across 12 measured swarm runs
- zero degradation in task outcomes (measured by downstream agent success rate)
- `brief` mode reduces user-facing output 22–38%

### routing-check hook latency
```
  p50:  29ms
  p99:  71ms
  false-positive rate after catalog tuning: 0%
```

## reproduce

```bash
bash benchmarks/longmemeval/run.sh
bash benchmarks/routing-drift-scan.sh
bash benchmarks/speak-compression.sh
bash benchmarks/routing-check-latency.sh
```
