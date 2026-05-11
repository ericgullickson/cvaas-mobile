# MotoVaultPro Agent Team

Specialized agents for MotoVaultPro development. Each agent has detailed instructions in their own file.

## Quick Reference

| Agent | File | Use When |
|-------|------|----------|
| Feature Agent | `feature-agent.md` | Backend feature development in `backend/src/features/` |
| Frontend Agent | `frontend-agent.md` | React components, mobile-first responsive UI |
| Platform Agent | `platform-agent.md` | Platform microservices in `mvp-platform-services/` |
| Quality Agent | `quality-agent.md` | Final validation before merge/deploy |

## Sprint Workflow

All agents follow the sprint workflow defined in `.ai/workflow-contract.json`:

1. Pick issue from current sprint with `status/ready`
2. Move to `status/in-progress`, create branch `issue-{index}-{slug}`
3. Implement with commits referencing issue
4. Open PR, move to `status/review`
5. Quality Agent validates before `status/done`

## Coordination

- Agents do NOT modify each other's code
- Feature + Frontend agents can work in parallel
- Quality Agent validates all work before completion
- Conflicts escalate to Expert Software Architect

## Context Loading

Each agent loads minimal context:
- `.ai/context.json` - Architecture overview
- `.ai/workflow-contract.json` - Sprint workflow
- Their specific agent file - Role and responsibilities
- Feature/component README - Task-specific context

## Quality Standards (All Agents)

- All linters pass (zero errors)
- All tests pass
- Mobile + desktop validated
- Old code deleted
- Documentation updated
