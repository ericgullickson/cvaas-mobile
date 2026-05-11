# hooks/

## Files

| File | What | When to read |
| ---- | ---- | ------------ |
| `enforce-agent-model.sh` | Enforces correct model for Task tool calls | Debugging agent model issues |

## enforce-agent-model.sh

PreToolUse hook that ensures Task tool calls use the correct model based on `subagent_type`.

### Agent Model Mapping

| Agent | Required Model |
|-------|----------------|
| feature-agent | sonnet |
| first-frontend-agent | sonnet |
| platform-agent | sonnet |
| quality-agent | sonnet |
| developer | sonnet |
| technical-writer | sonnet |
| debugger | sonnet |
| quality-reviewer | opus |
| Explore | sonnet |
| Plan | sonnet |
| Bash | sonnet |
| general-purpose | sonnet |

### Behavior

- Blocks Task calls where `model` parameter doesn't match expected value
- Returns error message instructing Claude to retry with correct model
- Unknown agent types are allowed through (no enforcement)

### Adding New Agents

Edit the `get_expected_model()` function in `enforce-agent-model.sh` to add new agent mappings.
