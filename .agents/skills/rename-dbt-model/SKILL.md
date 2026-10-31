---
name: rename-dbt-model
description: Rename a dbt model everywhere it is referenced, including the SQL filename, ref() calls, YAML metadata, and documentation blocks. Use when a dbt model name changes or a user asks to update all references to a dbt model.
---

# Rename a dbt model

Rename the model consistently across the repository while preserving its SQL
logic, configuration, documentation, and dependency graph.

## Workflow

1. Confirm the old model name and requested new model name. Treat model names
   as the dbt node name: normally the SQL file stem, without its directory or
   extension.
2. Inspect repository guidance and locate the target SQL file. Search the
   repository for the old name before editing so the complete impact is known.
3. Rename only the target model's SQL file from `<old_name>.sql` to
   `<new_name>.sql`. Preserve its directory and do not change SQL behavior.
4. Update every exact dbt reference to the model:
   - `ref('old_name')`
   - `ref("old_name")`
   - whitespace variants such as `ref( 'old_name' )`
   Preserve quote style and surrounding Jinja/SQL.
5. Update YAML references and metadata, including model entries, `name:`
   fields, tests, exposures, metrics, semantic metadata, and any other dbt
   configuration that names the model. Do not rename unrelated columns,
   sources, macros, packages, or filesystem paths merely because they contain
   similar text.
6. Update documentation blocks and doc references, including `docs()` blocks
   and markdown/YAML documentation that explicitly names or links to the old
   model. Preserve the prose meaning and formatting.
7. Search again for the old model name using exact-name-aware patterns. Review
   every remaining match manually; retain matches that are intentionally
   unrelated and report them.
8. Search for the new name and inspect the diff. Verify that the SQL filename,
   `ref()` dependencies, YAML metadata, and documentation all agree.

## Safety rules

- Make the smallest coherent change. Do not alter SQL expressions, filters,
  joins, aliases, column names, tests, or business logic unless explicitly
  requested.
- Do not perform a broad blind replacement of the old string. Scope edits to
  the target model reference and inspect ambiguous matches.
- Preserve capitalization unless the user explicitly requests a case change.
- Avoid changing comments or prose that refer to a different concept with the
  same text.
- If multiple SQL files have the old stem, stop and identify the ambiguity
  before renaming a file. References alone may not determine which file is the
  intended model.
- Check git status before and after editing so unrelated user changes remain
  untouched.

## Verification checklist

- [ ] The intended SQL file has the new filename and the old file is absent.
- [ ] No unintended `ref('old_name')` or `ref("old_name")` calls remain.
- [ ] YAML model/configuration references use the new name.
- [ ] Documentation blocks and explicit documentation references use the new
      name.
- [ ] The new model name appears in the expected dependency and metadata files.
- [ ] The final diff contains only the rename and reference updates.
- [ ] Run the repository's applicable dbt parse, compile, or targeted tests when
      available; otherwise report that validation was limited to static search
      and diff inspection.

## Completion report

Report the renamed SQL path, the categories of references updated, any
intentional old-name matches retained, and the validation commands run.
