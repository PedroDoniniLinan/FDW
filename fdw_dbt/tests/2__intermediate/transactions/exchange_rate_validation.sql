select *
from {{ ref("int_transactions__fiat_converted") }}
where exchange_rate * units != amount