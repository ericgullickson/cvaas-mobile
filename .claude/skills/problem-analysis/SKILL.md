---
name: problem-analysis
description: Invoke IMMEDIATELY for structured problem analysis and solution discovery.
---

# Problem Analysis

When this skill activates, IMMEDIATELY invoke the script. The script IS the
workflow.

## Invocation

```bash
python3 scripts/analyze.py \
  --step 1 \
  --total-steps 7 \
  --thoughts "Problem: <describe>"
```

| Argument        | Required | Description                               |
| --------------- | -------- | ----------------------------------------- |
| `--step`        | Yes      | Current step (starts at 1)                |
| `--total-steps` | Yes      | Minimum 7; adjust as script instructs     |
| `--thoughts`    | Yes      | Accumulated state from all previous steps |

Do NOT analyze or explore first. Run the script and follow its output.
