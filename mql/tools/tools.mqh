//+------------------------------------------------------------------+
//|                                                        tools.mqh |
//|                                      Copyright 2026,JBlanked LLC |
//|                                         https://www.jblanked.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked LLC"
#property link      "https://www.jblanked.com"
#property strict
#include "backtesting.mqh"
#include "constants.mqh"
#include "mt5.mqh"
#include "compile.mqh"
#include "tool.mqh"
#include "context.mqh"
#include "indicators.mqh"
#include "file.mqh"
#include "terminal.mqh"
#include "chart.mqh"

#define BOOL_TO_STRING(value) ((value) ? "true" : "false")

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES StringToTimeframe(string tf)
{
   if (tf == "PERIOD_M1")  return PERIOD_M1;
   if (tf == "PERIOD_M2")  return PERIOD_M2;
   if (tf == "PERIOD_M3")  return PERIOD_M3;
   if (tf == "PERIOD_M4")  return PERIOD_M4;
   if (tf == "PERIOD_M5")  return PERIOD_M5;
   if (tf == "PERIOD_M6")  return PERIOD_M6;
   if (tf == "PERIOD_M10") return PERIOD_M10;
   if (tf == "PERIOD_M15") return PERIOD_M15;
   if (tf == "PERIOD_M20") return PERIOD_M20;
   if (tf == "PERIOD_M30") return PERIOD_M30;
   if (tf == "PERIOD_H1")  return PERIOD_H1;
   if (tf == "PERIOD_H2")  return PERIOD_H2;
   if (tf == "PERIOD_H4")  return PERIOD_H4;
   if (tf == "PERIOD_H8")  return PERIOD_H8;
   if (tf == "PERIOD_H12") return PERIOD_H12;
   if (tf == "PERIOD_D1")  return PERIOD_D1;
   if (tf == "PERIOD_W1")  return PERIOD_W1;
   if (tf == "PERIOD_MN1") return PERIOD_MN1;
   return PERIOD_CURRENT;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE StringToOrderType(string t)
{
   if (t == "ORDER_TYPE_BUY")        return ORDER_TYPE_BUY;
   if (t == "ORDER_TYPE_SELL")       return ORDER_TYPE_SELL;
   if (t == "ORDER_TYPE_BUY_LIMIT")  return ORDER_TYPE_BUY_LIMIT;
   if (t == "ORDER_TYPE_SELL_LIMIT") return ORDER_TYPE_SELL_LIMIT;
   if (t == "ORDER_TYPE_BUY_STOP")   return ORDER_TYPE_BUY_STOP;
   return ORDER_TYPE_SELL_STOP;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int StringToAppliedPrice(string p)
{
   if (p == "PRICE_CLOSE")    return PRICE_CLOSE;
   if (p == "PRICE_OPEN")     return PRICE_OPEN;
   if (p == "PRICE_HIGH")     return PRICE_HIGH;
   if (p == "PRICE_LOW")      return PRICE_LOW;
   if (p == "PRICE_MEDIAN")   return PRICE_MEDIAN;
   if (p == "PRICE_TYPICAL")  return PRICE_TYPICAL;
   if (p == "PRICE_WEIGHTED") return PRICE_WEIGHTED;
   return PRICE_CLOSE;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_MA_METHOD StringToMAMethod(string m)
{
   if (m == "MODE_SMA")  return MODE_SMA;
   if (m == "MODE_EMA")  return MODE_EMA;
   if (m == "MODE_SMMA") return MODE_SMMA;
   if (m == "MODE_LWMA") return MODE_LWMA;
   return MODE_SMA;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_STO_PRICE StringToStoPrice(string p)
{
   if (p == "STO_LOWHIGH")    return STO_LOWHIGH;
   if (p == "STO_CLOSECLOSE") return STO_CLOSECLOSE;
   return STO_LOWHIGH;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_APPLIED_VOLUME StringToVolumeType(string v)
{
#ifdef __MQL4__
   if (v == "VOLUME_TICK") return VOLUME_TICK;
   if (v == "VOLUME_REAL") return VOLUME_REAL;
   return VOLUME_TICK;
#else
   if (v == "VOLUME_TICK") return VOLUME_TICK;
   if (v == "VOLUME_REAL") return VOLUME_REAL;
   return VOLUME_TICK;
#endif
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetAccountInfo : public Tool
{
public:
   ToolGetAccountInfo() : Tool("get_account_info", "Get account information such as balance, equity, margin, etc.", NULL) {}
   virtual string execute(CJAVal &json) override
   {
      return getAccountInfo();
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetBars : public Tool
{
public:
   ToolGetBars() : Tool("get_bars", "Get rates for a specific symbol, timeframe, and range.", toolGetBarsParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getBars(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (datetime)StringToTime(json["from_date"].ToStr()),
                (datetime)StringToTime(json["to_date"].ToStr())
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetHistoryPosition : public Tool
{
public:
   ToolGetHistoryPosition() : Tool("get_history_position", "Get all deals related to the ticket number of a closed position.", toolHistoryPositionParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getHistoryPosition((ulong)json["ticket"].ToInt());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetHistoryPositions : public Tool
{
public:
   ToolGetHistoryPositions() : Tool("get_history_positions", "Get historical positions, optionally filtered.", toolHistoryPositionsParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getHistoryPositions(
                json["symbol"].ToStr(),
                json["magic"].ToInt(),
                (datetime)StringToTime(json["from_date"].ToStr()),
                (datetime)StringToTime(json["to_date"].ToStr())
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetOrder : public Tool
{
public:
   ToolGetOrder() : Tool("get_order", "Get a specific pending order by ticket number.", toolGetOrderParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getOrder((ulong)json["ticket"].ToInt());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetOrders : public Tool
{
public:
   ToolGetOrders() : Tool("get_orders", "Get all pending orders, optionally filtered by symbol.", toolGetOrdersParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getOrders(json["symbol"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetPipValue : public Tool
{
public:
   ToolGetPipValue() : Tool("get_pip_value", "Get the pip value for a specific symbol.", toolGetPipValueParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return DoubleToString(getPipValue(json["symbol"].ToStr()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetPosition : public Tool
{
public:
   ToolGetPosition() : Tool("get_position", "Get a specific open position by ticket number.", toolGetPositionParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getPosition((ulong)json["ticket"].ToInt());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetPositions : public Tool
{
public:
   ToolGetPositions() : Tool("get_positions", "Get all open positions, optionally filtered by symbol.", toolGetPositionsParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getPositions(json["symbol"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetRecentBars : public Tool
{
public:
   ToolGetRecentBars() : Tool("get_recent_bars", "Get recent OHLCV bars for a specific symbol and timeframe.", toolGetRecentBarsParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getRecentBars(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["number_of_bars"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetRisk : public Tool
{
public:
   ToolGetRisk() : Tool("get_risk", "Calculate the lot size based on a percentage risk and stop loss in pips.", toolGetRiskParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return DoubleToString(getRisk(json["symbol"].ToStr(), json["percent_risk"].ToDbl(), json["stop_loss_pips"].ToDbl()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetScreenshot : public Tool
{
public:
   ToolGetScreenshot() : Tool("get_screenshot", "Screenshot a chart, optionally switch to symbol/timeframe first.", toolGetScreenshotParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getScreenshot(json["symbol"].ToStr(), StringToTimeframe(json["timeframe"].ToStr()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetSymbolInfo : public Tool
{
public:
   ToolGetSymbolInfo() : Tool("get_symbol_info", "Get symbol information such as bid, ask, spread, etc.", toolGetSymbolInfoParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getSymbolInfo(json["symbol"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolIClose : public Tool
{
public:
   ToolIClose() : Tool("iClose", "Get the close price of a specific historical bar.", toolIBarParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return DoubleToString(iClose(json["symbol"].ToStr(), StringToTimeframe(json["timeframe"].ToStr()), (int)json["shift"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolIDate : public Tool
{
public:
   ToolIDate() : Tool("iDate", "Get the date and time of a specific historical bar.", toolIBarParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return TimeToString(iTime(json["symbol"].ToStr(), StringToTimeframe(json["timeframe"].ToStr()), (int)json["shift"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolIHigh : public Tool
{
public:
   ToolIHigh() : Tool("iHigh", "Get the high price of a specific historical bar.", toolIBarParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return DoubleToString(iHigh(json["symbol"].ToStr(), StringToTimeframe(json["timeframe"].ToStr()), (int)json["shift"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolILow : public Tool
{
public:
   ToolILow() : Tool("iLow", "Get the low price of a specific historical bar.", toolIBarParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return DoubleToString(iLow(json["symbol"].ToStr(), StringToTimeframe(json["timeframe"].ToStr()), (int)json["shift"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolIOpen : public Tool
{
public:
   ToolIOpen() : Tool("iOpen", "Get the open price of a specific historical bar.", toolIBarParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return DoubleToString(iOpen(json["symbol"].ToStr(), StringToTimeframe(json["timeframe"].ToStr()), (int)json["shift"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolIsOrderOpened : public Tool
{
public:
   ToolIsOrderOpened() : Tool("is_order_opened", "Check whether any pending orders are open.", toolIsOrderOpenedParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return BOOL_TO_STRING(isOrderOpened(json["symbol"].ToStr(), json["magic"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolIsPositionOpened : public Tool
{
public:
   ToolIsPositionOpened() : Tool("is_position_opened", "Check whether any positions are currently open.", toolIsPositionOpenedParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return BOOL_TO_STRING(isPositionOpened(json["symbol"].ToStr(), json["magic"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolOrderDelete : public Tool
{
public:
   ToolOrderDelete() : Tool("order_delete", "Delete a pending order by ticket number.", toolOrderDeleteParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return BOOL_TO_STRING(orderDelete((ulong)json["ticket"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolOrderSend : public Tool
{
public:
   ToolOrderSend() : Tool("order_send", "Send an order using absolute entry, stop loss, and take profit.", toolOrderSendParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return BOOL_TO_STRING(orderSend(
                               json["symbol"].ToStr(),
                               StringToOrderType(json["type"].ToStr()),
                               json["volume"].ToDbl(),
                               json["price"].ToDbl(),
                               (int)json["slippage"].ToInt(),
                               json["stoploss"].ToDbl(),
                               json["takeprofit"].ToDbl(),
                               json["comment"].ToStr(),
                               json["magic"].ToInt()
                            ));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolOrderSendPips : public Tool
{
public:
   ToolOrderSendPips() : Tool("order_send_pips", "Send an order using stop loss and take profit distances in pips.", toolOrderSendPipsParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return BOOL_TO_STRING(orderSendPips(
                               json["symbol"].ToStr(),
                               StringToOrderType(json["type"].ToStr()),
                               json["volume"].ToDbl(),
                               json["price"].ToDbl(),
                               (int)json["slippage"].ToInt(),
                               json["stoploss_pips"].ToDbl(),
                               json["takeprofit_pips"].ToDbl(),
                               json["comment"].ToStr(),
                               json["magic"].ToInt()
                            ));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolOrderModify : public Tool
{
public:
   ToolOrderModify() : Tool("order_modify", "Modify the price, stop loss, and take profit of a pending order.", toolOrderModifyParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return BOOL_TO_STRING(orderModify((ulong)json["ticket"].ToInt(), json["price"].ToDbl(), json["stop_loss"].ToDbl(), json["take_profit"].ToDbl()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolPositionClose : public Tool
{
public:
   ToolPositionClose() : Tool("position_close", "Close an open position by ticket number.", toolPositionCloseParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return BOOL_TO_STRING(positionClose((ulong)json["ticket"].ToInt()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolPositionModify : public Tool
{
public:
   ToolPositionModify() : Tool("position_modify", "Modify the stop loss and take profit of an open position.", toolPositionModifyParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return BOOL_TO_STRING(positionModify(json["symbol"].ToStr(), (ulong)json["ticket"].ToInt(), json["stop_loss"].ToDbl(), json["take_profit"].ToDbl()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolSelectSymbol : public Tool
{
public:
   ToolSelectSymbol() : Tool("select_symbol", "Enable or disable a symbol in the Market Watch.", toolSelectSymbolParams()) {}
   virtual string execute(CJAVal &json) override
   {
      string enable = json["enable"].ToStr();
      StringToLower(enable);
      bool enableFlag = enable == "true" || enable == "1";
      return BOOL_TO_STRING(selectSymbol(json["symbol"].ToStr(), enableFlag));
   }
};
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolCompileMql5 : public Tool
{
public:
   ToolCompileMql5() : Tool("compile_mql5", "Compile an MQL5 file and return any compilation errors.", toolCompileMql5Params()) {}
   virtual string execute(CJAVal &json) override
   {      
       return compileMql5(json["mq5_path"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetMA : public Tool
{
public:
   ToolGetMA() : Tool("get_ma", "Get a Moving Average value for a specific symbol, timeframe, and bar.", toolGetMAParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getMA(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["ma_period"].ToInt(),
                (int)json["ma_shift"].ToInt(),
                StringToMAMethod(json["ma_method"].ToStr()),
                StringToAppliedPrice(json["applied_price"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetRSI : public Tool
{
public:
   ToolGetRSI() : Tool("get_rsi", "Get the Relative Strength Index (RSI) value.", toolGetRSIParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getRSI(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["rsi_period"].ToInt(),
                StringToAppliedPrice(json["applied_price"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetATR : public Tool
{
public:
   ToolGetATR() : Tool("get_atr", "Get the Average True Range (ATR) value.", toolGetATRParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getATR(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["atr_period"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetADX : public Tool
{
public:
   ToolGetADX() : Tool("get_adx", "Get the Average Directional Index (ADX) value.", toolGetADXParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getADX(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["adx_period"].ToInt(),
                (ENUM_APPLIED_PRICE)StringToAppliedPrice(json["applied_price"].ToStr()),
                (int)json["adx_mode"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetCustom : public Tool
{
public:
   ToolGetCustom() : Tool("get_custom", "Get a value from a custom indicator.", toolGetCustomParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getCustom(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                json["indicator_name"].ToStr(),
                (int)json["buffer"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetEnvelopes : public Tool
{
public:
   ToolGetEnvelopes() : Tool("get_envelopes", "Get an Envelopes indicator value.", toolGetEnvelopesParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getEnvelopes(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["env_period"].ToInt(),
                (int)json["ma_shift"].ToInt(),
                StringToMAMethod(json["ma_method"].ToStr()),
                StringToAppliedPrice(json["applied_price"].ToStr()),
                json["deviation"].ToDbl(),
                (int)json["env_mode"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetFractals : public Tool
{
public:
   ToolGetFractals() : Tool("get_fractals", "Get a Fractals indicator value.", toolGetFractalsParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getFractals(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["fractal_mode"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetMACD : public Tool
{
public:
   ToolGetMACD() : Tool("get_macd", "Get a MACD indicator value.", toolGetMACDParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getMACD(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["fast_period"].ToInt(),
                (int)json["slow_period"].ToInt(),
                (int)json["signal_period"].ToInt(),
                (ENUM_APPLIED_PRICE)StringToAppliedPrice(json["applied_price"].ToStr()),
                (int)json["macd_mode"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetAO : public Tool
{
public:
   ToolGetAO() : Tool("get_ao", "Get the Awesome Oscillator value.", toolGetAOParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getAO(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetMomentum : public Tool
{
public:
   ToolGetMomentum() : Tool("get_momentum", "Get the Momentum indicator value.", toolGetMomentumParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getMomentum(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["momentum_period"].ToInt(),
                (ENUM_APPLIED_PRICE)StringToAppliedPrice(json["applied_price"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetWPR : public Tool
{
public:
   ToolGetWPR() : Tool("get_wpr", "Get the Williams Percent Range (WPR) value.", toolGetWPRParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getWPR(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["wpr_period"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetBullsPower : public Tool
{
public:
   ToolGetBullsPower() : Tool("get_bulls_power", "Get the Bulls Power indicator value.", toolGetBullsPowerParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getBullsPower(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["bull_period"].ToInt(),
                (ENUM_APPLIED_PRICE)StringToAppliedPrice(json["applied_price"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetBearsPower : public Tool
{
public:
   ToolGetBearsPower() : Tool("get_bears_power", "Get the Bears Power indicator value.", toolGetBearsPowerParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getBearsPower(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["bear_period"].ToInt(),
                (ENUM_APPLIED_PRICE)StringToAppliedPrice(json["applied_price"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetATHR : public Tool
{
public:
   ToolGetATHR() : Tool("get_athr", "Get the ATHR (composite MA/RSI trend score) value.", toolGetATHRParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getATHR(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetStochastic : public Tool
{
public:
   ToolGetStochastic() : Tool("get_stochastic", "Get the Stochastic Oscillator value.", toolGetStochasticParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getStochastic(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["k_period"].ToInt(),
                (int)json["d_period"].ToInt(),
                (int)json["slow_period"].ToInt(),
                StringToMAMethod(json["ma_method"].ToStr()),
                StringToStoPrice(json["sto_price"].ToStr()),
                (int)json["stoch_mode"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetCCI : public Tool
{
public:
   ToolGetCCI() : Tool("get_cci", "Get the Commodity Channel Index (CCI) value.", toolGetCCIParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getCCI(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["cci_period"].ToInt(),
                (ENUM_APPLIED_PRICE)StringToAppliedPrice(json["applied_price"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetADR : public Tool
{
public:
   ToolGetADR() : Tool("get_adr", "Get the Average Daily Range (ADR) value.", toolGetADRParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getADR(
                json["symbol"].ToStr(),
                (int)json["adr_period"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetVWAP : public Tool
{
public:
   ToolGetVWAP() : Tool("get_vwap", "Get the Volume Weighted Average Price (VWAP) value.", toolGetVWAPParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getVWAP(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                (int)json["vwap_period"].ToInt(),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetPVI : public Tool
{
public:
   ToolGetPVI() : Tool("get_pvi", "Get the Positive Volume Index (PVI) value.", toolGetPVIParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getPVI(
                json["symbol"].ToStr(),
                StringToTimeframe(json["timeframe"].ToStr()),
                StringToVolumeType(json["volume_type"].ToStr()),
                (int)json["shift"].ToInt()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolFileCopy : public Tool
{
public:
   ToolFileCopy() : Tool("file_copy", "Copy a file from source to destination.", toolFileCopyParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return fileCopy(json["src"].ToStr(), json["dest"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolFileDelete : public Tool
{
public:
   ToolFileDelete() : Tool("file_delete", "Delete a file by path.", toolFileDeleteParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return fileDelete(json["path"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolFileExists : public Tool
{
public:
   ToolFileExists() : Tool("file_exists", "Check if a file exists at the specified path.", toolFileExistsParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return fileExists(json["path"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolFileMove : public Tool
{
public:
   ToolFileMove() : Tool("file_move", "Move a file from source to destination.", toolFileMoveParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return fileMove(json["src"].ToStr(), json["dest"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolFileRead : public Tool
{
public:
   ToolFileRead() : Tool("file_read", "Read the contents of a file.", toolFileReadParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return fileRead(json["path"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolFileWrite : public Tool
{
public:
   ToolFileWrite() : Tool("file_write", "Write content to a file (must escape quotes (in content parameter) + provide a full path (including drive and directories for the path parameter)).", toolFileWriteParams()) {}
   virtual string execute(CJAVal &json) override
   {
      string content = json["content"].ToStr();
      char data[];
      StringToCharArray(content, data);
      string overwrite = json["overwrite"].ToStr();
      StringToLower(overwrite);
      bool overwriteFlag = overwrite != "false" && overwrite != "0";
      return fileWrite(json["path"].ToStr(), data, (int)json["index"].ToInt(), overwriteFlag);
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolFileList : public Tool
{
public:
   ToolFileList() : Tool("file_list", "List files in a folder, optionally matching a name key and/or extension.", toolFileListParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return fileList(
                json["folder"].ToStr(),
                json["key"].ToStr(),
                json["ext"].ToStr(),
                json["recursive"].ToBool()
             );
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetTerminalInfo : public Tool
{
public:
   ToolGetTerminalInfo() : Tool("get_terminal_info", "Get information about the current MetaTrader terminal.", toolGetTerminalInfoParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getTerminalInfo();
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolChartClose : public Tool
{
public:
   ToolChartClose() : Tool("chart_close", "Close a chart by chart ID.", toolChartCloseParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return chartClose((long)json["chart_id"].ToInt());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolChartOpen : public Tool
{
public:
   ToolChartOpen() : Tool("chart_open", "Open a new chart for a symbol and timeframe.", toolChartOpenParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return chartOpen(json["symbol"].ToStr(), StringToTimeframe(json["timeframe"].ToStr()));
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetChartInfo : public Tool
{
public:
   ToolGetChartInfo() : Tool("get_chart_info", "Get detailed information about a chart.", toolGetChartInfoParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getChartInfo((long)json["chart_id"].ToInt());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolGetChartIndicator : public Tool
{
public:
   ToolGetChartIndicator() : Tool("get_chart_indicator", "Find an indicator on the chart and return its details.", toolGetChartIndicatorParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return getChartIndicator(json["indicator_name"].ToStr());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolRemoveChartIndicator : public Tool
{
public:
   ToolRemoveChartIndicator() : Tool("remove_chart_indicator", "Remove an indicator from the chart.", toolRemoveChartIndicatorParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return removeChartIndicator(json["indicator_name"].ToStr(), (long)json["chart_id"].ToInt(), (int)json["sub_window"].ToInt());
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolBacktestSingle : public Tool
{
public:
   ToolBacktestSingle() : Tool("backtest_single", "Run a single backtest in the strategy tester with the specified inputs and expert parameters.", toolBacktestSingleParams()) {}
   virtual string execute(CJAVal &json) override
   {
      CJAVal testInputs;
      testInputs["name"]       = json["name"];
      testInputs["symbol"]     = json["symbol"];
      testInputs["timeframe"]  = json["timeframe"];
      testInputs["to_date"]    = json["to_date"];
      testInputs["from_date"]  = json["from_date"];
      testInputs["deposit"]    = json["deposit"];

      CJAVal expertParams;
      expertParams.Deserialize(json["expert_params"].ToStr());

      return backtestSingle(testInputs, expertParams);
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolBacktestOptimization : public Tool
{
public:
   ToolBacktestOptimization() : Tool("backtest_optimization", "Run a backtest optimization in the strategy tester with the specified inputs and optimization parameters.", toolBacktestOptimizationParams()) {}
   virtual string execute(CJAVal &json) override
   {
      CJAVal testInputs;
      testInputs["name"]       = json["name"];
      testInputs["symbol"]     = json["symbol"];
      testInputs["timeframe"]  = json["timeframe"];
      testInputs["to_date"]    = json["to_date"];
      testInputs["from_date"]  = json["from_date"];
      testInputs["deposit"]    = json["deposit"];

      CJAVal optimizationParams;
      optimizationParams.Deserialize(json["optimization_params"].ToStr());

      return backtestOptimization(testInputs, optimizationParams);
   }
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ToolContextRead : public Tool
{
public:
   ToolContextRead() : Tool("context_read", "Read a context file by path and return its contents", toolContextReadParams()) {}
   virtual string execute(CJAVal &json) override
   {
      return contextRead(json["path"].ToStr());
   }
};