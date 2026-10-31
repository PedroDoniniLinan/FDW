---
name: dbt-model-sql
description: >-
  Create or update dbt model SQL to follow the project's model conventions,
  especially when migrating legacy models to the current standard.
---

# dbt model SQL

Use this skill when creating or revising a dbt model's SQL, with particular
attention to migrations from legacy patterns. ALWAYS preserve the model's
existing behavior and business logic, output contract, and project conventions.
Change behavior or business logic only when the user explicitly requests that
change.

## Workflow

1. Inspect the target model and relevant upstream refs/sources, project
   configuration, and nearby models to understand existing semantics and local
   conventions.
2. Identify the output columns needed and the columns consumed by downstream
   expressions. Keep source filtering and column selection in import CTEs.
3. Make the smallest coherent edit that satisfies the request and the rules
   below. Preserve all existing behavior and business logic, including
   meaningful filters, joins, casts, aliases, and edge-case handling. Do not
   silently remove, alter, or simplify any of them, and do not invent missing
   schema or semantics. If the requested change appears to require a behavior
   change, ask the user before making it unless they have explicitly authorized
   that change.
4. Review the finished SQL against every rule below and confirm that existing
   behavior and business logic remain unchanged unless the user explicitly
   requested otherwise. If a rule conflicts with the requested behavior or
   repository convention, explain the conflict and ask for input rather than
   guessing at a logic change.

## Model SQL rules

- Preserve existing behavior and business logic ALWAYS. Refactors and
  convention updates must be behavior-preserving unless the user explicitly
  requests a behavior or logic change.
- Put all import CTEs first, before transformation or other CTEs.
- An **import CTE** selects from exactly one dbt `ref()` or `source()`
  relation. It may apply the filters needed for that upstream relation.
- An import CTE selects only columns consumed later in the model. Include
  columns used by later CTEs, joins, filters, grouping, or the final output;
  exclude unused upstream columns.
- Write `ref()` and `source()` calls directly in the import CTE's `from` clause.
  Do not assign a relation to a Jinja variable and use that variable as the
  relation; keep dbt dependencies explicit in model SQL.
- Name the final CTE exactly `final`. It must only select the model's intended
  output columns explicitly and may apply filters; do not put transformations
  such as derived expressions, casts, joins, or aggregations in `final`. Keep
  those in preceding CTEs.
- End the query with `select * from final`.

## Extending the standard

Treat the rules in **Model SQL rules** as the current baseline. When the user
adds or changes coding standards, update this section so the skill remains the
single source of truth. Keep new rules specific and compatible with existing
project conventions; call out ambiguity or conflicts rather than silently
guessing.
