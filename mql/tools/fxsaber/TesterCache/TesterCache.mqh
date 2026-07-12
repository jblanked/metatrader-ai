#ifndef __TESTERCACHE__
#define __TESTERCACHE__

#include "TestCacheHeader.mqh"
#include "ExpTradeSummary.mqh"
#include "TestCacheInput.mqh"
#include "Mathematics.mqh"
#include "TestCacheRecord.mqh"
#include "TestCacheSymbolRecord.mqh"

template <typename T>
class TESTERCACHE
{
private:
  bool IsCorrectType( void ) const
  {
    // https://www.mql5.com/ru/forum/170952/page227#comment_43202572
    return((typename(T) == "struct MATHEMATICS") && (this.Header.symbol[] == "")) ||
           ((typename(T) == "struct TestCacheSymbolRecord") && (this.Header.opt_mode == 2)) ||
//           ((typename(T) == "struct ExpTradeSummary") && (this.Header.symbol[] != "") && (this.Header.opt_mode < 2));
           // https://www.mql5.com/ru/forum/318998/page12#comment_58725229
           ((typename(T) == "struct ExpTradeSummary") && (this.Header.symbol[] != "") && (this.Header.opt_mode != 2));//opt_mode=3 forward
}

public:
  TestCacheHeader Header;
  TestCacheInput Inputs[];
  uchar ParametersBuffer[];
  TestCacheRecord<T> Record[];
  int UnknownNums[];

  bool Load( const string FileName )
  {
    const int handle = ::FileOpen(FileName, FILE_READ | FILE_BIN);
    bool Res = (handle != INVALID_HANDLE);

    if (Res)
    {
      ::ArrayFree(this.Inputs);
      ::ArrayFree(this.ParametersBuffer);
      ::ArrayFree(this.Record);
      ::ArrayFree(this.UnknownNums);

      ::FileReadStruct(handle, this.Header);

      if (Res = this.IsCorrectType() && this.Header.passes_passed)
      {
        ::FileReadArray(handle, this.Inputs, 0, this.Header.parameters_total);

        ::FileReadArray(handle, this.ParametersBuffer, 0, this.Header.parameters_size);

        ::FileReadArray(handle, this.UnknownNums, 0, this.Header.snapshot_size);

        const int Size = ::ArrayResize(this.Record, this.Header.passes_passed);
        const bool Offset = (this.Header.record_size - this.Header.opt_params_size - sizeof(T) == sizeof(long));

        for (int i = 0; i < Size; i++)
        {
          ::FileReadStruct(handle, this.Record[i].Result);

          ::FileReadArray(handle, this.Record[i].OptBuffer, 0, this.Header.opt_params_size);

          if (Offset)
            ::FileReadArray(handle, this.Record[i].Genetic, 0, sizeof(long) + this.Header.dwords_cnt * sizeof(int));
          else
            ::FileReadArray(handle, this.Record[i].Genetic, 0, this.Header.dwords_cnt * sizeof(int));
        }
      }

      ::FileClose(handle);
    }

    return(Res);
  }

  bool Load( const uchar &Bytes[] )
  {
    bool Res = ::ArraySize(Bytes);

    if (Res)
    {
      ::ArrayFree(this.Inputs);
      ::ArrayFree(this.ParametersBuffer);
      ::ArrayFree(this.Record);
      ::ArrayFree(this.UnknownNums);

      _W(this.Header) = Bytes;

      if (Res = this.IsCorrectType() && this.Header.passes_passed)
      {
        int Pos = sizeof(this.Header);

        Pos += ::_ArrayCopy(this.Inputs, Bytes, 0, Pos, this.Header.parameters_total * sizeof(TestCacheInput));
        Pos += ::_ArrayCopy(this.ParametersBuffer, Bytes, 0, Pos, this.Header.parameters_size);
        Pos += ::_ArrayCopy(this.UnknownNums, Bytes, 0, Pos, this.Header.snapshot_size * sizeof(int));

        const int Size = ::ArrayResize(this.Record, this.Header.passes_passed);
        const bool Offset = (this.Header.record_size - this.Header.opt_params_size - sizeof(T) == sizeof(long));

        for (int i = 0; i < Size; i++)
        {
          T Result[1];

          Pos += ::_ArrayCopy(Result, Bytes, 0, Pos, sizeof(T));
          this.Record[i].Result = Result[0];

          Pos += ::_ArrayCopy(this.Record[i].OptBuffer, Bytes, 0, Pos, this.Header.opt_params_size);

          if (Offset)
            Pos += ::_ArrayCopy(this.Record[i].Genetic, Bytes, 0, Pos, sizeof(long) + this.Header.dwords_cnt * sizeof(int));
          else
            Pos += ::_ArrayCopy(this.Record[i].Genetic, Bytes, 0, Pos, this.Header.dwords_cnt * sizeof(int));
        }
      }
    }

    return(Res);
  }

  bool Save( const string FileName )
  {
    const int handle = ::FileOpen(FileName, FILE_WRITE | FILE_BIN);
    bool Res = (handle != INVALID_HANDLE);

    if (Res)
    {
      ::FileWriteStruct(handle, this.Header);

      ::FileWriteArray(handle, this.Inputs);

      ::FileWriteArray(handle, this.ParametersBuffer);

      ::FileWriteArray(handle, this.UnknownNums);

      const int Size = ::ArraySize(this.Record);

      for (int i = 0; i < Size; i++)
      {
        ::FileWriteStruct(handle, this.Record[i].Result);

        ::FileWriteArray(handle, this.Record[i].OptBuffer);

        ::FileWriteArray(handle, this.Record[i].Genetic);
      }

      ::FileClose(handle);
    }

    return(Res);
  }

  TESTERCACHE( void )
  {
  }

  TESTERCACHE( const string FileName )
  {
    this.Load(FileName);
  }

  // https://www.mql5.com/ru/forum/324536/page20#comment_13850494
  TESTERCACHE( const uchar &Bytes[] )
  {
    this.Load(Bytes);
  }

#define PARAM_NAME 0
#define PARAM_VALUE 1
#define PARAM_START 2
#define PARAM_STEP 3
#define PARAM_STOP 4

#define MACROS(A, B)                                                                                                      \
  const string Str##A = ((Type == TYPE_FLOAT) || (Type == TYPE_DOUBLE)) ? (string)this.Inputs[i].StartStepStop.Number.##A \
                                                                      : (string)this.Inputs[i].StartStepStop.Integer.##A; \
  Params[j][PARAM_##B].type = Params[j][PARAM_VALUE].type;                                                                \
  Params[j][PARAM_##B].integer_value = (long)Str##A;                                                                      \
  Params[j][PARAM_##B].double_value = (double)Str##A;                                                                     \
  Params[j][PARAM_##B].string_value = Str##A;

  int GetInputs( const int Num, MqlParam &Params[][5], const bool Full = false ) const
  {
    int j = 0;
    int Count = 0;
    const int Size = ::ArraySize(this.Inputs);

    ::ArrayResize(Params, Size);
    ::ZeroMemory(Params);

    for (int i = 0; i < Size; i++)
      if (Full || this.Inputs[i].flag)
      {
        Params[j][PARAM_NAME].type = TYPE_STRING;
        Params[j][PARAM_NAME].string_value = this.Inputs[i].name[];

        const int Type = this.Inputs[i].type - TYPE_OFFSET;
        string StrValue;

        if (this.Inputs[i].flag)
        {
          StrValue = ((Type == TYPE_FLOAT) || (Type == TYPE_DOUBLE)) ? (string)_R(this.Record[Num].OptBuffer)[(double)Count]
                                                                     : (string)_R(this.Record[Num].OptBuffer)[(long)Count];

          Count += sizeof(long);
        }
        else
        {
          const string Str = this.Inputs[i].ToString(this.ParametersBuffer);

          StrValue = (Type == TYPE_BOOL) ? ((Str == "true") ? "1" : "0") :
                     ((Type == TYPE_COLOR) ? (string)(long)(color)Str :
                     ((Type == TYPE_DATETIME) ? (string)(long)(datetime)Str : Str));
        }

        // https://www.mql5.com/ru/forum/318305/page43#comment_53639656
        Params[j][PARAM_VALUE].type = (ENUM_DATATYPE)Type; // (Type >= TYPE_BOOL) && (Type <= TYPE_STRING) ? (ENUM_DATATYPE)Type : TYPE_INT;
        Params[j][PARAM_VALUE].integer_value = (long)StrValue;
        Params[j][PARAM_VALUE].double_value = (double)StrValue;
        Params[j][PARAM_VALUE].string_value = StrValue;

        MACROS(Start, START)
        MACROS(Step, STEP)
        MACROS(Stop, STOP)

        j++;
      }

    return(::ArrayResize(Params, j));
  }
#undef MACROS

  string SettingsString( const int Num ) const
  {
    string Str = NULL;

    MqlParam Params[][5];
    const int Size = this.GetInputs(Num, Params, true);

    for (int i = 0; i < Size; i++)
    {
      const bool EnumType = (Params[i][PARAM_VALUE].type > TYPE_STRING);

      Str +=  Params[i][PARAM_NAME].string_value == "" ? ";\n" :
              Params[i][PARAM_NAME].string_value + "=" +
              Params[i][PARAM_VALUE].string_value +
              ((!Params[i][PARAM_START].double_value &&
                !Params[i][PARAM_STEP].double_value &&
                !Params[i][PARAM_STOP].double_value) ? NULL : "||" +
                (EnumType ? NULL : Params[i][PARAM_START].string_value) + "||" +
                (EnumType ? "0" : Params[i][PARAM_STEP].string_value) + "||" +
                (EnumType ? NULL : Params[i][PARAM_STOP].string_value) + "||" +
                (this.Inputs[i].flag ? "Y" : "N")) + "\n";
    }

    return(Str);
  }

  string TesterString( const int Num ) const
  {
    return(this.Header.TesterString() + "\n[TesterInputs]\n" + this.SettingsString(Num));
  }

  bool SaveSet( const int Num, string FileName = NULL, const bool Details = true, string AddInformation = NULL ) const
  {
    if (FileName == NULL)
      FileName = this.Header.expert_name[] + "_" + (string)Num + ".set";

    const int handle = ::FileOpen(FileName, FILE_WRITE | FILE_UNICODE | FILE_TXT);
    const bool Res= (handle != INVALID_HANDLE);

    if (Res)
    {
      if (AddInformation != NULL)
      {
        AddInformation += "\n";

        ::StringReplace(AddInformation, "\n", "\n; ");

        ::FileWriteString(handle, "; " + AddInformation);
      }

      if (Details)
      {
        ::FileWriteString(handle, ((AddInformation == NULL) ? NULL : "\n") +
                                  "; saved on " + (string)::TimeLocal() + "\n; " +
                                  this.Header.expert_path[] + "\n; " +
                                  this.Header.symbol[] + "\n; " +
                                  ::TimeToString(this.Header.date_from, TIME_DATE) + " - " + ::TimeToString(this.Header.date_to, TIME_DATE) + "\n; " +
                                  ::DoubleToString(this[Num].TesterStatistics(STAT_PROFIT), 0) + ", " +
                                  ::DoubleToString(this[Num].TesterStatistics(STAT_TRADES), 0) + ", " +
                                  ::DoubleToString(this[Num].TesterStatistics(STAT_PROFIT_FACTOR), 2) + ", " +
                                  ::DoubleToString(this[Num].TesterStatistics(STAT_EXPECTED_PAYOFF), 2) +  ", -" +
                                  ::DoubleToString(this[Num].TesterStatistics(STAT_EQUITY_DD), 2) +
                                  "\n;\n");

      }

      ::FileWriteString(handle, this.SettingsString(Num));

      if (Details)
      {
        string Str = ";\n" + this[Num].ToString() + "\n" + this.Header.ToString();

        ::StringReplace(Str, "\n", "\n; ");

        ::FileWriteString(handle, Str);
      }

      ::FileClose(handle);
    }

    return(Res);
  }

  const T operator[]( const int Num ) const
  {
    return(this.Record[Num].Result);
  }

  int GetAmount( void ) const
  {
    return(::ArraySize(this.Record));
  }

  int SortByStat( const ENUM_STATISTICS Stat, int &Pos[] ) const
  {
    double Array[][2];

    const int Size = ::ArrayResize(Array, this.GetAmount());

    for (int i = 0; i < Size; i++)
    {
      Array[i][0] = this[i].TesterStatistics(Stat);
      Array[i][1] = i;
    }

    ::ArraySort(Array);

    for (int i = ArrayResize(Pos, Size) - 1; i >= 0; i--)
      Pos[i] = (int)(Array[i][1] + 0.1);

    return(Size);
  }

  int SortByCrit( const int Crit, int &Pos[] ) const
  {
    double Array[][2];

    const int Size = ::ArrayResize(Array, this.GetAmount());

    for (int i = 0; i < Size; i++)
    {
      Array[i][0] = this[i].GetCriterionResult(Crit);
      Array[i][1] = i;
    }

    ::ArraySort(Array);

    for (int i = ArrayResize(Pos, Size) - 1; i >= 0; i--)
      Pos[i] = (int)(Array[i][1] + 0.1);

    return(Size);
  }
};

#endif // __TESTERCACHE__