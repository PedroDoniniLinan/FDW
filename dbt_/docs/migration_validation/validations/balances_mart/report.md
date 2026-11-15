# Validation: balances_mart

- Legacy: `gold.balances_mart`
- Current: `fct_blc__balances_enriched_daily`
- Last run: 2026-11-02 21:45:00
- Tests folder: `dbt_/analyses/migration_validation/balances_mart/`
- Verdict: **2 of 6 tests differ**

Amounts are compared per currency only. Amounts in different currencies are never summed together.

## Summary

| test | groups | not matching | verdict | query |
|---|---|---|---|---|
| balances_mart__amount_by_account_eur | 27 | 0 | ok | updated |
| balances_mart__amount_by_budget_level_2_eur | 12 | 4 | differs | updated |
| balances_mart__amount_by_year_and_currency | 24 | 0 | ok | updated |
| balances_mart__last_balance_by_account_eur | 27 | 0 | ok | updated |
| balances_mart__last_balance_by_budget_level_2_eur | 12 | 5 | differs | updated |
| balances_mart__last_balance_by_year_and_currency | 24 | 0 | ok | updated |

Query column: `added` (new test), `updated` (its SQL changed since the last run), `kept` (unchanged), `removed` (test deleted).

Tests with issues: `balances_mart__amount_by_budget_level_2_eur`, `balances_mart__last_balance_by_budget_level_2_eur`.
Open groups are listed in `open_items.md`.

## balances_mart__amount_by_account_eur

balance per account, EUR only (sum of daily balance), legacy vs current.

Query: `queries/balances_mart__amount_by_account_eur.sql` (updated)

| account | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|
| AB | 527,761.91 | 527,761.91 | 0.00 | ok |
| Alelo | 217,075.30 | 217,075.30 | 0.00 | ok |
| Avenue | 16,113,158.38 | 16,113,104.92 | -53.45 | ok |
| BB | 128,255.13 | 128,255.13 | 0.00 | ok |
| BNB | 1,776,339.61 | 1,776,278.02 | -61.59 | ok |
| BT | 126,136.13 | 126,136.13 | 0.00 | ok |
| BTG | 2,267,976.39 | 2,267,976.14 | -0.25 | ok |
| BlockFi | 1,091,504.62 | 1,091,530.21 | 25.59 | ok |
| Caju | 116,163.03 | 116,163.03 | 0.00 | ok |
| Coverflex | 79,637.47 | 79,637.47 | 0.00 | ok |
| Degiro | 27,400,685.08 | 27,400,684.73 | -0.35 | ok |
| Easy | 21,100,673.98 | 21,100,669.20 | -4.77 | ok |
| IBKR | 12,144,547.69 | 12,144,547.53 | -0.16 | ok |
| Klarna | 56,158.32 | 56,158.32 | 0.00 | ok |
| Kraken | 487,582.33 | 487,588.57 | 6.23 | ok |
| Ledger | 13,003,244.38 | 13,003,243.27 | -1.11 | ok |
| MetaMask | 77,263.46 | 77,262.31 | -1.16 | ok |
| N26 | 5,404,102.20 | 5,404,101.35 | -0.85 | ok |
| Nu | 34,785,280.45 | 34,785,280.73 | 0.29 | ok |
| Nubank C | 618,723.82 | 618,723.84 | 0.02 | ok |
| Nubank D | 12,061,532.11 | 12,061,533.33 | 1.22 | ok |
| Payoneer | 3,037,404.16 | 3,037,404.16 | 0.00 | ok |
| Phantom | 19,739.11 | 19,744.62 | 5.51 | ok |
| Ronin | 349,812.52 | 349,812.34 | -0.17 | ok |
| T212 | 24,442,975.13 | 24,442,979.59 | 4.46 | ok |
| Wise | 16,198,718.75 | 16,198,703.49 | -15.25 | ok |
| Wise D | 5,564,156.26 | 5,564,156.29 | 0.03 | ok |

## balances_mart__amount_by_budget_level_2_eur

balance per budget_level_2, EUR only (sum of daily balance), legacy vs current.

Query: `queries/balances_mart__amount_by_budget_level_2_eur.sql` (updated)

| budget_level_2 | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|
| <null> |  | 602,827.76 | 602,827.76 | missing_in_legacy |
| Bonds BR | 24,352,496.22 | 22,874,152.03 | -1,478,344.19 | mismatch |
| Bonds EU | 24,140,955.01 | 24,140,951.73 | -3.27 | ok |
| Crypto | 15,100,821.85 | 15,100,796.67 | -25.18 | ok |
| Gold | 478,972.46 | 478,971.80 | -0.66 | ok |
| Growth stocks | 58,518,559.61 | 58,293,700.84 | -224,858.77 | mismatch |
| NFT games | 367,534.95 | 367,548.49 | 13.54 | ok |
| Real state | 3,158,047.77 | 3,158,047.77 | 0.00 | ok |
| Stable (Cash) | 22,797,287.34 | 22,797,188.48 | -98.87 | ok |
| Stablecoin | 900,533.33 | 900,560.89 | 27.56 | ok |
| Value stocks | 27,657,696.33 | 27,631,130.64 | -26,565.68 | ok |
| Volatile (Cash) | 21,723,702.83 | 22,850,634.83 | 1,126,931.99 | mismatch |

## balances_mart__amount_by_year_and_currency

balance per year and fiat currency (sum of daily balance), legacy vs current. Rows in currency 'Original' are excluded; a separate per-asset test covers them when requested.

Query: `queries/balances_mart__amount_by_year_and_currency.sql` (updated)

| period | currency | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|---|
| 2019-01-01 | BRL | 13,090,894.54 | 13,090,894.07 | -0.47 | ok |
| 2019-01-01 | EUR | 2,685,311.69 | 2,685,311.59 | -0.10 | ok |
| 2019-01-01 | USD | 3,141,814.69 | 3,141,814.58 | -0.11 | ok |
| 2020-01-01 | BRL | 49,673,832.16 | 49,673,830.67 | -1.49 | ok |
| 2020-01-01 | EUR | 8,432,726.89 | 8,432,726.63 | -0.26 | ok |
| 2020-01-01 | USD | 9,866,289.71 | 9,866,289.41 | -0.30 | ok |
| 2021-01-01 | BRL | 89,995,782.59 | 89,995,798.13 | 15.54 | ok |
| 2021-01-01 | EUR | 14,052,928.66 | 14,052,931.08 | 2.42 | ok |
| 2021-01-01 | USD | 16,698,624.96 | 16,698,627.70 | 2.74 | ok |
| 2022-01-01 | BRL | 90,346,603.60 | 90,346,540.66 | -62.94 | ok |
| 2022-01-01 | EUR | 16,654,182.74 | 16,654,171.32 | -11.43 | ok |
| 2022-01-01 | USD | 17,563,716.38 | 17,563,704.11 | -12.27 | ok |
| 2023-01-01 | BRL | 143,266,335.49 | 143,266,269.88 | -65.61 | ok |
| 2023-01-01 | EUR | 26,742,615.41 | 26,742,603.18 | -12.23 | ok |
| 2023-01-01 | USD | 28,922,061.20 | 28,922,047.98 | -13.22 | ok |
| 2024-01-01 | BRL | 224,769,557.15 | 224,769,434.35 | -122.80 | ok |
| 2024-01-01 | EUR | 38,516,169.14 | 38,516,148.32 | -20.82 | ok |
| 2024-01-01 | USD | 41,625,427.25 | 41,625,404.76 | -22.49 | ok |
| 2025-01-01 | BRL | 293,766,251.97 | 293,766,055.20 | -196.77 | ok |
| 2025-01-01 | EUR | 46,772,470.00 | 46,772,438.69 | -31.31 | ok |
| 2025-01-01 | USD | 52,791,449.10 | 52,791,413.81 | -35.29 | ok |
| 2026-01-01 | BRL | 270,427,771.58 | 270,427,639.60 | -131.99 | ok |
| 2026-01-01 | EUR | 45,340,203.17 | 45,340,181.12 | -22.05 | ok |
| 2026-01-01 | USD | 52,545,415.94 | 52,545,390.37 | -25.57 | ok |

## balances_mart__last_balance_by_account_eur

balance on the last calendar_date of each account, EUR only (sum of balance on that date), legacy vs current.

Query: `queries/balances_mart__last_balance_by_account_eur.sql` (updated)

| account | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|
| AB | 99.98 | 99.98 | 0.00 | ok |
| Alelo | 0.00 | 0.00 | 0.00 | ok |
| Avenue | 32.06 | 32.01 | -0.05 | ok |
| BB | 0.00 | 0.00 | 0.00 | ok |
| BNB | 0.01 | -0.02 | -0.03 | ok |
| BT | 0.00 | 0.00 | 0.00 | ok |
| BTG | 17,534.41 | 17,534.41 | 0.00 | ok |
| BlockFi | 0.00 | 0.00 | 0.00 | ok |
| Caju | 0.00 | 0.00 | 0.00 | ok |
| Coverflex | 0.00 | 0.00 | 0.00 | ok |
| Degiro | 10,765.52 | 10,765.52 | 0.00 | ok |
| Easy | 0.00 | 0.00 | 0.00 | ok |
| IBKR | 36,196.95 | 36,196.95 | 0.00 | ok |
| Klarna | 127.96 | 127.96 | 0.00 | ok |
| Kraken | 0.00 | 0.01 | 0.01 | ok |
| Ledger | 18,715.64 | 18,715.63 | 0.00 | ok |
| MetaMask | 0.19 | 0.19 | 0.00 | ok |
| N26 | 166.00 | 166.00 | 0.00 | ok |
| Nu | -61.54 | -61.54 | 0.00 | ok |
| Nubank C | 4,837.70 | 4,837.70 | 0.00 | ok |
| Nubank D | 27,741.90 | 27,741.91 | 0.01 | ok |
| Payoneer | 54.17 | 54.17 | 0.00 | ok |
| Phantom | 0.00 | 0.00 | 0.00 | ok |
| Ronin | 0.00 | 0.00 | 0.00 | ok |
| T212 | 36,221.88 | 36,221.88 | -0.01 | ok |
| Wise | 27,667.06 | 27,667.04 | -0.02 | ok |
| Wise D | 11,057.41 | 11,057.41 | 0.00 | ok |

## balances_mart__last_balance_by_budget_level_2_eur

balance on the last calendar_date of each budget_level_2, EUR only (sum of balance on that date), legacy vs current.

Query: `queries/balances_mart__last_balance_by_budget_level_2_eur.sql` (updated)

| budget_level_2 | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|
| <null> |  | 8,560.44 | 8,560.44 | missing_in_legacy |
| Bonds BR | 28,649.21 | 16,971.27 | -11,677.94 | mismatch |
| Bonds EU | 54,747.27 | 54,747.27 | 0.00 | ok |
| Crypto | 16,707.98 | 16,707.98 | 0.00 | ok |
| Gold | 2,475.07 | 2,475.07 | 0.00 | ok |
| Growth stocks | 51,236.29 | 48,308.46 | -2,927.83 | mismatch |
| NFT games | 0.00 | 0.00 | 0.00 | ok |
| Real state | 0.00 | 0.00 | 0.00 | ok |
| Stable (Cash) | 3,142.07 | 3,142.00 | -0.07 | ok |
| Stablecoin | 0.00 | 0.00 | 0.00 | ok |
| Value stocks | 26,457.48 | 25,979.11 | -478.37 | mismatch |
| Volatile (Cash) | 7,741.94 | 14,265.63 | 6,523.69 | mismatch |

## balances_mart__last_balance_by_year_and_currency

balance on the last calendar_date of each year and fiat currency (sum of balance on that date), legacy vs current. Rows in currency 'Original' are excluded; a separate per-asset test covers them when requested.

Query: `queries/balances_mart__last_balance_by_year_and_currency.sql` (updated)

| period | currency | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|---|
| 2019-01-01 | BRL | 91,623.03 | 91,623.02 | 0.00 | ok |
| 2019-01-01 | EUR | 18,794.47 | 18,794.47 | 0.00 | ok |
| 2019-01-01 | USD | 21,989.53 | 21,989.53 | 0.00 | ok |
| 2020-01-01 | BRL | 199,770.94 | 199,770.94 | 0.00 | ok |
| 2020-01-01 | EUR | 30,734.00 | 30,734.00 | 0.00 | ok |
| 2020-01-01 | USD | 35,958.77 | 35,958.77 | 0.00 | ok |
| 2021-01-01 | BRL | 285,912.16 | 285,911.75 | -0.41 | ok |
| 2021-01-01 | EUR | 44,925.41 | 44,925.34 | -0.07 | ok |
| 2021-01-01 | USD | 50,783.69 | 50,783.62 | -0.07 | ok |
| 2022-01-01 | BRL | 298,450.58 | 298,450.48 | -0.09 | ok |
| 2022-01-01 | EUR | 52,238.17 | 52,238.15 | -0.02 | ok |
| 2022-01-01 | USD | 55,889.62 | 55,889.60 | -0.02 | ok |
| 2023-01-01 | BRL | 514,350.08 | 514,349.85 | -0.23 | ok |
| 2023-01-01 | EUR | 96,087.32 | 96,087.28 | -0.04 | ok |
| 2023-01-01 | USD | 106,051.57 | 106,051.52 | -0.05 | ok |
| 2024-01-01 | BRL | 774,154.06 | 774,153.53 | -0.53 | ok |
| 2024-01-01 | EUR | 124,786.59 | 124,786.50 | -0.09 | ok |
| 2024-01-01 | USD | 131,950.59 | 131,950.50 | -0.09 | ok |
| 2025-01-01 | BRL | 912,071.65 | 912,071.09 | -0.56 | ok |
| 2025-01-01 | EUR | 139,790.05 | 139,789.96 | -0.09 | ok |
| 2025-01-01 | USD | 164,532.89 | 164,532.79 | -0.10 | ok |
| 2026-01-01 | BRL | 1,063,315.22 | 1,063,314.72 | -0.50 | ok |
| 2026-01-01 | EUR | 191,157.31 | 191,157.22 | -0.09 | ok |
| 2026-01-01 | USD | 214,153.57 | 214,153.47 | -0.10 | ok |
