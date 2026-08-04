//+------------------------------------------------------------------+
//|                                                        agent.mqh |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict

#include "llm.mqh"
#include "tools/mt5.mqh"
#include "tools/dispatch.mqh"
#include "tools/requests.mqh"
#include "tools/context.mqh"

//+------------------------------------------------------------------+
//| Agent — wraps multi-turn conversation state and OpenAI API calls |
//+------------------------------------------------------------------+
class Agent
{
public:
   Agent(
      string apiKey, 
      const ENUM_LLM_PROVIDER providerId = LLM_PROVIDER_DEEPSEEK, 
      const int providerModel = LLM_MODEL_DEEPSEEK_V4_FLASH,
      const string localUrl = "http://127.0.0.1:8080/v1/chat/completions",
      const ENUM_LLM_THINKING thinking = LLM_THINKING_MEDIUM
   );  // Constructor
   ~Agent();                  // Deconstructor
   void reset();              // Clear conversation history while preserving the system message
   string run(string prompt); // Process one user turn and return the assistant's final text response

private:
   CJAVal    m_messages;        // persistent conversation history (jtARRAY)
   Dispatch *m_dispatch;        // tool dispatcher
   string    m_headers;         // Content-Type + Authorization headers
   bool      m_initialized;     // is initialized
   string    m_deferredImageMsg;// user-role image message deferred until after all tool results
   LLM       m_llm;             // LLM configuration
   string    m_apiKey;          // API key

   string loadContextFiles();                                   // Read and concatenate all CONTEXT_FILES
   bool initialize();                                           // Load system prompt and context files
   void pushMessage(string role, string content);               // Append a standard role/content message
   void pushRaw(string serialized);                             // Append a pre-serialized JSON object (used for assistant messages with tool_calls)
   void pushToolResult(string toolCallId, string content);      // Append a tool result message
   void pushToolResultImage(string toolCallId, string b64data); // Append a tool result image
   void setThinking(CJAVal& payload);                           // Set the "thinking" parameter in the payload 
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
Agent::Agent(string apiKey, const ENUM_LLM_PROVIDER providerId, const int providerModel, const string localUrl, const ENUM_LLM_THINKING thinking)
{
   m_messages.m_type = jtARRAY;
   m_dispatch        = new Dispatch();
   m_llm             = LLM(providerId, providerModel, localUrl, thinking);
   m_apiKey          = apiKey;
   m_initialized     = initialize();
   m_headers = "Content-Type: application/json\r\n";
   if(m_llm.id != "local")
      m_headers += "Authorization: Bearer " + m_apiKey;
   m_deferredImageMsg = "";
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
