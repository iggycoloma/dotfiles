---
name: optimize-performance
description: Diagnose and improve a measured performance problem using representative baselines, profiling, a focused change, and equivalent before/after validation. Use when the user identifies latency, throughput, memory, CPU, I/O, build, or bundle performance as the problem.
---

# Optimize

Treat optimization as an evidence problem. Do not change code based only on a pattern that looks inefficient.

## Define the target

Identify the affected operation, workload, metric, environment, and success threshold. If the user has not supplied a symptom or target, ask what is slow or expensive before editing.

Distinguish:

- Latency from throughput.
- Average behavior from tail behavior.
- CPU from memory, allocation, disk, network, database, build, or bundle cost.
- A regression from a longstanding limit.

## Establish a representative baseline

1. Reproduce the workload using repository fixtures or a minimal representative case.
2. Record the command, inputs, environment, warm-up, repetitions, and metric.
3. Prefer an existing benchmark or profiler. Add a focused benchmark when results would otherwise be anecdotal.
4. Reduce noise enough to distinguish the expected improvement; do not overstate precision.

If a trustworthy baseline cannot be obtained, stop before implementation and report what evidence is missing.

## Locate the bottleneck

Profile or instrument the relevant path. Trace expensive work to a concrete call, query, allocation, serialization boundary, network request, or algorithm. Check recent history when the issue is a regression. Rank hypotheses and test them rather than applying a catalogue of generic optimizations.

## Change one mechanism

- Make the smallest change that addresses the measured bottleneck.
- Preserve behavior and operational visibility.
- Add or update correctness tests before relying on benchmark results.
- Avoid unrelated cleanup and avoid caches unless invalidation, memory bounds, and observability are understood.
- Document a non-obvious tradeoff in the handoff; put it in source only when it is a durable constraint the code cannot express.

## Re-measure

Run the same workload under equivalent conditions. Report absolute results, relative change, run-to-run variation when available, and any tradeoff in memory, complexity, startup, or tail latency. Run relevant correctness checks after the performance change.

## Output

Report the baseline, evidence locating the bottleneck, change made, before/after measurements, correctness validation, limitations, and whether the target was met. If no measured improvement remains, revert or recommend not taking the optimization rather than defending the diff.
