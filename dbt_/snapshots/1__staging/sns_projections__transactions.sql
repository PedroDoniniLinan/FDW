select * from {{ source('bronze', 'projections') }}
