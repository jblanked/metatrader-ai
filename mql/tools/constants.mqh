//+------------------------------------------------------------------+
//|                                                    constants.mqh |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict

#include "tool.mqh"

//+------------------------------------------------------------------+
//| Account info tool                                                |
//+------------------------------------------------------------------+
Tool TOOL_ACCOUNT_INFO(
   "get_account_info",
   "Get account information such as balance, equity, margin, etc.",
   NULL
);
//+------------------------------------------------------------------+
//| Parameters for get_bars                                          |
//+------------------------------------------------------------------+
Parameters *toolGetBarsParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",    "string",  "The trading symbol", true));
   p.add(new Property("timeframe", "string",  "The timeframe (e.g. 1 for 1-Minute, 5 for 5-Minute, 15 for 15-Minute, 30 for 30-Minute, 16385 for 1-Hour, 16388 for 4-Hour, 16408 for Daily, 32769 for Weekly, 49153 for Monthly)", true));
   p.add(new Property("from_date", "string",  "Start date", true));
   p.add(new Property("to_date",   "string",  "End date", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get bars tool                                                    |
//+------------------------------------------------------------------+
Tool TOOL_GET_BARS(
   "get_bars",
   "Get rates for a specific symbol, timeframe, and range.",
   toolGetBarsParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_history_position                              |
//+------------------------------------------------------------------+
Parameters *toolHistoryPositionParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("ticket", "integer", "The ticket number of the closed position", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get history position tool                                        |
//+------------------------------------------------------------------+
Tool TOOL_HISTORY_POSITION(
   "get_history_position",
   "Get all deals related to the ticket number of a closed position.",
   toolHistoryPositionParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_history_positions                             |
//+------------------------------------------------------------------+
Parameters *toolHistoryPositionsParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",    "string",  "Filter by symbol (optional)"));
   p.add(new Property("magic",     "integer", "Filter by magic number (optional)"));
   p.add(new Property("from_date", "string",  "Filter from this date (optional)"));
   p.add(new Property("to_date",   "string",  "Filter to this date (optional)"));
   return p;
}

//+------------------------------------------------------------------+
//| Get history positions tool                                       |
//+------------------------------------------------------------------+
Tool TOOL_HISTORY_POSITIONS(
   "get_history_positions",
   "Get historical positions, optionally filtered by symbol, magic number, and date range.",
   toolHistoryPositionsParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_order                                         |
//+------------------------------------------------------------------+
Parameters *toolGetOrderParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("ticket", "integer", "The ticket number of the pending order", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get order tool                                                   |
//+------------------------------------------------------------------+
Tool TOOL_GET_ORDER(
   "get_order",
   "Get a specific pending order by ticket number.",
   toolGetOrderParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_orders                                        |
//+------------------------------------------------------------------+
Parameters *toolGetOrdersParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol", "string", "Filter by symbol (optional)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get orders tool                                                  |
//+------------------------------------------------------------------+
Tool TOOL_GET_ORDERS(
   "get_orders",
   "Get all pending orders, optionally filtered by symbol.",
   toolGetOrdersParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_pip_value                                     |
//+------------------------------------------------------------------+
Parameters *toolGetPipValueParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol", "string", "The trading symbol to get the pip value for", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get pip value tool                                               |
//+------------------------------------------------------------------+
Tool TOOL_GET_PIP_VALUE(
   "get_pip_value",
   "Get the pip value for a specific symbol.",
   toolGetPipValueParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_position                                      |
//+------------------------------------------------------------------+
Parameters *toolGetPositionParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("ticket", "integer", "The ticket number of the open position", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get position tool                                                |
//+------------------------------------------------------------------+
Tool TOOL_GET_POSITION(
   "get_position",
   "Get a specific open position by ticket number.",
   toolGetPositionParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_positions                                     |
//+------------------------------------------------------------------+
Parameters *toolGetPositionsParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol", "string", "Filter by symbol (optional)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get positions tool                                               |
//+------------------------------------------------------------------+
Tool TOOL_GET_POSITIONS(
   "get_positions",
   "Get all open positions, optionally filtered by symbol.",
   toolGetPositionsParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_recent_bars                                   |
//+------------------------------------------------------------------+
Parameters *toolGetRecentBarsParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol",                             true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. 1 for 1-Minute, 5 for 5-Minute, 15 for 15-Minute, 30 for 30-Minute, 16385 for 1-Hour, 16388 for 4-Hour, 16408 for Daily, 32769 for Weekly, 49153 for Monthly)", true));
   p.add(new Property("number_of_bars", "integer", "The number of bars to retrieve",                 true));
   p.add(new Property("shift",          "integer", "The bar index to start from (optional, default 0)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get recent bars tool                                             |
//+------------------------------------------------------------------+
Tool TOOL_GET_RECENT_BARS(
   "get_recent_bars",
   "Get recent OHLCV bars for a specific symbol and timeframe.",
   toolGetRecentBarsParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_risk                                          |
//+------------------------------------------------------------------+
Parameters *toolGetRiskParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",          "string", "The trading symbol",                                true));
   p.add(new Property("percent_risk",    "number", "The percentage of account equity to risk",          true));
   p.add(new Property("stop_loss_pips",  "number", "The stop loss distance in pips",                   true));
   return p;
}
//+------------------------------------------------------------------+
//| Get risk tool                                                    |
//+------------------------------------------------------------------+
Tool TOOL_GET_RISK(
   "get_risk",
   "Calculate the lot size based on a percentage risk and stop loss in pips.",
   toolGetRiskParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_screenshot                                    |
//+------------------------------------------------------------------+
Parameters *toolGetScreenshotParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",    "string", "The trading symbol to retrieve information for", false));
   p.add(new Property("timeframe", "string", "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", false));
   return p;
}
//+------------------------------------------------------------------+
//| Get screenshot tool                                              |
//+------------------------------------------------------------------+
Tool TOOL_GET_SCREENSHOT(
   "get_screenshot",
   "Screenshot a chart, optionally switch to symbol/timeframe.",
   toolGetScreenshotParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_symbol_info                                   |
//+------------------------------------------------------------------+
Parameters *toolGetSymbolInfoParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol", "string", "The trading symbol to retrieve information for", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get symbol info tool                                             |
//+------------------------------------------------------------------+
Tool TOOL_GET_SYMBOL_INFO(
   "get_symbol_info",
   "Get symbol information such as bid, ask, spread, digits, and lot limits.",
   toolGetSymbolInfoParams()
);
//+------------------------------------------------------------------+
//| Parameters for iClose/iDate/iHigh/iLow/iOpen                    |
//+------------------------------------------------------------------+
Parameters *toolIBarParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",    "string",  "The trading symbol",                                                             true));
   p.add(new Property("timeframe", "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("shift",     "integer", "The bar index where 0 is the current bar",                                      true));
   return p;
}
//+------------------------------------------------------------------+
//| iClose tool                                                      |
//+------------------------------------------------------------------+
Tool TOOL_ICLOSE(
   "iClose",
   "Get the close price of a specific historical bar.",
   toolIBarParams()
);
//+------------------------------------------------------------------+
//| iDate tool                                                       |
//+------------------------------------------------------------------+
Tool TOOL_IDATE(
   "iDate",
   "Get the date and time of a specific historical bar.",
   toolIBarParams()
);
//+------------------------------------------------------------------+
//| iHigh tool                                                       |
//+------------------------------------------------------------------+
Tool TOOL_IHIGH(
   "iHigh",
   "Get the high price of a specific historical bar.",
   toolIBarParams()
);
//+------------------------------------------------------------------+
//| iLow tool                                                        |
//+------------------------------------------------------------------+
Tool TOOL_ILOW(
   "iLow",
   "Get the low price of a specific historical bar.",
   toolIBarParams()
);
//+------------------------------------------------------------------+
//| iOpen tool                                                       |
//+------------------------------------------------------------------+
Tool TOOL_IOPEN(
   "iOpen",
   "Get the open price of a specific historical bar.",
   toolIBarParams()
);
//+------------------------------------------------------------------+
//| Parameters for is_order_opened                                   |
//+------------------------------------------------------------------+
Parameters *toolIsOrderOpenedParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol", "string",  "Filter by symbol (optional)"));
   p.add(new Property("magic",  "integer", "Filter by magic number (optional)"));
   return p;
}
//+------------------------------------------------------------------+
//| Is order opened tool                                             |
//+------------------------------------------------------------------+
Tool TOOL_IS_ORDER_OPENED(
   "is_order_opened",
   "Check whether any pending orders are currently open, optionally filtered by symbol and magic number.",
   toolIsOrderOpenedParams()
);
//+------------------------------------------------------------------+
//| Parameters for is_position_opened                                |
//+------------------------------------------------------------------+
Parameters *toolIsPositionOpenedParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol", "string",  "Filter by symbol (optional)"));
   p.add(new Property("magic",  "integer", "Filter by magic number (optional)"));
   return p;
}
//+------------------------------------------------------------------+
//| Is position opened tool                                          |
//+------------------------------------------------------------------+
Tool TOOL_IS_POSITION_OPENED(
   "is_position_opened",
   "Check whether any positions are currently open, optionally filtered by symbol and magic number.",
   toolIsPositionOpenedParams()
);
//+------------------------------------------------------------------+
//| Parameters for order_delete                                      |
//+------------------------------------------------------------------+
Parameters *toolOrderDeleteParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("ticket", "integer", "The ticket number of the pending order to delete", true));
   return p;
}
//+------------------------------------------------------------------+
//| Order delete tool                                                |
//+------------------------------------------------------------------+
Tool TOOL_ORDER_DELETE(
   "order_delete",
   "Delete a pending order by ticket number.",
   toolOrderDeleteParams()
);
//+------------------------------------------------------------------+
//| Parameters for order_send                                        |
//+------------------------------------------------------------------+
Parameters *toolOrderSendParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",      "string",  "The trading symbol",                              true));
   p.add(new Property("type",        "string",  "The order type (e.g. ORDER_TYPE_BUY)",            true));
   p.add(new Property("volume",      "number",  "The lot size",                                    true));
   p.add(new Property("price",       "number",  "The entry price (0 for market order)",            true));
   p.add(new Property("slippage",    "integer", "Maximum allowed slippage in points",              true));
   p.add(new Property("stoploss",    "number",  "Absolute stop loss price (0 to disable)",         true));
   p.add(new Property("takeprofit",  "number",  "Absolute take profit price (0 to disable)",       true));
   p.add(new Property("comment",     "string",  "Order comment (optional)"));
   p.add(new Property("magic",       "integer", "Magic number (optional)"));
   return p;
}
//+------------------------------------------------------------------+
//| Order send tool                                                  |
//+------------------------------------------------------------------+
Tool TOOL_ORDER_SEND(
   "order_send",
   "Send an order using absolute entry, stop loss, and take profit prices.",
   toolOrderSendParams()
);
//+------------------------------------------------------------------+
//| Parameters for order_send_pips                                   |
//+------------------------------------------------------------------+
Parameters *toolOrderSendPipsParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",          "string",  "The trading symbol",                              true));
   p.add(new Property("type",            "string",  "The order type (e.g. ORDER_TYPE_BUY)",            true));
   p.add(new Property("volume",          "number",  "The lot size",                                    true));
   p.add(new Property("price",           "number",  "The entry price (0 for market order)",            true));
   p.add(new Property("slippage",        "integer", "Maximum allowed slippage in points",              true));
   p.add(new Property("stoploss_pips",   "number",  "Stop loss distance in pips",                      true));
   p.add(new Property("takeprofit_pips", "number",  "Take profit distance in pips",                    true));
   p.add(new Property("comment",         "string",  "Order comment (optional)"));
   p.add(new Property("magic",           "integer", "Magic number (optional)"));
   return p;
}
//+------------------------------------------------------------------+
//| Order send pips tool                                             |
//+------------------------------------------------------------------+
Tool TOOL_ORDER_SEND_PIPS(
   "order_send_pips",
   "Send an order using entry price, stop loss, and take profit distances in pips.",
   toolOrderSendPipsParams()
);
//+------------------------------------------------------------------+
//| Parameters for order_modify                                      |
//+------------------------------------------------------------------+
Parameters *toolOrderModifyParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("ticket",      "integer", "The ticket number of the pending order to modify", true));
   p.add(new Property("price",       "number",  "New entry price",                                  true));
   p.add(new Property("stop_loss",   "number",  "New stop loss price",                              true));
   p.add(new Property("take_profit", "number",  "New take profit price",                            true));
   return p;
}
//+------------------------------------------------------------------+
//| Order modify tool                                                |
//+------------------------------------------------------------------+
Tool TOOL_ORDER_MODIFY(
   "order_modify",
   "Modify the price, stop loss, and take profit of an existing pending order.",
   toolOrderModifyParams()
);
//+------------------------------------------------------------------+
//| Parameters for position_close                                    |
//+------------------------------------------------------------------+
Parameters *toolPositionCloseParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("ticket", "integer", "The ticket number of the open position to close", true));
   return p;
}
//+------------------------------------------------------------------+
//| Position close tool                                              |
//+------------------------------------------------------------------+
Tool TOOL_POSITION_CLOSE(
   "position_close",
   "Close an open position by ticket number.",
   toolPositionCloseParams()
);
//+------------------------------------------------------------------+
//| Parameters for position_modify                                   |
//+------------------------------------------------------------------+
Parameters *toolPositionModifyParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",      "string",  "The trading symbol of the position",              true));
   p.add(new Property("ticket",      "integer", "The ticket number of the position to modify",     true));
   p.add(new Property("stop_loss",   "number",  "New stop loss price",                             true));
   p.add(new Property("take_profit", "number",  "New take profit price",                           true));
   return p;
}
//+------------------------------------------------------------------+
//| Position modify tool                                             |
//+------------------------------------------------------------------+
Tool TOOL_POSITION_MODIFY(
   "position_modify",
   "Modify the stop loss and take profit of an existing open position.",
   toolPositionModifyParams()
);
//+------------------------------------------------------------------+
//| Parameters for select_symbol                                     |
//+------------------------------------------------------------------+
Parameters *toolSelectSymbolParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol", "string",  "The trading symbol to enable or disable in Market Watch", true));
   p.add(new Property("enable", "boolean", "True to enable, false to disable (optional, default true)"));
   return p;
}
//+------------------------------------------------------------------+
//| Select symbol tool                                               |
//+------------------------------------------------------------------+
Tool TOOL_SELECT_SYMBOL(
   "select_symbol",
   "Enable or disable a symbol in the Market Watch.",
   toolSelectSymbolParams()
);
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Parameters for get_ma                                            |
//+------------------------------------------------------------------+
Parameters *toolGetMAParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("ma_period",      "integer", "The moving average period", true));
   p.add(new Property("ma_shift",       "integer", "The MA shift", true));
   p.add(new Property("ma_method",      "string",  "The MA method: MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA", true));
   p.add(new Property("applied_price",  "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get MA tool                                                      |
//+------------------------------------------------------------------+
Tool TOOL_GET_MA(
   "get_ma",
   "Get a Moving Average value for a specific symbol, timeframe, and bar.",
   toolGetMAParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_rsi                                           |
//+------------------------------------------------------------------+
Parameters *toolGetRSIParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("rsi_period",     "integer", "The RSI period", true));
   p.add(new Property("applied_price",  "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get RSI tool                                                     |
//+------------------------------------------------------------------+
Tool TOOL_GET_RSI(
   "get_rsi",
   "Get the Relative Strength Index (RSI) value.",
   toolGetRSIParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_atr                                           |
//+------------------------------------------------------------------+
Parameters *toolGetATRParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("atr_period",     "integer", "The ATR period", true));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get ATR tool                                                     |
//+------------------------------------------------------------------+
Tool TOOL_GET_ATR(
   "get_atr",
   "Get the Average True Range (ATR) value.",
   toolGetATRParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_adx                                           |
//+------------------------------------------------------------------+
Parameters *toolGetADXParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("adx_period",     "integer", "The ADX period", true));
   p.add(new Property("applied_price",  "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("adx_mode",       "integer", "ADX mode (0 = main, 1 = plusDI, 2 = minusDI)"));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get ADX tool                                                     |
//+------------------------------------------------------------------+
Tool TOOL_GET_ADX(
   "get_adx",
   "Get the Average Directional Index (ADX) value.",
   toolGetADXParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_custom                                        |
//+------------------------------------------------------------------+
Parameters *toolGetCustomParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",          "string",  "The trading symbol", true));
   p.add(new Property("timeframe",       "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("indicator_name",  "string",  "The custom indicator file name (without path)", true));
   p.add(new Property("buffer",          "integer", "The indicator buffer index", true));
   p.add(new Property("shift",           "integer", "The bar index (0 = current bar)", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get custom tool                                                  |
//+------------------------------------------------------------------+
Tool TOOL_GET_CUSTOM(
   "get_custom",
   "Get a value from a custom indicator.",
   toolGetCustomParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_envelopes                                     |
//+------------------------------------------------------------------+
Parameters *toolGetEnvelopesParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("env_period",     "integer", "The envelopes period", true));
   p.add(new Property("ma_shift",       "integer", "The MA shift", true));
   p.add(new Property("ma_method",      "string",  "The MA method: MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA", true));
   p.add(new Property("applied_price",  "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("deviation",      "number",  "Deviation percentage", true));
   p.add(new Property("env_mode",       "integer", "Envelope mode (0 = upper, 1 = lower)"));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get Envelopes tool                                               |
//+------------------------------------------------------------------+
Tool TOOL_GET_ENVELOPES(
   "get_envelopes",
   "Get an Envelopes indicator value.",
   toolGetEnvelopesParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_fractals                                      |
//+------------------------------------------------------------------+
Parameters *toolGetFractalsParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("fractal_mode",   "integer", "Fractal mode (0 = upper, 1 = lower)"));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get Fractals tool                                                |
//+------------------------------------------------------------------+
Tool TOOL_GET_FRACTALS(
   "get_fractals",
   "Get a Fractals indicator value.",
   toolGetFractalsParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_macd                                          |
//+------------------------------------------------------------------+
Parameters *toolGetMACDParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("fast_period",    "integer", "Fast EMA period", true));
   p.add(new Property("slow_period",    "integer", "Slow EMA period", true));
   p.add(new Property("signal_period",  "integer", "Signal line period", true));
   p.add(new Property("applied_price",  "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("macd_mode",      "integer", "MACD mode (0 = main, 1 = signal)"));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get MACD tool                                                    |
//+------------------------------------------------------------------+
Tool TOOL_GET_MACD(
   "get_macd",
   "Get a MACD indicator value.",
   toolGetMACDParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_ao                                            |
//+------------------------------------------------------------------+
Parameters *toolGetAOParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",    "string",  "The trading symbol", true));
   p.add(new Property("timeframe", "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("shift",     "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get AO tool                                                      |
//+------------------------------------------------------------------+
Tool TOOL_GET_AO(
   "get_ao",
   "Get the Awesome Oscillator value.",
   toolGetAOParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_momentum                                      |
//+------------------------------------------------------------------+
Parameters *toolGetMomentumParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",           "string",  "The trading symbol", true));
   p.add(new Property("timeframe",        "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("momentum_period",  "integer", "The momentum period", true));
   p.add(new Property("applied_price",    "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("shift",            "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get Momentum tool                                                |
//+------------------------------------------------------------------+
Tool TOOL_GET_MOMENTUM(
   "get_momentum",
   "Get the Momentum indicator value.",
   toolGetMomentumParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_wpr                                           |
//+------------------------------------------------------------------+
Parameters *toolGetWPRParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",     "string",  "The trading symbol", true));
   p.add(new Property("timeframe",  "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("wpr_period", "integer", "The WPR period", true));
   p.add(new Property("shift",      "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get WPR tool                                                     |
//+------------------------------------------------------------------+
Tool TOOL_GET_WPR(
   "get_wpr",
   "Get the Williams Percent Range (WPR) value.",
   toolGetWPRParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_bulls_power                                   |
//+------------------------------------------------------------------+
Parameters *toolGetBullsPowerParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("bull_period",    "integer", "The Bulls Power period", true));
   p.add(new Property("applied_price",  "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get Bulls Power tool                                             |
//+------------------------------------------------------------------+
Tool TOOL_GET_BULLS_POWER(
   "get_bulls_power",
   "Get the Bulls Power indicator value.",
   toolGetBullsPowerParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_bears_power                                   |
//+------------------------------------------------------------------+
Parameters *toolGetBearsPowerParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("bear_period",    "integer", "The Bears Power period", true));
   p.add(new Property("applied_price",  "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get Bears Power tool                                             |
//+------------------------------------------------------------------+
Tool TOOL_GET_BEARS_POWER(
   "get_bears_power",
   "Get the Bears Power indicator value.",
   toolGetBearsPowerParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_athr                                          |
//+------------------------------------------------------------------+
Parameters *toolGetATHRParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",    "string",  "The trading symbol", true));
   p.add(new Property("timeframe", "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("shift",     "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get ATHR tool                                                    |
//+------------------------------------------------------------------+
Tool TOOL_GET_ATHR(
   "get_athr",
   "Get the ATHR (composite MA/RSI trend score) value.",
   toolGetATHRParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_stochastic                                    |
//+------------------------------------------------------------------+
Parameters *toolGetStochasticParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("k_period",       "integer", "%K period", true));
   p.add(new Property("d_period",       "integer", "%D period", true));
   p.add(new Property("slow_period",    "integer", "Slow period", true));
   p.add(new Property("ma_method",      "string",  "The MA method: MODE_SMA, MODE_EMA, MODE_SMMA, MODE_LWMA", true));
   p.add(new Property("sto_price",      "string",  "Stochastic price: STO_LOWHIGH, STO_CLOSECLOSE", true));
   p.add(new Property("stoch_mode",     "integer", "Stochastic mode (0 = main, 1 = signal)"));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get Stochastic tool                                              |
//+------------------------------------------------------------------+
Tool TOOL_GET_STOCHASTIC(
   "get_stochastic",
   "Get the Stochastic Oscillator value.",
   toolGetStochasticParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_cci                                           |
//+------------------------------------------------------------------+
Parameters *toolGetCCIParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",         "string",  "The trading symbol", true));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("cci_period",     "integer", "The CCI period", true));
   p.add(new Property("applied_price",  "string",  "Applied price: PRICE_CLOSE, PRICE_OPEN, PRICE_HIGH, PRICE_LOW, PRICE_MEDIAN, PRICE_TYPICAL, PRICE_WEIGHTED", true));
   p.add(new Property("shift",          "integer", "The bar index (0 = current bar)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get CCI tool                                                     |
//+------------------------------------------------------------------+
Tool TOOL_GET_CCI(
   "get_cci",
   "Get the Commodity Channel Index (CCI) value.",
   toolGetCCIParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_adr                                           |
//+------------------------------------------------------------------+
Parameters *toolGetADRParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",     "string",  "The trading symbol", true));
   p.add(new Property("adr_period", "integer", "The ADR period (in days)", true));
   p.add(new Property("shift",      "integer", "The bar index (0 = current bar)", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get ADR tool                                                     |
//+------------------------------------------------------------------+
Tool TOOL_GET_ADR(
   "get_adr",
   "Get the Average Daily Range (ADR) value.",
   toolGetADRParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_vwap                                          |
//+------------------------------------------------------------------+
Parameters *toolGetVWAPParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",      "string",  "The trading symbol", true));
   p.add(new Property("timeframe",   "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("vwap_period", "integer", "The VWAP period", true));
   p.add(new Property("shift",       "integer", "The bar index (0 = current bar)", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get VWAP tool                                                    |
//+------------------------------------------------------------------+
Tool TOOL_GET_VWAP(
   "get_vwap",
   "Get the Volume Weighted Average Price (VWAP) value.",
   toolGetVWAPParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_pvi                                           |
//+------------------------------------------------------------------+
Parameters *toolGetPVIParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",      "string",  "The trading symbol", true));
   p.add(new Property("timeframe",   "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   p.add(new Property("volume_type", "string",  "Volume type: VOLUME_TICK or VOLUME_REAL", true));
   p.add(new Property("shift",       "integer", "The bar index (0 = current bar)", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get PVI tool                                                     |
//+------------------------------------------------------------------+
Tool TOOL_GET_PVI(
   "get_pvi",
   "Get the Positive Volume Index (PVI) value.",
   toolGetPVIParams()
);
//+------------------------------------------------------------------+
//| Parameters for file_copy                                         |
//+------------------------------------------------------------------+
Parameters *toolFileCopyParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("src",  "string", "Source file path", true));
   p.add(new Property("dest", "string", "Destination file path", true));
   return p;
}
//+------------------------------------------------------------------+
//| File copy tool                                                   |
//+------------------------------------------------------------------+
Tool TOOL_FILE_COPY(
   "file_copy",
   "Copy a file from source to destination.",
   toolFileCopyParams()
);
//+------------------------------------------------------------------+
//| Parameters for file_delete                                       |
//+------------------------------------------------------------------+
Parameters *toolFileDeleteParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("path", "string", "File path to delete", true));
   return p;
}
//+------------------------------------------------------------------+
//| File delete tool                                                 |
//+------------------------------------------------------------------+
Tool TOOL_FILE_DELETE(
   "file_delete",
   "Delete a file by path.",
   toolFileDeleteParams()
);
//+------------------------------------------------------------------+
//| Parameters for file_exists                                       |
//+------------------------------------------------------------------+
Parameters *toolFileExistsParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("path", "string", "File path to check", true));
   return p;
}
//+------------------------------------------------------------------+
//| File exists tool                                                 |
//+------------------------------------------------------------------+
Tool TOOL_FILE_EXISTS(
   "file_exists",
   "Check if a file exists at the specified path.",
   toolFileExistsParams()
);
//+------------------------------------------------------------------+
//| Parameters for file_move                                         |
//+------------------------------------------------------------------+
Parameters *toolFileMoveParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("src",  "string", "Source file path", true));
   p.add(new Property("dest", "string", "Destination file path", true));
   return p;
}
//+------------------------------------------------------------------+
//| File move tool                                                   |
//+------------------------------------------------------------------+
Tool TOOL_FILE_MOVE(
   "file_move",
   "Move a file from source to destination.",
   toolFileMoveParams()
);
//+------------------------------------------------------------------+
//| Parameters for file_read                                         |
//+------------------------------------------------------------------+
Parameters *toolFileReadParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("path", "string", "File path to read", true));
   return p;
}
//+------------------------------------------------------------------+
//| File read tool                                                   |
//+------------------------------------------------------------------+
Tool TOOL_FILE_READ(
   "file_read",
   "Read the contents of a file.",
   toolFileReadParams()
);
//+------------------------------------------------------------------+
//| Parameters for file_write                                        |
//+------------------------------------------------------------------+
Parameters *toolFileWriteParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("path",      "string",  "File path to write to (must be a full path, including drive and directories)", true));
   p.add(new Property("index",     "integer", "Byte offset to start writing", true));
   p.add(new Property("overwrite", "boolean", "Whether to overwrite if file exists", true));
   p.add(new Property("content",   "string",  "Content to write to the file. Must escape quotes", true));
   return p;
}
//+------------------------------------------------------------------+
//| File write tool                                                  |
//+------------------------------------------------------------------+
Tool TOOL_FILE_WRITE(
   "file_write",
   "Write content to a file.",
   toolFileWriteParams()
);
//+------------------------------------------------------------------+
//| Parameters for file_list                                         |
//+------------------------------------------------------------------+
Parameters *toolFileListParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("folder",    "string",  "Folder path to list files from (must be a full path, including drive and directories)", true));
   p.add(new Property("key",       "string",  "Optional filter: only list files whose name contains this key", false));
   p.add(new Property("ext",       "string",  "Optional filter: only list files with this extension (e.g. \"mqh\" or \".mqh\")", false));
   p.add(new Property("recursive", "boolean", "Whether to list files in subfolders too", false));
   return p;
}
//+------------------------------------------------------------------+
//| File list tool                                                   |
//+------------------------------------------------------------------+
Tool TOOL_FILE_LIST(
   "file_list",
   "List files in a folder, optionally matching a name key and/or extension.",
   toolFileListParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_terminal_info                                 |
//+------------------------------------------------------------------+
Parameters *toolGetTerminalInfoParams(void)
{
   Parameters *p = new Parameters();
   return p;
}
//+------------------------------------------------------------------+
//| Get terminal info tool                                           |
//+------------------------------------------------------------------+
Tool TOOL_GET_TERMINAL_INFO(
   "get_terminal_info",
   "Get information about the current MetaTrader terminal (OS, CPU, memory, build, connection status, etc.).",
   toolGetTerminalInfoParams()
);
//+------------------------------------------------------------------+
//| Parameters for chart_close                                       |
//+------------------------------------------------------------------+
Parameters *toolChartCloseParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("chart_id", "integer", "Chart ID to close (optional, 0 = current chart)"));
   return p;
}
//+------------------------------------------------------------------+
//| Chart close tool                                                 |
//+------------------------------------------------------------------+
Tool TOOL_CHART_CLOSE(
   "chart_close",
   "Close a chart by chart ID.",
   toolChartCloseParams()
);
//+------------------------------------------------------------------+
//| Parameters for chart_open                                        |
//+------------------------------------------------------------------+
Parameters *toolChartOpenParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("symbol",    "string", "The trading symbol", true));
   p.add(new Property("timeframe", "string", "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1)", true));
   return p;
}
//+------------------------------------------------------------------+
//| Chart open tool                                                  |
//+------------------------------------------------------------------+
Tool TOOL_CHART_OPEN(
   "chart_open",
   "Open a new chart for a symbol and timeframe.",
   toolChartOpenParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_chart_info                                    |
//+------------------------------------------------------------------+
Parameters *toolGetChartInfoParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("chart_id", "integer", "Chart ID to query (optional, 0 = current chart)"));
   return p;
}
//+------------------------------------------------------------------+
//| Get chart info tool                                              |
//+------------------------------------------------------------------+
Tool TOOL_GET_CHART_INFO(
   "get_chart_info",
   "Get detailed information about a chart including windows, indicators, prices, and dimensions.",
   toolGetChartInfoParams()
);
//+------------------------------------------------------------------+
//| Parameters for get_chart_indicator                               |
//+------------------------------------------------------------------+
Parameters *toolGetChartIndicatorParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("indicator_name", "string", "The indicator name to find on the chart", true));
   return p;
}
//+------------------------------------------------------------------+
//| Get chart indicator tool                                         |
//+------------------------------------------------------------------+
Tool TOOL_GET_CHART_INDICATOR(
   "get_chart_indicator",
   "Find an indicator on the chart and return its details (name, handle, window).",
   toolGetChartIndicatorParams()
);
//+------------------------------------------------------------------+
//| Parameters for remove_chart_indicator                            |
//+------------------------------------------------------------------+
Parameters *toolRemoveChartIndicatorParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("indicator_name", "string",  "The indicator name to remove", true));
   p.add(new Property("chart_id",       "integer", "Chart ID (optional, 0 = current chart)"));
   p.add(new Property("sub_window",     "integer", "Sub-window index (optional, default 0)"));
   return p;
}
//+------------------------------------------------------------------+
//| Remove chart indicator tool                                      |
//+------------------------------------------------------------------+
Tool TOOL_REMOVE_CHART_INDICATOR(
   "remove_chart_indicator",
   "Remove an indicator from the chart.",
   toolRemoveChartIndicatorParams()
);
//+------------------------------------------------------------------+
//| Parameters for compile_mql5                                      |
//+------------------------------------------------------------------+
Parameters *toolCompileMql5Params(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("mq5_path", "string", "The full path to the .mq5 file to compile", true));
   return p;
}
//+------------------------------------------------------------------+
//| MQL5 Compile tool                                                |
//+------------------------------------------------------------------+
Tool TOOL_COMPILE_MQL5(
   "compile_mql5",
   "Compile an MQL5 file and return the log output.",
   toolCompileMql5Params()
);
//+------------------------------------------------------------------+
//| Parameters for backtest_single                                   |
//+------------------------------------------------------------------+
Parameters *toolBacktestSingleParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("name",           "string",  "The expert advisor name (e.g. Experts\\MyExpert.ex5), must start with 'Experts\\' and end with '.ex5'", true));
   p.add(new Property("symbol",         "string",  "The trading symbol to test (e.g. EURUSD), default is current symbol", false));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1), default is PERIOD_CURRENT", false));
   p.add(new Property("from_date",      "string",  "Backtest start date (default is start of current month)", false));
   p.add(new Property("to_date",        "string",  "Backtest end date (default is current datetime)", false));
   p.add(new Property("deposit",        "number",  "Starting deposit amount (default is account equity)", false));
   p.add(new Property("expert_params",  "string",  "JSON array of expert parameter objects with key, value, and type fields (e.g. [{\"key\":\"TakeProfit\",\"value\":\"50\",\"type\":\"int\"}])", false));
   return p;
}
//+------------------------------------------------------------------+
//| Backtest single tool                                             |
//+------------------------------------------------------------------+
Tool TOOL_BACKTEST_SINGLE(
   "backtest_single",
   "Run a single backtest in the strategy tester with the specified expert advisor, symbol, timeframe, date range, deposit, and expert parameters.",
   toolBacktestSingleParams()
);
//+------------------------------------------------------------------+
//| Parameters for backtest_optimization                             |
//+------------------------------------------------------------------+
Parameters *toolBacktestOptimizationParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("name",           "string",  "The expert advisor name (e.g. Experts\\MyExpert.ex5), must start with 'Experts\\' and end with '.ex5'", true));
   p.add(new Property("optimization_params", "string", "JSON array of optimization parameter objects with key, value, start_value, step_value, stop_value, checked (bool), and type fields (e.g. [{\"key\":\"TakeProfit\",\"value\":\"50\",\"start_value\":\"10\",\"step_value\":\"10\",\"stop_value\":\"100\",\"checked\":true,\"type\":\"int\"}])", true));
   p.add(new Property("symbol",         "string",  "The trading symbol to test (e.g. EURUSD), default is current symbol", false));
   p.add(new Property("timeframe",      "string",  "The timeframe (e.g. PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1), default is PERIOD_CURRENT", false));
   p.add(new Property("from_date",      "string",  "Backtest start date (default is start of current month)", false));
   p.add(new Property("to_date",        "string",  "Backtest end date (default is current datetime)", false));
   p.add(new Property("deposit",        "number",  "Starting deposit amount (default is account equity)", false));
   return p;
}
//+------------------------------------------------------------------+
//| Backtest optimization tool                                       |
//+------------------------------------------------------------------+
Tool TOOL_BACKTEST_OPTIMIZATION(
   "backtest_optimization",
   "Run a backtest optimization in the strategy tester with the specified expert advisor, symbol, timeframe, date range, deposit, and optimization parameters (with start/step/stop ranges).",
   toolBacktestOptimizationParams()
);
//+------------------------------------------------------------------+
//| Parameters for context_read                                      |
//+------------------------------------------------------------------+
Parameters *toolContextReadParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("path", "string", "The context file path to read (e.g. 'context\\mql.md', 'context\\builder\\style.md')", true));
   return p;
}
//+------------------------------------------------------------------+
//| Context read tool                                                |
//+------------------------------------------------------------------+
Tool TOOL_CONTEXT_READ(
   "context_read",
   "Read a context file by path and return its contents. Supports both embedded resources (MQL5) and file-system reads (MQL4).",
   toolContextReadParams()
);
//+------------------------------------------------------------------+
