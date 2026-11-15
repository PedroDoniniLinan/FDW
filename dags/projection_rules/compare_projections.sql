-- Compare bronze.projections (sheet-fed) with bronze.projections_generated (repo generator).
-- Rows are matched on the full output key. Amounts are summed per key first, so duplicate
-- keys are compared on their total and on their row count.
-- Amounts in bronze.projections come from the sheet's displayed values (read_spreadsheet uses
-- FORMATTED_VALUE), so they can be rounded to the cell format (up to 5 decimals). The generator
-- keeps full precision. DISPLAY_TOL is the largest rounding error that 5-decimal display gives.
-- Run with execute_query(file, code=False).
with old_side as (
    select calendar_date, simulation_set, transaction_type, budget_level, level_2,
           sum(amount) as old_amount, count(*) as old_n
    from bronze.projections
    group by 1, 2, 3, 4, 5
),
new_side as (
    select calendar_date, simulation_set, transaction_type, budget_level, level_2,
           sum(amount) as new_amount, count(*) as new_n
    from bronze.projections_generated
    group by 1, 2, 3, 4, 5
),
joined as (
    select coalesce(o.calendar_date, n.calendar_date) as calendar_date,
           coalesce(o.simulation_set, n.simulation_set) as simulation_set,
           coalesce(o.transaction_type, n.transaction_type) as transaction_type,
           coalesce(o.budget_level, n.budget_level) as budget_level,
           coalesce(o.level_2, n.level_2) as level_2,
           o.old_amount, n.new_amount, o.old_n, n.new_n
    from old_side o
    full join new_side n
        on o.calendar_date = n.calendar_date
       and o.simulation_set = n.simulation_set
       and o.transaction_type = n.transaction_type
       and o.budget_level = n.budget_level
       and o.level_2 = n.level_2
)
select
    simulation_set,
    count(*) as keys_compared,
    count(*) filter (where old_amount is null) as only_in_generated,
    count(*) filter (where new_amount is null) as only_in_old,
    count(*) filter (where old_n is distinct from new_n) as row_count_differs,
    count(*) filter (where abs(old_amount - new_amount) > 1e-9) as not_exact,
    count(*) filter (where abs(old_amount - new_amount) > 5e-6 + 1e-9) as beyond_display_rounding,
    max(abs(old_amount - new_amount)) as max_abs_diff,
    case when count(*) filter (where old_amount is null or new_amount is null
                                  or old_n is distinct from new_n
                                  or abs(old_amount - new_amount) > 5e-6 + 1e-9) = 0
         then 'OK' else 'DIFF' end as status
from joined
group by rollup (simulation_set)
order by simulation_set nulls last;
