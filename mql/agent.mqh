//+------------------------------------------------------------------+
//|                                                        agent.mqh |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict

#include "llm.mqh"
#include "session.mqh"
#include "tools/mt5.mqh"
#include "tools/dispatch.mqh"
#include "tools/requests.mqh"
#include "tools/context.mqh"

//+------------------------------------------------------------------+
//| Sub-agent configuration                                          |
//+------------------------------------------------------------------+
#define SUBAGENT_FOLDER           "metatrader-ai\\subagents" // common-files sub-agent folder
#define SUBAGENT_INDICATOR_FOLDER "Indicators\\"             // sub-agent .ex5 folder

//+------------------------------------------------------------------+
//| Agent — wraps multi-turn conversation state and OpenAI API calls |
//+------------------------------------------------------------------+
class Agent
{
public:
                     Agent(
      string apiKey,
      const ENUM_LLM_PROVIDER providerId = LLM_PROVIDER_DEEPSEEK,
      const ENUM_LLM_MODEL providerModel = LLM_MODEL_DEEPSEEK_V4_FLASH,
      const string localUrl = "http://127.0.0.1:8080/v1/chat/completions",
      const ENUM_LLM_THINKING thinking = LLM_THINKING_MEDIUM
   );                                                                      // Constructor
                    ~Agent();                                              // Deconstructor
   void              reset();                                              // Clear conversation history while preserving the system message
   string            run(string prompt);                                   // Process one user turn and return the assistant's final text response
   bool              hasSession();                                         // True when an active session exists
   string            newSession();                                         // Start a new session and reset history
   bool              loadSession(string name);                             // Load a saved session into history
   void              saveSession();                                        // Persist the current conversation
   int               historyCount();                                       // Number of conversation messages
   bool              historyMessage(int i, string &role, string &content); // Read a conversation entry
   string            runSubAgent(string prompt);                           // Launch sub-agent on new chart
   string            pollSubAgent(string subAgentId);                      // Collect sub-agent result

private:
   CJAVal            m_messages;        // persistent conversation history (jtARRAY)
   Dispatch          *m_dispatch;       // tool dispatcher
   string            m_headers;         // Content-Type + Authorization headers
   bool              m_initialized;     // is initialized
   string            m_deferredImageMsg;// user-role image message deferred until after all tool results
   LLM               m_llm;             // LLM configuration
   string            m_apiKey;          // API key
   Session           *m_session;        // current session
   ENUM_LLM_PROVIDER m_providerId;      // LLM provider
   ENUM_LLM_MODEL    m_providerModel;   // LLM model
   ENUM_LLM_THINKING m_thinking;        // LLM thinking level
   string            m_pendingSubAgents[]; // pending sub-agent ids

   string            loadContextFiles();                                     // Read and concatenate all CONTEXT_FILES
   bool              initialize();                                           // Load system prompt and context files
   bool              hasConversation();                                      // True when history holds a user/assistant turn
   void              pushMessage(string role, string content);               // Append a standard role/content message
   void              pushRaw(string serialized);                             // Append a pre-serialized JSON object (used for assistant messages with tool_calls)
   void              pushToolResult(string toolCallId, string content);      // Append a tool result message
   void              pushToolResultImage(string toolCallId, string b64data); // Append a tool result image
   void              collectSubAgents();                                     // Drain finished sub-agents
   string            buildSubAgentIndicatorSource(string id, string apiKey, ENUM_LLM_PROVIDER providerId, ENUM_LLM_MODEL providerModel, string localUrl, ENUM_LLM_THINKING thinking); // Generate sub-agent source
   string            escapeMqlString(string value);                          // Escape for MQL literal
   string            extractCompileErrors(string log);                       // Extract error lines from log
   void              setThinking(CJAVal& payload);                           // Set the "thinking" parameter in the payload
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
Agent::Agent(string apiKey, const ENUM_LLM_PROVIDER providerId, const ENUM_LLM_MODEL providerModel, const string localUrl, const ENUM_LLM_THINKING thinking)
{
   m_messages.m_type = jtARRAY;
   m_dispatch        = new Dispatch();
   m_llm             = LLM(providerId, providerModel, localUrl, thinking);
   m_apiKey          = apiKey;
   m_providerId      = providerId;
   m_providerModel   = providerModel;
   m_thinking        = thinking;
   ArrayResize(m_pendingSubAgents, 0);
   m_initialized     = initialize();
   m_headers = "Content-Type: application/json\r\n";
   if(m_llm.id != "local")
      m_headers += "Authorization: Bearer " + m_apiKey;
   m_deferredImageMsg = "";
   m_session = new Session(false, false);
#ifdef __MQL4__
   if(!FolderCreate("metatrader-ai", FILE_COMMON)) Print("Failed to create metatrader-ai folder");
   if(!FolderCreate("metatrader-ai\\context", FILE_COMMON)) Print("Failed to create metatrader-ai\\context folder");
   if(!FolderCreate("metatrader-ai\\workflows", FILE_COMMON)) Print("Failed to create metatrader-ai\\workflows folder");
#endif
}

//+------------------------------------------------------------------+
//| Deconstructor                                                    |
//+------------------------------------------------------------------+
Agent::~Agent()
{
   if (CheckPointer(m_dispatch) == POINTER_DYNAMIC)
   {
      delete m_dispatch;
      m_dispatch = NULL;
   }
   if (CheckPointer(m_session) == POINTER_DYNAMIC)
   {
      delete m_session;
      m_session = NULL;
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Agent::initialize(void)
{
#ifdef __MQL5__
   string systemContent = contextRead("context\\prompt.md") + "\nYou are in a MQL5/MetaTrader 5 environment." + loadContextFiles();
#else
   string systemContent = contextRead("context\\prompt.md") + "\nYou are in a MQL4/MetaTrader 4 environment." + loadContextFiles();
#endif
   if(systemContent == "") return false;
   pushMessage("system", systemContent);
   return true;
}

//+------------------------------------------------------------------+
//| Read and concatenate all CONTEXT_FILES                           |
//+------------------------------------------------------------------+
string Agent::loadContextFiles()
{
   string combined = "";
   int n = ArraySize(CONTEXT_FILES);
   for (int i = 0; i < n; i++)
      combined += "\n\n--- " + CONTEXT_FILES[i] + " ---\n" + contextRead(CONTEXT_FILES[i]);
   return combined;
}

//+------------------------------------------------------------------+
//| Append a standard role/content message                           |
//+------------------------------------------------------------------+
void Agent::pushMessage(string role, string content)
{
   CJAVal msg;
   msg["role"]    = role;
   msg["content"] = content;
   m_messages.Add(msg);
}

//+------------------------------------------------------------------+
//| Append a pre-serialized JSON object                              |
//+------------------------------------------------------------------+
void Agent::pushRaw(string serialized)
{
   CJAVal msg;
   msg.Deserialize(serialized);
   m_messages.Add(msg);
}

//+------------------------------------------------------------------+
//| Append a tool result message                                     |
//+------------------------------------------------------------------+
void Agent::pushToolResult(string toolCallId, string content)
{
   CJAVal msg;
   msg["role"]         = "tool";
   msg["tool_call_id"] = toolCallId;
   msg["content"]      = content;
   m_messages.Add(msg);
}

//+------------------------------------------------------------------+
//| Append a tool result — defers the user-role image message        |
//| so it can be flushed after all tool results are committed        |
//+------------------------------------------------------------------+
void Agent::pushToolResultImage(string toolCallId, string b64data)
{
   if(m_llm.id == "openai")
   {
      pushToolResult(toolCallId, "Screenshot captured.");
      string imgContent = "[{\"type\":\"text\",\"text\":\"Here is the chart screenshot.\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64," + b64data + "\"}}]";
      m_deferredImageMsg = "{\"role\":\"user\",\"content\":" + imgContent + "}";
   }
   else
   {
      pushToolResult(toolCallId, "Screenshot captured successfully. The chart image data is available but this LLM provider does not support inline image display.");
   }
}

//+------------------------------------------------------------------+
//| Process one user turn, return the assistant's final text response|
//+------------------------------------------------------------------+
string Agent::run(string prompt)
{
   if(!m_initialized)
   {
      m_initialized = initialize();
      if(!m_initialized) return "Failed to initialize context.";
   }
   if(!hasSession())
      newSession();

// Append finished sub-agent results
   collectSubAgents();

   pushMessage("user", prompt);

   CJAVal toolList;
   m_dispatch.toolList(toolList, false);

   while (true)
   {
      CJAVal payload;
      payload["model"] = m_llm.model;
      payload["tool_choice"] = "auto";
      payload["messages"].Set(m_messages);
      payload["tools"].Set(toolList);
      setThinking(payload);

      string jsonString = requestPost(m_llm.url, m_headers, payload);
      if(jsonString == "")
         return "HTTP request failed.";

      CJAVal response;
      response.Deserialize(jsonString);

      if (response["error"]["message"].ToStr() != "")
         return "API error: " + response["error"]["message"].ToStr();

      if (response["choices"].m_type != jtARRAY || ArraySize(response["choices"].m_e) == 0)
         return "Unexpected API response: " + jsonString;

      string msgSerialized = response["choices"][0]["message"].Serialize();

      CJAVal message;
      message.Deserialize(msgSerialized);

      bool hasToolCalls = (message["tool_calls"].m_type == jtARRAY)
                          && (ArraySize(message["tool_calls"].m_e) > 0);

      if (!hasToolCalls)
      {
         string content = message["content"].ToStr();
         pushMessage("assistant", content);
         saveSession();
         return content;
      }

      // Persist the full assistant message (including tool_calls) into history
      pushRaw(msgSerialized);

      // Execute each tool call and append its result
      m_deferredImageMsg = "";
      int n = ArraySize(message["tool_calls"].m_e);
      for (int i = 0; i < n; i++)
      {
         CJAVal toolCall;
         toolCall.Deserialize(message["tool_calls"][i].Serialize());

         string callId  = toolCall["id"].ToStr();
         string name    = toolCall["function"]["name"].ToStr();
         string rawArgs = toolCall["function"]["arguments"].ToStr();

         CJAVal args;
         if (StringLen(rawArgs) > 0)
            args.Deserialize(rawArgs);

         Print("[Agent] Executing tool: ", name, " args: ", rawArgs);
         string result = m_dispatch.execute(name, args);
         Print("[Agent] Tool ", name, " returned: ", result);

         if(name == "get_screenshot")
            pushToolResultImage(callId, result);
         else
            pushToolResult(callId, result);
      }
      // Flush deferred image message after ALL tool results are committed
      if(m_deferredImageMsg != "")
      {
         pushRaw(m_deferredImageMsg);
         m_deferredImageMsg = "";
      }
   }

   return ""; // unreachable
}

//+------------------------------------------------------------------+
//| Clear conversation history while preserving the system message   |
//+------------------------------------------------------------------+
void Agent::reset()
{
   string systemMsgStr = "";
   if (ArraySize(m_messages.m_e) > 0)
      systemMsgStr = m_messages[0].Serialize();

   m_messages.Clear();
   m_messages.m_type = jtARRAY;

   if (systemMsgStr != "")
   {
      CJAVal systemMsg;
      systemMsg.Deserialize(systemMsgStr);
      m_messages.Add(systemMsg);
   }
}

//+------------------------------------------------------------------+
//| True when an active session exists                               |
//+------------------------------------------------------------------+
bool Agent::hasSession()
{
   return CheckPointer(m_session) == POINTER_DYNAMIC && m_session.active();
}

//+------------------------------------------------------------------+
//| Start a new session and reset history to the system message      |
//+------------------------------------------------------------------+
string Agent::newSession()
{
   saveSession();
   if(CheckPointer(m_session) == POINTER_DYNAMIC)
   {
      delete m_session;
      m_session = NULL;
   }
   m_session = new Session(true, false);
   reset();
   return m_session.name;
}

//+------------------------------------------------------------------+
//| Load a saved session into the live history                       |
//+------------------------------------------------------------------+
bool Agent::loadSession(string name)
{
   saveSession();

   Session *loaded = new Session(false, false);
   if(!loaded.load(name))
   {
      delete loaded;
      return false;
   }

   string systemMsgStr = "";
   if(ArraySize(m_messages.m_e) > 0 && m_messages[0]["role"].ToStr() == "system")
      systemMsgStr = m_messages[0].Serialize();

   m_messages.Clear();
   m_messages.m_type = jtARRAY;

   if(systemMsgStr != "" && (ArraySize(loaded.messages.m_e) == 0 || loaded.messages[0]["role"].ToStr() != "system"))
   {
      CJAVal sys;
      sys.Deserialize(systemMsgStr);
      m_messages.Add(sys);
   }
   int n = ArraySize(loaded.messages.m_e);
   for(int i = 0; i < n; i++)
      m_messages.Add(loaded.messages[i]);

   if(CheckPointer(m_session) == POINTER_DYNAMIC)
   {
      delete m_session;
      m_session = NULL;
   }
   m_session = loaded;
   return true;
}

//+------------------------------------------------------------------+
//| Persist the current conversation to the active session           |
//+------------------------------------------------------------------+
void Agent::saveSession()
{
   if(CheckPointer(m_session) != POINTER_DYNAMIC) return;
   if(!m_session.active()) return;
   if(!hasConversation()) return;

   m_session.messages.Clear();
   m_session.messages.m_type = jtARRAY;
   m_session.messages.Set(m_messages);
   m_session.save();
}

//+------------------------------------------------------------------+
//| True when history holds at least one user or assistant turn      |
//+------------------------------------------------------------------+
bool Agent::hasConversation()
{
   int n = ArraySize(m_messages.m_e);
   for(int i = 0; i < n; i++)
   {
      string role = m_messages[i]["role"].ToStr();
      if(role == "user" || role == "assistant")
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Number of messages in the live history                           |
//+------------------------------------------------------------------+
int Agent::historyCount()
{
   return ArraySize(m_messages.m_e);
}

//+------------------------------------------------------------------+
//| Read a history entry into role/content                           |
//+------------------------------------------------------------------+
bool Agent::historyMessage(int i, string &role, string &content)
{
   if(i < 0 || i >= ArraySize(m_messages.m_e)) return false;
   role = m_messages[i]["role"].ToStr();
   content = m_messages[i]["content"].ToStr();
   return true;
}

//+------------------------------------------------------------------+
//| Run a sub-agent on a NEW chart, return its session id            |
//+------------------------------------------------------------------+
string Agent::runSubAgent(string prompt)
{
#ifdef __MQL5__
   // Gather inputs
   const string id = StringFormat("subagent_%I64d_%d", (long)TimeCurrent(), (int)GetTickCount());

   if(!FolderCreate(SUBAGENT_FOLDER, FILE_COMMON))
      return "Sub-agent failed: could not create the subagents folder.";

   const string promptRel        = SUBAGENT_FOLDER + "\\" + id + ".prompt.txt";
   const string indicatorsFolder = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\" + SUBAGENT_INDICATOR_FOLDER;
   const string mq5Path          = indicatorsFolder + id + ".mq5";
   const string ex5Path          = indicatorsFolder + id + ".ex5";

   // Save prompt file
   FileDelete(promptRel, FILE_COMMON);
   int ph = FileOpen(promptRel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(ph == INVALID_HANDLE)
      return "Sub-agent failed: could not write the prompt file (error " + (string)GetLastError() + ").";
   FileWriteString(ph, prompt);
   FileClose(ph);

   // Write generated indicator into the Indicators folder
   const string source = buildSubAgentIndicatorSource(id, m_apiKey, m_providerId, m_providerModel, m_llm.url, m_thinking);
   char srcData[];
   StringToCharArray(source, srcData);
   if(fileWrite(mq5Path, srcData) != "true")
   {
      FileDelete(promptRel, FILE_COMMON);
      return "Sub-agent failed: could not write the indicator (error " + (string)GetLastError() + ").";
   }

   // Compile indicator in place
   const string compileLog = compileMql5(mq5Path);
   if(StringFind(compileLog, "[Build Error]") >= 0 || StringFind(compileLog, "error:") >= 0 || fileExists(ex5Path) != "true")
   {
      FileDelete(promptRel, FILE_COMMON);
      fileDelete(mq5Path);
      return "Sub-agent compile failed:\n" + extractCompileErrors(compileLog);
   }

   // Open a new chart
   const long chartId = ChartOpen(_Symbol, PERIOD_CURRENT);
   if(chartId == 0)
   {
      FileDelete(promptRel, FILE_COMMON);
      fileDelete(mq5Path);
      return "Sub-agent failed: ChartOpen error " + (string)GetLastError() + ".";
   }

   // Load the indicator by name and attach it to the new chart
   int indHandle = INVALID_HANDLE;
   for(int attempt = 0; attempt < 10 && indHandle == INVALID_HANDLE; attempt++)
   {
      indHandle = iCustom(_Symbol, PERIOD_CURRENT, id);
      if(indHandle == INVALID_HANDLE)
         Sleep(500);
   }
   if(indHandle == INVALID_HANDLE || !ChartIndicatorAdd(chartId, 0, indHandle))
   {
      const string indStatus = fileExists(ex5Path);
      ChartClose(chartId);
      FileDelete(promptRel, FILE_COMMON);
      fileDelete(mq5Path);
      fileDelete(ex5Path);
      return "Sub-agent failed: could not add indicator " + id + " to the new chart (ex5 exists: " + indStatus + ", error: " + (string)GetLastError() + ").";
   }

   // Track for later collection
   int pendingCount = ArraySize(m_pendingSubAgents);
   ArrayResize(m_pendingSubAgents, pendingCount + 1);
   m_pendingSubAgents[pendingCount] = id;

   PrintFormat("[Agent] Launched sub-agent %s on chart %d", id, chartId);

   // Return session id
   return id;
#else
   return "Sub-agents require MetaTrader 5.";
#endif
}

//+------------------------------------------------------------------+
//| Poll for the saved response file, append result                  |
//+------------------------------------------------------------------+
string Agent::pollSubAgent(string subAgentId)
{
#ifdef __MQL5__
   const string responseRel = SUBAGENT_FOLDER + "\\" + subAgentId + ".response.json";
   if(!FileIsExist(responseRel, FILE_COMMON))
      return "";

   int h = FileOpen(responseRel, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return "";
   string content = "";
   while(!FileIsEnding(h))
   {
      content += FileReadString(h);
      if(!FileIsEnding(h)) content += "\n";
   }
   FileClose(h);

   CJAVal res;
   res.Deserialize(content);
   const string response   = res["response"].ToStr();
   const long   chartId    = (long)res["chart_id"].ToInt();
   const string subSession = res["session"].ToStr();

   // Clean up artifacts
   FileDelete(responseRel, FILE_COMMON);
   FileDelete(SUBAGENT_FOLDER + "\\" + subAgentId + ".prompt.txt", FILE_COMMON);
   fileDelete(TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\" + SUBAGENT_INDICATOR_FOLDER + subAgentId + ".mq5");
   fileDelete(TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\" + SUBAGENT_INDICATOR_FOLDER + subAgentId + ".ex5");
   fileDelete(TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\" + SUBAGENT_INDICATOR_FOLDER + subAgentId + ".log");

   // Detach sub-agent indicator and close its chart
   if(chartId != 0 && chartId != ChartID())
   {
      ChartIndicatorDelete(chartId, 0, subAgentId);
      ChartClose(chartId);
   }

// Append to conversation
   if(response != "")
   {
      pushMessage("user", "Sub-agent [" + subAgentId + "] result:\n" + response);
      Print("[Agent] Sub-agent ", subAgentId, " (session ", subSession, ") returned: ", response);
   }

   return response;
#else
   return "";
#endif
}

//+------------------------------------------------------------------+
//| Drain finished sub-agents, keep unfinished                       |
//+------------------------------------------------------------------+
void Agent::collectSubAgents()
{
   const int pendingCount = ArraySize(m_pendingSubAgents);
   if(pendingCount == 0)
      return;

   string remaining[];
   int kept = 0;
   for(int i = 0; i < pendingCount; i++)
   {
      const string result = pollSubAgent(m_pendingSubAgents[i]);
      // Keep unfinished for next call
      if(result == "" && FileIsExist(SUBAGENT_FOLDER + "\\" + m_pendingSubAgents[i] + ".response.json", FILE_COMMON))
      {
         ArrayResize(remaining, kept + 1);
         remaining[kept++] = m_pendingSubAgents[i];
      }
   }
   ArrayResize(m_pendingSubAgents, 0);
   for(int i = 0; i < kept; i++)
   {
      ArrayResize(m_pendingSubAgents, i + 1);
      m_pendingSubAgents[i] = remaining[i];
   }
}

//+------------------------------------------------------------------+
//| Generate the sub-agent indicator source                          |
//+------------------------------------------------------------------+
string Agent::buildSubAgentIndicatorSource(string id, string apiKey, ENUM_LLM_PROVIDER providerId, ENUM_LLM_MODEL providerModel, string localUrl, ENUM_LLM_THINKING thinking)
{
   const string eKey = escapeMqlString(apiKey);
   const string eUrl = escapeMqlString(localUrl);

   string src = "";
   src += "//+------------------------------------------------------------------+\n";
   src += "//| " + id + ".mq5 - generated sub-agent indicator                |\n";
   src += "//| Generated by Agent::runSubAgent. Do not edit manually.        |\n";
   src += "//+------------------------------------------------------------------+\n";
   src += "#property strict\n";
   src += "#property indicator_chart_window\n";
   src += "#property indicator_buffers 1\n";
   src += "#property indicator_plots   1\n";
   src += "#property indicator_type1   DRAW_NONE\n";
   src += "#property indicator_label1  \"subagent\"\n\n";
   src += "#include <metatrader-ai\\mql\\agent.mqh>\n\n";
   src += "input string inpApiKey   = \"" + eKey + "\"; // API Key\n";
   src += "input int    inpProvider = " + (string)(int)providerId + "; // LLM Provider\n";
   src += "input int    inpModel    = " + (string)(int)providerModel + "; // LLM Model\n";
   src += "input string inpLocalUrl = \"" + eUrl + "\"; // Local LLM URL\n";
   src += "input int    inpThinking = " + (string)(int)thinking + "; // LLM Thinking Level\n\n";
   src += "#define SUBAGENT_ID \"" + id + "\"\n";
   src += "#define SUBAGENT_PROMPT_FILE \"metatrader-ai\\\\subagents\\\\" + id + ".prompt.txt\"\n";
   src += "#define SUBAGENT_RESPONSE_FILE \"metatrader-ai\\\\subagents\\\\" + id + ".response.json\"\n\n";
   src += "double subBuf[];\n\n";
   src += "//+------------------------------------------------------------------+\n";
   src += "int OnInit()\n";
   src += "{\n";
   src += "   SetIndexBuffer(0, subBuf, INDICATOR_DATA);\n";
   src += "   return INIT_SUCCEEDED;\n";
   src += "}\n\n";
   src += "//+------------------------------------------------------------------+\n";
   src += "int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])\n";
   src += "{\n";
   src += "   RunSubAgentWork();\n";
   src += "   return rates_total;\n";
   src += "}\n\n";
   src += "//+------------------------------------------------------------------+\n";
   src += "void OnDeinit(const int reason)\n";
   src += "{\n";
   src += "}\n\n";
   src += "//+------------------------------------------------------------------+\n";
   src += "void RunSubAgentWork()\n";
   src += "{\n";
   src += "   static bool done = false;\n";
   src += "   if(done)\n";
   src += "      return;\n";
   src += "   done = true;\n\n";
   src += "   // Read parent prompt\n";
   src += "   string prompt = \"\";\n";
   src += "   int r = FileOpen(SUBAGENT_PROMPT_FILE, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);\n";
   src += "   if(r != INVALID_HANDLE)\n";
   src += "   {\n";
   src += "      while(!FileIsEnding(r))\n";
   src += "      {\n";
   src += "         prompt += FileReadString(r);\n";
   src += "         if(!FileIsEnding(r)) prompt += \"\\n\";\n";
   src += "      }\n";
   src += "      FileClose(r);\n";
   src += "   }\n\n";
   src += "   PrintFormat(\"[SubAgent] prompt length: %d\", StringLen(prompt));\n\n";
   src += "   string response = \"\";\n";
   src += "   string sessionName = \"\";\n";
   src += "   Agent *sub = new Agent(inpApiKey, (ENUM_LLM_PROVIDER)inpProvider, (ENUM_LLM_MODEL)inpModel, inpLocalUrl, (ENUM_LLM_THINKING)inpThinking);\n";
   src += "   if(CheckPointer(sub) == POINTER_DYNAMIC)\n";
   src += "   {\n";
   src += "      sessionName = sub.newSession();\n";
   src += "      response = sub.run(prompt);\n";
   src += "      delete sub;\n";
   src += "   }\n";
   src += "   else\n";
   src += "      response = \"Sub-agent failed: could not create Agent (error \" + (string)GetLastError() + \")\";\n\n";
   src += "   PrintFormat(\"[SubAgent] response (%d chars): %s\", StringLen(response), response);\n\n";
   src += "   // Write result file\n";
   src += "   CJAVal result;\n";
   src += "   result[\"subagent_id\"] = SUBAGENT_ID;\n";
   src += "   result[\"chart_id\"]    = (long)ChartID();\n";
   src += "   result[\"session\"]     = sessionName;\n";
   src += "   result[\"response\"]    = response;\n\n";
   src += "   int w = FileOpen(SUBAGENT_RESPONSE_FILE, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);\n";
   src += "   if(w != INVALID_HANDLE)\n";
   src += "   {\n";
   src += "      FileWriteString(w, result.Serialize());\n";
   src += "      FileClose(w);\n";
   src += "   }\n";
   src += "}\n";
   src += "//+------------------------------------------------------------------+\n";

   return src;
}

//+------------------------------------------------------------------+
//| Escape a value for a generated MQL string literal                |
//+------------------------------------------------------------------+
string Agent::escapeMqlString(string value)
{
   string out = "";
   const int len = StringLen(value);
   for(int i = 0; i < len; i++)
   {
      const ushort c = StringGetCharacter(value, i);
      switch(c)
      {
      case '\\':
         out += "\\\\";
         break;
      case '"':
         out += "\\\"";
         break;
      case '\r':
         out += "\\r";
         break;
      case '\n':
         out += "\\n";
         break;
      case '\t':
         out += "\\t";
         break;
      default:
         out += ShortToString(c);
         break;
      }
   }
   return out;
}

//+------------------------------------------------------------------+
//| Extract error and warning lines from a compile log               |
//+------------------------------------------------------------------+
string Agent::extractCompileErrors(string log)
{
   string out = "";
   string lines[];
   const int count = StringSplit(log, '\n', lines);
   for(int i = 0; i < count; i++)
   {
      string line = lines[i];
      StringTrimLeft(line);
      StringTrimRight(line);
      if(line == "") continue;
      if(StringFind(line, "error:") >= 0 || StringFind(line, "warning:") >= 0 || StringFind(line, "error(s)") >= 0 || StringFind(line, "warning(s)") >= 0)
         out += line + "\n";
   }
   if(out == "")
      out = "(no error details in compile log)";
   return out;
}

//+------------------------------------------------------------------+
//| et the "thinking" parameter in the payload                       |
//+------------------------------------------------------------------+
void Agent::setThinking(CJAVal& payload)
{
   if(m_llm.thinking != "none")
   {
      if(m_llm.id == "deepseek")
      {
         CJAVal thinking;
         thinking["type"] = "enabled";
         payload["thinking"].Set(thinking);
         payload["reasoning_effort"] = m_llm.thinking;
      }
      else if(m_llm.id == "local")
      {
         payload["think"] = true;
      }
      else if(m_llm.id == "openai" || m_llm.id == "gemini")
      {
         payload["reasoning_effort"] = m_llm.thinking;
      }
      else if(m_llm.id == "anthropic")
      {
         CJAVal thinking;
         thinking["type"] = "enabled";
         payload["thinking"].Set(thinking);
      }
   }
   else
   {
      if(m_llm.id == "deepseek")
      {
         CJAVal thinking;
         thinking["type"] = "disabled";
         payload["thinking"].Set(thinking);
      }
      else if(m_llm.id == "local")
      {
         payload["think"] = false;
      }
      else if(m_llm.id == "openai" || m_llm.id == "gemini")
      {
         payload["reasoning_effort"] = m_llm.thinking;
      }
      else if(m_llm.id == "anthropic")
      {
         CJAVal thinking;
         thinking["type"] = "disabled";
         payload["thinking"].Set(thinking);
      }
   }
}
//+------------------------------------------------------------------+
