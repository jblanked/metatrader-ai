//+------------------------------------------------------------------+
//|                                                    sub-agent.mq5 |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property version   "1.00"
#property strict

#include <metatrader-ai/mql/agent.mqh>

input string inpApiKey              = "sk-";                                       // Your API Key
input string inpPrompt              = "What do you see on my current chart?";      // Prompt
input ENUM_LLM_PROVIDER inpProvider = LLM_PROVIDER_DEEPSEEK;                       // LLM Provider
input ENUM_LLM_MODEL    inpModel    = LLM_MODEL_DEEPSEEK_V4_FLASH;                 // LLM Model
input string inpLocalUrl            = "http://127.0.0.1:8080/v1/chat/completions"; // Local LLM URL

Agent *agent      = NULL;  // main agent
string subAgentId = "";    // launched sub-agent id
bool   done       = false; // response received

//+------------------------------------------------------------------+
//| Launch sub-agent and poll                                         |
//+------------------------------------------------------------------+
int OnInit()
{
   agent = new Agent(inpApiKey, inpProvider, inpModel, inpLocalUrl);

   subAgentId = agent.runSubAgent(inpPrompt);
   PrintFormat("[SubAgent] launched: %s", subAgentId);
   if(StringFind(subAgentId, "subagent_") != 0)
   {
      Print("[SubAgent] launch failed - removing expert");
      return INIT_FAILED;
   }

   EventSetMillisecondTimer(500);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Poll for sub-agent response                                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(done)
      return;
   if(CheckPointer(agent) != POINTER_DYNAMIC)
   {
      done = true;
      EventKillTimer();
      ExpertRemove();
      return;
   }

   const string response = agent.pollSubAgent(subAgentId);
   if(response == "")
      return; // not ready yet

   PrintFormat("[SubAgent] response:\n%s", response);
   done = true;
   EventKillTimer();

   ExpertRemove(); // done testing - remove this expert
}

//+------------------------------------------------------------------+
//| Clean up                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(CheckPointer(agent) == POINTER_DYNAMIC)
   {
      delete agent;
      agent = NULL;
   }
}
//+------------------------------------------------------------------+
