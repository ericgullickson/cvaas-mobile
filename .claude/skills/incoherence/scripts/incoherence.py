#!/usr/bin/env python3
"""
Incoherence Detector - Step-based incoherence detection workflow

Usage:
    python3 incoherence.py --step-number 1 --total-steps 21 --thoughts "Analyzing project X"

DETECTION PHASE (Steps 1-12):
    Steps 1-3 (Parent): Survey, dimension selection, exploration dispatch
    Steps 4-7 (Sub-Agent): Broad sweep, coverage check, gap-fill, format findings
    Step 8 (Parent): Synthesis & candidate selection
    Step 9 (Parent): Deep-dive dispatch
    Steps 10-11 (Sub-Agent): Deep-dive exploration and formatting
    Step 12 (Parent): Verdict analysis and grouping

INTERACTIVE RESOLUTION PHASE (Steps 13-15):
    Step 13 (Parent): Prepare resolution batches from groups
    Step 14 (Parent): Present batch via AskUserQuestion
                      - Group batches: ask group question ONLY first
                      - Non-group or MODE=individual: ask per-issue questions
    Step 15 (Parent): Loop controller
                      - If unified chosen: record for all, next batch
                      - If individual chosen: loop to step 14 with MODE=individual
                      - If all batches done: proceed to application

APPLICATION PHASE (Steps 16-21):
    Step 16 (Parent): Analyze targets and select agent types
    Step 17 (Parent): Dispatch current wave of agents
    Steps 18-19 (Sub-Agent): Apply resolution, format result
    Step 20 (Parent): Collect wave results, check for next wave
    Step 21 (Parent): Present final report to user

Resolution is interactive - user answers AskUserQuestion prompts inline.
No manual file editing required.
"""

import argparse
import sys
import os

DIMENSION_CATALOG = """
ABSTRACT DIMENSION CATALOG
==========================

Choose dimensions from this catalog based on Step 1 info sources.

CATEGORY A: SPECIFICATION VS BEHAVIOR
  - README/docs claim X, but code does Y
  - API documentation vs actual API behavior
  - Examples in docs that don't actually work
  Source pairs: Documentation <-> Code implementation

CATEGORY B: INTERFACE CONTRACT INTEGRITY
  - Type definitions vs actual runtime values
  - Schema definitions vs validation behavior
  - Function signatures vs docstrings
  Source pairs: Type/Schema definitions <-> Runtime behavior

CATEGORY C: CROSS-REFERENCE CONSISTENCY
  - Same concept described differently in different docs
  - Numeric constants/limits stated inconsistently
  - Intra-document contradictions
  Source pairs: Document <-> Document

CATEGORY D: TEMPORAL CONSISTENCY (Staleness)
  - Outdated comments referencing removed code
  - TODO/FIXME comments for completed work
  - References to renamed/moved files
  Source pairs: Historical references <-> Current state

CATEGORY E: ERROR HANDLING CONSISTENCY
  - Documented error codes vs actual error responses
  - Exception handling docs vs throw/catch behavior
  Source pairs: Error documentation <-> Error implementation

CATEGORY F: CONFIGURATION & ENVIRONMENT
  - Documented env vars vs actual env var usage
  - Default values in docs vs defaults in code
  Source pairs: Config documentation <-> Config handling code

CATEGORY G: AMBIGUITY & UNDERSPECIFICATION
  - Vague statements that could be interpreted multiple ways
  - Missing thresholds, limits, or parameters
  - Implicit assumptions not stated explicitly
  Detection method: Ask "could two people read this differently?"

CATEGORY H: POLICY & CONVENTION COMPLIANCE
  - Architectural decisions (ADRs) violated by implementation
  - Style guide rules not followed in code
  - "We don't do X" statements violated in codebase
  Source pairs: Policy documents <-> Implementation patterns

CATEGORY I: COMPLETENESS & DOCUMENTATION GAPS
  - Public API endpoints with no documentation
  - Functions/classes with no docstrings
  - Magic values/constants without explanation
  Detection method: Find code constructs, check if docs exist

CATEGORY J: COMPOSITIONAL CONSISTENCY
  - Claims individually valid but jointly impossible
  - Numeric constraints that contradict when combined
  - Configuration values that create impossible states
  - Timing/resource constraints that cannot all be satisfied
  Detection method: Gather related claims, compute implications, check for contradiction
  Example: timeout=30s, retries=10, max_duration=60s → 30×10=300≠60

CATEGORY K: IMPLICIT CONTRACT INTEGRITY
  - Names/identifiers promise behavior the code doesn't deliver
  - Function named validateX() that doesn't actually validate
  - Error messages that misrepresent the actual error
  - Module/package names that don't match contents
  - Log messages that lie about what happened
  Detection method: Parse names semantically, infer promise, compare to behavior
  Note: LLMs are particularly susceptible to being misled by names

CATEGORY L: DANGLING SPECIFICATION REFERENCES
  - Entity A references entity B, but B is never defined anywhere
  - FK references table that has no schema (e.g., api_keys.tenant_id but no tenants table)
  - UI/API mentions endpoints or types that are not specified
  - Schema field references enum or type with no definition
  Detection method:
    1. Extract DEFINED entities (tables, APIs, types, enums) with locations
    2. Extract REFERENCED entities (FKs, type usages, API calls) with locations
    3. Report: referenced but not defined = dangling reference
  Source pairs: Any specification -> Cross-file entity registry
  Note: Distinct from I (code-without-docs). L is SPEC-without-SPEC.

CATEGORY M: INCOMPLETE SPECIFICATION DEFINITIONS
  - Entity is defined but missing components required for implementation
  - Table schema documented but missing fields that other docs reference
  - API endpoint defined but missing request/response schema
  - Proto/schema has fields but lacks types others expect
  Detection method:
    1. For each defined entity, extract CLAIMED components
    2. Cross-reference with EXPECTED components from consuming docs
    3. Report: expected but not claimed = incomplete definition
  Source pairs: Definition document <-> Consumer documents
  Example: rules table shows (id, name, enabled) but API doc expects 'expression' field

SELECTION RULES:
- Select ALL categories relevant to Step 1 info sources
- Typical selection is 5-8 dimensions
- G, H, I, K are especially relevant for LLM-assisted coding
- J requires cross-referencing multiple claims (more expensive)
- L, M are critical for design-phase docs and specs-to-be-implemented
  Select when docs describe systems that need to be built
"""


def get_step_guidance(step_number, total_steps, script_path=None):
    if script_path is None:
        script_path = os.path.abspath(__file__)

    # =========================================================================
    # DETECTION PHASE: Steps 1-9
    # =========================================================================

    if step_number == 1:
        return {
            "actions": [
                "CODEBASE SURVEY",
                "",
                "Gather MINIMAL context. Do NOT read domain-specific docs.",
                "",
                "ALLOWED: README.md (first 50 lines), CLAUDE.md, directory listing, package manifest",
                "NOT ALLOWED: Detailed docs, source code, configs, tests",
                "",
                "Identify:",
                "1. CODEBASE TYPE: library/service/CLI/framework/application",
                "2. PRIMARY LANGUAGE",
                "3. DOCUMENTATION LOCATIONS",
                "4. INFO SOURCE TYPES:",
                "   [ ] README/guides  [ ] API docs  [ ] Code comments",
                "   [ ] Type definitions  [ ] Configs  [ ] Schemas",
                "   [ ] ADRs  [ ] Style guides  [ ] CONTRIBUTING.md",
                "   [ ] Test descriptions  [ ] Error catalogs",
            ],
            "next": "Invoke step 2 with survey results in --thoughts"
        }

    if step_number == 2:
        return {
            "actions": [
                "DIMENSION SELECTION",
                "",
                "Select from catalog (A-K) based on Step 1 info sources.",
                "Do NOT read files. Do NOT create domain-specific dimensions.",
                "",
                DIMENSION_CATALOG,
                "",
                "OUTPUT: List selected dimensions with rationale.",
            ],
            "next": "Invoke step 3 with selected dimensions in --thoughts"
        }

    if step_number == 3:
        return {
            "actions": [
                "EXPLORATION DISPATCH",
                "",
                "Launch one haiku Explore agent per dimension.",
                "Launch ALL in a SINGLE message for parallelism.",
                "",
                f"SCRIPT PATH: {script_path}",
                "",
                "AGENT PROMPT TEMPLATE (copy exactly, fill placeholders):",
                "```",
                "DIMENSION EXPLORATION TASK",
                "",
                "DIMENSION: {category_letter} - {dimension_name}",
                "DESCRIPTION: {description_from_catalog}",
                "",
                "Start by invoking:",
                f"  python3 {script_path} --step-number 4 --total-steps 21 \\",
                "    --thoughts \"Dimension: {category_letter} - {dimension_name}\"",
                "```",
            ],
            "next": "After all agents complete, invoke step 8 with combined findings"
        }

    # =========================================================================
    # EXPLORATION SUB-AGENT STEPS: 4-7
    # =========================================================================

    if step_number == 4:
        return {
            "actions": [
                "BROAD SWEEP [SUB-AGENT]",
                "",
                "Cast a WIDE NET. Prioritize recall over precision.",
                "Report ANYTHING that MIGHT be incoherence. Verification comes later.",
                "",
                "Your dimension (from --thoughts) tells you what to look for.",
                "",
                "SEARCH STRATEGY:",
                "  1. Start with obvious locations (docs/, README, src/)",
                "  2. Search for keywords related to your dimension",
                "  3. Check configs, schemas, type definitions",
                "  4. Look at tests for behavioral claims",
                "",
                "FOR OMISSION DIMENSIONS (L, M):",
                "  Before searching for conflicts, BUILD AN ENTITY REGISTRY:",
                "",
                "  5. Extract DEFINED entities from each doc:",
                "     - Database tables (CREATE TABLE, schema blocks)",
                "     - API endpoints (route definitions, endpoint specs)",
                "     - Types/enums (type definitions, enum declarations)",
                "     Record: entity_name, entity_type, file:line, components[]",
                "",
                "  6. Extract REFERENCED entities from each doc:",
                "     - FK patterns (table_id -> implies 'table' entity)",
                "     - Type usages (returns UserResponse -> implies UserResponse)",
                "     - API calls (calls /api/users -> implies endpoint)",
                "     Record: entity_name, reference_type, file:line",
                "",
                "  7. Cross-reference:",
                "     - REFERENCED but not DEFINED -> Category L finding",
                "     - DEFINED but missing expected components -> Category M finding",
                "",
                "FOR EACH POTENTIAL FINDING, note:",
                "  - Location A (file:line)",
                "  - Location B (file:line)",
                "  - What might conflict",
                "  - Confidence: high/medium/low (low is OK!)",
                "",
                "BIAS: Report more, not fewer. False positives are filtered later.",
                "",
                "Track which directories/files you searched.",
            ],
            "next": "Invoke step 5 with your findings and searched locations in --thoughts"
        }

    if step_number == 5:
        return {
            "actions": [
                "COVERAGE CHECK [SUB-AGENT]",
                "",
                "Review your search coverage. Identify GAPS.",
                "",
                "ASK YOURSELF:",
                "  - What directories have I NOT searched?",
                "  - What file types did I skip? (.yaml, .json, .toml, tests?)",
                "  - Are there related modules I haven't checked?",
                "  - Did I only look at obvious places?",
                "  - What would a second reviewer check that I didn't?",
                "",
                "DIVERSITY CHECK:",
                "  - Are all my findings in one directory? (bad)",
                "  - Are all my findings the same file type? (bad)",
                "  - Did I check both docs AND code? Both should have claims.",
                "",
                "OUTPUT:",
                "  1. List of gaps/unexplored areas (at least 3)",
                "  2. Specific files or patterns to search next",
            ],
            "next": "Invoke step 6 with identified gaps in --thoughts"
        }

    if step_number == 6:
        return {
            "actions": [
                "GAP-FILL EXPLORATION [SUB-AGENT]",
                "",
                "Explore the gaps identified in step 5.",
                "",
                "REQUIREMENTS:",
                "  - Search at least 3 new locations from your gap list",
                "  - Use different search strategies than before",
                "  - Look in non-obvious places (tests, examples, scripts/)",
                "",
                "ADDITIONAL TECHNIQUES:",
                "  - Search for negations ('not', 'don't', 'never', 'deprecated')",
                "  - Look for TODOs, FIXMEs, HACKs near your dimension's topic",
                "  - Check git-ignored or generated files if accessible",
                "",
                "Record any new potential incoherences found.",
                "Same format: Location A, Location B, conflict, confidence.",
            ],
            "next": "Invoke step 7 with all findings (original + new) in --thoughts"
        }

    if step_number == 7:
        return {
            "actions": [
                "FORMAT EXPLORATION FINDINGS [SUB-AGENT]",
                "",
                "Consolidate all findings from your exploration.",
                "",
                "OUTPUT FORMAT:",
                "```",
                "EXPLORATION RESULTS - DIMENSION {letter}",
                "",
                "FINDING 1:",
                "  Location A: [file:line]",
                "  Location B: [file:line]",
                "  Potential conflict: [one-line description]",
                "  Confidence: high|medium|low",
                "",
                "[repeat for each finding]",
                "",
                "TOTAL FINDINGS: N",
                "AREAS SEARCHED: [list of directories/file patterns]",
                "```",
                "",
                "Include ALL findings, even low-confidence ones.",
                "Deduplication happens in step 8.",
            ],
            "next": "Output formatted results. Sub-agent task complete."
        }

    # =========================================================================
    # DETECTION PHASE CONTINUED: Steps 8-13
    # =========================================================================

    if step_number == 8:
        return {
            "actions": [
                "SYNTHESIS & CANDIDATE SELECTION",
                "",
                "Process ALL findings from exploration phase:",
                "",
                "1. SCORE: Rate each (0-10) on Impact + Confidence + Specificity + Fixability",
                "2. SORT: Order by score descending",
                "",
                "Output: C1, C2, ... with location, summary, score, DIMENSION.",
                "",
                "IMPORTANT: Pass ALL scored candidates to verification.",
                "  - Do NOT limit to 10 or any arbitrary number",
                "  - If exploration found 25 candidates, pass all 25",
                "  - Step 9 will launch agents for every candidate",
                "  - System handles batching automatically",
                "",
                "NOTE: Deduplication happens AFTER Sonnet verification (step 12)",
                "to leverage richer analysis for merge decisions.",
            ],
            "next": "Invoke step 9 with all candidates in --thoughts"
        }

    if step_number == 9:
        return {
            "actions": [
                "DEEP-DIVE DISPATCH",
                "",
                "Launch Task agents (subagent_type='general-purpose', model='sonnet')",
                "to verify each candidate.",
                "",
                "CRITICAL: Launch ALL candidates in a SINGLE message.",
                "  - Do NOT self-limit to 10 or any other number",
                "  - If you have 15 candidates, launch 15 agents",
                "  - If you have 30 candidates, launch 30 agents",
                "  - Claude Code automatically queues and batches execution",
                "  - All agents will complete before step 10 proceeds",
                "",
                "Sub-agents will invoke THIS SCRIPT to get their instructions.",
                "",
                f"SCRIPT PATH: {script_path}",
                "",
                "AGENT PROMPT TEMPLATE (copy exactly, fill placeholders):",
                "```",
                "DEEP-DIVE VERIFICATION TASK",
                "",
                "CANDIDATE: {id} at {location}",
                "DIMENSION: {dimension_letter} - {dimension_name}",
                "Claimed issue: {summary}",
                "",
                "YOUR WORKFLOW:",
                "",
                "STEP A: Get exploration instructions",
                f"   python3 {script_path} --step-number 10 --total-steps 21 --thoughts \"Verifying: {{id}}\"",
                "",
                "STEP B: Follow those instructions to gather evidence",
                "",
                "STEP C: Format your findings",
                f"   python3 {script_path} --step-number 11 --total-steps 21 --thoughts \"<your findings>\"",
                "",
                "IMPORTANT: You MUST invoke step 10 before exploring, step 11 to format.",
                "```",
            ],
            "next": "After all agents complete, invoke step 12 with all verdicts"
        }

    # =========================================================================
    # DEEP-DIVE SUB-AGENT STEPS: 10-11
    # =========================================================================

    if step_number == 10:
        return {
            "actions": [
                "DEEP-DIVE EXPLORATION [SUB-AGENT]",
                "",
                "You are verifying a specific candidate. Follow this process:",
                "",
                "1. LOCATE PRIMARY SOURCE",
                "   - Navigate to exact file:line",
                "   - Read 100+ lines of context",
                "   - Identify the claim being made",
                "",
                "2. FIND CONFLICTING SOURCE",
                "   - Locate the second source",
                "   - Read its context too",
                "",
                "3. EXTRACT EVIDENCE",
                "   For EACH source: file path, line number, exact quote, claim",
                "",
                "4. ANALYZE BY DIMENSION TYPE",
                "",
                "   Check the DIMENSION from your task prompt, then apply:",
                "",
                "   FOR CONTRADICTION DIMENSIONS (A, B, C, E, F, J, K):",
                "     - Same thing discussed?",
                "     - Actually contradictory?",
                "     - Context resolves it?",
                "     -> If genuinely contradictory: TRUE_INCOHERENCE",
                "",
                "   FOR AMBIGUITY DIMENSION (G):",
                "     - Could two competent readers interpret this differently?",
                "     - Would clarification benefit users?",
                "     -> If ambiguous and clarification helps: SIGNIFICANT_AMBIGUITY",
                "",
                "   FOR COMPLETENESS DIMENSION (I):",
                "     - Is there missing information readers need?",
                "     - Would documentation here benefit users?",
                "     -> If gap exists and docs needed: DOCUMENTATION_GAP",
                "",
                "   FOR POLICY DIMENSION (H):",
                "     - Orphaned references to deleted content?",
                "       -> DOCUMENTATION_GAP",
                "     - Active policy being violated?",
                "       -> TRUE_INCOHERENCE",
                "",
                "   FOR OMISSION DIMENSIONS (L, M):",
                "     - Is the referenced entity defined ANYWHERE in the doc corpus?",
                "     - If defined, does definition include the referenced component?",
                "     - Could this be implicit/assumed? (e.g., standard library type)",
                "     - Would an implementer be blocked by this omission?",
                "     -> If referenced entity not defined: SPECIFICATION_GAP (dangling)",
                "     -> If defined but incomplete: SPECIFICATION_GAP (incomplete)",
                "",
                "5. DETERMINE VERDICT",
                "   - TRUE_INCOHERENCE: genuinely conflicting claims (A says X, B says not-X)",
                "   - SIGNIFICANT_AMBIGUITY: could confuse readers, clarification needed",
                "   - DOCUMENTATION_GAP: missing info that should exist (code without docs)",
                "   - SPECIFICATION_GAP: entity referenced but not defined, or defined incomplete",
                "     * Dangling reference: spec references entity not defined anywhere",
                "     * Incomplete definition: entity defined but missing expected components",
                "   - FALSE_POSITIVE: not actually a problem",
            ],
            "next": "When done exploring, invoke step 11 with findings in --thoughts"
        }

    if step_number == 11:
        return {
            "actions": [
                "FORMAT RESULTS [SUB-AGENT]",
                "",
                "Structure your findings. This is your FINAL OUTPUT.",
                "",
                "REQUIRED FORMAT:",
                "```",
                "VERIFICATION RESULT",
                "",
                "CANDIDATE: {id}",
                "VERDICT: TRUE_INCOHERENCE | SIGNIFICANT_AMBIGUITY | DOCUMENTATION_GAP | SPECIFICATION_GAP | FALSE_POSITIVE",
                "",
                "SOURCE A:",
                "  File: [path]",
                "  Line: [number]",
                "  Quote: \"[exact quote]\"",
                "  Claims: [what it asserts]",
                "",
                "SOURCE B:",
                "  File: [path]",
                "  Line: [number]",
                "  Quote: \"[exact quote]\"",
                "  Claims: [what it asserts]",
                "",
                "ANALYSIS: [why they do/don't conflict]",
                "",
                "SEVERITY: critical|high|medium|low (if not FALSE_POSITIVE)",
                "RECOMMENDATION: [fix action]",
                "```",
            ],
            "next": "Output formatted result. Sub-agent task complete."
        }

    if step_number == 12:
        return {
            "actions": [
                "VERDICT ANALYSIS",
                "",
                "STEP A: TALLY RESULTS",
                "  - Total verified",
                "  - TRUE_INCOHERENCE count",
                "  - SIGNIFICANT_AMBIGUITY count",
                "  - DOCUMENTATION_GAP count",
                "  - SPECIFICATION_GAP count",
                "  - FALSE_POSITIVE count",
                "  - By severity (critical/high/medium/low)",
                "",
                "STEP B: QUALITY CHECK",
                "  Verify each non-FALSE_POSITIVE verdict has exact quotes from sources.",
                "",
                "STEP C: DEDUPLICATE VERIFIED ISSUES",
                "",
                "  With Sonnet analysis complete, merge issues that:",
                "  - Reference IDENTICAL source pairs (same file:line for both A and B)",
                "  - Have semantically equivalent conflict descriptions",
                "",
                "  Sonnet context enables better merge decisions than raw Haiku findings.",
                "  Keep the version with more detailed analysis.",
                "",
                "STEP D: IDENTIFY ISSUE GROUPS",
                "",
                "  Analyze confirmed incoherences for relationships. Group by:",
                "",
                "  SHARED ROOT CAUSE:",
                "    - Same file appears in multiple issues",
                "    - Same outdated documentation affects multiple claims",
                "    - Same config/constant is inconsistent across locations",
                "",
                "  SHARED THEME:",
                "    - Multiple issues in same dimension (e.g., all Category D)",
                "    - Multiple issues about same concept (e.g., 'timeout')",
                "    - Multiple issues requiring same type of fix",
                "",
                "  For each group, note:",
                "    - Group ID (G1, G2, ...)",
                "    - Member issues",
                "    - Relationship description",
                "    - Potential unified resolution approach",
                "",
                "  Issues without clear relationships remain ungrouped.",
            ],
            "next": "Invoke step 13 with confirmed findings and groups"
        }

    if step_number == 13:
        return {
            "actions": [
                "PREPARE RESOLUTION BATCHES",
                "",
                "Transform verified incoherences from step 12 into batches for",
                "interactive resolution via AskUserQuestion.",
                "",
                "BATCHING RULES (in priority order):",
                "",
                "1. GROUP-BASED BATCHING:",
                "   - Issues sharing a group (G1, G2, ...) go in same batch",
                "   - Max 4 issues per batch (AskUserQuestion limit)",
                "   - If group has >4 members, split by file proximity",
                "",
                "2. FILE-BASED BATCHING:",
                "   - Ungrouped issues affecting same file go together",
                "   - Max 4 issues per batch",
                "",
                "3. SINGLETON BATCHING:",
                "   - Remaining unrelated issues bundled up to 4 per batch",
                "",
                "OUTPUT FORMAT (include in --thoughts for step 14):",
                "",
                "```",
                "RESOLUTION BATCHES",
                "",
                "Batch 1 (Group G1: Timeout inconsistencies):",
                "  Issues: I2, I5, I7",
                "  Theme: Timeout values differ between docs and code",
                "  Files: src/client.py, docs/config.md",
                "  Group suggestion: Update all to 30s",
                "",
                "Batch 2 (File: src/uploader.py):",
                "  Issues: I1, I6",
                "  No group relationship",
                "",
                "Batch 3 (Singletons):",
                "  Issues: I3, I4",
                "  No relationship",
                "",
                "Total batches: 3",
                "Current batch: 1",
                "```",
                "",
                "ISSUE DATA FORMAT (required for step 14):",
                "",
                "For EACH issue, output in this structure:",
                "",
                "```",
                "ISSUE {id}: {title}",
                "  Severity: {critical|high|medium|low}",
                "  Dimension: {category name}",
                "  Group: {G1|G2|...|none}",
                "",
                "  Source A:",
                "    File: {path}",
                "    Line: {number}",
                "    Quote: \"\"\"{exact text, max 10 lines}\"\"\"",
                "    Claims: {what this source asserts}",
                "",
                "  Source B:",
                "    File: {path}",
                "    Line: {number}",
                "    Quote: \"\"\"{exact text, max 10 lines}\"\"\"",
                "    Claims: {what this source asserts}",
                "",
                "  Analysis: {why these conflict}",
                "",
                "  Suggestions:",
                "    1. {concrete action with ACTUAL values from sources}",
                "    2. {alternative action with ACTUAL values}",
                "```",
                "",
                "CRITICAL: Suggestions must use ACTUAL values, not generic labels.",
                "  WRONG: 'Update docs to match code'",
                "  RIGHT: 'Update docs to say 60s (matching src/config.py:42)'",
            ],
            "next": "Invoke step 14 with batch definitions and issue data in --thoughts"
        }

    # =========================================================================
    # INTERACTIVE RESOLUTION PHASE: Steps 14-15
    # =========================================================================

    if step_number == 14:
        return {
            "actions": [
                "PRESENT RESOLUTION BATCH",
                "",
                "Use AskUserQuestion to collect resolutions for the current batch.",
                "Each question MUST be self-contained with full context.",
                "",
                "STEP A: Identify current batch and mode from --thoughts",
                "",
                "  Check --thoughts for 'MODE: individual' flag.",
                "  - If present: skip to STEP C (individual questions only)",
                "  - If absent: this is first pass for this batch",
                "",
                "EDGE CASE RULES:",
                "",
                "1. EMPTY BATCH (0 issues after filtering):",
                "   - Skip this batch entirely",
                "   - Proceed to next batch or step 15 if none remain",
                "",
                "2. SINGLE-MEMBER GROUP (group with exactly 1 issue):",
                "   - Treat as non-group batch (skip group question)",
                "   - Go directly to individual question",
                "",
                "3. LONG QUOTES (>10 lines):",
                "   - Truncate to first 10 lines",
                "   - Append: '[...truncated, see {file}:{line} for full context]'",
                "",
                "4. MARKDOWN IN QUOTES (backticks, headers, code blocks):",
                "   - Escape or use different fence style to prevent rendering issues",
                "",
                "STEP B: For GROUP BATCHES (2+ members), ask ONLY the group question:",
                "",
                "  IMPORTANT: Do NOT include individual questions in this call.",
                "  The group question determines whether to ask individuals later.",
                "",
                "```yaml",
                "questions:",
                "  - question: |",
                "      ## Group {id}: {relationship}",
                "",
                "      **Member issues**: {I2, I5, I7}",
                "      **Common thread**: {what connects them}",
                "",
                "      Apply a unified resolution to ALL members?",
                "    header: 'G{n}'",
                "    multiSelect: false",
                "    options:",
                "      - label: '{unified_suggestion}'",
                "        description: 'Applies to all {N} issues in this group'",
                "      - label: 'Resolve individually'",
                "        description: 'Answer for each issue separately (next prompt)'",
                "      - label: 'Skip all'",
                "        description: 'Leave all {N} issues in this group unresolved'",
                "```",
                "",
                "  After this call, step 15 will either:",
                "  - Record unified resolution for all members, OR",
                "  - Loop back here with 'MODE: individual' to ask per-issue questions",
                "",
                "STEP C: For NON-GROUP batches OR when MODE=individual:",
                "",
                "  Ask individual questions for each issue:",
                "",
                "```yaml",
                "questions:",
                "  - question: |",
                "      ## Issue {id}: {title}",
                "",
                "      **Severity**: {severity} | **Type**: {dimension}",
                "",
                "      ### Source A",
                "      **File**: `{file_a}`:{line_a}",
                "      ```",
                "      {exact_quote_a}",
                "      ```",
                "      **Claims**: {what_source_a_asserts}",
                "",
                "      ### Source B",
                "      **File**: `{file_b}`:{line_b}",
                "      ```",
                "      {exact_quote_b}",
                "      ```",
                "      **Claims**: {what_source_b_asserts}",
                "",
                "      ### Analysis",
                "      {why_these_conflict}",
                "",
                "      How should this be resolved?",
                "    header: 'I{n}'",
                "    multiSelect: false",
                "    options:",
                "      - label: '{suggestion_1}'",
                "        description: '{what this means concretely}'",
                "      - label: '{suggestion_2}'",
                "        description: '{what this means concretely}'",
                "      - label: 'Skip'",
                "        description: 'Leave this incoherence unresolved'",
                "```",
                "",
                "FULL CONTEXT REQUIREMENT:",
                "",
                "Each question MUST include:",
                "  - Exact file paths and line numbers",
                "  - Exact quotes from both sources",
                "  - Clear analysis of the conflict",
                "  - Concrete suggestion descriptions",
                "",
                "User should NOT need to recall earlier context or open files.",
                "",
                "SUGGESTION PATTERNS (use ACTUAL values, not generic labels):",
                "",
                "| Type              | Option 1                       | Option 2                        |",
                "|-------------------|-------------------------------|--------------------------------|",
                "| Docs vs Code      | Update docs to say {B_value}  | Update code to use {A_value}   |",
                "| Stale comment     | Remove the comment            | Update comment to say {actual} |",
                "| Missing docs      | Add docs for {element}        | Mark {element} as internal     |",
                "| Config mismatch   | Use {A_value} ({A_source})    | Use {B_value} ({B_source})     |",
                "| Cross-ref conflict| Use {A_claim}                 | Use {B_claim}                  |",
                "",
                "CRITICAL: Replace placeholders with ACTUAL values from the issue.",
                "",
                "EXAMPLE:",
                "  Issue: docs say 30s timeout, code says 60s",
                "  WRONG option: 'Update docs to match code'",
                "  RIGHT option: 'Update docs to say 60s (matching src/config.py:42)'",
                "",
                "Note: 'Other' option is always available (users can type custom text).",
            ],
            "next": "After AskUserQuestion returns, invoke step 15 with responses"
        }

    if step_number == 15:
        return {
            "actions": [
                "RESOLUTION LOOP CONTROLLER",
                "",
                "Process responses from step 14 and determine next action.",
                "",
                "EARLY EXIT CHECK:",
                "",
                "If ALL collected resolutions so far are NO_RESOLUTION (user skipped everything):",
                "  - Skip remaining batches",
                "  - Output: 'No issues selected for resolution. Workflow complete.'",
                "  - Do NOT proceed to step 16",
                "",
                "This is a normal outcome, not an error. User may choose to skip all issues.",
                "",
                "STEP A: IDENTIFY RESPONSE TYPE",
                "",
                "Check what type of response was received:",
                "",
                "  1. GROUP QUESTION RESPONSE (header was 'G{n}'):",
                "     - User answered unified resolution question for a group batch",
                "     - Check which option was selected",
                "",
                "  2. INDIVIDUAL QUESTION RESPONSES (headers were 'I{n}'):",
                "     - User answered per-issue questions",
                "     - Record each resolution",
                "",
                "STEP B: HANDLE GROUP QUESTION RESPONSE",
                "",
                "If response was to a group question:",
                "",
                "  - If user selected UNIFIED SUGGESTION:",
                "    -> Record that resolution for ALL member issues",
                "    -> Mark batch complete, proceed to next batch or step 16",
                "",
                "  - If user selected 'Resolve individually':",
                "    -> Do NOT record any resolutions yet",
                "    -> Loop back to step 14 with 'MODE: individual' in --thoughts",
                "    -> Include same batch definition and issue data",
                "",
                "  - If user selected 'Skip all':",
                "    -> Mark ALL member issues as NO_RESOLUTION",
                "    -> Mark batch complete, proceed to next batch or step 16",
                "",
                "  - If user selected 'Other' (custom text):",
                "    -> Record their custom text for ALL member issues",
                "    -> Mark batch complete, proceed to next batch or step 16",
                "",
                "STEP C: HANDLE INDIVIDUAL QUESTION RESPONSES",
                "",
                "If response was to individual questions:",
                "",
                "For each issue in the batch:",
                "  - If user selected a suggestion -> record the resolution text",
                "  - If user selected 'Skip' -> mark as NO_RESOLUTION",
                "  - If user selected 'Other' -> record their custom text",
                "",
                "Mark batch complete, proceed to next batch or step 16.",
                "",
                "ACCUMULATED STATE FORMAT (add to --thoughts):",
                "",
                "```",
                "COLLECTED RESOLUTIONS",
                "",
                "Batch 1 complete:",
                "  I2: 'Update timeout to 30s' [from G1 unified]",
                "  I5: 'Update timeout to 30s' [from G1 unified]",
                "  I7: 'Update timeout to 30s' [from G1 unified]",
                "",
                "Batch 2 complete:",
                "  I1: 'Use 100MB from spec' [individual]",
                "  I6: NO_RESOLUTION [skipped]",
                "",
                "Current batch: 2 of 3",
                "```",
                "",
                "STEP D: LOOP DECISION",
                "",
                "Priority order:",
                "",
                "1. If group question answered 'Resolve individually':",
                "   -> Invoke step 14 with same batch + 'MODE: individual'",
                "",
                "2. If current_batch < total_batches:",
                "   -> Invoke step 14 with next batch definition",
                "",
                "3. If current_batch >= total_batches (all complete):",
                "   -> All resolutions collected, invoke step 16",
                "",
                "STEP E: PREPARE NEXT INVOCATION",
                "",
                "Include in --thoughts:",
                "  - All collected resolutions so far",
                "  - Batch definitions for remaining batches (if any)",
                "  - Full issue data for next batch (if looping to step 14)",
                "  - 'MODE: individual' flag if looping back for individual questions",
            ],
            "next": (
                "If 'Resolve individually' selected: invoke step 14 with MODE=individual\n"
                "If more batches remain: invoke step 14 with next batch\n"
                "If all batches complete: invoke step 16 with all resolutions"
            )
        }

    # =========================================================================
    # APPLICATION PHASE: Steps 16-22
    # =========================================================================

    if step_number == 16:
        return {
            "actions": [
                "ANALYZE TARGETS AND PLAN DISPATCH",
                "",
                "Read collected resolutions from --thoughts (from step 15).",
                "Skip issues marked NO_RESOLUTION.",
                "",
                "STEP A: DETERMINE TARGET FILES",
                "",
                "For each issue WITH a resolution:",
                "  - Identify which file(s) need modification",
                "  - Use Source A/B locations as hints",
                "  - Resolution text may specify which source to change",
                "",
                "STEP B: SELECT AGENT TYPES BY FILE EXTENSION",
                "",
                "  Documentation -> technical-writer:",
                "    .md, .rst, .txt, .adoc, .asciidoc",
                "",
                "  Code/Config -> developer:",
                "    .py, .js, .ts, .go, .rs, .java, .c, .cpp, .h",
                "    .yaml, .yml, .json, .toml, .ini, .cfg",
                "",
                "STEP C: GROUP BY TARGET FILE",
                "",
                "```",
                "FILE GROUPS",
                "",
                "src/uploader.py:",
                "  - I1: 'Use the spec value (100MB)'",
                "  - I6: 'Add input validation'",
                "  Agent: developer",
                "",
                "docs/config.md:",
                "  - I3: 'Update to match code'",
                "  Agent: technical-writer",
                "```",
                "",
                "STEP D: CREATE DISPATCH WAVES",
                "",
                "  BATCH: Multiple issues for same file -> one agent",
                "  PARALLEL: Different files -> dispatch in parallel",
                "",
                "```",
                "DISPATCH PLAN",
                "",
                "WAVE 1 (parallel):",
                "  - Agent 1: developer -> src/uploader.py",
                "    Issues: I1, I6 (batched)",
                "  - Agent 2: technical-writer -> docs/config.md",
                "    Issues: I3",
                "",
                "WAVE 2 (after Wave 1):",
                "  [none or additional waves if file conflicts]",
                "```",
            ],
            "next": "Invoke step 17 with dispatch plan in --thoughts"
        }

    if step_number == 17:
        return {
            "actions": [
                "RECONCILE DISPATCH",
                "",
                "Launch agents for the current wave.",
                "",
                "WHICH WAVE?",
                "  - First time here: dispatch Wave 1",
                "  - Returned from step 20: dispatch the next wave",
                "",
                f"SCRIPT PATH: {script_path}",
                "",
                "Use the appropriate subagent_type for each agent:",
                "  - subagent_type='developer' for code and config files",
                "  - subagent_type='technical-writer' for documentation (.md, .rst, .txt)",
                "",
                "AGENT PROMPT TEMPLATE:",
                "```",
                "RECONCILIATION TASK",
                "",
                "TARGET FILE: {file_path}",
                "",
                "RESOLUTIONS TO APPLY:",
                "",
                "--- Issue {id} ---",
                "Type: {type}",
                "Severity: {severity}",
                "Source A: {file}:{line}",
                "Source B: {file}:{line}",
                "Analysis: {analysis}",
                "User's Resolution: {resolution_text}",
                "",
                "[Repeat for batched issues]",
                "",
                "YOUR WORKFLOW:",
                f"1. python3 {script_path} --step-number 18 --total-steps 21 \\",
                "     --thoughts \"FILE: {file_path} | ISSUES: {id_list}\"",
                "2. Apply the resolution(s)",
                f"3. python3 {script_path} --step-number 19 --total-steps 21 \\",
                "     --thoughts \"<what you did>\"",
                "4. Output your formatted result",
                "```",
                "",
                "Launch all agents for THIS WAVE in a SINGLE message (parallel).",
            ],
            "next": "After all wave agents complete, invoke step 20 with results"
        }

    # =========================================================================
    # APPLICATION SUB-AGENT STEPS: 18-19
    # =========================================================================

    if step_number == 18:
        return {
            "actions": [
                "RECONCILE APPLY [SUB-AGENT]",
                "",
                "Apply the user's resolution(s) to the target file.",
                "",
                "PROCESS:",
                "",
                "For EACH resolution assigned to you:",
                "",
                "1. UNDERSTAND THE RESOLUTION",
                "   - What did the user decide?",
                "   - Which source is authoritative?",
                "   - What specific changes are needed?",
                "",
                "2. LOCATE THE TARGET",
                "   - Find the exact location in the file",
                "   - Read surrounding context",
                "",
                "3. APPLY THE CHANGE",
                "   - Make the edit directly",
                "   - Be precise: match the user's intent",
                "   - Preserve surrounding context and formatting",
                "",
                "4. VERIFY",
                "   - Does the change address the incoherence?",
                "   - If batched: any conflicts between changes?",
                "",
                "BATCHED RESOLUTIONS:",
                "",
                "If you have multiple resolutions for the same file:",
                "  - Apply them in logical order",
                "  - Watch for interactions between changes",
                "  - If changes conflict, note this in output",
                "",
                "UNCLEAR RESOLUTIONS:",
                "",
                "If a resolution is genuinely unclear, do your best to interpret",
                "the user's intent. Only skip if truly impossible to apply.",
                "",
                "BIAS: Apply the resolution. Interpret charitably. Skip rarely.",
            ],
            "next": "When done, invoke step 19 with results in --thoughts"
        }

    if step_number == 19:
        return {
            "actions": [
                "RECONCILE FORMAT [SUB-AGENT]",
                "",
                "Format your reconciliation result(s).",
                "",
                "OUTPUT ONE BLOCK PER ISSUE:",
                "",
                "IF SUCCESSFULLY APPLIED:",
                "```",
                "RECONCILIATION RESULT",
                "",
                "ISSUE: {id}",
                "STATUS: RESOLVED",
                "FILE: {file_path}",
                "CHANGE: {brief one-line description}",
                "```",
                "",
                "IF COULD NOT APPLY:",
                "```",
                "RECONCILIATION RESULT",
                "",
                "ISSUE: {id}",
                "STATUS: SKIPPED",
                "REASON: {why it couldn't be applied}",
                "```",
                "",
                "FOR BATCHED ISSUES: Output one block per issue, separated by ---",
                "",
                "Keep CHANGE descriptions brief (one line, ~60 chars max).",
            ],
            "next": "Output formatted result(s). Sub-agent task complete."
        }

    if step_number == 20:
        return {
            "actions": [
                "RECONCILE COLLECT",
                "",
                "Collect results from the completed wave.",
                "",
                "STEP A: COLLECT RESULTS",
                "",
                "For each sub-agent that completed:",
                "  - Issues handled",
                "  - Status (RESOLVED or SKIPPED)",
                "  - File and change (if RESOLVED)",
                "  - Reason (if SKIPPED)",
                "",
                "```",
                "WAVE N RESULTS",
                "",
                "Agent 1 (developer -> src/uploader.py):",
                "  I1: RESOLVED - Changed MAX_FILE_SIZE to 100MB",
                "  I6: RESOLVED - Added validation",
                "",
                "Agent 2 (technical-writer -> README.md):",
                "  I3: RESOLVED - Added file size definition",
                "```",
                "",
                "STEP B: CHECK FOR NEXT WAVE",
                "",
                "Review your dispatch plan from step 16:",
                "  - More waves remaining? -> Invoke step 17 for next wave",
                "  - All waves complete? -> Invoke step 21 to write audit",
                "",
                "OUTPUT:",
                "",
                "```",
                "COLLECTION SUMMARY",
                "",
                "Wave N complete:",
                "  - RESOLVED: I1, I3, I6",
                "  - SKIPPED: [none]",
                "",
                "Remaining waves: [list or \"none\"]",
                "```",
            ],
            "next": "If more waves: invoke step 17. Otherwise: invoke step 21."
        }

    if step_number >= 21:
        return {
            "actions": [
                "PRESENT REPORT",
                "",
                "Output the final report directly to the user.",
                "Do NOT write to a file - present inline.",
                "",
                "FORMAT:",
                "",
                "```",
                "INCOHERENCE RESOLUTION COMPLETE",
                "",
                "Summary:",
                "  - Issues detected: {N}",
                "  - Issues resolved: {M}",
                "  - Issues skipped: {K}",
                "",
                "+-----+----------+----------+------------------------------------------+",
                "| ID  | Severity | Status   | Summary                                  |",
                "+-----+----------+----------+------------------------------------------+",
                "| I1  | high     | RESOLVED | src/uploader.py: MAX_FILE_SIZE -> 100MB  |",
                "| I2  | medium   | RESOLVED | src/client.py: timeout -> 30s            |",
                "| I3  | low      | RESOLVED | README.md: Added size definition         |",
                "| I6  | medium   | SKIPPED  | (user chose to skip)                     |",
                "| I7  | low      | SKIPPED  | (could not apply)                        |",
                "+-----+----------+----------+------------------------------------------+",
                "```",
                "",
                "RULES:",
                "  - List ALL issues (resolved + skipped)",
                "  - Include severity for context",
                "  - Use RESOLVED for successfully applied",
                "  - Use SKIPPED with reason in parentheses",
                "  - Keep summaries brief (~40 chars)",
            ],
            "next": "WORKFLOW COMPLETE."
        }

    return {"actions": ["Unknown step"], "next": "Check step number"}


def main():
    parser = argparse.ArgumentParser(description="Incoherence Detector")
    parser.add_argument("--step-number", type=int, required=True)
    parser.add_argument("--total-steps", type=int, required=True)
    parser.add_argument("--thoughts", type=str, required=True)
    args = parser.parse_args()

    script_path = os.path.abspath(__file__)
    guidance = get_step_guidance(args.step_number, args.total_steps, script_path)

    # Determine agent type and phase
    # Detection sub-agents: 4-7 (exploration), 10-11 (deep-dive)
    if args.step_number in [4, 5, 6, 7, 10, 11]:
        agent_type = "SUB-AGENT"
        phase = "DETECTION"
    # Application sub-agents: 18-19 (apply resolution)
    elif args.step_number in [18, 19]:
        agent_type = "SUB-AGENT"
        phase = "APPLICATION"
    # Detection parent: 1-12
    elif args.step_number <= 12:
        agent_type = "PARENT"
        phase = "DETECTION"
    # Resolution parent: 13-15
    elif args.step_number <= 15:
        agent_type = "PARENT"
        phase = "RESOLUTION"
    # Application parent: 16-22
    else:
        agent_type = "PARENT"
        phase = "APPLICATION"

    print("=" * 70)
    print(f"INCOHERENCE DETECTOR - Step {args.step_number}/{args.total_steps}")
    print(f"[{phase}] [{agent_type}]")
    print("=" * 70)
    print()
    print("THOUGHTS:", args.thoughts[:300] + "..." if len(args.thoughts) > 300 else args.thoughts)
    print()
    print("REQUIRED ACTIONS:")
    for action in guidance["actions"]:
        print(f"  {action}")
    print()
    print("NEXT:", guidance["next"])
    print("=" * 70)


if __name__ == "__main__":
    main()
