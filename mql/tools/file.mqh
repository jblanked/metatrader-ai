//+------------------------------------------------------------------+
//|                                                         file.mqh |
//|                                      Copyright 2026,JBlanked LLC |
//|                                         https://www.jblanked.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked LLC"
#property link      "https://www.jblanked.com"
#property strict

#include "JSON.mqh"

#import "shell32.dll"
int ShellExecuteW(int hWnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

#define FILE_COMMON_FOLDER TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\" + "Files" + "\\"
#define FILE_PRINT_RETURN(msg) do { Print(msg); return msg; } while(0)
#define FILE_RETURN(res) (res > 32 ? "true" : "false")
#define FILE_TEMP_FOLDER "metatrader-ai\\temp"


// forwards (in mql4 is shows import warning)
#ifdef __MQL5__
string fileCopy(const string src, const string dest);
string fileDelete(const string path);
string fileExists(const string path);
string fileList(const string folder, const string key = "", const string ext = "", const bool recursive = false);
string fileMove(const string src, const string dest);
string fileRead(const string path);
string fileWrite(const string path, char &data[], int index = 0, bool overwrite = true);
#endif

// helper
#ifdef __MQL5__
string getFileNameFromPath(const string path);
#endif

//+------------------------------------------------------------------+
//| Copy a file from source to destination                           |
//+------------------------------------------------------------------+
string fileCopy(const string src, const string dest)
{
   const int result = ShellExecuteW(0, "open", "cmd.exe", ("/C copy /Y \"" + src + "\" \"" + dest + "\""), NULL, 0);
   return FILE_RETURN(result);
}

//+------------------------------------------------------------------+
//| Delete a file from path                                          |
//+------------------------------------------------------------------+
string fileDelete(const string path)
{
   if(fileExists(path) == "true")
   {
      const int result = ShellExecuteW(0, "open", "cmd.exe", ("/C del /F /Q \"" + path + "\""), NULL, 0);
      return FILE_RETURN(result);
   }
   return "true";
}

//+------------------------------------------------------------------+
//| Check if a path exists                                           |
//+------------------------------------------------------------------+
string fileExists(const string path)
{
   const string tempName   = "fexists_" + (string)GetTickCount() + ".txt";
   const string tempRel    = "metatrader-ai\\temp\\" + tempName;
   const string commonPath = FILE_COMMON_FOLDER + tempRel;
   if(!::FolderCreate("metatrader-ai", FILE_COMMON) || !::FolderCreate(FILE_TEMP_FOLDER, FILE_COMMON))
   {
      FILE_PRINT_RETURN("Failed to create temporary read folder");
   }

   const string cmd = "-NoProfile -Command \"$r = Test-Path '" + path + "'; $r.ToString().ToLower() | Out-File -FilePath '" + commonPath + "' -Encoding ascii -Force\"";
   const int shellResult = ShellExecuteW(0, "open", "powershell.exe", cmd, NULL, 0);
   if(shellResult <= 32)
   {
      FILE_PRINT_RETURN("Failed to run powershell, error: " + (string)shellResult);
   }

   for(int i = 0; i < 30; i++)
   {
      Sleep(100);
      if(::FileIsExist(tempRel, FILE_COMMON)) break;
   }

   int handle = ::FileOpen(tempRel, FILE_READ | FILE_COMMON | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      FILE_PRINT_RETURN("Failed to open file! error: " + (string)GetLastError());
   }

   string result = ::FileReadString(handle);
   ::FileClose(handle);
   StringTrimRight(result);
   StringTrimLeft(result);
   ShellExecuteW(0, "open", "cmd.exe", ("/C del /F /Q \"" + commonPath + "\""), NULL, 0);
   return result == "true" ? "true" : "false";
}

//+------------------------------------------------------------------+
//| Move a file from source to destination                           |
//+------------------------------------------------------------------+
string fileMove(const string src, const string dest)
{
   const int result = ShellExecuteW(0, "open", "cmd.exe", ("/C move /Y \"" + src + "\" \"" + dest + "\""), NULL, 0);
   return FILE_RETURN(result);
}

//+------------------------------------------------------------------+
//| List files in a folder optionally matching key and extension     |
//+------------------------------------------------------------------+
string fileList(const string folder, const string key = "", const string ext = "", const bool recursive = false)
{
   const string tempName   = "flist_" + (string)GetTickCount() + ".txt";
   const string tempRel    = "metatrader-ai\\temp\\" + tempName;
   const string commonPath = FILE_COMMON_FOLDER + tempRel;
   if(!::FolderCreate("metatrader-ai", FILE_COMMON) || !::FolderCreate(FILE_TEMP_FOLDER, FILE_COMMON))
   {
      FILE_PRINT_RETURN("Failed to create temporary list folder");
   }

   // Build the file name filter: "*<key>*<ext>"
   string filter = "*";
   if(key != "") filter += key;
   filter += "*";
   if(ext != "")
   {
      if(StringSubstr(ext, 0, 1) != ".") filter += ".";
      filter += ext;
   }

   const string recurse = recursive ? " -Recurse" : "";
   const string cmd = "-NoProfile -Command \"" +
      "if(Test-Path -LiteralPath '" + folder + "' -PathType Container){ " +
      "Get-ChildItem -LiteralPath '" + folder + "' -File -Filter '" + filter + "'" + recurse +
      " | ForEach-Object { $_.FullName } } | Out-File -FilePath '" + commonPath + "' -Encoding ascii -Force\"";
   const int shellResult = ShellExecuteW(0, "open", "powershell.exe", cmd, NULL, 0);
   if(shellResult <= 32)
   {
      FILE_PRINT_RETURN("Failed to run powershell, error: " + (string)shellResult);
   }

   for(int i = 0; i < 30; i++)
   {
      Sleep(100);
      if(::FileIsExist(tempRel, FILE_COMMON)) break;
   }

   int handle = ::FileOpen(tempRel, FILE_READ | FILE_COMMON | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      FILE_PRINT_RETURN("Failed to open list file! error: " + (string)GetLastError());
   }

   CJAVal result;
   result.m_type = jtARRAY;
   while(!::FileIsEnding(handle))
   {
      string line = ::FileReadString(handle);
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line != "")
      {
         result.Add(line);
      }
   }
   ::FileClose(handle);

   ::FileDelete(tempRel, FILE_COMMON);

   return result.Serialize();
}

//+------------------------------------------------------------------+
//| Read a file from path                                            |
//+------------------------------------------------------------------+
string fileRead(const string path)
{
   const string fileName   = getFileNameFromPath(path);
   const string commonPath = FILE_COMMON_FOLDER + FILE_TEMP_FOLDER + "\\" + fileName;
   if(!::FolderCreate("metatrader-ai", FILE_COMMON) || !::FolderCreate(FILE_TEMP_FOLDER, FILE_COMMON))
   {
      FILE_PRINT_RETURN("Failed to create temporary read folder");
   }
   const int fileCopyResult = ShellExecuteW(0, "open", "cmd.exe", ("/C copy /Y \"" + path + "\" \"" + commonPath + "\""), NULL, 0);
   if(fileCopyResult <= 32)
   {
      FILE_PRINT_RETURN("Failed to copy temp file! Retcode: " + string(fileCopyResult));
   }
   for(int i = 0; i < 30; i++)
   {
      Sleep(100);
      if(::FileIsExist(FILE_TEMP_FOLDER + "\\" + fileName, FILE_COMMON)) break;
   }
   int handle = ::FileOpen(FILE_TEMP_FOLDER + "\\" + fileName, FILE_READ | FILE_COMMON | FILE_TXT | FILE_ANSI);
   if (handle == INVALID_HANDLE)
   {
      FILE_PRINT_RETURN("Error '" + (string)GetLastError() + "', could not open file: " + commonPath);
   }
   string content = "";
   while (!::FileIsEnding(handle))
   {
      content += ::FileReadString(handle);
      if(!::FileIsEnding(handle)) content += "\n";
   }
   ::FileClose(handle);
   return content;
}

//+------------------------------------------------------------------+
//| Write bytes to a file                                            |
//+------------------------------------------------------------------+
string fileWrite(const string path, char &data[], int index = 0, bool overwrite = true)
{
   const bool exists = fileExists(path) == "true";

   if(!overwrite && exists && index == 0)
   {
      FILE_PRINT_RETURN("File already exists and overwrite is set to turned off so no action occurred.");
   }

   if(!::FolderCreate("metatrader-ai", FILE_COMMON) || !::FolderCreate(FILE_TEMP_FOLDER, FILE_COMMON))
   {
      FILE_PRINT_RETURN("Failed to create temporary write folder");
   }

   if(index == 0)
   {
      const string tempName  = "fwrite_" + (string)GetTickCount() + ".tmp";
      const string tempRel   = FILE_TEMP_FOLDER + "\\" + tempName;
      const string commonTmp = FILE_COMMON_FOLDER + tempRel;

      ::FileDelete(tempRel, FILE_COMMON);

      int handle = ::FileOpen(tempRel, FILE_WRITE | FILE_COMMON | FILE_BIN);
      if(handle == INVALID_HANDLE)
      {
         FILE_PRINT_RETURN("Failed to create temp file for write! error: " + (string)GetLastError());
      }

      const int dataLen = ArraySize(data);
      char trimmed[];
      ArrayCopy(trimmed, data, 0, 0, (dataLen > 0 && data[dataLen - 1] == 0) ? dataLen - 1 : dataLen);

      ::FileWriteArray(handle, trimmed);
      ::FileClose(handle);

      fileCopy(commonTmp, path);

      bool copied = false;
      for(int i = 0; i < 100; i++)
      {
         Sleep(100);
         if(fileExists(path) == "true")
         {
            copied = true;
            break;
         }
      }

      ::FileDelete(tempRel, FILE_COMMON);
      return copied ? "true" : "false";
   }

   const string fileName   = getFileNameFromPath(path);
   const string commonPath = FILE_COMMON_FOLDER + FILE_TEMP_FOLDER + "\\" + fileName;

   fileCopy(path, commonPath);

   bool copied = false;
   for(int i = 0; i < 100; i++)
   {
      Sleep(100);
      if(::FileIsExist(FILE_TEMP_FOLDER + "\\" + fileName, FILE_COMMON))
      {
         copied = true;
         break;
      }
   }

   if(!copied)
   {
      FILE_PRINT_RETURN("Failed to copy file to temp for indexed write.");
   }

   int handle = ::FileOpen(FILE_TEMP_FOLDER + "\\" + fileName, FILE_READ | FILE_WRITE | FILE_COMMON | FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      FILE_PRINT_RETURN("Failed to open temp file for indexed write! error: " + (string)GetLastError());
   }
   ::FileSeek(handle, index, SEEK_SET);
   const int dataLen = ArraySize(data);
   char trimmed[];
   ArrayCopy(trimmed, data, 0, 0, (dataLen > 0 && data[dataLen - 1] == 0) ? dataLen - 1 : dataLen);
   ::FileWriteArray(handle, trimmed);
   ::FileClose(handle);
   return fileMove(commonPath, path) == "true" ? "true" : "false";
}

//+------------------------------------------------------------------+
//| Helper to get a file name from a path                            |
//+------------------------------------------------------------------+
string getFileNameFromPath(const string path)
{
   int slash = -1;
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
      Print("Failed to find last slash!");
      return "";
   }
   return StringSubstr(path, slash + 1);
}

//+------------------------------------------------------------------+