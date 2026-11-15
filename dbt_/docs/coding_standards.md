# dbt coding standards

## Intermediate and mart model names

- Name intermediate and mart models `<layer>_<domain>__<entity>_(<descriptor>)_(<fiat>)_(<time_grain>)`, where `layer` is `fct`, `agg`, or `dim`.
- Name an intermediate model `int_<domain>__<entity>_(<descriptor>)_(<fiat>)_(<time_grain>)` only when it is intentionally materialized to improve query performance or to reuse expensive transformations.
- Do not use `int` merely because a model lives in the intermediate directory.
- Include `<descriptor>` as optional text that makes the model's purpose clear.
- Include `<fiat>` only when values are in fiat currency.
- Use `<time_grain>` as `daily`, `weekly`, `monthly`, `quarterly`, `yearly`, or `eop` for multiple grains.

## Domain and entity

- Use one of these `<domain>` codes: `blc` (balances and holdings), `trx` (transactions), `prj` (projections), `inv` (investing), `mtr` (metrics), `alc` (allocation), `sim` (simulations), or `com` (common/shared utilities).
- Use an `<entity>` that names the subject of the model, for example `balances`, `holdings`, `rates`, `transactions`, or `categories`.

## Staging model names

- Name staging models `stg_<domain>__<source>_<descriptor>`.
- Use the literal source name for `<source>`.

## Model YAML files

- Name each model YAML file `_<layer>_<domain>__models.yml`.

## Renaming models

- When renaming a model, update its SQL filename, `ref()` calls, YAML model name, and documentation references together.
