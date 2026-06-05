<!-- asset related fields -->
{% docs exchange_rate %}
Rate of exchange between to assets in a given date defined as "`exchange rate = exchange asset / asset`" or "`exchange rate = currency / asset`" (for fiat currency specifically).
{% enddocs %}

{% docs units %}
Quantity of the asset held in the account or transacted on a given date. Represents the raw number of units before any monetary conversion, such as number of shares, BTC, or bond units or the monetary value itself for fiat currencies.
{% enddocs %}

<!-- balance related fields -->
{% docs balance %}
Monetary value of the asset holding in the target currency on the given date. Calculated as units multiplied by the exchange rate. Represents the fiat value of the position.
{% enddocs %}

<!-- transaction related fields -->

{% docs amount %}
Value of the transaction or projection in units of the asset transacted. Positive values represent inflows and negative values represent outflows.
{% enddocs %}

{% docs tax_amount %}
Monetary value of taxes paid on the exchange transaction, denominated in the tax_asset. Used for capital gains tracking and tax reporting.
{% enddocs %}

{% docs tax_units %}
Same as units, but specifically used on taxes and fees on a exchange operation.
{% enddocs %}

{% docs absolute_amount %}
Transaction amount normalized to always represent a positive value, regardless of the original transaction sign convention.
{% enddocs %}

{% docs income %}
Total amount of transactions classified as income for the selected time grain and currency.
{% enddocs %}

{% docs income_work %}
Portion of total income generated from employment-related sources, including salary, wages, bonuses, and other work-derived compensation.
{% enddocs %}

{% docs income_investments %}
Portion of total income generated from investment-related sources, including dividends, interest, capital gains, and other investment returns.
{% enddocs %}

{% docs expenses_essentials %}
Total expenses classified as essential spending, including mandatory or non-discretionary costs such as housing, utilities, food, transport, and core obligations.
{% enddocs %}

{% docs expenses_non_essentials %}
Total expenses classified as non-essential spending, including discretionary purchases, leisure, entertainment, and optional consumption.
{% enddocs %}

{% docs expenses %}
Total expenses across all categories, representing the sum of essential and non-essential spending for the given time grain and currency.
{% enddocs %}

{% docs savings_rate %}
Proportion of income that is saved rather than spent, calculated as savings divided by total income.
{% enddocs %}

{% docs essentials_burden_rate %}
Share of total income consumed by essential expenses, indicating the financial burden of mandatory spending.
{% enddocs %}

{% docs non_essentials_burden_rate %}
Share of total income consumed by non-essential expenses, indicating discretionary spending intensity relative to income.
{% enddocs %}

{% docs investment_to_work_ratio %}
Ratio of investment income to work-derived income, used to assess reliance on investment returns versus active employment income.
{% enddocs %}
