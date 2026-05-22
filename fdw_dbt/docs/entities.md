<!-- general fields -->
{% docs calendar_date %}
Date of the record in calendar terms. Represents the day the event occurred or the snapshot was taken.
{% enddocs %}

{% docs is_end_of_period %}
Flag indicating whether the date represents the last day of a calendar period. Contains the period type as a concatenated string, such as day, dayweek, daymonth, or dayyear, allowing filtering by any period granularity.
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

{% docs currency %}
Fiat currency in which the balance or transaction amount is expressed. Represents the target conversion currency, such as BRL, USD, or EUR. Differs from asset when the holding has been converted from its original denomination.
{% enddocs %}

<!-- balance related fields -->
{% docs extract_id %}
Unique identifier of an extract taken periodically from accounts for validation purposes.
{% enddocs %}

{% docs holding_id %}
Unique identifier for the holding record, generated as a deterministic UUID based on account, asset, and calendar_date. Ensures deduplication across pipeline runs.
{% enddocs %}

{% docs balance_id %}
Unique identifier for the balance record, generated as a deterministic UUID based on account, asset, currency, and calendar_date. Ensures deduplication across pipeline runs.
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

{% docs transaction_description %}
General description of what was the transaction, the merchant or similar information.
{% enddocs %}

{% docs count_to_balance %}
Flag indicating whether this transaction should be included in balance calculations. When false, the transaction is recorded for temporarily validation purposes only and does not affect reports.
{% enddocs %}

<!-- transaction category related fields -->

{% docs category_id %}
Unique identifier for the category record, generated as a deterministic UUID based on the category label. Ensures consistent referencing across models.
{% enddocs %}

{% docs category %}
Business category manually assigned to the transaction, used for budget tracking and reporting. Maps to the category hierarchy defined in the categories seed.
{% enddocs %}

{% docs source %}
Origin or frequency context of the category. Indicates how the category is sourced or how often it applies, such as Fixed, Variable, or Monthly.
{% enddocs %}

{% docs budget_level %}
Top level budget classification for the transaction or transaction projection. Used to organize financial planning across different ownerships.
{% enddocs %}

{% docs level_1%}
First level of the category hierarchy. Provides a broad grouping of transactions or projections, such as Income source (Salary, Growth stocks, etc) or Expense category (Home, Food, etc).
{% enddocs %}

{% docs level_2 %}
Second level of the category hierarchy below level_1. Provides further granularity within a category grouping, such as a specific expense subcategory or investment product type.
{% enddocs %}

{% docs level_3 %}
Third and most granular level of the category hierarchy. Represents the most specific classification within the budget structure, such as a specific bond type like TD CDI or CDB IPCA and very specific expense types.
{% enddocs %}

<!-- projection related fields -->

{% docs simulation_set %}
Identifier for a group of projection scenarios run together. Each simulation set represents a distinct set of assumptions used to model future financial outcomes, allowing comparison between different projection runs.
{% enddocs %}
