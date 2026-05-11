#!/usr/bin/env python3
"""
Prompt Engineer Skill - Multi-turn prompt optimization workflow.

Guides prompt optimization through nine phases:
  1. Triage     - Assess complexity, route to lightweight or full process
  2. Understand - Blind problem identification (NO references yet)
  3. Plan       - Consult references, match techniques, generate visual cards
  4. Verify     - Factored verification of FACTS (open questions, cross-check)
  5. Feedback   - Generate actionable critique from verification results
  6. Refine     - Apply feedback to update the plan
  7. Approval   - Present refined plan to human, HARD GATE
  8. Execute    - Apply approved changes to prompt
  9. Integrate  - Coherence check, anti-pattern audit, quality verification

Research grounding:
  - Self-Refine (Madaan 2023): Separate feedback from refinement for 5-40%
    improvement. Feedback must be "actionable and specific."
  - CoVe (Dhuliawala 2023): Factored verification improves accuracy 17%->70%.
    Use OPEN questions, not yes/no ("model tends to agree whether right or wrong")
  - Factor+Revise: Explicit cross-check achieves +7.7 FACTSCORE points over
    factored verification alone.
  - Separation of Concerns: "Each turn has a distinct cognitive goal. Mixing
    these goals within a single turn reduces effectiveness."

Usage:
    python3 optimize.py --step 1 --total-steps 9 --thoughts "Prompt: agents/developer.md"
"""

import argparse
import sys


def get_step_1_guidance():
    """Step 1: Triage - Assess complexity and route appropriately."""
    return {
        "title": "Triage",
        "actions": [
            "Assess the prompt complexity:",
            "",
            "SIMPLE prompts (use lightweight 3-step process):",
            "  - Under 20 lines",
            "  - Single clear purpose (one tool, one behavior)",
            "  - No conditional logic or branching",
            "  - No inter-section dependencies",
            "",
            "COMPLEX prompts (use full 9-step process):",
            "  - Multiple sections serving different functions",
            "  - Conditional behaviors or rule hierarchies",
            "  - Tool orchestration or multi-step workflows",
            "  - Known failure modes that need addressing",
            "",
            "If SIMPLE: Note 'LIGHTWEIGHT' and proceed with abbreviated analysis",
            "If COMPLEX: Note 'FULL PROCESS' and proceed to step 2",
            "",
            "Read the prompt file now. Do NOT read references yet.",
        ],
        "state_requirements": [
            "PROMPT_PATH: path to the prompt being optimized",
            "COMPLEXITY: SIMPLE or COMPLEX",
            "PROMPT_SUMMARY: 2-3 sentences describing purpose",
            "PROMPT_LENGTH: approximate line count",
        ],
    }


def get_step_2_guidance():
    """Step 2: Understand - Blind problem identification."""
    return {
        "title": "Understand (Blind)",
        "actions": [
            "CRITICAL: Do NOT read the reference documents yet.",
            "This step uses BLIND problem identification to prevent pattern-shopping.",
            "",
            "Document the prompt's OPERATING CONTEXT:",
            "  - Interaction model: single-shot or conversational?",
            "  - Agent type: tool-use, coding, analysis, or general?",
            "  - Token constraints: brevity critical or thoroughness preferred?",
            "  - Failure modes: what goes wrong when this prompt fails?",
            "",
            "Identify PROBLEMS by examining the prompt text directly:",
            "  - Quote specific problematic text with line numbers",
            "  - Describe what's wrong in concrete terms",
            "  - Note observable symptoms (not guessed causes)",
            "",
            "Examples of observable problems:",
            "  'Lines 12-15 use hedging language: \"might want to\", \"could try\"'",
            "  'No examples provided for expected output format'",
            "  'Multiple rules marked CRITICAL with no clear precedence'",
            "  'Instructions say what NOT to do but not what TO do'",
            "",
            "List at least 3 specific problems with quoted evidence.",
        ],
        "state_requirements": [
            "OPERATING_CONTEXT: interaction model, agent type, constraints",
            "PROBLEMS: list of specific issues with QUOTED text from prompt",
            "Each problem must have: line reference, quoted text, description",
        ],
    }


def get_step_3_guidance():
    """Step 3: Plan - Consult references, match techniques."""
    return {
        "title": "Plan",
        "actions": [
            "NOW read the reference documents:",
            "  - references/prompt-engineering-single-turn.md (always)",
            "  - references/prompt-engineering-multi-turn.md (if multi-turn prompt)",
            "",
            "For EACH problem identified in Step 2:",
            "",
            "1. Locate a matching technique in the reference",
            "2. QUOTE the trigger condition from the Technique Selection Guide",
            "3. QUOTE the expected effect",
            "4. Note stacking compatibility and conflicts",
            "5. Draft the BEFORE/AFTER transformation",
            "",
            "Format each proposed change as a visual card:",
            "",
            "  CHANGE N: [title]",
            "  PROBLEM: [quoted text from prompt]",
            "  TECHNIQUE: [name]",
            "  TRIGGER: \"[quoted from reference]\"",
            "  EFFECT: \"[quoted from reference]\"",
            "  BEFORE: [original prompt text]",
            "  AFTER: [modified prompt text]",
            "",
            "If you cannot quote a trigger condition that matches, do NOT apply.",
        ],
        "state_requirements": [
            "PROBLEMS: (from step 2)",
            "PROPOSED_CHANGES: list of visual cards, each with:",
            "  - Problem quoted from prompt",
            "  - Technique name",
            "  - Trigger condition QUOTED from reference",
            "  - Effect QUOTED from reference",
            "  - BEFORE/AFTER text",
            "STACKING_NOTES: compatibility between proposed techniques",
        ],
    }


def get_step_4_guidance():
    """Step 4: Verify - Factored verification of facts."""
    return {
        "title": "Verify (Factored)",
        "actions": [
            "FACTORED VERIFICATION: Answer questions WITHOUT seeing your proposals.",
            "",
            "For EACH proposed technique, generate OPEN verification questions:",
            "",
            "  WRONG (yes/no): 'Is Affirmative Directives applicable here?'",
            "  RIGHT (open):   'What is the trigger condition for Affirmative Directives?'",
            "",
            "  WRONG (yes/no): 'Does the prompt have hedging language?'",
            "  RIGHT (open):   'What hedging phrases appear in lines 10-20?'",
            "",
            "Answer each question INDEPENDENTLY:",
            "  - Pretend you have NOT seen your proposals",
            "  - Answer from the reference or prompt text directly",
            "  - Do NOT defend your choices; seek truth",
            "",
            "Then CROSS-CHECK: Compare answers to your claims:",
            "",
            "  TECHNIQUE: [name]",
            "  CLAIMED TRIGGER: \"[what you quoted in step 3]\"",
            "  VERIFIED TRIGGER: \"[what the reference actually says]\"",
            "  MATCH: CONSISTENT / INCONSISTENT / PARTIAL",
            "",
            "  CLAIMED PROBLEM: \"[quoted prompt text in step 3]\"",
            "  VERIFIED TEXT: \"[what the prompt actually says at that line]\"",
            "  MATCH: CONSISTENT / INCONSISTENT / PARTIAL",
        ],
        "state_requirements": [
            "VERIFICATION_QS: open questions for each technique",
            "VERIFICATION_ANSWERS: factored answers (without seeing proposals)",
            "CROSS_CHECK: for each technique:",
            "  - Claimed vs verified trigger condition",
            "  - Claimed vs verified prompt text",
            "  - Match status: CONSISTENT / INCONSISTENT / PARTIAL",
        ],
    }


def get_step_5_guidance():
    """Step 5: Feedback - Generate actionable critique."""
    return {
        "title": "Feedback",
        "actions": [
            "Generate FEEDBACK based on verification results.",
            "",
            "Self-Refine research requires feedback to be:",
            "  - ACTIONABLE: contains concrete action to improve",
            "  - SPECIFIC: identifies concrete phrases to change",
            "",
            "WRONG (vague): 'The technique selection could be improved.'",
            "RIGHT (actionable): 'Change 3 claims Affirmative Directives but the",
            "  prompt text at line 15 is already affirmative. Remove this change.'",
            "",
            "For each INCONSISTENT or PARTIAL match from Step 4:",
            "",
            "  ISSUE: [specific problem from cross-check]",
            "  ACTION: [concrete fix]",
            "    - Replace technique with [alternative]",
            "    - Modify BEFORE/AFTER to [specific change]",
            "    - Remove change entirely because [reason]",
            "",
            "For CONSISTENT matches: Note 'VERIFIED - no changes needed'",
            "",
            "Do NOT apply feedback yet. Only generate critique.",
        ],
        "state_requirements": [
            "CROSS_CHECK: (from step 4)",
            "FEEDBACK: for each proposed change:",
            "  - STATUS: VERIFIED / NEEDS_REVISION / REMOVE",
            "  - If NEEDS_REVISION: specific actionable fix",
            "  - If REMOVE: reason for removal",
        ],
    }


def get_step_6_guidance():
    """Step 6: Refine - Apply feedback to update plan."""
    return {
        "title": "Refine",
        "actions": [
            "Apply the feedback from Step 5 to update your proposed changes.",
            "",
            "For each change marked VERIFIED: Keep unchanged",
            "",
            "For each change marked NEEDS_REVISION:",
            "  - Apply the specific fix from feedback",
            "  - Update the BEFORE/AFTER text",
            "  - Verify the trigger condition still matches",
            "",
            "For each change marked REMOVE: Delete from proposal",
            "",
            "After applying all feedback, verify:",
            "  - No stacking conflicts between remaining techniques",
            "  - All BEFORE/AFTER transformations are consistent",
            "  - No duplicate or overlapping changes",
            "",
            "Produce the REFINED PLAN ready for human approval.",
        ],
        "state_requirements": [
            "REFINED_CHANGES: updated list of visual cards",
            "CHANGES_MADE: what was revised or removed and why",
            "FINAL_STACKING_CHECK: confirm no conflicts",
        ],
    }


def get_step_7_guidance():
    """Step 7: Approval - Present to human, hard gate."""
    return {
        "title": "Approval Gate",
        "actions": [
            "Present the REFINED PLAN to the user for approval.",
            "",
            "Format:",
            "",
            "  ## Proposed Changes",
            "",
            "  [Visual cards for each change]",
            "",
            "  ## Verification Summary",
            "  - [N] changes verified against reference",
            "  - [M] changes revised based on verification",
            "  - [K] changes removed (did not match trigger conditions)",
            "",
            "  ## Compatibility",
            "  - [Note stacking synergies]",
            "  - [Note any resolved conflicts]",
            "",
            "  ## Anti-Patterns Checked",
            "  - Hedging Spiral: [checked/found/none]",
            "  - Everything-Is-Critical: [checked/found/none]",
            "  - Negative Instruction Trap: [checked/found/none]",
            "",
            "  ---",
            "  Does this plan look reasonable? Confirm to proceed with execution.",
            "",
            "HARD GATE: Do NOT proceed to Step 8 without explicit user approval.",
        ],
        "state_requirements": [
            "REFINED_CHANGES: (from step 6)",
            "APPROVAL_PRESENTATION: formatted summary for user",
            "USER_APPROVAL: must be obtained before step 8",
        ],
    }


def get_step_8_guidance():
    """Step 8: Execute - Apply approved changes."""
    return {
        "title": "Execute",
        "actions": [
            "Apply the approved changes to the prompt.",
            "",
            "Work through changes in logical order (by prompt section).",
            "",
            "For each approved change:",
            "  1. Locate the target text in the prompt",
            "  2. Apply the BEFORE -> AFTER transformation",
            "  3. Verify the modification matches what was approved",
            "",
            "No additional approval needed per change - plan was approved in Step 7.",
            "",
            "If a conflict is discovered during execution:",
            "  - STOP and present the conflict to user",
            "  - Wait for resolution before continuing",
            "",
            "After all changes applied, proceed to integration.",
        ],
        "state_requirements": [
            "APPROVED_CHANGES: (from step 7)",
            "APPLIED_CHANGES: list of what was modified",
            "EXECUTION_NOTES: any issues encountered",
        ],
    }


def get_step_9_guidance():
    """Step 9: Integrate - Coherence and quality verification."""
    return {
        "title": "Integrate",
        "actions": [
            "Verify the optimized prompt holistically.",
            "",
            "COHERENCE CHECKS:",
            "  - Cross-section references: do sections reference each other correctly?",
            "  - Terminology consistency: same terms throughout?",
            "  - Priority consistency: do multiple sections align on priorities?",
            "  - Flow and ordering: logical progression?",
            "",
            "EMPHASIS AUDIT:",
            "  - Count CRITICAL, IMPORTANT, NEVER, ALWAYS markers",
            "  - If more than 2-3 highest-level markers, reconsider",
            "",
            "ANTI-PATTERN FINAL CHECK:",
            "  - Hedging Spiral: accumulated uncertainty language?",
            "  - Everything-Is-Critical: overuse of emphasis?",
            "  - Negative Instruction Trap: 'don't' instead of 'do'?",
            "  - Implicit Category Trap: examples without principles?",
            "",
            "QUALITY VERIFICATION (open questions):",
            "  - 'What behavior will this produce in edge cases?'",
            "  - 'How would an agent interpret this if skimming?'",
            "  - 'What could go wrong with this phrasing?'",
            "",
            "Present the final optimized prompt with summary of changes.",
        ],
        "state_requirements": [],  # Final step
    }


def get_guidance(step: int, total_steps: int):
    """Dispatch to appropriate guidance based on step number."""
    guidance_map = {
        1: get_step_1_guidance,
        2: get_step_2_guidance,
        3: get_step_3_guidance,
        4: get_step_4_guidance,
        5: get_step_5_guidance,
        6: get_step_6_guidance,
        7: get_step_7_guidance,
        8: get_step_8_guidance,
        9: get_step_9_guidance,
    }

    if step in guidance_map:
        return guidance_map[step]()

    # Extra steps beyond 9 continue integration/verification
    return get_step_9_guidance()


def format_output(step: int, total_steps: int, thoughts: str) -> str:
    """Format output for display."""
    guidance = get_guidance(step, total_steps)
    is_complete = step >= total_steps

    lines = [
        "=" * 70,
        f"PROMPT ENGINEER - Step {step}/{total_steps}: {guidance['title']}",
        "=" * 70,
        "",
        "ACCUMULATED STATE:",
        thoughts[:1200] + "..." if len(thoughts) > 1200 else thoughts,
        "",
        "ACTIONS:",
    ]
    lines.extend(f"  {action}" for action in guidance["actions"])

    state_reqs = guidance.get("state_requirements", [])
    if not is_complete and state_reqs:
        lines.append("")
        lines.append("NEXT STEP STATE MUST INCLUDE:")
        lines.extend(f"  - {item}" for item in state_reqs)

    lines.append("")

    if is_complete:
        lines.extend([
            "COMPLETE - Present to user:",
            "  1. Summary of optimization process",
            "  2. Techniques applied with reference sections",
            "  3. Quality improvements (top 3)",
            "  4. What was preserved from original",
            "  5. Final optimized prompt",
        ])
    else:
        next_guidance = get_guidance(step + 1, total_steps)
        lines.extend([
            f"NEXT: Step {step + 1} - {next_guidance['title']}",
            f"REMAINING: {total_steps - step} step(s)",
            "",
            "ADJUST: increase --total-steps if more verification needed (min 9)",
        ])

    lines.extend(["", "=" * 70])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Prompt Engineer - Multi-turn optimization workflow",
        epilog=(
            "Phases: triage (1) -> understand (2) -> plan (3) -> "
            "verify (4) -> feedback (5) -> refine (6) -> "
            "approval (7) -> execute (8) -> integrate (9)"
        ),
    )
    parser.add_argument("--step", type=int, required=True)
    parser.add_argument("--total-steps", type=int, required=True)
    parser.add_argument("--thoughts", type=str, required=True)
    args = parser.parse_args()

    if args.step < 1:
        sys.exit("ERROR: --step must be >= 1")
    if args.total_steps < 9:
        sys.exit("ERROR: --total-steps must be >= 9 (requires 9 phases)")
    if args.step > args.total_steps:
        sys.exit("ERROR: --step cannot exceed --total-steps")

    print(format_output(args.step, args.total_steps, args.thoughts))


if __name__ == "__main__":
    main()
