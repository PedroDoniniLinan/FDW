select *
from {{ source('bronze', 'balances') }}