# Project instructions

## Language

* All documentation must be written in Russian.
* This includes technical documentation, architecture documentation, ADRs, OpenSpec artifacts, comments intended for documentation, and other project documentation.
* Keep code identifiers, API names, library names, protocol names, and standard technical terms in their original form.
* User-facing text should be written in clear, natural Russian.

## Specification-driven development

* This project uses OpenSpec for specification-driven development (SDD).
* Before implementing a non-trivial change, inspect the relevant OpenSpec specification and change artifacts.
* New requirements and planned changes must be represented in OpenSpec rather than being introduced only through implementation code or documentation.
* Do not duplicate OpenSpec specifications in `docs/`.
* OpenSpec remains the source of truth for requirements and active specification changes.

## Architectural decisions

* Architectural decisions are documented using ADRs.
* ADRs must be stored under `docs/`.
* When making a significant architectural decision, check existing ADRs before creating a new one.
* Do not create a second decision log or an alternative ADR repository.
* When an existing decision changes, prefer creating a new ADR that supersedes the previous one rather than rewriting historical ADRs.
* ADRs should explain the context, decision, alternatives, and consequences. Implementation details that belong to OpenSpec should not be duplicated unnecessarily.

## Technical documentation

* Technical documentation is stored under `docs/`.
* Keep documentation organized by subject and avoid creating documentation files in arbitrary locations.
* Prefer linking to the authoritative source instead of duplicating the same information in multiple documents.
* Keep documentation describing the current state separate from historical decision records.

## Working with existing documentation

* Before creating new documentation, inspect relevant files under `docs/`.
* Reuse existing document structure, terminology, naming conventions, and ADR numbering.
* Do not create duplicate documents when an existing document can be updated.
* Do not delete historical ADRs unless explicitly requested.

## Priority of sources

When information conflicts, use the following priority:

1. Current implementation and configuration for the actual system behavior.
2. OpenSpec for requirements and active changes.
3. ADRs for architectural decisions and their rationale.
4. Technical documentation under `docs/` for consolidated project knowledge.

When documenting a discrepancy, do not silently overwrite the existing source. Identify the discrepancy and update the appropriate authoritative artifact.
