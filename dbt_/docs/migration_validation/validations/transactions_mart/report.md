# Validation: transactions_mart

- Legacy: `gold.transactions_mart`
- Current: `fct_trx__transactions_enriched_daily`
- Last run: 2026-11-02 20:19:09
- Tests folder: `dbt_/analyses/migration_validation/transactions_mart/`
- Verdict: **2 of 3 tests differ**

Amounts are compared per currency only. Amounts in different currencies are never summed together.

## Summary

| test | groups | not matching | verdict | query |
|---|---|---|---|---|
| transactions_mart__amount_by_account_eur | 27 | 2 | differs | kept |
| transactions_mart__amount_by_budget_level_2_eur | 53 | 7 | differs | kept |
| transactions_mart__amount_by_year_and_currency | 24 | 0 | ok | kept |

Query column: `added` (new test), `updated` (its SQL changed since the last run), `kept` (unchanged), `removed` (test deleted).

Tests with issues: `transactions_mart__amount_by_account_eur`, `transactions_mart__amount_by_budget_level_2_eur`.
Open groups are listed in `open_items.md`.

## transactions_mart__amount_by_account_eur

amount per account, EUR only (sum of amount), legacy vs current.

Query: `queries/transactions_mart__amount_by_account_eur.sql` (kept)

| account | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|
| AB | 99.98 | 99.98 | 0.00 | ok |
| Alelo | 0.00 | 0.00 | 0.00 | ok |
| Avenue | 83.15 | 83.05 | -0.10 | mismatch |
| BB | 0.00 | 0.00 | 0.00 | ok |
| BNB | -472.62 | -472.70 | -0.08 | ok |
| BT | 155.08 | 155.08 | 0.00 | ok |
| BTG | 17,361.87 | 17,361.87 | 0.00 | ok |
| BlockFi | 31.29 | 31.30 | 0.01 | ok |
| Caju | 0.00 | 0.00 | 0.00 | ok |
| Coverflex | 0.00 | 0.00 | 0.00 | ok |
| Degiro | 9,979.00 | 9,979.00 | -0.01 | ok |
| Easy | 124.12 | 124.12 | 0.00 | ok |
| IBKR | 36,258.73 | 36,258.74 | 0.00 | ok |
| Klarna | 127.96 | 127.96 | 0.00 | ok |
| Kraken | 552.26 | 552.29 | 0.02 | ok |
| Ledger | 18,715.64 | 18,715.63 | 0.00 | ok |
| MetaMask | 192.39 | 192.53 | 0.14 | ok |
| N26 | 166.00 | 166.00 | 0.00 | ok |
| Nu | 315.01 | 315.01 | 0.00 | ok |
| Nubank C | 4,772.37 | 4,772.37 | 0.00 | ok |
| Nubank D | 27,742.99 | 27,743.00 | 0.01 | ok |
| Payoneer | -14.36 | -14.36 | 0.00 | ok |
| Phantom | -23.50 | -23.47 | 0.03 | mismatch |
| Ronin | -90.60 | -90.60 | 0.00 | ok |
| T212 | 34,957.81 | 34,957.81 | 0.00 | ok |
| Wise | 27,655.70 | 27,655.68 | -0.02 | ok |
| Wise D | 11,009.88 | 11,009.88 | 0.00 | ok |

## transactions_mart__amount_by_budget_level_2_eur

amount per budget_level_2, EUR only (sum of amount), legacy vs current.

Query: `queries/transactions_mart__amount_by_budget_level_2_eur.sql` (kept)

| budget_level_2 | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|
| <null> | -883.35 | 6,124.98 | 7,008.33 | mismatch |
| Alternative | -3.77 | -3.77 | 0.00 | ok |
| Bonds BR | 7,003.25 | 7,192.37 | 189.12 | mismatch |
| Bonds EU | 2,846.23 | 2,846.23 | 0.00 | ok |
| Car | -320.70 | -320.70 | 0.00 | ok |
| Cash | 51.06 | 51.06 | 0.00 | ok |
| Clothes D | -3,368.03 | -3,368.04 | -0.01 | ok |
| Clothes P | -597.01 | -497.11 | 99.90 | mismatch |
| Crypto | 1,179.85 | 1,179.98 | 0.13 | ok |
| Eat out | -11,724.91 | -11,724.91 | 0.00 | ok |
| Event food | -3,875.12 | -3,875.12 | 0.00 | ok |
| Fraud | 19.25 | 19.25 | 0.00 | ok |
| Gifts (famiy & friends) | -2,612.06 | -2,612.06 | -0.01 | ok |
| Gifts D | -2,671.07 | -2,671.08 | 0.00 | ok |
| Gifts P | -1,226.97 | -1,226.97 | 0.00 | ok |
| Gold | -269.94 | -269.95 | -0.01 | ok |
| Gov. Taxes | -5,276.36 | -5,276.36 | 0.00 | ok |
| Growth stocks | 20,506.01 | 20,505.99 | -0.02 | ok |
| Hobbies & Interests B | -1,464.39 | -1,464.39 | 0.00 | ok |
| Hobbies & Interests D | -4,780.87 | -4,780.87 | 0.00 | ok |
| Hobbies & Interests P | -5,361.58 | -5,361.58 | 0.00 | ok |
| House bills | -49,723.53 | -49,723.53 | 0.00 | ok |
| Inconsistencies | -660.55 | -660.55 | 0.00 | ok |
| Internal |  | -883.28 | -883.28 | missing_in_legacy |
| Loan | -2,342.91 | -2,342.91 | 0.00 | ok |
| Major goods | -5,304.38 | -5,304.38 | 0.00 | ok |
| Major services | -775.00 | -775.00 | 0.00 | ok |
| Minor goods | -1,723.70 | -1,723.70 | 0.00 | ok |
| NFT games | -3,203.96 | -3,203.94 | 0.02 | ok |
| Non-routine | -5,738.38 |  | 5,738.38 | missing_in_current |
| Parents | 17,164.84 | 17,164.84 | 0.00 | ok |
| Public transport | -684.40 | -684.40 | 0.00 | ok |
| Real state | -406.59 | -406.59 | 0.00 | ok |
| Regular care | -2,420.09 | -2,420.09 | 0.00 | ok |
| Routine | -3,066.88 | -3,066.88 | 0.00 | ok |
| Salary | 244,784.91 | 244,784.91 | 0.00 | ok |
| Souvenir | -69.97 | -69.97 | 0.00 | ok |
| Stable (Cash) | -971.77 | -971.77 | 0.00 | ok |
| Stablecoin | 315.34 | 315.33 | -0.01 | ok |
| Stay | -3,872.74 | -3,872.74 | 0.00 | ok |
| Supermarket | -16,018.67 | -16,018.67 | 0.00 | ok |
| Taxes | 14,379.09 | 14,379.09 | 0.00 | ok |
| Teaching | 30,960.72 | 30,960.72 | 0.00 | ok |
| Tickets & Long Transport | -12,890.61 | -12,890.61 | 0.00 | ok |
| Tours | -1,371.08 | -1,371.08 | 0.00 | ok |
| Transaction Fees | -2,358.35 | -2,358.47 | -0.12 | ok |
| Travel Transport | -266.03 | -266.03 | 0.00 | ok |
| Uber | -2,064.29 | -2,064.29 | 0.00 | ok |
| Unexpected |  | -5,738.38 | -5,738.38 | missing_in_legacy |
| Value stocks | 9,382.32 | 9,382.28 | -0.04 | ok |
| Variable care | -2,900.13 | -2,900.13 | 0.00 | ok |
| Volatile (Cash) | 6,276.35 | -137.66 | -6,414.00 | mismatch |
| Work related | -1,898.93 | -1,898.93 | 0.00 | ok |

## transactions_mart__amount_by_year_and_currency

amount per year and fiat currency (sum of amount), legacy vs current. Rows in currency 'Original' are excluded; see transactions_mart__amount_original_by_asset.

Query: `queries/transactions_mart__amount_by_year_and_currency.sql` (kept)

| period | currency | legacy_amount | current_amount | amount_diff | status |
|---|---|---|---|---|---|
| 2019-01-01 | BRL | 87,876.97 | 87,876.96 | -0.01 | ok |
| 2019-01-01 | EUR | 18,026.05 | 18,026.04 | 0.00 | ok |
| 2019-01-01 | USD | 21,090.47 | 21,090.47 | 0.00 | ok |
| 2020-01-01 | BRL | 108,050.95 | 108,050.95 | 0.00 | ok |
| 2020-01-01 | EUR | 11,915.54 | 11,915.54 | 0.00 | ok |
| 2020-01-01 | USD | 13,941.18 | 13,941.18 | 0.00 | ok |
| 2021-01-01 | BRL | 83,436.56 | 83,436.92 | 0.36 | ok |
| 2021-01-01 | EUR | 13,761.27 | 13,761.33 | 0.06 | ok |
| 2021-01-01 | USD | 14,318.84 | 14,318.90 | 0.06 | ok |
| 2022-01-01 | BRL | 12,561.18 | 12,561.37 | 0.19 | ok |
| 2022-01-01 | EUR | 7,301.46 | 7,301.48 | 0.02 | ok |
| 2022-01-01 | USD | 5,106.28 | 5,106.31 | 0.03 | ok |
| 2023-01-01 | BRL | 215,566.32 | 215,566.18 | -0.14 | ok |
| 2023-01-01 | EUR | 43,784.94 | 43,784.91 | -0.03 | ok |
| 2023-01-01 | USD | 50,092.77 | 50,092.74 | -0.03 | ok |
| 2024-01-01 | BRL | 262,372.49 | 262,372.22 | -0.27 | ok |
| 2024-01-01 | EUR | 29,114.13 | 29,114.09 | -0.04 | ok |
| 2024-01-01 | USD | 26,342.79 | 26,342.76 | -0.04 | ok |
| 2025-01-01 | BRL | 140,683.63 | 140,683.58 | -0.06 | ok |
| 2025-01-01 | EUR | 15,439.02 | 15,439.01 | 0.00 | ok |
| 2025-01-01 | USD | 33,111.77 | 33,111.76 | -0.02 | ok |
| 2026-01-01 | BRL | 145,281.67 | 145,281.73 | 0.05 | ok |
| 2026-01-01 | EUR | 50,357.79 | 50,357.78 | -0.01 | ok |
| 2026-01-01 | USD | 48,445.29 | 48,445.29 | 0.00 | ok |
