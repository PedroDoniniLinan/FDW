select *
from {{ ref("fct_trx__cashflow_fiat_daily") }}
where exchange_rate * units != amount
