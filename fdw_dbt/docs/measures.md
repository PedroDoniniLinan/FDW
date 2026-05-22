<!-- asset related fields -->
{% docs exchange_rate %}
Rate of exchange between to assets in a given date defined as "`exchange rate = exchange asset / asset`" or "`exchange rate = currency / asset`" (for fiat currency specifically).
{% enddocs %}

{% docs units %}
Quantity of the asset held in the account on the given date. Represents the raw number of units before any monetary conversion, such as number of shares, BTC, or bond units or the monetary value itself for fiat currencies.
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