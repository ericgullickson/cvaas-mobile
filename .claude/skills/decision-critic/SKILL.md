---
name: decision-critic
description: Invoke IMMEDIATELY via python script to stress-test decisions and reasoning. Do NOT analyze first - the script orchestrates the critique workflow.
---

# Decision Critic

When this skill activates, IMMEDIATELY invoke the script. The script IS the workflow.

## Invocation

```bash
python3 scripts/decision-critic.py \
  --step-number 1 \
  --total-steps 7 \
  --decision "<decision text>" \
  --context "<constraints and background>" \
  --thoughts "<your accumulated analysis from all previous steps>"
```

| Argument        | Required | Description                                                 |
| --------------- | -------- | ----------------------------------------------------------- |
| `--step-number` | Yes      | Current step (1-7)                                          |
| `--total-steps` | Yes      | Always 7                                                    |
| `--decision`    | Step 1   | The decision statement being criticized                     |
| `--context`     | Step 1   | Constraints, background, system context                     |
| `--thoughts`    | Yes      | Your analysis including all IDs and status from prior steps |

Do NOT analyze or critique first. Run the script and follow its output.
