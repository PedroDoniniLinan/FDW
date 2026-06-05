{%- macro window_truncate_pre_hook(date_column, lookback_days) -%}
    {%- set hook = "{%- if adapter.get_relation(this.database, this.schema, this.identifier) -%}"
        ~ "delete from {{ this }} where calendar_date > (select max(" ~ date_column ~ ") - interval '" ~ lookback_days ~ " days' from {{ this }})"
        ~ "{%- endif -%}"
    -%}
    {{ return(hook) }}
{%- endmacro -%}