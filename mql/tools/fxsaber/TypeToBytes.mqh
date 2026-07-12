// MQL4&5-code
#ifndef __TYPETOBYTES__
#define __TYPETOBYTES__

template <typename T>
class CASTING
{
public:
  template <typename T1>
  static const T Casting( const T1 &Value )
  {
#ifdef TYPETOBYTES_FULL_SLOW
    static const bool IsScript = ((ENUM_PROGRAM_TYPE)::MQLInfoInteger(MQL_PROGRAM_TYPE) == PROGRAM_SCRIPT);
    static bool FirstRun = true;

    T Data = {};

    if (FirstRun)
    {
      if (IsScript)
      {
        const int handle = ::FileOpen("Casting.tmp", FILE_READ | FILE_WRITE | FILE_BIN);

        if (handle != INVALID_HANDLE)
        {
          ::FileWriteStruct(handle, Value);

          ::FileSeek(handle, 0, SEEK_SET);
          ::FileReadStruct(handle, Data);

          ::FileClose(handle);
        }
      }
      else
      {
        ::Alert("TYPETOBYTES_FULL_SLOW-mode only for Scripts!");

        FirstRun = false;
      }
    }

    return(Data);
#else // TYPETOBYTES_FULL_SLOW
    union CAST
    {
      T1 Value1;
      const T Value2;

      CAST( const T1 &Value)
      {
        this.Value1 = Value; // ��������� �������� ����� ��� ���������
      }
    };

    const CAST Union(Value);

    return(Union.Value2);
#endif // TYPETOBYTES_FULL_SLOW
  }
};

#define _C(A, B) CASTING<A>::Casting(B)
#define _R(A) TYPETOBYTES::Read(A)
#define _W(A) A=TYPETOBYTES::Write(A)
#define _OFFSET(A,B) TYPETOBYTES::Offset(A, A.B)
#define _WRONG_ASSIGN_OPERATOR(A) TYPETOBYTES::IsWrongAssignOperator<A>()

#define EQUAL_DEFINE(A)                 \
  template <typename T1>                \
  bool operator ==( const T1 &A ) const \
  {                                     \
    return(::ArrayCompare(this.Bytes,   \
           _R(Value).Bytes) == 0);      \
  }                                     \
                                        \
  template <typename T1>                \
  bool operator !=( const T1 &A ) const \
  {                                     \
    return(!(this == Value));           \
  }

#define CONSTRUCTOR_DEFINE(A)                                  \
  template <typename T1>                                       \
  T1 operator []( const T1 Pos ) const                         \
  {                                                            \
    STRUCT_TYPE<T1> Res = {};                                 \
    const int iPos = (int)Pos;                                 \
                                                               \
    if (iPos + sizeof(T1) <= ::ArraySize(this.Bytes))          \
    {                                                          \
      STRUCT_READ<T1> Tmp = {};                               \
                                                               \
      ::ArrayCopy(Tmp.Bytes, this.Bytes, 0, iPos, sizeof(T1)); \
                                                               \
      Res = _C(STRUCT_TYPE<T1>, Tmp);                          \
    }                                                          \
                                                               \
    return(Res.Value);                                         \
  }                                                            \
                                                               \
  string operator []( const string Pos ) const                 \
  {                                                            \
    string Res = NULL;                                         \
    const int iPos = (int)Pos;                                 \
    const int Size = ::ArraySize(this.Bytes);                  \
    int iEnd = iPos;                                           \
                                                               \
    while ((iEnd < Size) && (this.Bytes[iEnd] != 0))           \
      iEnd++;                                                  \
                                                               \
    if (iPos < Size)                                           \
    {                                                          \
      uchar TmpBytes[];                                        \
                                                               \
      ::ArrayCopy(TmpBytes, this.Bytes, 0, iPos, iEnd - iPos); \
                                                               \
      _W(Res) = TmpBytes;                                      \
    }                                                          \
                                                               \
    return(Res);                                               \
  }                                                            \
                                                               \
  EQUAL_DEFINE(Value)                                          \
  EQUAL_DEFINE(Value[])

struct STRUCT_READ_ARRAY
{
  uchar Bytes[];

  STRUCT_READ_ARRAY( void )
  {
  }

  template <typename T>
  STRUCT_READ_ARRAY( const T &Value[] )
  {

    if ((typename(T) == "uchar") || (typename(T) == "char"))
      ::ArrayCopy(this.Bytes, Value);
    else
    {
      const int Size = ::ArraySize(Value);
      const int Step = sizeof(T);

      ::ArrayResize(this.Bytes, Size * Step);

      for (int i = 0, j = 0; i < Size; i++, j += Step)
        ::ArrayCopy(this.Bytes, _R(Value[i]).Bytes, j);
    }
  }

  STRUCT_READ_ARRAY( const string &Value[] )
  {
    const int Size = ::ArraySize(Value);

    for (int i = 0, j = 0; i < Size; j += ::StringLen(Value[i++]) + 1)
      ::ArrayCopy(this.Bytes, _R(Value[i]).Bytes, j);
  }

  STRUCT_READ_ARRAY( const string &Value )
  {
    ::StringToCharArray(Value, this.Bytes);
  }

  void operator =( const STRUCT_READ_ARRAY &Value )
  {
    ::ArrayCopy(this.Bytes, Value.Bytes);

    return;
  }

  CONSTRUCTOR_DEFINE(STRUCT_READ_ARRAY)
};

#define DEFINE_TYPES                                         \
  M(char) M(short) M(int) M(long) M(uchar) M(ushort) M(uint) \
  M(ulong) M(bool) M(double) M(float) M(color) M(datetime)

template <typename T>
struct STRUCT_TYPE
{
private:
  template <typename T1>
  void Set( STRUCT_TYPE<T1> &Struct, const T1 &tValue ) const
  {
    Struct = _C(STRUCT_TYPE<T1>, tValue);
  }

#define M(A)                                               \
  void Set( STRUCT_TYPE<A> &Struct, const A tValue ) const \
  {                                                        \
    Struct.Value = tValue;                                 \
  }

  DEFINE_TYPES

#undef M

public:
  T Value;

  void operator =( const T& tValue )
  {
    // ������� ��������� ��������� �������� ������������ � T-����
    // https://www.mql5.com/ru/forum/1111/page1870#comment_4863733
    this.Set(this, tValue);
  }
};

template <typename T>
struct STRUCT_READ
{
  uchar Bytes[sizeof(T)];

  void operator =( const T &Value )
  {
    const STRUCT_TYPE<T> Res = Value;

    this = _C(STRUCT_READ<T>, Res);
  }

  CONSTRUCTOR_DEFINE(STRUCT_READ)
};

#undef CONSTRUCTOR_DEFINE
#undef EQUAL_DEFINE

template <typename T>
struct STRUCT_WRITE
{
private:
  T Data;
  int Pos;

  template <typename T1>
  T1 GetValue( const T1&, const uchar &Array[] ) const
  {
    STRUCT_READ<T1> Res = {};

    // �������� ���� ����������, �.�. � MQL4 ����������� ������� ����� ������ ������
    ::ArrayCopy(Res.Bytes, Array, 0, 0, ::MathMin(::ArraySize(Array), ::ArraySize(Res.Bytes)));

    return(_C(STRUCT_TYPE<T1>, Res).Value);
  }

  string GetValue( const string&, const uchar &Array[] ) const
  {
    return(::CharArrayToString(Array));
  }

public:
  STRUCT_WRITE( const T &Value )
  {
    this.Data = Value;
    this.Pos = 0;
  }

  STRUCT_WRITE<T> operator []( const int iPos )
  {
    this.Pos = iPos;

    return(this);
  }

  // ����� ��� ����������� return(this)
  void operator =( const STRUCT_WRITE<T> &Value )
  {
    this.Data = Value.Data;
    this.Pos = Value.Pos;

    return;
  }

  // ����� ��� ����������� return(this)
  STRUCT_WRITE( void )
  {
  }

#define OPERATOR_DEFINE(A   )                         \
  template <typename T1>                              \
  T operator =( const T1 A ) const                    \
  {                                                   \
    uchar TmpBytes[];                                 \
    ::ArrayCopy(TmpBytes, _R(this.Data).Bytes);       \
                                                      \
    ::ArrayCopy(TmpBytes, _R(Value).Bytes, this.Pos); \
                                                      \
    return(this.GetValue(this.Data, TmpBytes));       \
  }

  OPERATOR_DEFINE(Value)
  OPERATOR_DEFINE(&Value)
  OPERATOR_DEFINE(&Value[])

#undef OPERATOR_DEFINE

  T operator =( const string &Value[] ) const
  {
    uchar TmpBytes[];
    ::ArrayCopy(TmpBytes, _R(this.Data).Bytes);

    if (typename(T) == "string") // ����� ����� ��������� ������ � ������, ����� ����� ����������
    {
      const int Size = ::ArraySize(Value);

      for (int i = 0, j = this.Pos; i < Size; j += ::StringLen(Value[i++])/* + 1*/) // ��� ������� ������� - ������������� ������� ������������
        ::ArrayCopy(TmpBytes, _R(Value[i]).Bytes, j);
    }
    else
      ::ArrayCopy(TmpBytes, _R(Value).Bytes, this.Pos);

    return(this.GetValue(this.Data, TmpBytes));
  }
};

class TYPETOBYTES
{
private:
  template <typename T>
  static const STRUCT_TYPE<T> FillBytes( const uchar Byte = UCHAR_MAX )
  {
    STRUCT_READ<T> Res = {};

    ::ArrayInitialize(Res.Bytes, Byte);

    return(_C(STRUCT_TYPE<T>, Res));
  }

public:
#define READ_DEFINE(A, B, C)       \
  static const B Read( const C A ) \
  {                                \
    const B Res = Value;           \
                                   \
    return(Res);                   \
  }

  template <typename T>
  READ_DEFINE(&Value, STRUCT_READ<T>, T)

  template <typename T>
  READ_DEFINE(&Value[], STRUCT_READ_ARRAY, T)

#define M(A) READ_DEFINE(Value, STRUCT_READ<A>, A)

  DEFINE_TYPES

#undef M
#undef READ_DEFINE
#undef DEFINE_TYPES

  static const STRUCT_READ_ARRAY Read( const string Value )
  {
    const STRUCT_READ_ARRAY Res(Value);

    return(Res);
  }

  template <typename T>
  static STRUCT_WRITE<T> Write( const T &Value )
  {
    const STRUCT_WRITE<T> Res(Value);

    return(Res);
  }

  template <typename T>
  static bool IsWrongAssignOperator( void )
  {
    bool Res = (sizeof(T) != 0);

    if (Res)
    {
      STRUCT_TYPE<T> NotNull_Type = TYPETOBYTES::FillBytes<T>();
      STRUCT_TYPE<T> Null_Type = {};

      T NotNull = NotNull_Type.Value;
      T Null = Null_Type.Value;

      // ����������, ����� �������� - https://www.mql5.com/ru/forum/1111/page1874#comment_4871926
      // ������� ����� �������� - https://www.mql5.com/ru/forum/95447/page3#comment_4872456
      const STRUCT_TYPE<T> constNotNull_Type = NotNull_Type;
      const STRUCT_TYPE<T> constNull_Type = Null_Type;

      const T constNotNull = constNotNull_Type.Value;
      const T constNull = constNull_Type.Value;


      Res = ((_R(Null) != Null_Type.Value) || (_R(NotNull) != NotNull_Type.Value) || (_R(Null) == NotNull) ||
             (_R(constNull) != Null_Type.Value) || (_R(constNotNull) != NotNull_Type.Value) || (_R(constNull) == constNotNull));
    }

    return(Res);
  }

 // Co-author - https://www.mql5.com/ru/users/alximiks
 // Return the first shift of Field bit in the Struct.
  template <typename T1, typename T2>
  static int Offset( T1 &Struct, T2 &Field )
  {
    int Res = -1;

    if (!TYPETOBYTES::IsWrongAssignOperator<T2>())
    {
      const STRUCT_TYPE<T2> StoredField = Field; // ������� T2-�������� ������������

      // get Struct where Field value is with all unset bits (0000...)
      const STRUCT_TYPE<T2> Null = {};
      Field = Null.Value;

      const STRUCT_READ<T1> StructWithUnsetField = _C(STRUCT_READ<T1>, Struct);

      // get Struct where Field value is with all set bits (1111...)
      Field = TYPETOBYTES::FillBytes<T2>().Value;
      const STRUCT_READ<T1> StructWithSetField = _C(STRUCT_READ<T1>, Struct);

      //restore Struct data
      Field = StoredField.Value;

      for (int i = 0; i < sizeof(T1); i++)
        if (StructWithUnsetField.Bytes[i] != StructWithSetField.Bytes[i])
        {
          Res = i;

          break;
        }
    }

    return(Res);
  }

  template <typename T1, typename T2>
  static int Offset( T1 &Struct, T2 &Field[] )
  {
    int Res = -1;

    if (!TYPETOBYTES::IsWrongAssignOperator<T2>())
    {
      const STRUCT_TYPE<T2> StoredField = Field[0]; // ������� T2-�������� ������������

      // get Struct where Field value is with all unset bits (0000...)
      const STRUCT_TYPE<T2> Null = {};
      Field[0] = Null.Value;

      const STRUCT_READ<T1> StructWithUnsetField = _C(STRUCT_READ<T1>, Struct);

      // get Struct where Field value is with all set bits (1111...)
      Field[0] = TYPETOBYTES::FillBytes<T2>().Value;
      const STRUCT_READ<T1> StructWithSetField = _C(STRUCT_READ<T1>, Struct);

      //restore Struct data
      Field[0] = StoredField.Value;

      for (int i = 0; i < sizeof(T1); i++)
        if (StructWithUnsetField.Bytes[i] != StructWithSetField.Bytes[i])
        {
          Res = i;

          break;
        }
    }

    return(Res);
  }
};

// ���������� ArrayCopy, ���������� ���������� ������������� ������
template <typename T1, typename T2>
int _ArrayCopy( T1 &Dst_Array[], const T2 &Src_Array[], const int Dst_Start = 0, const int Src_Start = 0, const int Count = WHOLE_ARRAY )
{
  int Amount;

  if (((typename(T1) == "uchar") || (typename(T1) == "char")) && ((typename(T2) == "uchar") || (typename(T2) == "char")))
  {
    Amount = ::ArrayCopy(Dst_Array, Src_Array, Dst_Start, Src_Start, Count);

    // https://www.mql5.com/ru/forum/170952/page209#comment_25563569
    if (!::ArraySize(Src_Array) && (ArraySize(Dst_Array) < Dst_Start))
      ::ArrayResize(Dst_Array, Dst_Start);
  }
  else
  {
    STRUCT_READ_ARRAY Dst(Dst_Array);

    // https://www.mql5.com/ru/forum/363680/page22#comment_21520985
    const bool Flag = (typename(T2) == "uchar") || (typename(T2) == "char");

    Amount = /*_WRONG_ASSIGN_OPERATOR(T1) ? 0 : */(Flag ? // https://www.mql5.com/ru/forum/1111/page2011#comment_5716224
//    Amount = /*_WRONG_ASSIGN_OPERATOR(T1) ? 0 : */(((typename(T2) == "uchar") || (typename(T2) == "char")) ? // https://www.mql5.com/ru/forum/1111/page2011#comment_5716224
                                              ::ArrayCopy(Dst.Bytes, Src_Array, Dst_Start, Src_Start, Count) :
                                              ::ArrayCopy(Dst.Bytes, _R(Src_Array).Bytes, Dst_Start, Src_Start, Count));

    // https://www.mql5.com/ru/forum/170952/page209#comment_25563569
    const bool Flag2 = !::ArraySize(Src_Array) && (ArraySize(Dst.Bytes) < Dst_Start);

    if (Flag2)
      ::ArrayResize(Dst.Bytes, Dst_Start);

    if ((Amount > 0) || Flag2)
    {
      if ((typename(T1) == "uchar") || (typename(T1) == "char"))
        ::ArrayCopy(Dst_Array, Dst.Bytes);
      else
      {
        const int Step = sizeof(T1);

        const int Size = ::ArraySize(Dst.Bytes);
        ::ArrayResize(Dst_Array, Size / Step + ((Size % Step == 0) ? 0 : 1));

        const int TmpEnd = Dst_Start + Amount;
        const int End = ::MathMin(TmpEnd / Step + ((TmpEnd % Step == 0) ? 1 : 2), ::ArraySize(Dst_Array));

        STRUCT_READ<T1> Tmp;

        for (int i = Dst_Start / Step, j = i * Step; i < End; i++, j += Step)
        {
          ::ArrayCopy(Tmp.Bytes, Dst.Bytes, 0, j, Step);

          Dst_Array[i] = _C(STRUCT_TYPE<T1>, Tmp).Value;
        }
      }
    }
  }

  return(Amount);
}

// ���������� ���������� ������������� �����
template <typename T>
int _ArrayCopy( string &Dst_Array[], const T &Src_Array[], const int Dst_Start = 0, const int Src_Start = 0, const int Count = WHOLE_ARRAY )
{
  const int Amount = ((Count == WHOLE_ARRAY) ? ::ArraySize(Src_Array) * sizeof(T) - Src_Start : Src_Start + Count);

  int Res = 0;

  if (Amount > 0)
    for (int i = Dst_Start, Pos = Src_Start; Pos < Amount ; i++)
    {
      if (i >= ::ArraySize(Dst_Array))
        ::ArrayResize(Dst_Array, i + 1);

      _W(Dst_Array[i]) = _R(Src_Array)[(string)Pos];

      Pos += ::StringLen(Dst_Array[i]) + 1;

      Res++;
    }

  return(Res);
}

template <typename T>
int _ArrayResize( T &Array[], const int Size )
{
  return(sizeof(T) * ::ArrayResize(Array, Size / sizeof(T) + ((bool)(Size % sizeof(T)) ? 1 : 0)));
}

// �������� ��������� ����� ��������� ������� �� ����� ������� �������.
// ���������� ���������� ������ ����� ������.
template <typename T1, typename T2>
int _ArrayReplace( T1 &Dst_Array[], const T2 &Src_Array[],
                   const int Dst_Start = 0, const int Dst_Count = WHOLE_ARRAY,
                   const int Src_Start = 0, const int Src_Count = WHOLE_ARRAY )
{
  uchar TmpData[];

  const bool FlagTmpData = (Dst_Count != WHOLE_ARRAY);

  if (FlagTmpData)
    _ArrayCopy(TmpData, Dst_Array, 0, Dst_Start + Dst_Count);

  _ArrayResize(Dst_Array, Dst_Start);

  const int Res = _ArrayCopy(Dst_Array, Src_Array, Dst_Start, Src_Start, Src_Count);

  if (FlagTmpData)
    _ArrayCopy(Dst_Array, TmpData, Dst_Start + Res);

  return(Res);
}

template <typename T>
class CONTAINER
{
private:
  int AmountBytes;

  string Types[];
  int Pos;
  int Amount;

  int GetPosBytes( void ) const
  {
    int Res = 0;

    for (int i = 0; i < this.Pos; i++)
      Res += _R(this.Data)[Res] + sizeof(int);

    return(Res);
  }

public:
  T Data[];

  CONTAINER( void ) : AmountBytes(0), Pos(-1), Amount(0)
  {
  }

  string GetType( void ) const
  {
    return(this.Types[(this.Pos == -1) ? 0 : this.Pos]);
  }

  CONTAINER* operator []( const int iPos )
  {
    this.Pos = iPos;

    return(&this);
  }

  int GetAmount( void ) const
  {
    return(this.Amount);
  }

#define OPERATOR_MACROS(A, B)                                                       \
  template <typename T1>                                                            \
  void operator =( const T1 A )                                                     \
  {                                                                                 \
    uchar Bytes[];                                                                  \
                                                                                    \
    ::ArrayCopy(Bytes, _R(::ArrayCopy(Bytes, _R(Value).Bytes, sizeof(int))).Bytes); \
                                                                                    \
    if ((this.Pos >= this.Amount) || (this.Pos == -1))                              \
    {                                                                               \
      this.Amount = ::ArrayResize(this.Types, this.Amount + 1);                     \
      this.Pos = this.Amount - 1;                                                   \
                                                                                    \
      this.AmountBytes += _ArrayCopy(this.Data, Bytes, this.AmountBytes);           \
    }                                                                               \
    else                                                                            \
    {                                                                               \
      const int PosBytes = this.GetPosBytes();                                      \
      const int Count = _R(this.Data)[PosBytes] + sizeof(int);                      \
                                                                                    \
      this.AmountBytes += _ArrayReplace(this.Data, Bytes, PosBytes, Count) - Count; \
    }                                                                               \
                                                                                    \
    this.Types[this.Pos] = typename(T1) + B;                                        \
    this.Pos = -1;                                                                  \
                                                                                    \
    return;                                                                         \
  }

  OPERATOR_MACROS(Value, "")
  OPERATOR_MACROS(&Value, "")
  OPERATOR_MACROS(&Value[], "[" + (string)::ArraySize(Value) + "]")
#undef OPERATOR_MACROS
/*
  template <typename T1>
  void operator =( CONTAINER<T1> &Container )
  {
    this.AmountBytes = Container.AmountBytes;

    this.Amount = Container.Amount;
    ::ArrayCopy(this.Types, Container.Types);
    _ArrayCopy(this.Data, Container.Data);

    return;
  }
*/
  template <typename T1>
  void Get( T1 &Value ) const
  {
    const int PosBytes = this.GetPosBytes();
    const int Count = _R(this.Data)[PosBytes];

    uchar Bytes[];

    _ArrayCopy(Bytes, this.Data, 0, PosBytes + sizeof(int), Count);

    _W(Value) = Bytes;

    return;
  }

  template <typename T1>
  int Get( T1 &Value[] ) const
  {
    const int PosBytes = this.GetPosBytes();
    const int Count = _R(this.Data)[PosBytes];

    _ArrayCopy(Value, this.Data, 0, PosBytes + sizeof(int), Count);

    return(::ArraySize(Value));
  }

  template <typename T1>
  T1 Get() const
  {
    T1 Res;

    this.Get(Res);

    return(Res);
  }
};
#endif // __TYPETOBYTES__