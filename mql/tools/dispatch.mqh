//+------------------------------------------------------------------+
//|                                                     dispatch.mqh |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict
#include "backtesting.mqh"
#include "constants.mqh"
#include "mt5.mqh"
#include "compile.mqh"
#include "tools.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class Dispatch
{
public:
   Tool *tools[];
   int   count;

   Dispatch()
   {
      count = 0;
      ArrayResize(tools, 0);

      add(new ToolGetAccountInfo());
      add(new ToolGetBars());
      add(new ToolGetHistoryPosition());
      add(new ToolGetHistoryPositions());
      add(new ToolGetOrder());
      add(new ToolGetOrders());
      add(new ToolGetPipValue());
      add(new ToolGetPosition());
      add(new ToolGetPositions());
      add(new ToolGetRecentBars());
      add(new ToolGetRisk());
      add(new ToolGetScreenshot());
      add(new ToolGetSymbolInfo());
      add(new ToolIClose());
      add(new ToolIDate());
      add(new ToolIHigh());
      add(new ToolILow());
      add(new ToolIOpen());
      add(new ToolIsOrderOpened());
      add(new ToolIsPositionOpened());
      add(new ToolOrderDelete());
      add(new ToolOrderSend());
      add(new ToolOrderSendPips());
      add(new ToolOrderModify());
      add(new ToolPositionClose());
      add(new ToolPositionModify());
      add(new ToolSelectSymbol());

      add(new ToolGetMA());
      add(new ToolGetRSI());
      add(new ToolGetATR());
      add(new ToolGetADX());
      add(new ToolGetCustom());
      add(new ToolGetEnvelopes());
      add(new ToolGetFractals());
      add(new ToolGetMACD());
      add(new ToolGetAO());
      add(new ToolGetMomentum());
      add(new ToolGetWPR());
      add(new ToolGetBullsPower());
      add(new ToolGetBearsPower());
      add(new ToolGetATHR());
      add(new ToolGetStochastic());
      add(new ToolGetCCI());
      add(new ToolGetADR());
      add(new ToolGetVWAP());
      add(new ToolGetPVI());

      add(new ToolFileCopy());
      add(new ToolFileDelete());
      add(new ToolFileExists());
      add(new ToolFileList());
      add(new ToolFileMove());
      add(new ToolFileRead());
      add(new ToolFileWrite());

      add(new ToolGetTerminalInfo());
      
      add(new ToolChartClose());
      add(new ToolChartOpen());
      add(new ToolGetChartInfo());
      add(new ToolGetChartIndicator());
      add(new ToolRemoveChartIndicator());

      add(new ToolCompileMql5());
      add(new ToolBacktestSingle());
      add(new ToolBacktestOptimization());
      add(new ToolContextRead());
   }

   void toolList(CJAVal &json, bool isAnthropic = true)
   {
      json.m_type = jtARRAY;
      for (int i = 0; i < count; i++)
      {
         CJAVal t;
         if (isAnthropic) tools[i].json_anthropic(t);
         else             tools[i].json_openai(t);
         json.Add(t);
      }
   }

   string execute(string name, CJAVal &json)
   {
      for (int i = 0; i < count; i++)
         if (tools[i].name == name)
            return tools[i].execute(json);

      return "{\"error\":\"unknown tool: " + name + "\"}";
   }

   ~Dispatch()
   {
      for (int i = 0; i < count; i++)
         if (CheckPointer(tools[i]) == POINTER_DYNAMIC) delete tools[i];
      ArrayResize(tools, 0);
   }

protected:
   void add(Tool *t)
   {
      ArrayResize(tools, count + 1);
      tools[count++] = t;
   }
};
//+------------------------------------------------------------------+
