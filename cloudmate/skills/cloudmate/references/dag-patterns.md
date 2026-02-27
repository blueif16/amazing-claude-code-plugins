# DAG Patterns

Load this when generating Level 2-3 plans. Pick the pattern closest to the user's intent, then customize.

## Feature Implementation (most common)
```
T1: Schema/Config ──┐
T2: Backend API ────┤── T4: Integration Test ── T5: Review
T3: Frontend UI ────┘
```
T1 is often a blocker (schema/types that others depend on). T2+T3 run in parallel. T4 validates the seams. T5 is a final pass.

## Bug Investigation
```
T1: Log/Error Analysis ──┐
T2: Code Archaeology ────┤── T4: Root Cause Synthesis ── T5: Fix ── T6: Regression Test
T3: Reproduce in Test ───┘
```
Fan-out to investigate from multiple angles. Synthesize before fixing. Always add a regression test.

## Refactor (Linear)
```
T1: Extract Interface ── T2: Migrate Callers ── T3: Remove Old Code ── T4: Test Suite
```
Refactors are usually sequential — each step depends on the previous. Keep it linear unless modules are truly independent.

## Refactor (Parallel Modules)
```
T1: Define shared interface ──┐
T2: Migrate Module A ─────────┤── T5: Integration Test
T3: Migrate Module B ─────────┤
T4: Migrate Module C ─────────┘
```
When refactoring N independent modules to a new interface, define the interface first, then parallelize.

## Research / Spike
```
T1: Approach A ──┐
T2: Approach B ──┤── T4: Compare & Recommend
T3: Approach C ──┘
```
Each approach investigated independently. Final task synthesizes with pros/cons and a recommendation.

## Migration
```
T1: Add new system (parallel-run) ── T2: Migrate reads ── T3: Migrate writes ── T4: Remove old ── T5: Verify
```
Migrations are almost always linear. Each step must be verified before proceeding. Never parallelize migration steps.

## Choosing a Pattern
- If tasks share files → linear (no parallelism possible)
- If tasks touch different dirs → fan-out (maximize parallelism)
- If you need competing perspectives → research/debate pattern
- If order matters for safety → linear even if technically parallelizable
- When in doubt, linear is safer. Parallelism is an optimization, not a default.
