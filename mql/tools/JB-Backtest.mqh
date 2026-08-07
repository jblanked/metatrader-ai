#ifndef __JB_BACKTEST_MQH__
#define __JB_BACKTEST_MQH__

//+------------------------------------------------------------------+
//|                                                  JB-Backtest.mqh |
//|                                     Copyright 2024-2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property description "Extension of FXSaber's MTTester"
#property strict

/*
   Features:
      - automatically creates .ini and .set files
      - simplifies the creation of settings
      - returns strategy tester results
*/

#include "fxsaber\Expert.mqh"                              // https://www.mql5.com/en/code/19003
#define private public
   #include "fxsaber\MultiTester\MTTester.mqh"                // https://www.mql5.com/en/code/26132
#undef private
#include "fxsaber\SingleTesterCache\SingleTesterCache.mqh" // https://www.mql5.com/en/code/27611
#include "fxsaber\TesterCache\TesterCache.mqh"             // https://www.mql5.com/ru/code/26223

#import "shell32.dll"
int ShellExecuteW(int hWnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

#ifndef TESTER_COMMON_PATH
#define TESTER_COMMON_PATH TerminalInfoString(TERMINAL_COMMONDATA_PATH)
#endif

struct testerInputs
{
   string            expertName;
   string            symbol;
   ENUM_TIMEFRAMES   timeFrame;
   bool              optimization; // true to run optimization, otherwise run single-test
   int               model; // 0 — "Every tick", 1 — "1 minute OHLC", 2 — "Open price only", 3 — "Math calculations", 4 — "Every tick based on real ticks"
   datetime          fromDate;
   datetime          toDate;
   int               forwardMode;
   double            deposit;
   string            currency;
   bool              profitInPips;
   long              leverage;
   int               executionMode;
   int               optimizationCriterion;
   bool              visual;

   testerInputs::testerInputs()
   {
      expertName            = "";
      symbol                = _Symbol;
      timeFrame             = PERIOD_CURRENT;
      optimization          = false;
      model                 = 0;
      fromDate              = iTime(_Symbol, PERIOD_MN1, 0);
      toDate                = TimeCurrent();
      forwardMode           = 0;
      deposit               = AccountInfoDouble(ACCOUNT_EQUITY);
      currency              = AccountInfoString(ACCOUNT_CURRENCY);
      profitInPips          = false;
      leverage              = AccountInfoInteger(ACCOUNT_LEVERAGE);
      executionMode         = 27;
      optimizationCriterion = 3;
      visual                = false;
   }
};

struct MqlParamInput
{
   double            double_value;  // field to store a double type
   long              integer_value; // field to store an integer type
   string            name;          // name of the input parameter
   string            string_value;  // field to store a string type
   ENUM_DATATYPE     type;          // type of the input parameter, value of ENUM_DATATYPE
};

struct InputParam
{
   string name;
   string value;
};

//+------------------------------------------------------------------+
//| Backtest class                                                   |
//+------------------------------------------------------------------+
class CBacktest
{
protected:
   string            m_settings;
   testerInputs      i_settings;

public:
   CBacktest(const string expertName, string symbol = "", const ENUM_TIMEFRAMES timeFrame = PERIOD_CURRENT, bool loadDefaultParameters = true);
   CBacktest(const testerInputs&inputs, bool loadDefaultParameters = true);

   template <typename T>
   void              addOptimizationSetting(const string inputVariable, T value, T valueStart, T valueStep, T valueStop, const bool checked = false);
   template <typename T>
   void              addSetting(const string inputVariable, T value);
   bool              ask(
      const bool openFolder = false,
      const string message = "Would you like to run a backtest of your current settings? (Note: Not recommended on a VPS)",
      const string title = "Alert"
   );
   bool              closeOtherCharts(void);
   string            doubleToString(const double doubleValue, const int digits = 2);
   datetime          endDate(void);
   int               getParameters(const string pathToExpert, MqlParamInput &params[]);
   datetime          monthCurrent(void);
   static bool       moveFile(const string src, const string dest);
   bool              openFolder(void);
   string            run(const bool openFolder = false, const bool removeTool = false);
   void              save(void);
   string            timeCurrent(void);
   string            timeframeSuffix(const ENUM_TIMEFRAMES timeframe);

private:
   bool              committed;
   uint              count;
   string            iniFileName;
   string            setFileName;
   InputParam        inputParams[];
   bool              inputsAdded;
   string            getExpertName(bool withExtension = false);
   void              loadDefaultParams();
   void              set(const string expertName, const string symbol, const ENUM_TIMEFRAMES timeFrame);
   string            testerInputsToString(const testerInputs &inputs);
   bool              stringToTesterInputs(const string testerInputString, testerInputs &inputs);
   ENUM_TIMEFRAMES   stringToTimeframe(string timeframeStr);
};

//+------------------------------------------------------------------+
//| Constructor (used for single tests)                              |
//+------------------------------------------------------------------+
CBacktest::CBacktest(const string expertName, string symbol, const ENUM_TIMEFRAMES timeFrame, bool loadDefaultParameters)
{
   if(expertName == "")
   {
      Alert("Expert name cannot be empty!");
      return;
   }

   if(StringFind(expertName, "Expert") != 0)
   {
      Alert("\"expertName\" must start with \"Expert//\"");
      return;
   }

#ifdef __MQL5__
   if(StringFind(expertName, ".ex5", StringLen(expertName) - 5) == -1)
   {
      Alert("\"expertName\" must end with \".ex5\"");
      return;
   }
#else
   if(StringFind(expertName, ".ex4", StringLen(expertName) - 5) == -1)
   {
      Alert("\"expertName\" must end with \".ex4\"");
      return;
   }
#endif

   symbol = symbol == "" ? _Symbol : symbol;

   this.iniFileName = "backtest\\" + expertName + "-" +
                      symbol + "-" +
                      this.timeframeSuffix(timeFrame) + "-" +
                      this.timeCurrent() +
                      ".ini";

   this.setFileName = "backtest\\" + expertName + "-" +
                      symbol + "-" +
                      this.timeframeSuffix(timeFrame) + "-" +
                      this.timeCurrent() +
                      ".set";

   this.i_settings.expertName = expertName;
   this.i_settings.symbol = symbol;
   this.i_settings.timeFrame = timeFrame;

   if(loadDefaultParameters)
   {
      this.loadDefaultParams();
   }
}

//+------------------------------------------------------------------+
//| Constructor (best used for custom single tests, msot cases)      |
//+------------------------------------------------------------------+
CBacktest::CBacktest(const testerInputs &inputs, bool loadDefaultParameters)
{
   if(inputs.expertName == "")
   {
      Alert("Expert name cannot be empty!");
      return;
   }

   this.i_settings = inputs;

   this.iniFileName = "backtest\\" + this.getExpertName() + "\\" +
                      inputs.symbol + "-" +
                      this.timeframeSuffix(inputs.timeFrame) + "-" +
                      this.timeCurrent() +
                      ".ini";

   this.setFileName = "backtest\\" + this.getExpertName() + "\\" +
                      inputs.symbol + "-" +
                      this.timeframeSuffix(inputs.timeFrame) + "-" +
                      this.timeCurrent() +
                      ".set";

   if(loadDefaultParameters)
   {
      this.loadDefaultParams();
   }
}

//+------------------------------------------------------------------+
//| Add an input to the testing config for optimizations             |
//+------------------------------------------------------------------+
template <typename T>
void              CBacktest::addOptimizationSetting(const string inputVariable, T value, T valueStart, T valueStep, T valueStop, const bool checked = false)
{
   if(!inputsAdded)
   {
      this.m_settings += "[TesterInputs]";
      inputsAdded = true;
   }

   const int prevSize = ArraySize(this.inputParams);
   for(int i = 0; i < prevSize; i++)
   {
      if(this.inputParams[i].name == inputVariable)
      {
         this.inputParams[i].value = (string)value;
         return;
      }
   }

   const int newSize = ArrayResize(this.inputParams, prevSize + 1);
   if(newSize == -1)
   {
      PrintFormat("Failed to increase input parameter array size to %d, error = %d", prevSize + 1, GetLastError());
      return;
   }

   this.inputParams[newSize - 1].name  = inputVariable;
   this.inputParams[newSize - 1].value = StringFormat("%s||%s||%s||%s||%s", (string)value, (string)valueStart, (string)valueStep, (string)valueStop, checked ? "Y" : "N");
}

//+------------------------------------------------------------------+
//| Add an input to the testing config                               |
//+------------------------------------------------------------------+
template <typename T>
void              CBacktest::addSetting(const string inputVariable, T value)
{
   if(!inputsAdded)
   {
      this.m_settings += "[TesterInputs]";
      inputsAdded = true;
   }

   const int prevSize = ArraySize(this.inputParams);
   for(int i = 0; i < prevSize; i++)
   {
      if(this.inputParams[i].name == inputVariable)
      {
         this.inputParams[i].value = (string)value;
         return;
      }
   }

   const int newSize = ArrayResize(this.inputParams, prevSize + 1);
   if(newSize == -1)
   {
      PrintFormat("Failed to increase input parameter array size to %d, error = %d", prevSize + 1, GetLastError());
      return;
   }

   this.inputParams[newSize - 1].name  = inputVariable;
   this.inputParams[newSize - 1].value = (string)value;
}

//+------------------------------------------------------------------+
//| Ask the user if they want to backtest, and backtest if so        |
//+------------------------------------------------------------------+
bool              CBacktest::ask(
   const bool openFolder = false,
   const string message = "Would you like to run a backtest of your current settings? (Note: Not recommended on a VPS)",
   const string title = "Alert"
)
{
   if(MessageBox(message, title, MB_YESNO | MB_ICONQUESTION) == 6)
   {
      Print(this.run(openFolder, false));
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
//| Close all charts except the current                              |
//+------------------------------------------------------------------+
bool              CBacktest::closeOtherCharts(void)
{
   bool Res = false;
   for(long Chart = ::ChartFirst(); Chart != -1; Chart = ::ChartNext(Chart))
   {
      if(Chart != ::ChartID())
         Res |= ::ChartClose(Chart);
   }
   return Res;
}

//+------------------------------------------------------------------+
//| Convert a double to string                                       |
//+------------------------------------------------------------------+
string            CBacktest::doubleToString(const double doubleValue, const int digits = 2)
{
   const string tempDouble = string(doubleValue) + "00000000";
   const int periodLocation = StringFind(tempDouble, ".");
   return StringSubstr(tempDouble, 0, periodLocation) + StringSubstr(tempDouble, periodLocation, digits + 1);
}

//+------------------------------------------------------------------+
//| Get the end date from the strategy tester                        |
//+------------------------------------------------------------------+
datetime          CBacktest::endDate(void)
{
   string currentSettings = testerInputsToString(this.i_settings);
   return (MTTESTER::GetSettings(currentSettings) ? (datetime)MTTESTER::GetValue(currentSettings, "ToDate") : 0);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string            CBacktest::getExpertName(bool withExtension)
{
   int slash = -1;
   string path = i_settings.expertName;
   for(int i = StringLen(path); i >= 0; i--)
   {
      if(path[i] == 92)
      {
         slash = i;
         break;
      }
   }
   if(slash == -1)
   {
      Alert("Failed to find last slash!");
      return "";
   }

   string ex5 = StringSubstr(path, slash + 1);
   return withExtension ? ex5 : StringSubstr(ex5, 0, StringFind(ex5, ".ex5"));
}

//+------------------------------------------------------------------+
//| Get parameters from an expert advisor                            |
//+------------------------------------------------------------------+
int               CBacktest::getParameters(const string pathToExpert, MqlParamInput &params[])
{
   long nextChartId = ChartNext(ChartID());
   while(nextChartId != -1)
   {
      long nextChartId = ChartNext(ChartID());
   }
   if(nextChartId != -1) // last chart
   {
      Print("Failed to get last chart..");
   }
   nextChartId = ChartOpen(this.i_settings.symbol, this.i_settings.timeFrame);
   if(nextChartId == 0)
   {
      PrintFormat("ChartOpen() failed, Error %d", GetLastError());
      return 0;
   }
   MqlParam expertParams[1];
   expertParams[0].string_value = pathToExpert;
   if(!EXPERT::Run(nextChartId, expertParams))
   {
      PrintFormat("Failed to load %s on chart %d", pathToExpert, nextChartId);
      ChartClose(nextChartId);
      return 0;
   }
   string inputNames[];
   MqlParam parameters[];
   if(!EXPERT::Parameters(nextChartId, parameters, inputNames))
   {
      PrintFormat("Failed to get parameters for %s on chart %d", pathToExpert, nextChartId);
      ChartClose(nextChartId);
      return 0;
   }
   ArrayResize(params, ArraySize(inputNames));
   for(int i = 1; i < ArraySize(parameters); i++)
   {
      // skip expert name (i == 0)
      params[i - 1].double_value  = parameters[i].double_value;
      params[i - 1].integer_value = parameters[i].integer_value;
      params[i - 1].name          = inputNames[i - 1];
      params[i - 1].string_value  = parameters[i].string_value;
      params[i - 1].type          = parameters[i].type;
   }
   if(!EXPERT::Remove(nextChartId))
   {
      PrintFormat("Failed to remove %s from chart %d", pathToExpert, nextChartId);
   }
   ChartClose(nextChartId);
   return ArraySize(params);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void              CBacktest::loadDefaultParams(void)
{
   MqlParamInput inputs[];
   const int paramCount = this.getParameters(this.i_settings.expertName, inputs);
   for(int i = 0; i < paramCount; i++)
   {
      switch(inputs[i].type)
      {
      case TYPE_STRING:
         this.addSetting(inputs[i].name, inputs[i].string_value);
         break;
      case TYPE_DOUBLE:
      case TYPE_FLOAT:
         inputs[i].string_value = (string)inputs[i].double_value;
         this.addSetting(inputs[i].name, inputs[i].double_value);
         break;
      case TYPE_INT:
         inputs[i].string_value = (string)inputs[i].integer_value;
         this.addSetting(inputs[i].name, inputs[i].integer_value);
         break;
      case TYPE_BOOL:
         inputs[i].string_value = (string)inputs[i].integer_value;
         this.addSetting(inputs[i].name, (bool)inputs[i].integer_value);
         break;
      case TYPE_DATETIME:
         inputs[i].string_value = (string)inputs[i].integer_value;
         this.addSetting(inputs[i].name, (datetime)inputs[i].integer_value);
         break;
      default:
         inputs[i].string_value = (string)inputs[i].integer_value;
         this.addSetting(inputs[i].name, inputs[i].integer_value);
         break;
      };
   }
}

//+------------------------------------------------------------------+
//| Get the date of the current month                                |
//+------------------------------------------------------------------+
datetime          CBacktest::monthCurrent(void)
{
   return iTime(_Symbol, PERIOD_MN1, 0);
}

//+------------------------------------------------------------------+
//| Move a file from src to dest
//+------------------------------------------------------------------+
static bool        CBacktest::moveFile(const string src, const string dest)
{
   return ShellExecuteW(0, "open", "cmd.exe", StringFormat("/C move /Y \"%s\" \"%s\"", src, dest), NULL, 0) > 32;
}

//+------------------------------------------------------------------+
//| Open the folder where settings and results are saved             |
//+------------------------------------------------------------------+
bool              CBacktest::openFolder(void)
{
   return ShellExecuteW(
             0,
             "open",
             "cmd.exe",
             StringFormat("/c start %s\\Files\\backtest", TESTER_COMMON_PATH),
             NULL,
             0
          ) > 32;
}

//+------------------------------------------------------------------+
//| Run strategy tester and return the results                       |
//+------------------------------------------------------------------+
string              CBacktest::run(const bool openFolder = false, const bool removeTool = false)
{
   if(!this.committed)
   {
      for(int i = 0; i < ArraySize(this.inputParams); i++)
         MTTESTER::SetValue(this.m_settings, this.inputParams[i].name, this.inputParams[i].value);
      this.committed = true;
   }

   MTTESTER::SetSettings2(testerInputsToString(this.i_settings) + this.m_settings);
   this.save();
   MTTESTER::ClickStart();

   while(!MTTESTER::IsReady() && !IsStopped())
   {
      Sleep(100);
   }

   uchar Bytes2[];
   string res = "";
   const string expertName = getExpertName();
   if(!this.i_settings.optimization)
   {
      if (MTTESTER::GetLastTstCache(Bytes2) != -1) // If it was possible to read the last cache record of a single run
      {
         const SINGLETESTERCACHE SingleTesterCache(Bytes2); // Drive it into the corresponding object.
         const string fileName = StringFormat("backtest\\%s\\single-test.txt", expertName);
         uchar Array[];
         res = SingleTesterCache.Summary.ToString();
         if (!(StringToCharArray(res, Array) > 0) || !FileSave(fileName, Array, FILE_READ | FILE_WRITE | FILE_COMMON | FILE_BIN))
         {
            PrintFormat("Failed to save single-test report to %s%s", TESTER_COMMON_PATH, fileName);
         }
      }
   }
   else
   {
      if (MTTESTER::GetLastOptCache(Bytes2) != -1) // If it was possible to read the last cache record of a single run
      {
         const TESTERCACHE<ExpTradeSummary> OptimizationCache(Bytes2); // Drive it into the corresponding object.
         uchar Array[];
         res = OptimizationCache.Header.ToString();
         // add each test result
         const int passes = OptimizationCache.GetAmount();
         for(int i = 0; i < passes; i++)
         {
            string toSave = OptimizationCache[i].ToString();
            StringReplace(toSave, ";", "");
            res += StringFormat("\n%s", toSave);
            string optiFileName = StringFormat("%s-pass-%d.txt", expertName, i);
            OptimizationCache.SaveSet(i, optiFileName);
            string ogLocation = StringFormat("%s\\MQL5\\Files\\%s", TerminalInfoString(TERMINAL_DATA_PATH), optiFileName);
            string newLocation = StringFormat("%s\\Files\\backtest\\%s\\%s", TESTER_COMMON_PATH, expertName, optiFileName);
            moveFile(ogLocation, newLocation);
         }
         const string fileName = StringFormat("backtest\\%s\\optimization.txt", expertName);
         if (!(StringToCharArray(res, Array) > 0) || !FileSave(fileName, Array, FILE_READ | FILE_WRITE | FILE_COMMON | FILE_BIN))
         {
            PrintFormat("Failed to save optimization report to %s%s", TESTER_COMMON_PATH, fileName);
         }
      }
   }

   if(openFolder && !this.openFolder())
   {
      PrintFormat("Results saved but failed to open folder!\nNavigate to %s", StringFormat("%s\\Files\\backtest\\%s", TESTER_COMMON_PATH, expertName));
   }

   if(removeTool)
   {
      ExpertRemove();
   }

   return res;
}

//+------------------------------------------------------------------+
//| Save the .ini/.set settings based on current set                 |
//+------------------------------------------------------------------+
void              CBacktest::save(void)
{
   if(this.m_settings == "") return;

   if(!FolderCreate(StringFormat("Files\\backtest\\%s", getExpertName()), FILE_COMMON))
   {
      PrintFormat("Failed to create folder for results, error %d", GetLastError());
      return;
   }

   string testInputData = testerInputsToString(this.i_settings);
   FileDelete(this.iniFileName, FILE_READ | FILE_REWRITE | FILE_WRITE | FILE_COMMON | FILE_BIN);
   int fileHandle = FileOpen(this.iniFileName, FILE_READ | FILE_REWRITE | FILE_WRITE | FILE_COMMON | FILE_BIN);
   FileWriteString(fileHandle, testInputData + this.m_settings);
   FileClose(fileHandle);

   FileDelete(this.setFileName, FILE_READ | FILE_REWRITE | FILE_WRITE | FILE_COMMON | FILE_BIN);
   int fileHandle2 = FileOpen(this.setFileName, FILE_READ | FILE_REWRITE | FILE_WRITE | FILE_COMMON | FILE_BIN);
   string settingsCopy = testInputData + this.m_settings;
   if(StringFind(this.m_settings, "[TesterInputs]") == 0)
   {
      settingsCopy = testInputData + StringSubstr(this.m_settings, StringLen("\n[TesterInputs]"));
   }
   FileWriteString(fileHandle2, settingsCopy);
   FileClose(fileHandle2);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES            CBacktest::stringToTimeframe(string timeframeStr)
{
   if (StringFind(timeframeStr, "M10") != -1) return PERIOD_M10;
   if (StringFind(timeframeStr, "M15") != -1) return PERIOD_M15;
   if (StringFind(timeframeStr, "M20") != -1) return PERIOD_M20;
   if (StringFind(timeframeStr, "M30") != -1) return PERIOD_M30;
   if (StringFind(timeframeStr, "M1")  != -1) return PERIOD_M1;
   if (StringFind(timeframeStr, "M2")  != -1) return PERIOD_M2;
   if (StringFind(timeframeStr, "M3")  != -1) return PERIOD_M3;
   if (StringFind(timeframeStr, "M4")  != -1) return PERIOD_M4;
   if (StringFind(timeframeStr, "M5")  != -1) return PERIOD_M5;
   if (StringFind(timeframeStr, "M6")  != -1) return PERIOD_M6;
   if (StringFind(timeframeStr, "H12") != -1) return PERIOD_H12;
   if (StringFind(timeframeStr, "H1")  != -1) return PERIOD_H1;
   if (StringFind(timeframeStr, "H2")  != -1) return PERIOD_H2;
   if (StringFind(timeframeStr, "H4")  != -1) return PERIOD_H4;
   if (StringFind(timeframeStr, "H8")  != -1) return PERIOD_H8;
   if (StringFind(timeframeStr, "D1")  != -1) return PERIOD_D1;
   if (StringFind(timeframeStr, "W1")  != -1) return PERIOD_W1;
   if (StringFind(timeframeStr, "MN1") != -1) return PERIOD_MN1;
   return PERIOD_CURRENT;
}

//+------------------------------------------------------------------+
//| Helper to convert testerInputs struct to string                  |
//+------------------------------------------------------------------+
string            CBacktest::testerInputsToString(const testerInputs &inputs)
{
   return StringFormat(
             "[Tester]\n" +
             "Expert=%s\n" +
             "Symbol=%s\n" +
             "Period=%s\n" +
             "Optimization=%d\n" +
             "Model=%d\n" +
             "FromDate=%s\n" +
             "ToDate=%s\n" +
             "ForwardMode=%d\n" +
             "Deposit=%g\n" +
             "Currency=%s\n" +
             "ProfitInPips=%d\n" +
             "Leverage=%d\n" +
             "ExecutionMode=%d\n" +
             "OptimizationCriterion=%d\n" +
             "Visual=%d\n",
             inputs.expertName,
             inputs.symbol,
             this.timeframeSuffix(inputs.timeFrame),
             inputs.optimization,
             inputs.model,
             TimeToString(inputs.fromDate, TIME_DATE),
             TimeToString(inputs.toDate, TIME_DATE),
             inputs.forwardMode,
             inputs.deposit,
             inputs.currency,
             inputs.profitInPips,
             inputs.leverage,
             inputs.executionMode,
             inputs.optimizationCriterion,
             inputs.visual
          );
}

//+------------------------------------------------------------------+
//| Helper to convert a string to testerInputs struct                |
//+------------------------------------------------------------------+
bool              CBacktest::stringToTesterInputs(const string testerInputString, testerInputs &inputs)
{
   string listOfInputs[];
   const int lines = StringSplit(testerInputString, '\n', listOfInputs);
   if(lines < 1) return false;
   for(int i = 0; i < lines; i++)
   {
      if(StringFind(listOfInputs[i], "Expert=") == 0)
      {
         inputs.expertName = StringSubstr(listOfInputs[i], StringLen("Expert="));
      }
      else if(StringFind(listOfInputs[i], "Symbol=") == 0)
      {
         inputs.symbol = StringSubstr(listOfInputs[i], StringLen("Symbol="));
      }
      else if(StringFind(listOfInputs[i], "Period=") == 0)
      {
         inputs.timeFrame = stringToTimeframe(StringSubstr(listOfInputs[i], StringLen("Period=")));
      }
      else if(StringFind(listOfInputs[i], "Optimization=") == 0)
      {
         const string res = StringSubstr(listOfInputs[i], StringLen("Optimization="));
         if(res == "true" || res == "false" || res == "True" || res == "False")
         {
            inputs.optimization = (res == "true" || res == "True");
         }
         else
         {
            inputs.optimization = (bool)StringToInteger(res);
         }
      }
      else if(StringFind(listOfInputs[i], "Model=") == 0)
      {
         inputs.model = (int)StringToInteger(StringSubstr(listOfInputs[i], StringLen("Model=")));
      }
      else if(StringFind(listOfInputs[i], "FromDate=") == 0)
      {
         inputs.fromDate = StringToTime(StringSubstr(listOfInputs[i], StringLen("FromDate=")));
      }
      else if(StringFind(listOfInputs[i], "ToDate=") == 0)
      {
         inputs.toDate = StringToTime(StringSubstr(listOfInputs[i], StringLen("ToDate=")));
      }
      else if(StringFind(listOfInputs[i], "ForwardMode=") == 0)
      {
         inputs.forwardMode = (int)StringToInteger(StringSubstr(listOfInputs[i], StringLen("ForwardMode=")));
      }
      else if(StringFind(listOfInputs[i], "Deposit=") == 0)
      {
         inputs.deposit = StringToDouble(StringSubstr(listOfInputs[i], StringLen("Deposit=")));
      }
      else if(StringFind(listOfInputs[i], "Currency=") == 0)
      {
         inputs.currency = StringSubstr(listOfInputs[i], StringLen("Currency="));
      }
      else if(StringFind(listOfInputs[i], "ProfitInPips=") == 0)
      {
         const string res = StringSubstr(listOfInputs[i], StringLen("ProfitInPips="));
         if(res == "true" || res == "false" || res == "True" || res == "False")
         {
            inputs.profitInPips = (res == "true" || res == "True");
         }
         else
         {
            inputs.profitInPips = (bool)StringToInteger(res);
         }
      }
      else if(StringFind(listOfInputs[i], "Leverage=") == 0)
      {
         inputs.leverage = StringToInteger(StringSubstr(listOfInputs[i], StringLen("Leverage=")));
      }
      else if(StringFind(listOfInputs[i], "ExecutionMode=") == 0)
      {
         inputs.executionMode = (int)StringToInteger(StringSubstr(listOfInputs[i], StringLen("ExecutionMode=")));
      }
      else if(StringFind(listOfInputs[i], "OptimizationCriterion=") == 0)
      {
         inputs.optimizationCriterion = (int)StringToInteger(StringSubstr(listOfInputs[i], StringLen("OptimizationCriterion=")));
      }
      else if(StringFind(listOfInputs[i], "Visual=") == 0)
      {
         const string res = StringSubstr(listOfInputs[i], StringLen("Visual="));
         if(res == "true" || res == "false" || res == "True" || res == "False")
         {
            inputs.visual = (res == "true" || res == "True");
         }
         else
         {
            inputs.visual = (bool)StringToInteger(res);
         }
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Get the current time as a string                                 |
//+------------------------------------------------------------------+
string            CBacktest::timeCurrent(void)
{
   string editedTime = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(editedTime, ".", "-");
   StringReplace(editedTime, ":", "-");
   StringReplace(editedTime, " ", "-");
   StringReplace(editedTime, "  ", "-");
   return editedTime;
}

//+------------------------------------------------------------------+
//| Get the suffix of a timeframe                                    |
//+------------------------------------------------------------------+
string            CBacktest::timeframeSuffix(const ENUM_TIMEFRAMES timeframe)
{
   const ENUM_TIMEFRAMES tframe = timeframe == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)Period() : timeframe;
   const string timeframeEdit = EnumToString(tframe);
// return last 3 characters
   return StringSubstr(timeframeEdit, StringLen(timeframeEdit) - 3, StringLen(timeframeEdit) - 1);
}
//+------------------------------------------------------------------+

#endif // __JB_BACKTEST_MQH__