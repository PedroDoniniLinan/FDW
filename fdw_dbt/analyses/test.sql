select distinct budget_level
from {{ ref("stg_projections__transactions") }}