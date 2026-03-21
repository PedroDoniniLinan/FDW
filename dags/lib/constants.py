# DB Update

sheets = {
    'balances': {'id': '1_RPrgDE-LK49RKtc1hWCnPpje24z7lbznhCfrW616l0', 'range': '_!A1:D'},
    'income': {'id': '1bS9NlfrVnA9R59KaChFR0CxiTEjhDnlgLMoMxtjz2g0', 'range': '_!A1:G'},
    'expenses': {'id': '1zNnxMx6toBnR_pRQu-sQ4WfebYvb0tAi4JXcSfxPibQ', 'range': 'main!A1:G'},
    'exchanges': {'id': '1lNXv7gXmlyft__u4srmpGiLNB_2ugklyJzMDO9vXfZc', 'range': '_!A1:J'},
    'transfers': {'id': '1S9tntlczTip-XLXM3jbFVy8nYioUJp_Hld1pZj8XxRQ', 'range': '_!A1:F'},
    'prices': {'id': '1ysBFniA7Q0fX8viYaLD7x214HfiIB8e1CHBHjUq0rEA', 'range': '_!A1:DA'},
    'projections': {'id': '1Cr8Br53t1wU1EUNEkyKQhAan30iGFzPRbVBDj1veARo', 'range': '_!A1:F'}
}

db = {
    'balances': {'table': 'bronze.balances'},
    'income': {'table': 'bronze.external_transactions'},
    'expenses': {'table': 'bronze.external_transactions'},
    'exchanges': {'table': 'bronze.exchanges'},
    'prices': {'table': 'bronze.prices'},
    'transfers': {'table': 'bronze.transfers'},
    'projections': {'table': 'bronze.projections'}
}
