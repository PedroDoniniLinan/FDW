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




