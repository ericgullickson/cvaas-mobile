# skills/incoherence/

## Overview

Incoherence detection skill using parallel agents. IMMEDIATELY invoke the
script -- do NOT explore first.

## Index

| File/Directory           | Contents          | Read When          |
| ------------------------ | ----------------- | ------------------ |
| `SKILL.md`               | Invocation        | Using this skill   |
| `scripts/incoherence.py` | Complete workflow | Debugging behavior |

## Key Point

The script IS the workflow. Three phases:

- Detection (steps 1-12): Survey, explore, verify candidates
- Resolution (steps 13-15): Interactive AskUserQuestion prompts
- Application (steps 16-21): Apply changes, present final report

Resolution is interactive - user answers structured questions inline. No manual
file editing required.
