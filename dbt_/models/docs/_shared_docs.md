# Shared docs

Doc blocks referenced by models across multiple subfolders.

<!-- general fields -->
{% docs calendar_date %}

Date of the record in calendar terms. Represents the day the event occurred or
the snapshot was taken.

{% enddocs %}

{% docs is_end_of_period %}

Flag indicating whether the date represents the last day of a calendar period.
Contains the period type as a concatenated string, such as day, dayweek,
daymonth, or dayyear, allowing filtering by any period granularity.

{% enddocs %}

<!-- asset related fields -->
{% docs asset %}

Asset name, ticker, acronym or key information.

{% enddocs %}

{% docs exchange_asset %}

Asset associated with an exchange rate with another asset. The exchange asset is
the numerator of the rate.

{% enddocs %}

{% docs rate_id %}

Unique identifier of an exchange rate defined by the asset (denominator),
exchange asset/currenncy (numerator) and date.

{% enddocs %}

{% docs currency %}

Fiat currency in which the balance or transaction amount is expressed. Represents
the target conversion currency, such as BRL, USD, or EUR. Differs from asset when
the holding has been converted from its original denomination.

{% enddocs %}

{% docs exchange_rate %}

Rate of exchange between to assets in a given date defined as "
`exchange rate = exchange asset / asset`" or "`exchange rate = currency / asset`"
(for fiat currency specifically).

{% enddocs %}

{% docs units %}

Quantity of the asset held in the account or transacted on a given date. Represents
the raw number of units before any monetary conversion, such as number of shares,
BTC, or bond units or the monetary value itself for fiat currencies.

{% enddocs %}

<!-- balance related fields -->
{% docs extract_id %}

Unique identifier of an extract taken periodically from accounts for validation
purposes.

{% enddocs %}

{% docs balance_id %}

Unique identifier for the balance record, generated as a deterministic UUID
based on account, asset, currency, and calendar_date. Ensures deduplication
across pipeline runs.

{% enddocs %}

{% docs account %}

Financial account where assets are held. Examples include brokerage accounts,
banks and crypto wallets.

{% enddocs %}

{% docs balance %}

Monetary value of the asset holding in the target currency on the given date.
Calculated as units multiplied by the exchange rate. Represents the fiat value of
the position.

{% enddocs %}

<!-- transaction related fields -->
{% docs transaction_id %}

Unique id of a transaction. It includes income, expenses, asset exchanges,
internal transfers between accounts and projected transactions.

{% enddocs %}

{% docs transaction_type %}

Classification of the financial movement direction. Indicates whether the record
represents an inflow (**Income**), outflow (**Expenses**), exchange of assets
(**Exchange**) or internal transfer between accounts (**Transfer**)

{% enddocs %}

{% docs transaction_description %}

General description of what was the transaction, the merchant or similar information.

{% enddocs %}

{% docs count_to_balance %}

Flag indicating whether this transaction should be included in balance calculations.
When false, the transaction is recorded for temporarily validation purposes only
and does not affect reports.

{% enddocs %}

{% docs amount %}

Value of the transaction or projection in units of the asset transacted. Positive
values represent inflows and negative values represent outflows.

{% enddocs %}

<!-- transaction dimension related fields -->
{% docs category %}

Business category manually assigned to the transaction, used for budget tracking
and reporting. Maps to the category hierarchy defined in the categories seed.

{% enddocs %}

{% docs financial_level_1 %}

Top-level financial classification representing the primary economic nature
of a transaction or holding.

Examples include:

- Essentials
- Discretionary
- Invested
- Uninvested

This level separates broad financial behavior such as spending,
capital allocation, and liquidity status.

{% enddocs %}

{% docs financial_level_2 %}

Secondary financial classification providing a more detailed breakdown
within the top-level financial category.

Examples include:

- Discretionary P
- Discretionary D
- Bonds
- Stocks & Crypto
- Cash
- Work
- Other sources

Typically used to distinguish ownership, investment allocation type,
or source grouping.

{% enddocs %}

{% docs budget_level_1 %}

Top-level budgeting category representing the broad domain or area
associated with a transaction or holding.

Examples include:

- Food
- Health
- Home
- Transport
- Bonds
- Stocks & Crypto
- Work

Used for high-level reporting and aggregation.

{% enddocs %}

{% docs budget_level_2 %}

Intermediate budgeting category used to further segment transactions
within a broader budgeting domain.

Examples include:

- Supermarket
- House bills
- Growth stocks
- Salary
- NFT games

Represents a functional or thematic grouping within a budget category.

{% enddocs %}

{% docs budget_level_3 %}

Most granular budgeting category representing the specific transaction,
asset, product, service, or sub-classification.

Examples include:

- Restaurant
- Rent
- BTC
- USDT
- Salary
- Fuel

Typically used for detailed analysis, reporting, and transaction tagging.

{% enddocs %}

<!-- other dimension related fields -->
<!-- account dimension related fields -->
{% docs account_country %}

Country where the financial account is domiciled. Represents the regulatory
jurisdiction and currency context of the account, such as BR for Brazilian accounts
or US for American accounts.

{% enddocs %}

{% docs account_ownership %}

Budget ownership level of the account. Distinguishes between Personal accounts
(single owner) and Shared accounts (joint ownership), determining how balances are
allocated across individual and household budgets.

{% enddocs %}

{% docs fiat_transaction_id %}

A unique identifier for each fiat transaction record, derived from the original
transaction ID and the currency to which the amount was converted.

{% enddocs %}

{% docs dbt_loaded_at %}

Timestamp of when this row was last processed and written by dbt, set using
`current_timestamp` at run time.

This column reflects dbt pipeline execution time, not when the event occurred in
the source. Use this column to audit data freshness, debug late-arriving
records, or identify when a specific row was last touched by a dbt run.

{% enddocs %}


{% docs simulation_set %}

Identifier for a group of projection scenarios run together. Each simulation set
represents a distinct set of assumptions used to model future financial outcomes,
allowing comparison between different projection runs.

{% enddocs %}

{% docs tax_asset %}

The asset in which taxes were paid for the exchange transaction. May differ from
both the asset and exchange_asset involved in the trade.

{% enddocs %}

{% docs tax_units %}

Same as units, but specifically used on taxes and fees on a exchange operation.

{% enddocs %}

{% docs tax_amount %}

Monetary value of taxes paid on the exchange transaction, denominated in the
tax_asset. Used for capital gains tracking and tax reporting.

{% enddocs %}

{% docs asset_id %}

Unique identifier for a held or transacted asset which includes: fiat, crypto,
bonds, stocks and any other financial holding.

{% enddocs %}

{% docs source_transaction_id %}

Unique identifier for the originating source record for a transaction. Used to trace
canonical transactions back to the original event, file, or system row that
generated the record.

{% enddocs %}

{% docs prev_units %}

Quantity of the asset held in the previous period. Used to compare current and prior
holdings when calculating day-over-day or period-over-period gains.

{% enddocs %}

{% docs exchange_rate_delta %}

Change in the exchange rate between the current and previous period. Represents how
much the exchange rate moved over the comparison window.

{% enddocs %}

{% docs holding_id %}

Unique identifier for the holding record, generated as a deterministic UUID
based on account, asset, and calendar_date. Ensures deduplication across
pipeline runs.

{% enddocs %}

{% docs category_id %}

Unique identifier for the category record, generated as a deterministic UUID based
on the category label. Ensures consistent referencing across models.

{% enddocs %}

{% docs time_grain %}

Period granularity of the aggregated transaction or balance snapshot. Indicates
whether the record represents a day, week, month, quarter, or year-end balance,
allowing analysis at different time scales.

{% enddocs %}

{% docs grain_id %}

Deterministic surrogate key generated from the model's grain columns, used
exclusively to enforce uniqueness and detect duplicate rows in aggregated models.
It does not represent a business identifier and should not be used for joins or
downstream logic.

{% enddocs %}

{% docs absolute_amount %}

Transaction amount normalized to always represent a positive value, regardless of
the original transaction sign convention.

{% enddocs %}

{% docs income %}

Total amount of transactions classified as income for the selected time grain and
currency.

{% enddocs %}

{% docs income_work %}

Portion of total income generated from employment-related sources, including
salary, wages, bonuses, and other work-derived compensation.

{% enddocs %}

{% docs income_investments %}

Portion of total income generated from investment-related sources, including
dividends, interest, capital gains, and other investment returns.

{% enddocs %}

{% docs expenses_essentials %}

Total expenses classified as essential spending, including mandatory or
non-discretionary costs such as housing, utilities, food, transport, and core
obligations.

{% enddocs %}

{% docs expenses_non_essentials %}

Total expenses classified as non-essential spending, including discretionary
purchases, leisure, entertainment, and optional consumption.

{% enddocs %}

{% docs expenses %}

Total expenses across all categories, representing the sum of essential and
non-essential spending for the given time grain and currency.

{% enddocs %}

{% docs savings_rate %}

Proportion of income that is saved rather than spent, calculated as savings
divided by total income.

{% enddocs %}

{% docs essentials_burden_rate %}

Share of total income consumed by essential expenses, indicating the financial
burden of mandatory spending.

{% enddocs %}

{% docs non_essentials_burden_rate %}

Share of total income consumed by non-essential expenses, indicating discretionary
spending intensity relative to income.

{% enddocs %}

{% docs investment_to_work_ratio %}

Ratio of investment income to work-derived income, used to assess reliance on
investment returns versus active employment income.

{% enddocs %}
