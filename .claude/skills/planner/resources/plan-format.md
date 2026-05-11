# Plan Format

Write your plan using this structure:

```markdown
# [Plan Title]

## Overview

[Problem statement, chosen approach, and key decisions in 1-2 paragraphs]

## Planning Context

This section is consumed VERBATIM by downstream agents (Technical Writer,
Quality Reviewer). Quality matters: vague entries here produce poor annotations
and missed risks.

### Decision Log

| Decision           | Reasoning Chain                                              |
| ------------------ | ------------------------------------------------------------ |
| [What you decided] | [Multi-step reasoning: premise -> implication -> conclusion] |

Each rationale must contain at least 2 reasoning steps. Single-step rationales
are insufficient.

INSUFFICIENT: "Polling over webhooks | Webhooks are unreliable" SUFFICIENT:
"Polling over webhooks | Third-party API has 30% webhook delivery failure in
testing -> unreliable delivery would require fallback polling anyway -> simpler
to use polling as primary mechanism"

INSUFFICIENT: "500ms timeout | Matches upstream latency" SUFFICIENT: "500ms
timeout | Upstream 95th percentile is 450ms -> 500ms covers 95% of requests
without timeout -> remaining 5% should fail fast rather than queue"

Include BOTH architectural decisions AND implementation-level micro-decisions:

- Architectural: "Event sourcing over CRUD | Need audit trail + replay
  capability -> CRUD would require separate audit log -> event sourcing provides
  both natively"
- Implementation: "Mutex over channel | Single-writer case -> channel
  coordination adds complexity without benefit -> mutex is simpler with
  equivalent safety"

Technical Writer sources ALL code comments from this table. If a micro-decision
isn't here, TW cannot document it.

### Rejected Alternatives

| Alternative          | Why Rejected                                                        |
| -------------------- | ------------------------------------------------------------------- |
| [Approach not taken] | [Concrete reason: performance, complexity, doesn't fit constraints] |

Technical Writer uses this to add "why not X" context to code comments.

### Constraints & Assumptions

- [Technical: API limits, language version, existing patterns to follow]
- [Organizational: timeline, team expertise, approval requirements]
- [Dependencies: external services, libraries, data formats]
- [Default conventions applied: cite any `<default-conventions domain="...">`
  used]

### Known Risks

| Risk            | Mitigation                                    | Anchor                                     |
| --------------- | --------------------------------------------- | ------------------------------------------ |
| [Specific risk] | [Concrete mitigation or "Accepted: [reason]"] | [file:L###-L### if claiming code behavior] |

**Anchor requirement**: If mitigation claims existing code behavior ("no change
needed", "already handles X"), cite the file:line + brief excerpt that proves
the claim. Skip anchors for hypothetical risks or external unknowns.

Quality Reviewer excludes these from findings but will challenge unverified
behavioral claims.

## Invisible Knowledge

This section captures knowledge NOT deducible from reading the code alone.
Technical Writer uses this for README.md documentation during
post-implementation.

**The test**: Would a new team member understand this from reading the source
files? If no, it belongs here.

**Categories** (not exhaustive -- apply the principle):

1. **Architectural decisions**: Component relationships, data flow, module
   boundaries
2. **Business rules**: Domain constraints that shape implementation choices
3. **System invariants**: Properties that must hold but are not enforced by
   types/compiler
4. **Historical context**: Why alternatives were rejected (links to Decision
   Log)
5. **Performance characteristics**: Non-obvious efficiency properties or
   requirements
6. **Tradeoffs**: Costs and benefits of chosen approaches

### Architecture
```

[ASCII diagram showing component relationships]

Example: User Request | v +----------+ +-------+ | Auth |---->| Cache |
+----------+ +-------+ | v +----------+ +------+ | Handler |---->| DB |
+----------+ +------+

```

### Data Flow

```

[How data moves through the system - inputs, transformations, outputs]

Example: HTTP Request --> Validate --> Transform --> Store --> Response | v Log
(async)

````

### Why This Structure

[Reasoning behind module organization that isn't obvious from file names]

- Why these boundaries exist
- What would break if reorganized differently

### Invariants

[Rules that must be maintained but aren't enforced by code]

- Ordering requirements
- State consistency rules
- Implicit contracts between components

### Tradeoffs

[Key decisions with their costs and benefits]

- What was sacrificed for what gain
- Performance vs. readability choices
- Consistency vs. flexibility choices

## Milestones

### Milestone 1: [Name]

**Files**: [exact paths - e.g., src/auth/handler.py, not "auth files"]

**Flags** (if applicable): [needs TW rationale, needs error handling review, needs conformance check]

**Requirements**:

- [Specific: "Add retry with exponential backoff", not "improve error handling"]

**Acceptance Criteria**:

- [Testable: "Returns 429 after 3 failed attempts" - QR can verify pass/fail]
- [Avoid vague: "Works correctly" or "Handles errors properly"]

**Tests** (milestone not complete until tests pass):

- **Test files**: [exact paths, e.g., tests/test_retry.py]
- **Test type**: [integration | property-based | unit] - see default-conventions
- **Backing**: [user-specified | doc-derived | default-derived]
- **Scenarios**:
  - Normal: [e.g., "successful retry after transient failure"]
  - Edge: [e.g., "max retries exhausted", "zero delay"]
  - Error: [e.g., "non-retryable error returns immediately"]

Skip tests when: user explicitly stated no tests, OR milestone is documentation-only,
OR project docs prohibit tests for this component. State skip reason explicitly.

**Code Changes** (for non-trivial logic, use unified diff format):

See `resources/diff-format.md` for specification.

```diff
--- a/path/to/file.py
+++ b/path/to/file.py
@@ -123,6 +123,15 @@ def existing_function(ctx):
   # Context lines (unchanged) serve as location anchors
   existing_code()

+  # WHY comment explaining rationale - transcribed verbatim by Developer
+  new_code()

   # More context to anchor the insertion point
   more_existing_code()
````

### Milestone N: ...

### Milestone [Last]: Documentation

**Files**:

- `path/to/CLAUDE.md` (index updates)
- `path/to/README.md` (if Invisible Knowledge section has content)

**Requirements**:

- Update CLAUDE.md index entries for all new/modified files
- Each entry has WHAT (contents) and WHEN (task triggers)
- If plan's Invisible Knowledge section is non-empty:
  - Create/update README.md with architecture diagrams from plan
  - Include tradeoffs, invariants, "why this structure" content
  - Verify diagrams match actual implementation

**Acceptance Criteria**:

- CLAUDE.md enables LLM to locate relevant code for debugging/modification tasks
- README.md captures knowledge not discoverable from reading source files
- Architecture diagrams in README.md match plan's Invisible Knowledge section

**Source Material**: `## Invisible Knowledge` section of this plan

### Cross-Milestone Integration Tests

When integration tests require components from multiple milestones:

1. Place integration tests in the LAST milestone that provides a required
   component
2. List dependencies explicitly in that milestone's **Tests** section
3. Integration test milestone is not complete until all dependencies are
   implemented

Example:

- M1: Auth handler (property tests for auth logic)
- M2: Database layer (property tests for queries)
- M3: API endpoint (integration tests covering M1 + M2 + M3 with testcontainers)

The integration tests in M3 verify the full flow that end users would exercise,
using real dependencies. This creates fast feedback as soon as all components
exist.

## Milestone Dependencies (if applicable)

```
M1 ---> M2
   \
    --> M3 --> M4
```

Independent milestones can execute in parallel during /plan-execution.

```

```
