//+------------------------------------------------------------------+
//|                                                          llm.mqh |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict

enum ENUM_LLM_PROVIDER
{
   LLM_PROVIDER_OPENAI    = 0, // OpenAI
   LLM_PROVIDER_DEEPSEEK  = 1, // DeepSeek
   LLM_PROVIDER_ANTHROPIC = 2, // Anthropic
   LLM_PROVIDER_LOCAL     = 3  // Local
};

enum ENUM_LLM_MODEL
{
   LLM_MODEL_NONE = -1,                 // None
   LLM_MODEL_OPENAI_GPT_5_4_NANO  = 0,  // gpt-5.4-nano
   LLM_MODEL_OPENAI_GPT_5_4_MINI  = 1,  // gpt-5.4-mini
   LLM_MODEL_OPENAI_GPT_5_4       = 2,  // gpt-5.4
   LLM_MODEL_OPENAI_GPT_5_5       = 3,  // gpt-5.5
   LLM_MODEL_OPENAI_GPT_5_6_LUNA  = 4,  // gpt-5.6-luna
   LLM_MODEL_OPENAI_GPT_5_6_TERRA = 5,  // gpt-5.6-terra
   LLM_MODEL_OPENAI_GPT_5_6_SOL   = 6,  // gpt-5.6-sol
   LLM_MODEL_ANTHROPIC_SONNET_4_6 = 7,  // claude-sonnet-4-6
   LLM_MODEL_ANTHROPIC_SONNET_5   = 8,  // claude-sonnet-5
   LLM_MODEL_ANTHROPIC_OPUS_4_8   = 9,  // claude-opus-4-8
   LLM_MODEL_ANTHROPIC_OPUS_5     = 10, // claude-opus-5
   LLM_MODEL_ANTHROPIC_FABLE_5    = 11, // claude-fable-5
   LLM_MODEL_ANTHROPIC_HAIKU_4_5  = 12, // claude-haiku-4-5-20251001
   LLM_MODEL_DEEPSEEK_V4_FLASH    = 13, // deepseek-v4-flash
   LLM_MODEL_DEEPSEEK_V4_PRO      = 14, // deepseek-v4-pro
   LLM_MODEL_LOCAL_NONE           = 15, // local (no model)
   LLM_MODEL_LOCAL_QWEN3_5_9B     = 16, // qwen3.5:9b (local)
   LLM_MODEL_LOCAL_QWEN3_5_4B     = 17, // qwen3.5:4b (local)
   LLM_MODEL_LOCAL_QWEN3_5_2B     = 18, // qwen3.5:2b (local)
   LLM_MODEL_LOCAL_LLAMA3_2_3B    = 19, // llama3.2:3b (local)
   LLM_MODEL_LOCAL_LLAMA3_2_1B    = 20, // llama3.2:1b (local)
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class LLM
{
public:
   string id;
   string label;
   string model;
   string url;

   LLM(const ENUM_LLM_PROVIDER providerId = LLM_PROVIDER_DEEPSEEK, const int providerModel = LLM_MODEL_DEEPSEEK_V4_FLASH, const string localUrl = "http://127.0.0.1:8080/v1/chat/completions");
};
//+------------------------------------------------------------------+
LLM::LLM(const ENUM_LLM_PROVIDER providerId, const int providerModel, const string localUrl)
{
   switch(providerId)
   {
   case LLM_PROVIDER_OPENAI:
      id    = "openai";
      label = "OpenAI";
      url   = "https://api.openai.com/v1/chat/completions";
      break;
   case LLM_PROVIDER_DEEPSEEK:
      id    = "deepseek";
      label = "DeepSeek";
      url   = "https://api.deepseek.com/chat/completions";
      break;
   case LLM_PROVIDER_ANTHROPIC:
      id    = "anthropic";
      label = "Anthropic";
      url   = "https://api.anthropic.com/v1/chat/completions"; 
      break;
   case LLM_PROVIDER_LOCAL:
      id    = "local";
      label = "Local";
      url   = localUrl;
      break;
   default:
      Alert("Invalid provider_id. Must be 0 (OpenAI), 1 (DeepSeek), 2 (Anthropic) or 3 (Local).");
      return;
   }
   switch(providerModel)
   {
   case LLM_MODEL_OPENAI_GPT_5_4_NANO:
      model = "gpt-5.4-nano";
      break;
   case LLM_MODEL_OPENAI_GPT_5_4_MINI:
      model = "gpt-5.4-mini";
      break;
   case LLM_MODEL_OPENAI_GPT_5_4:
      model = "gpt-5.4";
      break;
   case LLM_MODEL_OPENAI_GPT_5_5:
      model = "gpt-5.5";
      break;
   case LLM_MODEL_OPENAI_GPT_5_6_LUNA:
      model = "gpt-5.6-luna";
      break;
   case LLM_MODEL_OPENAI_GPT_5_6_TERRA:
      model = "gpt-5.6-terra";
      break;
   case LLM_MODEL_OPENAI_GPT_5_6_SOL:
      model = "gpt-5.6-sol";
      break;
   case LLM_MODEL_ANTHROPIC_SONNET_4_6:
      model = "claude-sonnet-4-6";
      break;
   case LLM_MODEL_ANTHROPIC_SONNET_5:
      model = "claude-sonnet-5";
      break;
   case LLM_MODEL_ANTHROPIC_OPUS_4_8:
      model = "claude-opus-4-8";
      break;
   case LLM_MODEL_ANTHROPIC_OPUS_5:
      model = "claude-opus-5";
      break;
   case LLM_MODEL_ANTHROPIC_FABLE_5:
      model = "claude-fable-5";
      break;
   case LLM_MODEL_ANTHROPIC_HAIKU_4_5:
      model = "claude-haiku-4-5-20251001";
      break;
   case LLM_MODEL_DEEPSEEK_V4_FLASH:
      model = "deepseek-v4-flash";
      break;
   case LLM_MODEL_DEEPSEEK_V4_PRO:
      model = "deepseek-v4-pro";
      break;
   case LLM_MODEL_LOCAL_NONE:
      model = "";
      break;
   case LLM_MODEL_LOCAL_QWEN3_5_9B:
      model = "qwen3.5:9b";
      break;
   case LLM_MODEL_LOCAL_QWEN3_5_4B:
      model = "qwen3.5:4b";
      break;
   case LLM_MODEL_LOCAL_QWEN3_5_2B:
      model = "qwen3.5:2b";
      break;
   case LLM_MODEL_LOCAL_LLAMA3_2_3B:
      model = "llama3.2:3b";
      break;
   case LLM_MODEL_LOCAL_LLAMA3_2_1B:
      model = "llama3.2:1b";
      break;
   default:
      model = "";
      break;
   };
}
//+------------------------------------------------------------------+
