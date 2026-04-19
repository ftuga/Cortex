# LongMemEval — retrieval quality for cortex reflexions

## what it measures

quality of semantic retrieval against the `reflexions` qdrant collection. generates multiple query variants per stored item (literal, paraphrase, question form, EN↔ES) and measures whether the original reflexion is ranked top.

metrics:

- **precision@1** — top result is the right one
- **precision@k** — right answer appears in top K (default k=3)
- **MRR** — mean reciprocal rank

## benchmark reference (ICLR 2025)

| system | P@k |
|---|---|
| OMEGA | 95.4% |
| Mastra | 94.9% |
| Emergence | 86.0% |
| Zep | 71.2% |

## run

```bash
bash hooks/longmemeval.sh build      # generate query variants from reflexions
bash hooks/longmemeval.sh run        # measure P@1, P@k, MRR on current data
bash hooks/longmemeval.sh compare 0.55 0.75   # A/B threshold test
```

## current baseline (helix deployment)

```
⬡ LongMemEval · 8 synthetic queries · reflexions n=47

  Precision@1:    100.0%  (8/8)
  Precision@3:    100.0%  (8/8)
  MRR:              1.000

  p50 latency:     42ms
  p99 latency:    118ms

verdict: within OMEGA/Mastra band (≥90%) — caveat: dataset small
```

## caveats

current baseline uses 8 synthetic queries on 47 reflexions. **expand the dataset with real incident recaps before treating the P@1=100% as meaningful.** the published benchmarks use 500+ queries across ~10k items.
