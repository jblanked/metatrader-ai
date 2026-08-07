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
#include "tools/fxsaber/Expert.mqh"

#define SUBAGENT_FOLDER "metatrader-ai\\subagents" // common-files sub-agent folder
#define SUBAGENT_EXE    "Experts\\app.ex5"         // sub-agent expert path

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
   string            collectSubAgentsAndWait();                            // Wait for all sub-agents
   string            pollSubAgent(string subAgentId, bool appendToConversation = true); // Collect sub-agent result

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
   string            m_pendingSubAgents[];      // pending sub-agent ids
   string            m_pendingSubAgentPrompts[]; // pending sub-agent prompts

   void              addSubAgentTool();                                      // Add the sub-agent tool to the dispatcher
   string            loadContextFiles();                                     // Read and concatenate all CONTEXT_FILES
   bool              initialize();                                           // Load system prompt and context files
   bool              hasConversation();                                      // True when history holds a user/assistant turn
   void              pushMessage(string role, string content);               // Append a standard role/content message
   void              pushRaw(string serialized);                             // Append a pre-serialized JSON object (used for assistant messages with tool_calls)
   void              pushToolResult(string toolCallId, string content);      // Append a tool result message
   void              pushToolResultImage(string toolCallId, string b64data); // Append a tool result image
   void              collectSubAgents();                                     // Drain finished sub-agents
   string            subAgentLabel(string id, string prompt);                // Label a sub-agent result
   void              setThinking(CJAVal& payload);                           // Set the "thinking" parameter in the payload
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
Agent::Agent(string apiKey, const ENUM_LLM_PROVIDER providerId, const ENUM_LLM_MODEL providerModel, const string localUrl, const ENUM_LLM_THINKING thinking)
{
   m_messages.m_type = jtARRAY;
   m_dispatch        = new Dispatch();
   addSubAgentTool();
   m_llm             = LLM(providerId, providerModel, localUrl, thinking);
   m_apiKey          = apiKey;
   m_providerId      = providerId;
   m_providerModel   = providerModel;
   m_thinking        = thinking;
   ArrayResize(m_pendingSubAgents, 0);
   ArrayResize(m_pendingSubAgentPrompts, 0);
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
//| Parameters for run_subagent                                      |
//+------------------------------------------------------------------+
Parameters *toolRunSubAgentParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("prompt", "string", "The prompt to send to the sub-agent", true));
   return p;
}

//+------------------------------------------------------------------+
//| Tool — run a prompt on a separate sub-agent                      |
//+------------------------------------------------------------------+
class ToolRunSubAgent : public Tool
{
private:
   Agent             *m_agent; // agent that owns this tool

public:
   ToolRunSubAgent(Agent *agent) : Tool("run_subagent", "Launch a sub-agent on a separate chart with the given prompt and return its id immediately (it runs in parallel). Launch as many as needed to split a large task, then call collect_subagents to retrieve all results.", toolRunSubAgentParams())
   {
      m_agent = agent;
   }

   virtual string    execute(CJAVal &json) override
   {
      const string id = m_agent.runSubAgent(json["prompt"].ToStr());
      if(StringFind(id, "subagent_") == 0)
         return "Launched sub-agent " + id + ". Call collect_subagents to retrieve its result.";
      return id; // launch failure message
   }
};

//+------------------------------------------------------------------+
//| Tool — collect all sub-agent results                             |
//+------------------------------------------------------------------+
class ToolCollectSubAgents : public Tool
{
private:
   Agent             *m_agent; // agent that owns this tool

public:
   ToolCollectSubAgents(Agent *agent) : Tool("collect_subagents", "Wait for all launched sub-agents to finish and return all their results together. Call after launching sub-agents with run_subagent.", NULL)
   {
      m_agent = agent;
   }

   virtual string    execute(CJAVal &json) override
   {
      return m_agent.collectSubAgentsAndWait();
   }
};

//+------------------------------------------------------------------+
//| Create and add the sub-agent tool to the dispatcher              |
//+------------------------------------------------------------------+
void Agent::addSubAgentTool()
{
   if(CheckPointer(m_dispatch) != POINTER_DYNAMIC) return;
   m_dispatch.add(new ToolRunSubAgent(this));
   m_dispatch.add(new ToolCollectSubAgents(this));
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
//| Run app.ex5 on a NEW chart, return its session id                |
//+------------------------------------------------------------------+
string Agent::runSubAgent(string prompt)
{
#ifdef __MQL5__
   const string id = StringFormat("subagent_%I64d_%d", (long)TimeCurrent(), (int)GetTickCount());

   if(!FolderCreate(SUBAGENT_FOLDER, FILE_COMMON))
      return "Sub-agent failed: could not create the subagents folder.";

   const string promptRel   = SUBAGENT_FOLDER + "\\" + id + ".prompt.txt";
   const string responseRel = SUBAGENT_FOLDER + "\\" + id + ".response.json";

// Save prompt file
   FileDelete(promptRel, FILE_COMMON);
   int ph = FileOpen(promptRel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(ph == INVALID_HANDLE)
      return "Sub-agent failed: could not write the prompt file (error " + (string)GetLastError() + ").";
   FileWriteString(ph, prompt);
   FileClose(ph);

// Open a new chart for the sub-agent
   const long chartId = ChartOpen(_Symbol, PERIOD_CURRENT);
   if(chartId == 0)
   {
      FileDelete(promptRel, FILE_COMMON);
      return "Sub-agent failed: ChartOpen error " + (string)GetLastError() + ".";
   }
   Sleep(1000);

// Forward credentials and prompt to app.ex5 (inputs in declaration order)
   MqlParam prms[10];
   prms[0].type = TYPE_STRING;
   prms[0].string_value = SUBAGENT_EXE;          // expert path
   prms[1].type = TYPE_STRING;
   prms[1].string_value = m_apiKey;              // inpApiKey
   prms[2].type = TYPE_INT;
   prms[2].integer_value = (int)m_providerId;    // inpProvider
   prms[3].type = TYPE_INT;
   prms[3].integer_value = (int)m_providerModel; // inpModel
   prms[4].type = TYPE_STRING;
   prms[4].string_value = m_llm.url;             // inpLocalUrl
   prms[5].type = TYPE_INT;
   prms[5].integer_value = (int)m_thinking;      // inpThinking
   prms[6].type = TYPE_STRING;
   prms[6].string_value = "true";                // inpRunSubAgent
   prms[7].type = TYPE_STRING;
   prms[7].string_value = "";                    // inpPrompt
   prms[8].type = TYPE_STRING;
   prms[8].string_value = promptRel;             // inpPromptFile
   prms[9].type = TYPE_STRING;
   prms[9].string_value = responseRel;           // inpResponseFile

// Attach is asynchronous: retry until the EA name appears on the chart
   bool attached = false;
   for(int attempt = 0; attempt < 60 && !attached; attempt++)
   {
      EXPERT::Run(chartId, prms);
      for(int wait = 0; wait < 10 && !attached; wait++)
      {
         if(ChartGetString(chartId, CHART_EXPERT_NAME) != "")
            attached = true;
         else
            Sleep(500);
      }
   }
   if(!attached)
   {
      ChartClose(chartId);
      FileDelete(promptRel, FILE_COMMON);
      return "Sub-agent failed: could not attach " + SUBAGENT_EXE + " on chart " + (string)chartId + ".";
   }

// First attach can race and leave defaults, so re-apply and verify inputs
   string names[];
   MqlParam params[];
   bool verified = false;
   for(int attempt = 0; attempt < 10 && !verified; attempt++)
   {
      EXPERT::Run(chartId, prms);
      Sleep(1000);
      if(EXPERT::Parameters(chartId, params, names))
      {
         string gotPrompt = "";
         string gotUrl    = "";
         for(int i = 0; i < ArraySize(names); i++)
         {
            if(names[i] == "inpPromptFile") gotPrompt = params[i + 1].string_value;
            if(names[i] == "inpLocalUrl")   gotUrl    = params[i + 1].string_value;
         }
         if(gotPrompt == promptRel && gotUrl == m_llm.url)
            verified = true;
      }
   }
   if(!verified)
   {
      ChartClose(chartId);
      FileDelete(promptRel, FILE_COMMON);
      return "Sub-agent failed: forwarded inputs not applied on chart " + (string)chartId + ".";
   }

// Track for later collection
   int pendingCount = ArraySize(m_pendingSubAgents);
   ArrayResize(m_pendingSubAgents, pendingCount + 1);
   ArrayResize(m_pendingSubAgentPrompts, pendingCount + 1);
   m_pendingSubAgents[pendingCount]      = id;
   m_pendingSubAgentPrompts[pendingCount] = prompt;

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
string Agent::pollSubAgent(string subAgentId, bool appendToConversation)
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

// Clean up per-call files
   FileDelete(responseRel, FILE_COMMON);
   FileDelete(SUBAGENT_FOLDER + "\\" + subAgentId + ".prompt.txt", FILE_COMMON);

// Close the sub-agent's chart
   if(chartId != 0 && chartId != ChartID())
      ChartClose(chartId);

// Append to conversation
   if(response != "")
   {
      Print("[Agent] Sub-agent ", subAgentId, " (session ", subSession, ") returned: ", response);
      if(appendToConversation)
         pushMessage("user", "Sub-agent [" + subAgentId + "] result:\n" + response);
   }

   return response;
#else
   return "";
#endif
}

//+------------------------------------------------------------------+
//| Build a readable label for a sub-agent result                    |
//+------------------------------------------------------------------+
string Agent::subAgentLabel(string id, string prompt)
{
   string shortPrompt = prompt;
   StringReplace(shortPrompt, "\n", " ");
   StringReplace(shortPrompt, "\r", " ");
   StringReplace(shortPrompt, "\"", "");
   if(StringLen(shortPrompt) > 100)
      shortPrompt = StringSubstr(shortPrompt, 0, 100) + "...";
   return "Sub-agent " + id + " (prompt: \"" + shortPrompt + "\")";
}

//+------------------------------------------------------------------+
//| Wait for all sub-agents and return their results                 |
//+------------------------------------------------------------------+
string Agent::collectSubAgentsAndWait()
{
#ifdef __MQL5__
   CJAVal results;
   results.m_type = jtARRAY;
   const int timeoutAttempts = 600; // 10 minutes

   for(int attempt = 0; attempt < timeoutAttempts; attempt++)
   {
      const int pending = ArraySize(m_pendingSubAgents);
      if(pending == 0)
         break;

      string remainingIds[];
      string remainingPrompts[];
      int kept = 0;
      for(int i = 0; i < pending; i++)
      {
         const string id     = m_pendingSubAgents[i];
         const string prompt = m_pendingSubAgentPrompts[i];
         const string result = pollSubAgent(id, false);
         if(result != "")
            results.Add(subAgentLabel(id, prompt) + "\n" + result);
         else
         {
            ArrayResize(remainingIds, kept + 1);
            ArrayResize(remainingPrompts, kept + 1);
            remainingIds[kept]     = id;
            remainingPrompts[kept] = prompt;
            kept++;
         }
      }

      ArrayResize(m_pendingSubAgents, 0);
      ArrayResize(m_pendingSubAgentPrompts, 0);
      for(int i = 0; i < kept; i++)
      {
         ArrayResize(m_pendingSubAgents, i + 1);
         ArrayResize(m_pendingSubAgentPrompts, i + 1);
         m_pendingSubAgents[i]      = remainingIds[i];
         m_pendingSubAgentPrompts[i] = remainingPrompts[i];
      }
      if(kept == 0)
         break;
      Sleep(1000);
   }

   string out = "";
   const int resultCount = ArraySize(results.m_e);
   for(int i = 0; i < resultCount; i++)
   {
      if(i > 0) out += "\n\n";
      out += results[i].ToStr();
   }
   if(out == "")
      out = "No sub-agent results available.";
   else if(ArraySize(m_pendingSubAgents) > 0)
      out += "\n\nNote: " + (string)ArraySize(m_pendingSubAgents) + " sub-agent(s) did not finish within the timeout.";
   return out;
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

   string remainingIds[];
   string remainingPrompts[];
   int kept = 0;
   for(int i = 0; i < pendingCount; i++)
   {
      const string result = pollSubAgent(m_pendingSubAgents[i]);
      // Keep unfinished for next call
      if(result == "" && FileIsExist(SUBAGENT_FOLDER + "\\" + m_pendingSubAgents[i] + ".response.json", FILE_COMMON))
      {
         ArrayResize(remainingIds, kept + 1);
         ArrayResize(remainingPrompts, kept + 1);
         remainingIds[kept]     = m_pendingSubAgents[i];
         remainingPrompts[kept] = m_pendingSubAgentPrompts[i];
         kept++;
      }
   }
   ArrayResize(m_pendingSubAgents, 0);
   ArrayResize(m_pendingSubAgentPrompts, 0);
   for(int i = 0; i < kept; i++)
   {
      ArrayResize(m_pendingSubAgents, i + 1);
      ArrayResize(m_pendingSubAgentPrompts, i + 1);
      m_pendingSubAgents[i]      = remainingIds[i];
      m_pendingSubAgentPrompts[i] = remainingPrompts[i];
   }
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
