---
name: migrate-dbt-model
description: Create active dbt models that replace legacy models using the current layered SQL conventions. Use when migrating models from dbt_/models/deprecated/ without modifying the deprecated tree.
---

# Migrate dbt model

Use this skill to create active replacement models for one legacy model or a related lineage. Treat `dbt_/models/deprecated/` as read-only: inspect it to understand behavior and consumers, but never edit, move, rename, or delete files there. Preserve behavior and the consumer-facing contract unless the user explicitly requests a change. The repository's `dbt-model-sql` skill defines the SQL rules; follow it alongside this workflow.

## Workflow

1. **Read the migration map first.** Use `dbt_/docs/dbt_model_migration_mapping.yml` (at `C:\Users\pedro\Files\Projects\FDW\dbt_\docs\dbt_model_migration_mapping.yml`) as the project's inventory of legacy-to-current model lineage. Find the entry by deprecated path. Read its `replacement`, `status`, `confidence`, and `note` fields; an empty replacement with `not_migrated` means there is no active mapped replacement. For `partial` or low-confidence entries, treat the mapping as a lead to investigate, not as a verified equivalent. If a model has no entry, inspect its lineage and report that the map has no entry rather than guessing.
2. **Map and verify the lineage.** Read the legacy SQL, its upstream models/macros/sources, downstream refs, YAML metadata, project configuration, and nearby current models. Treat all files under `dbt_/models/deprecated/` as read-only. Search by model name and output columns where names changed. Confirm every mapping against actual refs, columns, grain, and consumers. A replacement can be one-to-many or split across layers.
3. **Write a before/after contract.** Record grain, unique key, output columns and types, filters, join types and conditions, null/default behavior, calculations, time windows, materialization, incremental settings, and ordering only where consumers rely on it. Identify all downstream consumers.
4. **Compare representative current patterns.** Use nearby active models as structural guidance. Separate convention changes (CTEs, explicit imports, explicit output projection, tags) from semantic changes (grain, filtering, joins, calculations, keys, materialization). Do not copy changed semantics without authorization.
5. **Plan the smallest migration.** Create the replacement as a new model in the active tree; do not move or rename the legacy file. Decide whether the old model maps to one current model or requires a lineage of staging, intermediate, dimension, and mart models. Keep dependencies explicit with `ref()`/`source()`. Preserve output contract or document a necessary incompatibility and obtain direction before changing it.
6. **Implement with the `dbt-model-sql` rules.** Import CTEs first, selecting only consumed columns; transformations and joins in named CTEs; an explicit projection in `final`; finish with `select * from final`. Use the current directory/naming conventions visible in adjacent models and configure incremental behavior only when supported by the model's semantics.
7. **Review equivalence and migration scope.** Trace every output field and business rule from old to new SQL. Verify filters, join cardinality, null behavior, casts, deduplication, union behavior, date boundaries, and calculations. Flag any unproven differences instead of claiming equivalence. Update active model YAML and active downstream refs when the requested migration includes them. Never update refs or metadata in deprecated models; if a deprecated consumer still points to the legacy model, report that as an outstanding deprecated dependency.

## Mapping file maintenance

When a migration adds, confirms, or changes a legacy-to-current mapping, update `dbt_/docs/dbt_model_migration_mapping.yml` in the same task when documentation updates are in scope. Keep paths relative to `source_root` and `target_root`; use a list for one or more replacements, `[]` when none is mapped, and the existing `status`, `confidence`, and `note` conventions. Only mark a mapping `migrated` when the active lineage is confirmed. Use `partial` when responsibilities moved but the legacy model has no complete replacement, and `not_migrated` when none exists. Never edit the map based only on inferred similarity.

## Migration safeguards

- Do not infer a direct replacement solely from similar names or subject area. Establish lineage through refs, columns, grain, and consumers.
- Do not drop fields, filters, joins, casts, fallback values, or edge-case behavior as cleanup. If no equivalent exists in the new design, report the gap and ask before changing behavior.
- Do not introduce joins or dimensions merely because a nearby model uses them. Confirm the old relationship and cardinality.
- Do not change a view/table/incremental model, unique key, event time, batch size, or lookback without confirming that the new configuration preserves required behavior.
- When an intentional contract or behavior change is requested, enumerate it and update relevant YAML/docs and downstream models in scope.
- Treat the migration map as lineage documentation, not as proof of semantic equivalence or permission to change behavior.
- Never modify, move, rename, or delete a file under `dbt_/models/deprecated/`, including SQL, YAML, or documentation stored there. These files are read-only migration evidence; create replacements under the active `dbt_/models/` tree instead.
- Do not update downstream references inside deprecated models. Update active consumers only when they are in scope, and report deprecated consumers that continue to reference the legacy model.
- If evidence is incomplete, finish the structural work that is clearly safe and list unresolved semantic questions; do not label the migration behavior-preserving until they are resolved.

## Completion summary

Report the old-to-new model mapping, important structural changes, any output or logic differences, active downstream/YAML updates, deprecated consumers left on the legacy model, and what validation was performed. Distinguish SQL review from executed dbt validation.
