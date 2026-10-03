---
name: review
description: Review an OpenSpec change before implementation. Analyze proposal.md, specs, design.md, and tasks.md for missing requirements, ambiguities, contradictions, edge cases, non-functional requirements, architecture and codebase inconsistencies, API and data contract issues, and testability gaps. Fix unambiguous issues directly in the target OpenSpec files, keep unresolved product or business decisions in the chat, and never create review.md or other review artifacts.
---

# OpenSpec Review

## Purpose

Review the current OpenSpec change for correctness, completeness,
consistency, feasibility, and implementation readiness.

The review is performed entirely in the current agent session.

Do not create any review artifacts.

Do not create `review.md` or any other review report file.

The review result is communicated in chat and, when appropriate,
the target OpenSpec artifacts are corrected directly.

## Scope

Review the current OpenSpec change:

* `proposal.md`
* `specs/**/*.md`
* `design.md`
* `tasks.md`

Also inspect the existing codebase and relevant documentation when needed
to validate architectural and implementation assumptions.

Do not review unrelated parts of the repository.

## Review workflow

### 1. Discover the change

Identify the current OpenSpec change and inspect all existing artifacts.

Determine:

* intended outcome
* scope
* affected components
* requirements
* constraints
* proposed architecture
* implementation plan

### 2. Analyze requirements

Check every requirement for:

* clarity
* unambiguity
* consistency
* testability
* implementability
* explicit expected behavior

Look for vague wording such as:

* "properly"
* "appropriately"
* "if necessary"
* "quickly"
* "etc."
* "as usual"

unless the expected behavior is defined elsewhere.

### 3. Check consistency

Compare:

* proposal ↔ specs
* specs ↔ design
* design ↔ tasks
* requirements ↔ acceptance scenarios
* proposed design ↔ existing codebase

Identify contradictions and stale information.

### 4. Check missing scenarios

Look for missing behavior around:

* empty input
* invalid input
* duplicate input
* missing data
* retries
* repeated requests
* idempotency
* concurrent operations
* timeouts
* partial failures
* recovery
* rollback
* state transitions
* authorization
* backward compatibility

Only report scenarios that are relevant to the actual change.

### 5. Check non-functional requirements

Evaluate whether the change requires explicit requirements for:

* performance
* scalability
* reliability
* consistency
* concurrency
* idempotency
* security
* authorization
* observability
* auditability
* data retention
* backward compatibility
* migration

Do not invent NFRs that are irrelevant to the change.

### 6. Check architecture and codebase fit

Inspect the existing codebase when architectural assumptions are involved.

Validate:

* existing service boundaries
* existing abstractions
* APIs
* persistence model
* messaging
* configuration
* dependency boundaries
* existing implementation patterns
* deployment/runtime constraints

Prefer existing project conventions unless the change explicitly requires a new approach.

Do not reject a design merely because it is different from the existing implementation.

Report only concrete compatibility, maintenance, correctness, or architectural issues.

### 7. Check API and data contracts

Where applicable, inspect:

* request/response contracts
* events
* messages
* database schema
* migrations
* nullability
* defaults
* uniqueness
* identifiers
* serialization
* versioning
* backward compatibility

### 8. Check testability

Verify that important requirements can be expressed as deterministic
acceptance scenarios and automated tests.

Look for:

* missing positive scenarios
* missing negative scenarios
* missing edge cases
* unclear expected results
* nondeterministic requirements
* untestable requirements

### 9. Classify findings

Use:

* CRITICAL — implementation should not proceed
* HIGH — significant correctness, architecture, contract, or data risk
* MEDIUM — important gap or ambiguity that should be resolved
* LOW — minor wording, consistency, or maintainability issue

Do not create a finding merely to make the review look thorough.

### 10. Correct the OpenSpec artifacts

When a finding has an unambiguous resolution:

* modify the relevant OpenSpec artifact directly;
* keep the intended scope unchanged;
* preserve existing decisions unless the review demonstrates a contradiction;
* update dependent artifacts when necessary.

Typical targets:

* `proposal.md`
* `specs/**/*.md`
* `design.md`
* `tasks.md`

When modifying one artifact causes another artifact to become inconsistent,
update the affected dependent artifacts as well.

Do not create review files.

### 11. Handle unresolved decisions

When a problem requires a product, business, architecture,
security, or other explicit decision:

* do not invent the answer;
* do not silently choose one interpretation;
* report the question in chat;
* identify the affected requirement;
* explain why the decision matters.

Do not modify the specification to guess the answer.

### 12. Re-review after changes

After correcting the artifacts:

1. reread the modified artifacts;
2. check consistency again;
3. verify that no new contradictions were introduced;
4. verify that tasks still correspond to the requirements;
5. verify that design still matches the specifications.

Repeat until no actionable findings remain or unresolved decisions block further progress.

## Output format

All review output must be presented in chat.

Use this structure:

### Review

#### Findings

For each finding:

**[SEVERITY] ID**

**Location:** `path:section`

**Problem:** concise description.

**Impact:** why it matters.

**Action:** what was changed or what decision is required.

#### Changes made

List the OpenSpec files modified during the review.

#### Open questions

List only questions that require a human decision.

#### Final status

Use one of:

* `Ready`
* `Ready with minor changes`
* `Blocked by open questions`

Do not write the review result to a file.

## Important rules

* Never create `review.md`.
* Never create a separate review report.
* Do not modify source code.
* Do not expand the scope of the OpenSpec change.
* Do not invent business requirements.
* Do not silently resolve ambiguous business decisions.
* Prefer direct correction of existing OpenSpec artifacts.
* Keep all review communication in the current chat.
* After corrections, always re-check consistency.
