#!/usr/bin/env python3
"""
Problem Analysis Skill - Structured deep reasoning workflow.

Guides problem analysis through seven phases:
  1. Decompose  - understand problem space, constraints, assumptions
  2. Generate   - create initial solution approaches
  3. Expand     - push for MORE solutions not yet considered
  4. Critique   - Self-Refine feedback on solutions
  5. Verify     - factored verification of assumptions
  6. Cross-check - reconcile verified facts with claims
  7. Synthesize - structured trade-off analysis

Extra steps beyond 7 go to verification (where accuracy improves most).

Usage:
    python3 analyze.py --step 1 --total-steps 7 --thoughts "Problem: <describe the decision or challenge>"

Research grounding:
  - ToT (Yao 2023): decompose into thoughts "small enough for diverse samples,
    big enough to evaluate"
  - CoVe (Dhuliawala 2023): factored verification improves accuracy 17%->70%.
    Use OPEN questions, not yes/no ("model tends to agree whether right or wrong")
  - Self-Refine (Madaan 2023): feedback must be "actionable and specific";
    separate feedback from refinement for 5-40% improvement
  - Analogical Prompting (Yasunaga 2024): "recall relevant and distinct problems"
    improves reasoning; diversity in self-generated examples is critical
  - Diversity-Based Selection (Zhang 2022): "even with 50% wrong demonstrations,
    diversity-based clustering performance does not degrade significantly"
"""

import argparse
import sys


def get_step_1_guidance():
    """Step 1: Problem Decomposition - understand the problem space."""
    return (
        "Problem Decomposition",
        [
            "State the CORE PROBLEM in one sentence: 'I need to decide X'",
            "",
            "List HARD CONSTRAINTS (non-negotiable):",
            "  - Hard constraints: latency limits, accuracy requirements, compatibility",
            "  - Resource constraints: budget, timeline, skills, capacity",
            "  - Quality constraints: what 'good' looks like for this problem",
            "",
            "List SOFT CONSTRAINTS (preferences, can trade off)",
            "",
            "List VARIABLES (what you control):",
            "  - Structural choices (architecture, format, organization)",
            "  - Content choices (scope, depth, audience, tone)",
            "  - Process choices (workflow, tools, automation level)",
            "",
            "Surface HIDDEN ASSUMPTIONS by asking:",
            "  'What am I assuming about scale/load patterns?'",
            "  'What am I assuming about the team's capabilities?'",
            "  'What am I assuming will NOT change?'",
            "",
            "If unclear, use AskUserQuestion to clarify",
        ],
        [
            "PROBLEM (one sentence)",
            "HARD CONSTRAINTS (non-negotiable)",
            "SOFT CONSTRAINTS (preferences)",
            "VARIABLES (what you control)",
            "ASSUMPTIONS (surfaced via questions)",
        ],
    )


def get_step_2_guidance():
    """Step 2: Solution Generation - create distinct approaches."""
    return (
        "Solution Generation",
        [
            "Generate 2-4 DISTINCT solution approaches",
            "",
            "Solutions must differ on a FUNDAMENTAL AXIS:",
            "  - Scope: narrow-deep vs broad-shallow",
            "  - Complexity: simple-but-limited vs complex-but-flexible",
            "  - Control: standardized vs customizable",
            "  - Approach: build vs buy, manual vs automated, centralized vs distributed",
            "  (Identify axes specific to your problem domain)",
            "",
            "For EACH solution, document:",
            "  - Name: short label (e.g., 'Option A', 'Hybrid Approach')",
            "  - Core mechanism: HOW it solves the problem (1-2 sentences)",
            "  - Key assumptions: what must be true for this to work",
            "  - Claimed benefits: what this approach provides",
            "",
            "AVOID premature convergence - do not favor one solution yet",
        ],
        [
            "PROBLEM (from step 1)",
            "CONSTRAINTS (from step 1)",
            "SOLUTIONS (each with: name, mechanism, assumptions, claimed benefits)",
        ],
    )


def get_step_3_guidance():
    """Step 3: Solution Expansion - push beyond initial ideas."""
    return (
        "Solution Expansion",
        [
            "Review the solutions from step 2. Now PUSH FURTHER:",
            "",
            "UNEXPLORED AXES - What fundamental trade-offs were NOT represented?",
            "  - If all solutions are complex, what's the SIMPLEST approach?",
            "  - If all are centralized, what's DISTRIBUTED?",
            "  - If all use technology X, what uses its OPPOSITE or COMPETITOR?",
            "  - If all optimize for metric A, what optimizes for metric B?",
            "",
            "ADJACENT DOMAINS - What solutions from RELATED problems might apply?",
            "  'How does [related domain] solve similar problems?'",
            "  'What would [different industry/field] do here?'",
            "  'What patterns from ADJACENT DOMAINS might apply?'",
            "",
            "ANTI-SOLUTIONS - What's the OPPOSITE of each current solution?",
            "  If Solution A is stateful, what's stateless?",
            "  If Solution A is synchronous, what's asynchronous?",
            "  If Solution A is custom-built, what's off-the-shelf?",
            "",
            "NULL/MINIMAL OPTIONS:",
            "  - What if we did NOTHING and accepted the current state?",
            "  - What if we solved a SMALLER version of the problem?",
            "  - What's the 80/20 solution that's 'good enough'?",
            "",
            "ADD 1-3 MORE solutions. Each must represent an axis/approach",
            "not covered by the initial set.",
        ],
        [
            "INITIAL SOLUTIONS (from step 2)",
            "AXES NOT YET EXPLORED (identified gaps)",
            "NEW SOLUTIONS (1-3 additional, each with: name, mechanism, assumptions)",
            "COMPLETE SOLUTION SET (all solutions for next phase)",
        ],
    )


def get_step_4_guidance():
    """Step 4: Solution Critique - Self-Refine feedback phase."""
    return (
        "Solution Critique",
        [
            "For EACH solution, identify weaknesses:",
            "  - What could go wrong? (failure modes)",
            "  - What does this solution assume that might be false?",
            "  - Where is the complexity hiding?",
            "  - What operational burden does this create?",
            "",
            "Generate SPECIFIC, ACTIONABLE feedback:",
            "  BAD:  'This might have scaling issues'",
            "  GOOD: 'Single-node Redis fails at >100K ops/sec; Solution A",
            "         assumes <50K ops/sec but requirements say 200K'",
            "",
            "Identify which solutions should be:",
            "  - ELIMINATED: fatal flaw, violates hard constraint",
            "  - REFINED: fixable weakness, needs modification",
            "  - ADVANCED: no obvious flaws, proceed to verification",
            "",
            "For REFINED solutions, state the specific modification needed",
        ],
        [
            "SOLUTIONS (from step 2)",
            "CRITIQUE for each (specific weaknesses, failure modes)",
            "DISPOSITION: ELIMINATED / REFINED / ADVANCED for each",
            "MODIFICATIONS needed for REFINED solutions",
        ],
    )


def get_verification_guidance():
    """
    Steps 4 to N-2: Factored Assumption Verification.

    Key insight from CoVe: answer verification questions WITHOUT attending
    to the original solutions. Models that see their own hallucinations
    tend to repeat them.
    """
    return (
        "Factored Verification",
        [
            "FACTORED VERIFICATION (answer WITHOUT looking at solutions):",
            "",
            "Step A - List assumptions as OPEN questions:",
            "  BAD:  'Is option A better?' (yes/no triggers agreement bias)",
            "  GOOD: 'What throughput does option A achieve under heavy load?'",
            "  GOOD: 'What reading level does this document require?'",
            "  GOOD: 'How long does this workflow take with the proposed automation?'",
            "",
            "Step B - Answer each question INDEPENDENTLY:",
            "  - Pretend you have NOT seen the solutions",
            "  - Answer from first principles or domain knowledge",
            "  - Do NOT defend any solution; seek truth",
            "  - Cite sources or reasoning for each answer",
            "",
            "Step C - Categorize each assumption:",
            "  VERIFIED:  evidence confirms the assumption",
            "  FALSIFIED: evidence contradicts (note: 'claimed X, actually Y')",
            "  UNCERTAIN: insufficient evidence; note what would resolve it",
        ],
        [
            "SOLUTIONS still under consideration",
            "VERIFICATION QUESTIONS (open, not yes/no)",
            "ANSWERS (independent, from first principles)",
            "CATEGORIZED: VERIFIED / FALSIFIED / UNCERTAIN for each",
        ],
    )


def get_crosscheck_guidance():
    """
    Step N-1: Cross-check - reconcile verified facts with original claims.

    From CoVe Factor+Revise: explicit cross-check achieves +7.7 FACTSCORE
    points over factored verification alone.
    """
    return (
        "Cross-Check",
        [
            "Reconcile verified facts with solution claims:",
            "",
            "For EACH surviving solution:",
            "  - Which claims are now SUPPORTED by verification?",
            "  - Which claims are CONTRADICTED? (list specific contradictions)",
            "  - Which claims remain UNTESTED?",
            "",
            "Update solution viability:",
            "  - Mark solutions with falsified CORE assumptions as ELIMINATED",
            "  - Note which solutions gained credibility (verified strengths)",
            "  - Note which solutions lost credibility (falsified claims)",
            "",
            "Check for EMERGENT solutions:",
            "  - Do verified facts suggest an approach not previously considered?",
            "  - Can surviving solutions be combined based on verified strengths?",
        ],
        [
            "SOLUTIONS with updated status",
            "SUPPORTED claims (with evidence)",
            "CONTRADICTED claims (with specific contradictions)",
            "UNTESTED claims",
            "ELIMINATED solutions (if any, with reason)",
            "EMERGENT solutions (if any)",
        ],
    )


def get_final_step_guidance():
    """Final step: Structured Trade-off Synthesis."""
    return (
        "Trade-off Synthesis",
        [
            "STRUCTURED SYNTHESIS:",
            "",
            "1. SURVIVING SOLUTIONS:",
            "   List solutions NOT eliminated by falsified assumptions",
            "",
            "2. TRADE-OFF MATRIX (verified facts only):",
            "   For each dimension that matters to THIS decision:",
            "   - Measurable outcomes: 'A achieves X; B achieves Y (verified)'",
            "   - Complexity/effort: 'A requires N; B requires M'",
            "   - Risk profile: 'A fails when...; B fails when...'",
            "   (Add dimensions specific to your problem)",
            "",
            "3. DECISION FRAMEWORK:",
            "   'If [hard constraint] is paramount -> choose A because...'",
            "   'If [other priority] matters more -> choose B because...'",
            "   'If uncertain about [X] -> gather [specific data] first'",
            "",
            "4. RECOMMENDATION (if one solution dominates):",
            "   State which solution and the single strongest reason",
            "   Acknowledge what you're giving up by choosing it",
        ],
        [],  # No next step
    )


def get_guidance(step: int, total_steps: int):
    """
    Dispatch to appropriate guidance based on step number.

    7-phase structure:
      Step 1:      Decomposition
      Step 2:      Generation (initial solutions)
      Step 3:      Expansion (push for MORE solutions)
      Step 4:      Critique (Self-Refine feedback)
      Steps 5-N-2: Verification (factored, extra steps go here)
      Step N-1:    Cross-check
      Step N:      Synthesis
    """
    if step == 1:
        return get_step_1_guidance()
    if step == 2:
        return get_step_2_guidance()
    if step == 3:
        return get_step_3_guidance()
    if step == 4:
        return get_step_4_guidance()
    if step == total_steps:
        return get_final_step_guidance()
    if step == total_steps - 1:
        return get_crosscheck_guidance()
    # Steps 5 to N-2 are verification
    return get_verification_guidance()


def format_output(step: int, total_steps: int, thoughts: str) -> str:
    """Format output for display."""
    title, actions, next_state = get_guidance(step, total_steps)
    is_complete = step >= total_steps

    lines = [
        "=" * 70,
        f"PROBLEM ANALYSIS - Step {step}/{total_steps}: {title}",
        "=" * 70,
        "",
        "ACCUMULATED STATE:",
        thoughts[:1200] + "..." if len(thoughts) > 1200 else thoughts,
        "",
        "ACTIONS:",
    ]
    lines.extend(f"  {action}" for action in actions)

    if not is_complete and next_state:
        lines.append("")
        lines.append("NEXT STEP STATE MUST INCLUDE:")
        lines.extend(f"  - {item}" for item in next_state)

    lines.append("")

    if is_complete:
        lines.extend([
            "COMPLETE - Present to user:",
            "  1. Problem and constraints (from decomposition)",
            "  2. Solutions considered (including eliminated ones and why)",
            "  3. Verified facts (from factored verification)",
            "  4. Trade-off matrix with decision framework",
            "  5. Recommendation (if one dominates) or decision criteria",
        ])
    else:
        next_title, _, _ = get_guidance(step + 1, total_steps)
        lines.extend([
            f"NEXT: Step {step + 1} - {next_title}",
            f"REMAINING: {total_steps - step} step(s)",
            "",
            "ADJUST: increase --total-steps if more verification needed (min 7)",
        ])

    lines.extend(["", "=" * 70])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Problem Analysis - Structured deep reasoning",
        epilog=(
            "Phases: decompose (1) -> generate (2) -> expand (3) -> "
            "critique (4) -> verify (5 to N-2) -> cross-check (N-1) -> synthesize (N)"
        ),
    )
    parser.add_argument("--step", type=int, required=True)
    parser.add_argument("--total-steps", type=int, required=True)
    parser.add_argument("--thoughts", type=str, required=True)
    args = parser.parse_args()

    if args.step < 1:
        sys.exit("ERROR: --step must be >= 1")
    if args.total_steps < 7:
        sys.exit("ERROR: --total-steps must be >= 7 (requires 7 phases)")
    if args.step > args.total_steps:
        sys.exit("ERROR: --step cannot exceed --total-steps")

    print(format_output(args.step, args.total_steps, args.thoughts))


if __name__ == "__main__":
    main()
