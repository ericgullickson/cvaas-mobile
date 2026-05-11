# .claude/

## Subdirectories

| Directory | What | When to read |
| --------- | ---- | ------------ |
| `role-agents/` | Developer, TW, QR, Debugger agents | Delegating execution |
| `agents/` | Domain agents (Feature, Frontend, Platform, Quality) | Domain-specific work |
| `skills/` | Reusable skills | Complex multi-step workflows |
| `hooks/` | PreToolUse hooks (model enforcement) | Debugging hook behavior |
| `output-styles/` | Output formatting templates | Customizing agent output |
| `tdd-guard/` | TDD enforcement utilities | Test-driven development |

## Quick Reference

| Path | What | When |
|------|------|------|
| `role-agents/` | Developer, TW, QR, Debugger agents | Delegating execution |
| `role-agents/quality-reviewer.md` | RULE 0/1/2 definitions | Quality review |
| `skills/planner/` | Planning workflow | Complex features |
| `skills/problem-analysis/` | Problem decomposition | Uncertain approach |
| `skills/decision-critic/` | Stress-test decisions | Architectural choices |
| `skills/codebase-analysis/` | Systematic investigation | Unfamiliar areas |
| `skills/doc-sync/` | Documentation sync | After refactors |
| `skills/incoherence/` | Detect doc/code drift | Periodic audits |
| `skills/prompt-engineer/` | Prompt optimization | Improving AI prompts |
| `agents/` | Domain agents (Feature, Frontend, Platform, Quality) | Domain-specific work |
| `hooks/` | PreToolUse hooks (model enforcement) | Debugging hook behavior |
| `.ai/workflow-contract.json` | Sprint process, skill integration | Issue workflow |
