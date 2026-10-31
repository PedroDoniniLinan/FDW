---
name: apply-styles
description: apply-styles
invokable: true
---

# DBT SQL Model Transformer Skill

## Purpose

Transform dbt staging model SQL queries to conform to the project's coding style guidelines.

## When to Use

- Refactoring existing dbt staging models (`stg_` prefixed models)
- Writing new staging models that need to follow conventions
- Validating SQL queries against style guidelines

## Coding Style Rules

### 1. No Sources/Refs in SET Clause

- Avoid using `SET` with dynamic references
- All sources and refs must be declared in CTEs at the beginning of the file

### 2. Source/Ref Declaration Pattern

- **Any** `source()` or `ref()` calls must appear in a CTE at the beginning of the file
- Apply necessary filters (WHERE clauses, etc.) in this initial CTE
- Select **only the consumed columns** in the source CTE

### 3. No Subqueries

- Use only CTEs, never subqueries in FROM/WHERE/SELECT clauses
- Break complex logic into sequential CTEs

### 4. Staging Model Responsibilities

- Keep final SELECT statements simple (only column selection/rename)
- Complex business logic should be pushed to downstream models

### 5. Query Structure

- Every query must end with:
  ```sql
  final as (
      -- transformation logic here
  )

  select * from final
  ```
- The `final` CTE should be the last CTE before the final SELECT

## Transformation Process

### Step 1: Analyze Current Structure

- Identify all `source()` and `ref()` calls
- Locate where filters are applied
- Find casts and transformations
- Check for subqueries or complex nested queries

### Step 2: Restructure According to Rules

**Before (Non-compliant):**
```sql
{{ config(tags=['refactored']) }}

select
    distinct
        currency as asset,
        md5(currency)::uuid as asset_id
from {{ source('bronze', 'balances') }}
where active = true
```

**After (Compliant):**
```sql
{{ config(
    tags=['refactored']
) }}

with balances as (
    select
        currency
    from {{ source('bronze', 'balances') }}
    where active = true
),

final as (
    select distinct
        currency as asset,
        md5(currency)::uuid as asset_id
    from balances
)

select * from final
```

### Step 3: Validation Checklist

- [ ] All sources/refs are in initial CTEs only
- [ ] Filters are applied in source CTEs
- [ ] Only consumed columns are selected in source CTEs
- [ ] No subqueries present
- [ ] Casts and simple transformations exist
- [ ] `final` CTE is present as last CTE
- [ ] Query ends with `select * from final`

## Example Transformations

### Pattern: Moving Filters to Source CTE

**Before:**
```sql
select currency, amount
from {{ source('bronze', 'balances') }}
where deleted_at is null
```

**After:**
```sql
with raw_balances as (
    select
        currency,
        amount
    from {{ source('bronze', 'balances') }}
    where deleted_at is null
)

select * from raw_balances
```

### Pattern: Removing Subqueries

**Before:**
```sql
select
    asset_id,
    count(*) as balance_count
from (
    select currency::uuid as asset_id, amount
    from {{ source('bronze', 'balances') }}
) subquery
group by asset_id
```

**After:**
```sql
with balances as (
    select
        currency::uuid as asset_id,
        amount
    from {{ source('bronze', 'balances') }}
)

final_agg as (
    select
        asset_id,
        count(*) as balance_count
    from balances
    group by asset_id
)

select * from final_agg
```

## Key Principles

1. **Separation of Concerns**: Source CTEs handle filtering; final CTE handles transformations
2. **Readability**: Each CTE should have a clear, single purpose
3. **Maintainability**: Follow the pattern consistently across all staging models
4. **Performance**: Let dbt optimize by keeping structure predictable
