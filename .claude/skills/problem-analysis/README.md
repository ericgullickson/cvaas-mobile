# Problem Analysis

LLMs jump to solutions. You describe a problem, they propose an answer. For
complex decisions with multiple viable paths, that first answer often reflects
the LLM's biases rather than the best fit for your constraints. This skill
forces structured reasoning before you commit.

The skill runs through six phases:

| Phase       | Actions                                                                  |
| ----------- | ------------------------------------------------------------------------ |
| Decompose   | State problem; identify hard/soft constraints, variables, assumptions    |
| Generate    | Create 2-4 distinct approaches (fundamentally different, not variations) |
| Critique    | Specific weaknesses; eliminate or refine                                 |
| Verify      | Answer questions WITHOUT looking at solutions                            |
| Cross-check | Reconcile verified facts with original claims; update viability          |
| Synthesize  | Trade-off matrix with verified facts; decision framework                 |

## When to Use

Use this for decisions where the cost of choosing wrong is high:

- Multiple viable technical approaches (Redis vs Postgres, REST vs GraphQL)
- Architectural decisions with long-term consequences
- Problems where you suspect your first instinct might be wrong

## Example Usage

```
I need to decide how to handle distributed locking in our microservices.
Options I'm considering:

- Redis with Redlock algorithm
- ZooKeeper
- Database advisory locks

Use your problem-analysis skill to structure this decision.
```

## The Design

The structure prevents premature convergence. Critique catches obvious flaws
before costly verification. Factored verification prevents confirmation bias --
you answer questions without seeing your original solutions. Cross-check forces
explicit reconciliation of evidence with claims.
