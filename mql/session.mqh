//+------------------------------------------------------------------+
//|                                                      session.mqh |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict

#include "tools/file.mqh"

#define SESSION_FOLDER "metatrader-ai\\sessions"

//+------------------------------------------------------------------+
//| Class representing a session                                     |
//+------------------------------------------------------------------+
class Session
{
public:
   long              id;
   string            name;
   int               lastAccessed;
   CJAVal            messages;

                     Session(bool create = true, bool shouldSaveOnExit = true);
                    ~Session();
   bool              load(string filename);
   bool              save();
   bool              active();          // True once created or loaded
private:
   bool              isSet;
   bool              saveOnExit;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
Session::Session(bool create, bool shouldSaveOnExit)
{
   if (!FolderCreate(SESSION_FOLDER, FILE_COMMON))
   {
      PrintFormat("Failed to create session folder: %s", SESSION_FOLDER);
      return;
   }

   if(create)
   {
      id           = (long)TimeCurrent();
      name         = StringFormat("session_%ld", id);
      lastAccessed = (int)id;
      isSet        = true;
   }
   else
   {
      id           = 0;
      name         = "";
      lastAccessed = 0;
      isSet        = false;
   }
   saveOnExit      = shouldSaveOnExit;
   messages.m_type = jtARRAY;
}

//+------------------------------------------------------------------+
//| Deconstructor                                                    |
//+------------------------------------------------------------------+
Session::~Session()
{
   if (saveOnExit && isSet)
   {
      save();
   }
}

//+------------------------------------------------------------------+
//| Load session data                                                |
//+------------------------------------------------------------------+
bool Session::load(string filename)
{
   const string fullPath = StringFormat("%s%s\\%s.json", FILE_COMMON_FOLDER, SESSION_FOLDER, filename);
   const string content = fileRead(fullPath);
   if (content == "") return false;
   CJAVal json;
   json.Deserialize(content);
   id = json["id"].ToInt();
   name = json["name"].ToStr();
   lastAccessed = (int)json["lastAccessed"].ToInt();
   messages.Set(json["messages"]);
   isSet = true;
   return true;
}

//+------------------------------------------------------------------+
//| Save session data                                                |
//+------------------------------------------------------------------+
bool Session::save()
{
   if(!isSet) return false;

   CJAVal json;
   json["id"]           = id;
   json["name"]         = name;
   json["lastAccessed"] = lastAccessed;
   json["messages"].Set(messages);

   const string fullPath = StringFormat("%s%s\\%s.json", FILE_COMMON_FOLDER, SESSION_FOLDER, name);
   const string content = json.Serialize();
   char data[];
   if(StringToCharArray(content, data) == -1)
   {
      PrintFormat("Failed to convert JSON content to char array for session: %s", name);
      return false;
   }
   return fileWrite(fullPath, data) == "true";
}
//+------------------------------------------------------------------+
//| True once the session has been created or loaded                 |
//+------------------------------------------------------------------+
bool Session::active()
{
   return isSet;
}

//+------------------------------------------------------------------+
//| List saved sessions, newest first                                |
//+------------------------------------------------------------------+
int sessionList(string &names[])
{
   ArrayResize(names, 0);
#ifdef __MQL5__
   string fname;
   long handle = FileFindFirst(SESSION_FOLDER + "\\*.json", fname, FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return 0;

   long ids[];
   do
   {
      string base = fname;
      int slash = StringFind(base, "\\");
      if(slash >= 0)
         base = StringSubstr(base, slash + 1);
      if(StringLen(base) < 6) continue;
      if(StringSubstr(base, StringLen(base) - 5) != ".json") continue;
      string sname = StringSubstr(base, 0, StringLen(base) - 5);
      if(StringSubstr(sname, 0, 8) != "session_") continue;
      int n = ArraySize(names);
      ArrayResize(names, n + 1);
      ArrayResize(ids, n + 1);
      names[n] = sname;
      ids[n] = StringToInteger(StringSubstr(sname, 8));
   }
   while(FileFindNext(handle, fname));
   FileFindClose(handle);

   int count = ArraySize(names);
   for(int i = 1; i < count; i++)
   {
      long keyId = ids[i];
      string keyName = names[i];
      int j = i - 1;
      while(j >= 0 && ids[j] < keyId)
      {
         ids[j + 1] = ids[j];
         names[j + 1] = names[j];
         j--;
      }
      ids[j + 1] = keyId;
      names[j + 1] = keyName;
   }
   return count;
#else
   return 0;
#endif
}
//+------------------------------------------------------------------+
