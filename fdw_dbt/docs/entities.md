<!-- general fields -->
{% docs calendar_date %}
Date of the record in calendar terms. Represents the day the event occurred or the snapshot was taken.
{% enddocs %}

<!-- asset related fields -->
{% docs asset_id %}
Unique identifier for a held or transacted asset which includes: fiat, crypto, bonds, stocks and any other financial holding.
{% enddocs %}

{% docs asset %}
Asset name, ticker, acronym or key information.
{% enddocs %}

{% docs exchange_asset %}
Asset associated with an exchange rate with another asset. The exchange asset is the numerator of the rate.
{% enddocs %}

{% docs rate_id %}
Unique identifier of an exchange rate defined by the asset (denominator), exchange asset/currenncy (numerator) and date.
{% enddocs %}

{% docs tax_asset %}
The asset in which taxes were paid for the exchange transaction. May differ from both the asset and exchange_asset involved in the trade.
{% enddocs %}

<!-- balance related fields -->
{% docs extract_id %}
Unique identifier of an extract taken periodically from accounts for validation purposes.
{% enddocs %}

{% docs holding_id %}
Unique identifier of a holding defined by an unique combination of an account and an asset in a given date.
{% enddocs %}

{% docs balance_id %}
Unique identifier of a balance defined by an unique combination of an account, an asset and a fiat currency in a given date.
{% enddocs %}

{% docs account %}
Financial account where assets are held. Examples include brokerage accounts, banks and crypto wallets.
{% enddocs %}

<!-- transaction related fields -->

{% docs transaction_id %}
Unique id of a transaction. It includes income, expenses, asset exchanges, internal transfers between accounts and projected transactions.
{% enddocs %}

{% docs transaction_type %}
Classification of the financial movement direction. Indicates whether the record represents an inflow (**Income**), outflow (**Expenses**), exchange of assets (**Exchange**) or internal transfer between accounts (**Transfer**)
{% enddocs %}

<!-- projection related fields -->

{% docs simulation_set %}
Identifier for a group of projection scenarios run together. Each simulation set represents a distinct set of assumptions used to model future financial outcomes, allowing comparison between different projection runs.
{% enddocs %}

{% docs budget_level %}
Top level budget classification for the transaction or projection. Represents the highest grouping in the budget hierarchy, used to organize financial planning across different ownerships.
{% enddocs %}

{% docs level_1%}
First level of the category hierarchy below budget_level. Provides a more granular grouping of transactions or projections within a budget level, such as Income source (Salary, Growth stocks, etc) or Expense category (Home, Food, etc).
{% enddocs %}

{% docs amount %}
Value of the transaction or projection in units of the asset transacted. Positive values represent inflows and negative values represent outflows.
{% enddocs %}

{% docs transaction description %}
General description of what was the transaction, the merchant or similar information.
{% enddocs %}

{% docs category %}
Business category assigned to the transaction, used for budget tracking and reporting. Maps to the category hierarchy defined in the categories seed.
{% enddocs %}

{% docs count_to_balance %}
Flag indicating whether this transaction should be included in balance calculations. When false, the transaction is recorded for temporarily validation purposes only and does not affect reports.
{% enddocs %}

{% docs tax_amount %}
Monetary value of taxes paid on the exchange transaction, denominated in the tax_asset. Used for capital gains tracking and tax reporting.
{% enddocs %}