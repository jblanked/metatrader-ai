//+------------------------------------------------------------------+
//|                                                     requests.mqh |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict
#include "JSON.mqh"

#import "Wininet.dll"
int  InternetOpenW(string name, int config, string, string, int);
int  InternetOpenUrlW(int, string, string, int, int, int);
bool InternetReadFile(int, uchar &sBuffer[], int, int &OneInt);
bool InternetCloseHandle(int);
bool HttpSendRequestW(int hRequest, string lpszHeaders, int dwHeadersLength, char &lpOptional[], int dwOptionalLength);
int  InternetConnectW(int hInternet, string lpszServerName, int nServerPort, string lpszUserName, string lpszPassword, int dwService, int dwFlags, int dwContext);
int  HttpOpenRequestW(int hConnect, string lpszVerb, string lpszObjectName, string lpszVersion, string lpszReferer, string lplpszAcceptTypes, uint dwFlags, int dwContext);
#import

#ifdef __MQL5__
#define REQUEST_USER_AGENT "MetaTrader 5 Terminal (Wininet)"
#else
#define REQUEST_USER_AGENT "MetaTrader 4 Terminal (Wininet)"
#endif

#define INTERNET_SERVICE_HTTP        3
#define INTERNET_DEFAULT_HTTPS_PORT  443
#define INTERNET_DEFAULT_HTTP_PORT   80
#define INTERNET_FLAG_SECURE         ((uint)0x00800000)
#define INTERNET_FLAG_RELOAD         ((uint)0x80000000)
#define INTERNET_FLAG_NO_CACHE_WRITE ((uint)0x04000000)
#define HTTP_ADDREQ_FLAG_ADD         0x20000000

//
#ifdef __MQL5__
string requestGet(const string url, const string headers);                // send a GET request
string requestPost(const string url, const string headers, CJAVal &data); // send a POST request
#endif

//+------------------------------------------------------------------+
//| Parse scheme, host, port, and path from a URL                    |
//+------------------------------------------------------------------+
bool parseUrl(const string url, string &scheme, string &host, int &port, string &path)
{
   scheme = "";
   host   = "";
   path   = "/";
   port   = 80;

   int schemeEnd = StringFind(url, "://");
   if(schemeEnd < 0) return false;

   scheme = StringSubstr(url, 0, schemeEnd);
   StringToLower(scheme);

   string rest = StringSubstr(url, schemeEnd + 3);

   int slashPos = StringFind(rest, "/");
   string hostPort;
   if(slashPos < 0)
   {
      hostPort = rest;
      path     = "/";
   }
   else
   {
      hostPort = StringSubstr(rest, 0, slashPos);
      path     = StringSubstr(rest, slashPos);
   }

   int colonPos = StringFind(hostPort, ":");
   if(colonPos < 0)
   {
      host = hostPort;
      port = (scheme == "https") ? INTERNET_DEFAULT_HTTPS_PORT : INTERNET_DEFAULT_HTTP_PORT;
   }
   else
   {
      host = StringSubstr(hostPort, 0, colonPos);
      port = (int)StringToInteger(StringSubstr(hostPort, colonPos + 1));
   }

   return host != "";
}

//+------------------------------------------------------------------+
//| Read all bytes from an open WinInet handle into a string         |
//+------------------------------------------------------------------+
string readResponse(int hRequest)
{
   string result = "";
   uchar  buffer[4096];
   int    bytesRead = 0;

   while(InternetReadFile(hRequest, buffer, ArraySize(buffer) - 1, bytesRead) && bytesRead > 0)
   {
      buffer[bytesRead] = 0;
      result += CharArrayToString(buffer, 0, bytesRead, CP_UTF8);
   }
   return StringLen(result) > 0 ? result : "No response received or failed to read response.";
}

//+------------------------------------------------------------------+
//| Send a GET request                                               |
//+------------------------------------------------------------------+
string requestGet(const string url, const string headers)
{
   char   buffer[1024];
   int    bytesRead = 0;
   string result    = "";

   ResetLastError();

   int hInternet = InternetOpenW(REQUEST_USER_AGENT, 1, NULL, NULL, 0);
   if(!hInternet)
   {
      return StringFormat("requestGet: Failed to initialize WinHTTP, Error code: %d", GetLastError());
   }

   int hUrl = InternetOpenUrlW(hInternet, url, NULL, 0, 0, 0);
   if(!hUrl)
   {
      InternetCloseHandle(hInternet);
      return StringFormat("requestGet: Failed to open URL: %s, Error code: %d", url, GetLastError());
   }

   if(HttpSendRequestW(hUrl, headers, StringLen(headers), buffer, 0))
   {
      result = readResponse(hUrl);
   }

   InternetCloseHandle(hUrl);
   InternetCloseHandle(hInternet);
   return result;
}

//+------------------------------------------------------------------+
//| Send a POST request                                              |
//+------------------------------------------------------------------+
string requestPost(const string url, const string headers, CJAVal &data)
{
   string result = "";

   string scheme, host, path;
   int    port;
   if(!parseUrl(url, scheme, host, port, path))
   {
      return StringFormat("requestPost: Invalid URL: %s", url);
   }

   ResetLastError();

   bool isHttps = (scheme == "https");
   uint flags   = INTERNET_FLAG_RELOAD | INTERNET_FLAG_NO_CACHE_WRITE;
   if(isHttps) flags |= INTERNET_FLAG_SECURE;

   string headerStr = "Content-Type: application/json\r\n" + headers;
   string bodyStr   = data.Serialize();
   char   bodyBytes[];
   int    bodyLen   = StringToCharArray(bodyStr, bodyBytes, 0, StringLen(bodyStr), CP_UTF8);

   int hInternet = InternetOpenW(REQUEST_USER_AGENT, 1, NULL, NULL, 0);
   if(!hInternet)
   {
      return StringFormat("requestPost: Failed to initialize WinHTTP, Error code: %d", GetLastError());
   }

   int hConnect = InternetConnectW(hInternet, host, port, NULL, NULL, INTERNET_SERVICE_HTTP, 0, 0);
   if(!hConnect)
   {
      InternetCloseHandle(hInternet);
      return StringFormat("requestPost: Failed to connect to host: %s, Error code: %d", host, GetLastError());
   }

   string emptyStr = "";
   int hRequest = HttpOpenRequestW(hConnect, "POST", path, "HTTP/1.1", emptyStr, emptyStr, flags, 0);
   if(!hRequest)
   {
      InternetCloseHandle(hConnect);
      InternetCloseHandle(hInternet);
      return StringFormat("requestPost: Failed to open HTTP request for path: %s, Error code: %d", path, GetLastError());
   }

   if(!HttpSendRequestW(hRequest, headerStr, StringLen(headerStr), bodyBytes, bodyLen))
   {
      InternetCloseHandle(hRequest);
      InternetCloseHandle(hConnect);
      InternetCloseHandle(hInternet);
      return StringFormat("requestPost: Failed to send HTTP request to %s%s, Error code: %d", host, path, GetLastError());
   }

   result = readResponse(hRequest);

   InternetCloseHandle(hRequest);
   InternetCloseHandle(hConnect);
   InternetCloseHandle(hInternet);
   return result;
}
//+------------------------------------------------------------------+