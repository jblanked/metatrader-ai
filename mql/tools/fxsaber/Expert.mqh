#ifndef __EXPERT_MQH__
#define __EXPERT_MQH__

#define FILENAME (__FILE__ + ".tpl")
#define PATH "\\Files\\"
#define STRING_END "\r\n"
#define EXPERT_BEGIN ("<expert>" + STRING_END)
#define EXPERT_END ("</expert>" + STRING_END)
#define EXPERT_INPUT_BEGIN ("<inputs>" + STRING_END)
#define EXPERT_INPUT_END ("</inputs>" + STRING_END)
#define EXPERT_CHART_BEGIN ("<chart>" + STRING_END)
#define EXPERT_NAME "name="
#define EXPERT_PATH "path="
#define EXPERT_STOPLEVEL "stops_color="

class EXPERT
{
private:
  static bool StringReplace( string &Str, const string StrBegin, const string StrEnd, const string StrNew )
  {
    const int PosBegin = ::StringFind(Str, StrBegin);
    const bool Res = (PosBegin >= 0);

    if (Res)
    {
      const int PosEnd = ::StringFind(Str, StrEnd, PosBegin + ::StringLen(StrBegin));

      Str = ::StringSubstr(Str, 0, PosBegin) + StrNew + ((PosEnd >= 0) ? ::StringSubstr(Str, PosEnd + ::StringLen(StrEnd)): NULL);
    }

    return(Res);
  }

  static string StringBetween( string &Str, const string StrBegin, const string StrEnd = NULL )
  {
    int PosBegin = ::StringFind(Str, StrBegin);
    PosBegin = (PosBegin >= 0) ? PosBegin + ::StringLen(StrBegin) : 0;

    const int PosEnd = ::StringFind(Str, StrEnd, PosBegin);

    const string Res = ::StringSubstr(Str, PosBegin, (PosEnd >= 0) ? PosEnd - PosBegin : -1);
    Str = (PosEnd >= 0) ? ::StringSubstr(Str, PosEnd + ::StringLen(StrEnd)) : NULL;

    if (Str == "")
      Str = NULL;

    return(Res);
  }

  static string StringBetween2( string &Str, const string StrBegin, const string StrEnd = NULL )
  {
    return(StrBegin + EXPERT::StringBetween(Str, StrBegin, StrEnd) + StrEnd);
  }

  static string TemplateToString( const long Chart_ID = 0, const bool CheckExpert = false )
  {
    short Data[];

    return(((!CheckExpert || EXPERT::Is(Chart_ID)) && ::ChartSaveTemplate((ulong)Chart_ID, PATH + FILENAME) && (::FileLoad(FILENAME, Data) > 0)) ?
           ::ShortArrayToString(Data) : NULL);
  }

  static bool TemplateApply( const long Chart_ID, const string &Str, const bool Sync = true )
  {
    string TmpStr = Str;

    const bool SyncFlag = (Sync && Chart_ID && (Chart_ID != ::ChartID()) && !::IsStopped());

    if (SyncFlag)
    {
      const color ColorStopLevel = (color)::ChartGetInteger(Chart_ID, CHART_COLOR_STOP_LEVEL);

      if ((bool)(ColorStopLevel >> 24))
        ::ChartSetInteger(Chart_ID, CHART_COLOR_STOP_LEVEL, ColorStopLevel & 0xFFFFFF);

      const int NewColorStopLevel = (int)EXPERT::StringBetween(TmpStr, EXPERT_STOPLEVEL, STRING_END) | (0x01 << 24);

      TmpStr = Str;
      EXPERT::StringReplace(TmpStr, EXPERT_STOPLEVEL, STRING_END, EXPERT_STOPLEVEL + (string)NewColorStopLevel + STRING_END);
    }

    short Data[];
    const bool Res = ::StringToShortArray(TmpStr, Data, 0, ::StringLen(TmpStr)) &&
                     ::FileSave(FILENAME, Data) && ::ChartApplyTemplate((ulong)Chart_ID, PATH + FILENAME);

    if (Res && SyncFlag)
    {
      long Value;

      while ((!::IsStopped() && ::ChartGetInteger(Chart_ID, CHART_COLOR_STOP_LEVEL, 0, Value) && (!(bool)((int)Value >> 24))))
        ::Sleep(0);

      ::ChartSetInteger(Chart_ID, CHART_COLOR_STOP_LEVEL, (int)Value & 0xFFFFFF);
    }

    return(Res);
  }

  static int CorrectMqlParams( MqlParam &Params[] )
  {
    const int Amount = ::ArraySize(Params);

    for (int i = 1; i < Amount; i++)
    {
      const ENUM_DATATYPE Type = Params[i].type;

      if ((Type == TYPE_FLOAT) || (Type == TYPE_DOUBLE))
        Params[i].string_value = (string)Params[i].double_value;
      else if (Type != TYPE_STRING)
        Params[i].string_value = (string)Params[i].integer_value;
    }

    return(Amount);
  }

  // Expert base name from path
  static string GetName( const string Path )
  {
    int LastSlash = -1;

    for (int i = ::StringLen(Path); i >= 0; i--)
      if (Path[i] == 92)
      {
        LastSlash = i;
        break;
      }

    string FileName = (LastSlash >= 0) ? ::StringSubstr(Path, LastSlash + 1) : Path;
    const int Ext = ::StringFind(FileName, ".ex5");

    return((Ext > 0) ? ::StringSubstr(FileName, 0, Ext) : FileName);
  }

public:
  // ������� �� �������� �� ��������������� �����?
  static bool Is( const long Chart_ID = 0 )
  {
    return(::ChartGetString(Chart_ID, CHART_EXPERT_NAME) != NULL);
  }

  // ������� � ���������������� ����� ��������
  static bool Remove( const long Chart_ID = 0 )
  {
    string Str = EXPERT::TemplateToString(Chart_ID, true);

    return((Str != NULL) && EXPERT::StringReplace(Str, EXPERT_BEGIN, EXPERT_END, NULL) && EXPERT::TemplateApply(Chart_ID, Str));
  }

  // ������������� �������� �� ��������������� �����
  static bool Reopen( const long Chart_ID = 0 )
  {
    const string Str = EXPERT::TemplateToString(Chart_ID, true);

    return((Str != NULL) && EXPERT::TemplateApply(Chart_ID, Str));
  }

  // �������� ������ � ���������� ��������� �� ��������������� �����
  static bool Parameters( const long Chart_ID,
                          MqlParam &Parameters[], // ���� � ��������� � �������� ��� ������� ����������
                          string &Names[] )       // ����� ������� ����������
  {
    string Str = EXPERT::TemplateToString(Chart_ID, true);
    const bool Res = (Str != NULL);

    if (Res)
    {
      Str = EXPERT::StringBetween(Str, EXPERT_BEGIN, EXPERT_END);

      ::ArrayFree(Parameters);
      ::ArrayFree(Names);

      int Amount = ::ArrayResize(Parameters, 1) - 1;

      Parameters[Amount].type = TYPE_STRING;
      Parameters[Amount].integer_value = 0;
      Parameters[Amount].double_value = 0;
      Parameters[Amount].string_value = EXPERT::StringBetween(Str, EXPERT_PATH, STRING_END);

      Str = EXPERT::StringBetween(Str, EXPERT_INPUT_BEGIN, EXPERT_INPUT_END);

      while (Str != NULL)
      {
        ::ArrayResize(Names, Amount + 1);
        Names[Amount] = EXPERT::StringBetween(Str, NULL, "=");
        Amount++;

        ::ArrayResize(Parameters, Amount + 1);
        Parameters[Amount].type = TYPE_STRING;
        Parameters[Amount].string_value = EXPERT::StringBetween(Str, NULL, STRING_END);
        Parameters[Amount].integer_value = (long)Parameters[Amount].string_value;
        Parameters[Amount].double_value = (double)Parameters[Amount].string_value;
      }
    }

    return(Res);
  }

  // ��������� �������� �� ��������������� �����
  static bool Run( const long Chart_ID,
                   MqlParam &Parameters[] ) // ���� � ��������� � �������� ��� ������� ����������
  {
    static bool FirstRun = true;

    string StrTemplate = EXPERT::TemplateToString(Chart_ID, false);

    bool Res = (StrTemplate != NULL);

    if (Res)
    {
       PrintFormat("Template created on chart id %d", Chart_ID);
       
      if (EXPERT::Is(Chart_ID))
      {
        string Str = StrTemplate;
        Str = EXPERT::StringBetween(Str, EXPERT_BEGIN, EXPERT_END);

        string StrTmp = Str;

        if (EXPERT::StringBetween(StrTmp, EXPERT_PATH, STRING_END) == Parameters[0].string_value)
        {
          string StrNew = EXPERT::StringBetween2(Str, NULL, EXPERT_INPUT_BEGIN);
          Str = EXPERT::StringBetween(Str, NULL, EXPERT_INPUT_END);

          const int Amount = EXPERT::CorrectMqlParams(Parameters);
          int i = 1;

          while (Str != NULL)
            if (i < Amount)
            {
              StrNew += EXPERT::StringBetween2(Str, NULL, "=") + Parameters[i].string_value + STRING_END;

              EXPERT::StringBetween(Str, NULL, STRING_END);

              i++;
            }
            else
              StrNew += EXPERT::StringBetween2(Str, NULL, STRING_END);

          StrNew = EXPERT_BEGIN + StrNew + EXPERT_INPUT_END + EXPERT_END;

          Res = EXPERT::StringReplace(StrTemplate, EXPERT_BEGIN, EXPERT_END, StrNew) && EXPERT::TemplateApply(Chart_ID, StrTemplate);
          PrintFormat("expert path res: %d", Res);
        }
        else if (FirstRun)
        {
          const string StrNew = EXPERT_BEGIN + EXPERT_NAME + EXPERT::GetName(Parameters[0].string_value) + STRING_END +
                                EXPERT_PATH + Parameters[0].string_value + STRING_END + EXPERT_END;

          FirstRun = false;
          Res = EXPERT::StringReplace(StrTemplate, EXPERT_BEGIN, EXPERT_END, StrNew) && EXPERT::TemplateApply(Chart_ID, StrTemplate) &&
                EXPERT::Run(Chart_ID, Parameters);
          PrintFormat("First run res: %d", Res);
          FirstRun = true;
        }
        else
        {
          FirstRun = true;

          Res = false;
          Print("res set to false - inner");
        }
      }
      else if (FirstRun)
      {
        StrTemplate = EXPERT::StringBetween2(StrTemplate, NULL, EXPERT_CHART_BEGIN) +
                      EXPERT_BEGIN + EXPERT_NAME + EXPERT::GetName(Parameters[0].string_value) + STRING_END +
                      EXPERT_PATH + Parameters[0].string_value + STRING_END + EXPERT_END + StrTemplate;

        FirstRun = false;
        Res = EXPERT::TemplateApply(Chart_ID, StrTemplate) && ((::ArraySize(Parameters) > 1) ? EXPERT::Run(Chart_ID, Parameters) : true);
         PrintFormat("firsr run outer-res: %d", Res);
        FirstRun = true;
      }
      else
      {
        FirstRun = true;

        Res = false;
        Print("res set to false- outer");
      }
    }
    else
    {
      PrintFormat("Failed to create template on chart id %d", Chart_ID);
    }

    return(Res);
  }
};

#undef EXPERT_STOPLEVEL
#undef EXPERT_PATH
#undef EXPERT_NAME
#undef EXPERT_CHART_BEGIN
#undef EXPERT_INPUT_END
#undef EXPERT_INPUT_BEGIN
#undef EXPERT_END
#undef EXPERT_BEGIN
#undef STRING_END
#undef PATH
#undef FILENAME

#endif // __EXPERT_MQH__