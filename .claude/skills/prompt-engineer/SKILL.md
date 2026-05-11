---
name: prompt-engineer
description: Invoke IMMEDIATELY via python script when user requests prompt optimization. Do NOT analyze first - invoke this skill immediately.
---

# Prompt Engineer

When this skill activates, IMMEDIATELY invoke the script. The script IS the
workflow.

## Invocation

```bash
python3 scripts/optimize.py \
  --step 1 \
  --total-steps 9 \
  --thoughts "Prompt: <path or description>"
```

| Argument        | Required | Description                               |
| --------------- | -------- | ----------------------------------------- |
| `--step`        | Yes      | Current step (starts at 1)                |
| `--total-steps` | Yes      | Minimum 9; adjust as script instructs     |
| `--thoughts`    | Yes      | Accumulated state from all previous steps |

Do NOT analyze or explore first. Run the script and follow its output.
