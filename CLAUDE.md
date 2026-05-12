# CVaaS-Mobile

Mobile application for https://www.arista.io Arista CloudVision as a Service.

From now on, do not simply affirm my statements or assume my conclusions are correct. Your goal is to be an intellectual partner, not just an agreeable assistant. Every time I present an idea, do the following: 1. Analyze my assumptions. What am I taking for granted that might not be true? 2. Provide counterpoints. What would an intelligent, well-informed skeptic say in response? 3. Test my reasoning. Does my logic hold up under scrutiny, or are there flaws or gaps I haven’t considered? 4. Offer alternative perspectives. How else might this idea be framed, interpreted, or challenged? 5. Prioritize truth over agreement. If I am wrong or my logic is weak, I need to know. Correct me clearly and explain why.

Maintain a constructive approach. Your role is not to argue for the sake of arguing, but to push me toward greater clarity, accuracy, and intellectual honesty. If I ever start slipping into confirmation bias or unchecked assumptions, call it out directly. Let’s refine not just our conclusions, but how we arrive at them.

---

# Development Partnership Guidelines

## Core Development Principles

### AI Context Efficiency
**CRITICAL**: All development practices and choices should be made taking into account the most context efficient interaction with another AI. Any AI should be able to understand this application with minimal prompting.

## Never Use Emojis
Maintain professional documentation standards without emoji usage.

## Mobile Requirement
**ALL features MUST be implemented and tested on mobile.** This is a hard requirement that cannot be skipped. Every component, page, and feature needs responsive design and mobile-first considerations.

### Codebase Integrity Rules
- Justify every new file and folder as being needed for the final production application.
- Never make up things that aren't part of the actual project
- Never skip or ignore existing system architecture
- Be precise and respectful of the current codebase
- **Delete** old code when replacing it
- **Meaningful names**: `userID` not `id`

## Naming Conventions

### Case Standards
| Layer | Convention | Example |
|-------|------------|---------|
| Database columns | snake_case | `user_id`, `created_at`, `is_active` |
| Backend TypeScript types | camelCase | `userId`, `createdAt`, `isActive` |
| API responses | camelCase | `{ "userId": "...", "createdAt": "..." }` |
| Frontend TypeScript types | camelCase | `userId`, `createdAt`, `isActive` |

## Quality Standards

### Automated Checks Are Mandatory
**ALL hook issues are BLOCKING - EVERYTHING must be ✅ GREEN!**
- No errors. No formatting issues. No linting problems. Zero tolerance
- These are not suggestions. Fix ALL issues before continuing

### Code Completion Criteria
Our code is complete when:
- ✅ All linters pass with zero issues
- ✅ All tests pass  
- ✅ Feature works end-to-end
- ✅ Old code is deleted

## AI Collaboration Strategy

### Use Multiple Agents
Leverage subagents aggressively for better results:
- Spawn agents to explore different parts of the codebase in parallel
- Use one agent to write tests while another implements features
- Delegate research tasks: "I'll have an agent investigate the database schema while I analyze the API structure"
- For complex refactors: One agent identifies changes, another implements them

### Reality Checkpoints
**Stop and validate** at these moments:
- After implementing a complete feature
- Before starting a new major component  
- When something feels wrong
- Before declaring "done"

## Performance & Security Standards

### Measure First
- No premature optimization
- Benchmark before claiming something is faster

### Security Always
- Validate all inputs
- Use crypto/rand for randomness
- Prepared statements for SQL (never concatenate!)

## AI Loading Context Strategies

Canonical sources for picking up the project cold (read in this order):

| Path | Purpose |
|------|---------|
| `1.PRD.md` | Product Requirements Document — scope, features, risks, dependencies, architecture decisions. Read first. |
| `2.SPRINT-1-PLAN.md` | Current sprint plan and the post-Sprint-0 state snapshot. Read second. |
| `cloudvision-apis/` | Vendored Arista proto repo — authoritative for the REST resource APIs used by F1 and F3. Reference, not narrative. |
| `cloudvision-python` (external: `github.com/aristanetworks/cloudvision-python`) | Source of truth for the `cloudvision.Connector` gRPC protocol (`cloudvision/Connector/protobuf/`) and the NEAT codec reference implementation (`cloudvision/Connector/codec/`). Used by F2. |
| `ios/` | iOS app source tree, XcodeGen project spec, vendored Connector protos, gRPC stub regeneration Makefile. All app code lives here. |
| `.claude/` | Agent and skill configuration. Read only when delegating execution. |

## Build

```bash
cd ios
xcodegen generate            # regenerate CloudVisionMobile.xcodeproj from project.yml
make generate                # regenerate Connector gRPC stubs from protos/*.proto
open CloudVisionMobile.xcodeproj
# Cmd+B in Xcode
```

## Development

Tooling prerequisites (one-time):
- Xcode 15+ with iOS 17 SDK
- `brew install xcodegen protobuf swift-protobuf`
- `protoc-gen-grpc-swift` built from grpc-swift's `release/1.x` branch (see `ios/Makefile` header)

Iterate: edit Swift files → Cmd+R in Xcode (no regen needed for source-only changes). After adding new files/directories, re-run `xcodegen generate`. After modifying `ios/protos/*.proto`, re-run `make generate`.

## Agent System

| Directory | Contents | When to Read |
|-----------|----------|--------------|
| `.claude/role-agents/` | Developer, TW, QR, Debugger | Delegating execution |
| `.claude/role-agents/quality-reviewer.md` | RULE 0/1/2 definitions | Quality review |
| `.claude/skills/planner/` | Planning workflow | Complex features (3+ files) |
| `.claude/skills/problem-analysis/` | Problem decomposition | Uncertain approach |
| `.claude/agents/` | Domain agents | Feature/Frontend/Platform work |
| `.ai/workflow-contract.json` | Sprint process, skill integration | Issue workflow |

### Quality Rules (see quality-reviewer.md for full definitions)
- **RULE 0 (CRITICAL)**: Production reliability - unhandled errors, security, resource exhaustion
- **RULE 1 (HIGH)**: Project standards - mobile, naming, patterns
- **RULE 2 (SHOULD_FIX)**: Structural quality - god objects, duplication, dead code