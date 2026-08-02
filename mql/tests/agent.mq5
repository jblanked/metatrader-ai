//+------------------------------------------------------------------+
//|                                                        agent.mq5 |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property version   "1.05"
#property strict

#include <metatrader-ai/mql/agent.mqh>

input string inpApiKey              = "sk-";                                       // Your API Key
input string inpPrompt              = "What do you see on my current chart?";      // Prompt
input ENUM_LLM_PROVIDER inpProvider = LLM_PROVIDER_DEEPSEEK;                       // LLM Provider
input ENUM_LLM_MODEL    inpModel    = LLM_MODEL_DEEPSEEK_V4_FLASH;                 // LLM Model
input string inpLocalUrl            = "http://127.0.0.1:8080/v1/chat/completions"; // Local LLM URL
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   Agent *agent = new Agent(inpApiKey, inpProvider, inpModel, inpLocalUrl);

   const string response = agent.run(inpPrompt);
   Print("[Agent] ", response);

   delete agent; // clean up the agent
   ExpertRemove();
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
{

}
//+------------------------------------------------------------------+
