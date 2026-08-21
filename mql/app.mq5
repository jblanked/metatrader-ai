//+------------------------------------------------------------------+
//|                                                          app.mq5 |
//|                                      Copyright 2026,JBlanked LLC |
//|                                         https://www.jblanked.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked LLC"
#property link      "https://www.jblanked.com"
#property version   "1.09"
#property description "MetaTrader-AI: AI trading assistant for MetaTrader 5"
#property description "Last updated: August 21st, 2026"
#property strict

#include "agent.mqh"
#include "tools/Panel-Draw.mqh"
#include <VirtualKeys.mqh>

input string            inpApiKey       = "sk--";                                      // Your API Key
input ENUM_LLM_PROVIDER inpProvider     = LLM_PROVIDER_DEEPSEEK;                       // LLM Provider
input ENUM_LLM_MODEL    inpModel        = LLM_MODEL_DEEPSEEK_V4_FLASH;                 // LLM Model
input string            inpLocalUrl     = "http://127.0.0.1:8080/v1/chat/completions"; // Local LLM URL
input ENUM_LLM_THINKING inpThinking     = LLM_THINKING_NONE;                           // LLM Thinking Level
input bool              inpRunSubAgent  = false;                                       // Run prompt via sub-agent
input string            inpPrompt       = "";                                          // Prompt for sub-agent mode
input string            inpPromptFile   = "";                                          // Prompt file path
input string            inpResponseFile = "";                                          // Response file path
#define CHAT_RENDER_SCALE   1.0
#define MAX_OBJ_TEXT_CHARS  60
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_prevQuickNavigation = (ChartGetInteger(0, CHART_QUICK_NAVIGATION) != 0);
   g_prevQuickNavigationKnown = true;
   ChartSetInteger(0, CHART_QUICK_NAVIGATION, false);

   agent = new Agent(inpApiKey, inpProvider, inpModel, inpLocalUrl, inpThinking);

// Headless: run prompt here
   if(inpRunSubAgent)
   {
      g_subAgentHeadless = true;
      EventSetMillisecondTimer(500);
      return INIT_SUCCEEDED;
   }

   bool timerSet = EventSetMillisecondTimer(1);
   while(!timerSet)
   {
      timerSet = EventSetMillisecondTimer(1);
      Sleep(1);
   }

   int panelW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 1;
   int panelH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) - 1;
   ChartSetInteger(0, CHART_SHOW_ONE_CLICK, false);
   panel = new AIPanel("MetaTrader-AI", 0, 0, panelW, panelH, 0);
   if(CheckPointer(panel) != POINTER_DYNAMIC)
   {
      delete agent;
      return INIT_FAILED;
   }
   panel.SetAgent(agent);

   if(!panel.CreatePanel())
   {
      delete agent;
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   if(g_prevQuickNavigationKnown)
      ChartSetInteger(0, CHART_QUICK_NAVIGATION, g_prevQuickNavigation);

   if(CheckPointer(panel) == POINTER_DYNAMIC)
   {
      panel.Destroy(reason);
      delete panel;
   }

   if(CheckPointer(agent) == POINTER_DYNAMIC)
      delete agent;
}
//+------------------------------------------------------------------+
//| Expert on-event function                                         |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(CheckPointer(panel) == POINTER_DYNAMIC)
      panel.PanelChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
// Headless: run prompt once
   if(g_subAgentHeadless)
   {
      if(!g_subAgentDone)
      {
         g_subAgentDone = true;

         string prompt = inpPrompt;
         if(prompt == "")
         {
            // Sub-agent mode: common-files relative path
            if(inpPromptFile != "" && FileIsExist(inpPromptFile, FILE_COMMON))
            {
               int rh = FileOpen(inpPromptFile, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
               if(rh != INVALID_HANDLE)
               {
                  while(!FileIsEnding(rh))
                  {
                     prompt += FileReadString(rh);
                     if(!FileIsEnding(rh)) prompt += "\n";
                  }
                  FileClose(rh);
               }
            }
            // Manual use: absolute path
            if(prompt == "" && inpPromptFile != "" && fileExists(inpPromptFile) == "true")
               prompt = fileRead(inpPromptFile);
         }

         if(prompt == "")
         {
            Print("[App] No prompt for sub-agent mode");
            EventKillTimer();
            ExpertRemove();
            return;
         }

         string sessionName = agent.newSession();
         string response = agent.run(prompt);
         PrintFormat("[App] Sub-agent response:\n%s", response);

         // Write result file for parent
         if(inpResponseFile != "")
         {
            CJAVal result;
            result["response"] = response;
            result["session"]  = sessionName;
            result["chart_id"] = (long)ChartID();
            int w = FileOpen(inpResponseFile, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
            if(w != INVALID_HANDLE)
            {
               FileWriteString(w, result.Serialize());
               FileClose(w);
            }
         }

         EventKillTimer();
         ExpertRemove();
      }
      return;
   }

   if(CheckPointer(agent) == POINTER_DYNAMIC)
      agent.processScheduledTasks();

   panel.OnTickUpdate();

   if(panel.IsRequestPending())
   {
      string userMsg = panel.GetPendingMessage();
      string response = agent.run(userMsg);
      panel.CompletePending(response);
   }
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Chat message struct                                              |
//+------------------------------------------------------------------+
struct ChatMessage
{
   string            role;    // "user" or "assistant"
   string            content; // message text
   string            time;    // timestamp string
};

//+------------------------------------------------------------------+
//| AIPanel — pure chart-object AI panel                             |
//+------------------------------------------------------------------+
class AIPanel
{
private:
   // Tab state
   bool              m_isChatTab;
   bool              m_isInfoTab;
   bool              m_isSessionTab;
   bool              m_isTaskTab;
   bool              m_initialized;

   // Chat data
   ChatMessage       m_messages[];       // message storage
   int               m_messageCount;     // number of stored messages
   int               m_scrollOffset;     // chat scroll offset
   int               m_chatTotalHeight;  // total rendered chat height

   // Session data
   string            m_sessionNames[];   // session id list
   string            m_sessionPreviews[]; // cached preview text
   string            m_activeSessionName;
   int               m_sessionScrollOffset;
   int               m_sessionTotalHeight;
   int               m_sessionListTop;

   // Task data
   int               m_taskScrollOffset;
   int               m_taskTotalHeight;
   int               m_taskListTop;

   // Info data
   int               m_infoScrollOffset;
   int               m_infoTotalHeight;

   // Input state
   bool              m_inputFocused;
   string            m_inputBuffer;      // buffered input text
   string            m_localClipboard;   // internal clipboard fallback
   int               m_inputCursorPos;   // insertion point inside input buffer
   bool              m_shiftDown;        // shift key pressed state
   bool              m_ctrlDown;         // control key pressed state
   bool              m_altDown;          // alt/menu key pressed state
   int               m_inputMaxChars;    // hard cap for user input
   int               m_copyFlashCounter; // copy button flash counter

   // Agent
   Agent             *m_agent;
   bool              m_requestPending;   // waiting for AI response
   string            m_pendingMsg;       // last sent message

   // Layout constants
   int               m_panelW;
   int               m_panelH;
   int               m_tabHeight;
   int               m_inputAreaHeight;
   int               m_margin;
   int               m_msgSpacing;
   int               m_chatTop;
   int               m_chatBottom;
   int               m_chatHeight;
   int               m_copyBtnW;

   // Colors
   color             m_clrBg;
   color             m_clrUserBubble;
   color             m_clrAiBubble;
   color             m_clrUserText;
   color             m_clrAiText;
   color             m_clrTabActive;
   color             m_clrTabInactive;
   color             m_clrTabText;
   color             m_clrInputBg;
   color             m_clrSendBtn;
   color             m_clrSendText;
   color             m_clrAccent;
   color             m_clrBorder;

   // DPI
   int               m_dpi;
   double            m_dpiScale;

   // Internal
   string            m_panelName;
   int               m_tickCounter;      // tick counter for periodic refresh

   // Object name tracking
   string            m_allObjects[];     // every created object name
   string            m_msgLabels[];      // chat line object names
   int               m_msgLabelCount;
   string            m_infoLabels[];     // info label object names
   int               m_infoLabelCount;
   string            m_sessionBtns[];    // session button object names
   int               m_sessionBtnCount;
   string            m_sessionDeleteBtns[]; // delete button names
   int               m_sessionDeleteBtnCount;
   string            m_taskLabels[];     // task label object names
   int               m_taskLabelCount;
   string            m_taskCancelBtns[]; // task cancel object names
   int               m_taskCancelBtnCount;
   string            m_inputLabels[];    // input text label object names
   int               m_inputLabelCount;

   // Object helpers
   void              RegisterObject(const string name);
   void              CreateButton(const string name, const string text, const int x1, const int y1, const int x2, const int y2, const color textClr, const color bgClr, const int fontSize);
   void              CreateEditObj(const string name, const int x1, const int y1, const int x2, const int y2, const color textClr, const color bgClr, const int fontSize);
   void              CreateTextLabel(const string name, const string text, const int x, const int y, const color textClr, const int fontSize);
   void              SetObjectVisible(const string name, const bool show);
   void              DestroyAllObjects();

   // Tab helpers
   void              ApplyTabState();
   void              SwitchToChat();
   void              SwitchToInfo();
   void              SwitchToSession();
   void              SwitchToTasks();

   // Render helpers
   void              RenderMessages();
   void              ClearInfoLabels();
   void              PopulateInfoTab();
   void              AddInfoRow(int &yPos, int col1X, int col1W, int col2X, int col2W, int labelH, bool isHeader, string key, string val);
   void              CacheSessionList();
   void              RefreshSessionList();
   void              RefreshTaskList();
   void              ClearChatMessages();
   void              AppendMessage(const string role, const string content);
   void              LoadConversationFromAgent();
   void              RefreshInputText();
   string            SessionDisplayName(const string name, string preview);

   // Input helpers
   void              InsertTextAtCursor(const string text);
   bool              HandleInputKey(const long keyCode);
   string            KeyCodeToChar(const int keyCode, const bool shiftPressed);
   void              SetModifierKeyState(const int keyCode, const bool down);
   void              SendCurrentMessage();
   void              NewSession();
   void              LoadSession(const string name);
   void              DeleteSession(const string name);
   void              CopyConversation();

   // Text helpers
   string            FormatTimestamp();
   int               MaxCharsPerLine();
   int               ChatLabelWidth();
   int               CalibrateCharWidth(const int fontSize);
   void              WrapText(string text, int maxChars, string &lines[], int &lineCount);

public:
   // Constructor / Destructor
                     AIPanel(
      const string name,
      const int x1 = 0,
      const int y1 = 0,
      const int x2 = NULL,
      const int y2 = NULL,
      const int subWindow = 0
   );
                    ~AIPanel();

   // Lifecycle
   bool              CreatePanel();
   void              Destroy(const int reason);
   void              PanelChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
   void              OnTickUpdate();
   bool              OnResize(void);

   // Public methods
   void              AddMessage(const string role, const string content);
   void              RefreshInfo();
   void              SetAgent(Agent *ag)
   {
      m_agent = ag;
   }
   bool              IsRequestPending()
   {
      return m_requestPending;
   }
   string            GetPendingMessage()
   {
      return m_pendingMsg;
   }
   void              CompletePending(const string response);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
AIPanel::AIPanel(
   const string name,
   const int x1 = 0,
   const int y1 = 0,
   const int x2 = NULL,
   const int y2 = NULL,
   const int subWindow = 0
)
{
   m_isChatTab       = true;
   m_isInfoTab       = false;
   m_isSessionTab    = false;
   m_isTaskTab       = false;
   m_initialized     = false;
   m_messageCount    = 0;
   m_msgLabelCount   = 0;
   m_infoLabelCount  = 0;
   m_scrollOffset    = 0;
   m_agent           = NULL;
   m_requestPending  = false;
   m_pendingMsg      = "";
   m_inputFocused    = true;
   m_inputBuffer     = "";
   m_localClipboard  = "";
   m_inputCursorPos  = 0;
   m_shiftDown       = false;
   m_ctrlDown        = false;
   m_altDown         = false;
   m_inputMaxChars   = 1024;
   m_tickCounter     = 0;
   m_chatTotalHeight = 0;
   m_infoScrollOffset = 0;
   m_infoTotalHeight = 0;
   m_sessionBtnCount = 0;
   m_sessionDeleteBtnCount = 0;
   m_sessionScrollOffset = 0;
   m_sessionTotalHeight = 0;
   m_sessionListTop  = 0;
   m_activeSessionName = "";
   ArrayResize(m_sessionNames, 0);
   ArrayResize(m_sessionPreviews, 0);
   ArrayResize(m_sessionDeleteBtns, 0);
   m_taskLabelCount = 0;
   m_taskCancelBtnCount = 0;
   m_taskScrollOffset = 0;
   m_taskTotalHeight = 0;
   m_taskListTop = 0;
   m_copyFlashCounter = 0;
   m_inputLabelCount = 0;

// DPI scaling
   m_dpi             = (int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(m_dpi < 96) m_dpi = 96;
   m_dpiScale        = (double)m_dpi / 96.0;
   m_copyBtnW        = (int)(55 * m_dpiScale);

// Layout constants
   m_tabHeight       = (int)(28 * m_dpiScale);
   m_inputAreaHeight = (int)(40 * m_dpiScale);
   m_margin          = (int)(4 * m_dpiScale);
   m_msgSpacing      = (int)(6 * m_dpiScale);

// Color scheme
   m_clrBg           = C'30,30,30';        // Dark background
   m_clrUserBubble   = C'10,132,255';      // Blue bubble (user)
   m_clrAiBubble     = C'55,55,60';        // Dark gray bubble (AI)
   m_clrUserText     = clrWhite;
   m_clrAiText       = C'220,220,220';
   m_clrTabActive    = C'50,50,55';        // Active tab
   m_clrTabInactive  = C'35,35,40';        // Inactive tab
   m_clrTabText      = C'200,200,200';
   m_clrInputBg      = C'45,45,50';        // Input area bg
   m_clrSendBtn      = C'10,132,255';      // Send button (blue accent)
   m_clrSendText     = clrWhite;
   m_clrAccent       = C'10,132,255';      // Blue accent
   m_clrBorder       = C'60,60,65';        // Border color
   m_panelName       = name;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
AIPanel::~AIPanel()
{
   DestroyAllObjects();
}

//+------------------------------------------------------------------+
//| Destroy panel objects                                            |
//+------------------------------------------------------------------+
void AIPanel::Destroy(const int reason)
{
   DestroyAllObjects();
}

//+------------------------------------------------------------------+
//| Register an object name for cleanup                              |
//+------------------------------------------------------------------+
void AIPanel::RegisterObject(const string name)
{
   int n = ArraySize(m_allObjects);
   ArrayResize(m_allObjects, n + 1);
   m_allObjects[n] = name;
}

//+------------------------------------------------------------------+
//| Delete every created object                                      |
//+------------------------------------------------------------------+
void AIPanel::DestroyAllObjects()
{
   for(int i = 0; i < ArraySize(m_allObjects); i++)
   {
      if(m_allObjects[i] != "" && ObjectFind(0, m_allObjects[i]) >= 0)
         ObjectDelete(0, m_allObjects[i]);
   }
   ArrayResize(m_allObjects, 0);
   ArrayResize(m_msgLabels, 0);
   ArrayResize(m_infoLabels, 0);
   ArrayResize(m_sessionBtns, 0);
   ArrayResize(m_sessionDeleteBtns, 0);
   ArrayResize(m_taskLabels, 0);
   ArrayResize(m_taskCancelBtns, 0);
   ArrayResize(m_inputLabels, 0);
   m_msgLabelCount = 0;
   m_infoLabelCount = 0;
   m_sessionBtnCount = 0;
   m_sessionDeleteBtnCount = 0;
   m_taskLabelCount = 0;
   m_taskCancelBtnCount = 0;
   m_inputLabelCount = 0;
}

//+------------------------------------------------------------------+
//| Create a raw button object                                       |
//+------------------------------------------------------------------+
void AIPanel::CreateButton(const string name, const string text, const int x1, const int y1, const int x2, const int y2, const color textClr, const color bgClr, const int fontSize)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      return;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, MathMax(1, x2 - x1));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, MathMax(1, y2 - y1));
   ObjectSetInteger(0, name, OBJPROP_COLOR, textClr);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   RegisterObject(name);
}

//+------------------------------------------------------------------+
//| Create a raw edit object                                         |
//+------------------------------------------------------------------+
void AIPanel::CreateEditObj(const string name, const int x1, const int y1, const int x2, const int y2, const color textClr, const color bgClr, const int fontSize)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0))
      return;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, MathMax(1, x2 - x1));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, MathMax(1, y2 - y1));
   ObjectSetInteger(0, name, OBJPROP_COLOR, textClr);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, m_clrBorder);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_LEFT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_READONLY, true);
   ObjectSetString(0, name, OBJPROP_TEXT, "");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   RegisterObject(name);
}

//+------------------------------------------------------------------+
//| Create a raw text label object (keep text <= 60 chars)           |
//+------------------------------------------------------------------+
void AIPanel::CreateTextLabel(const string name, const string text, const int x, const int y, const color textClr, const int fontSize)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textClr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   RegisterObject(name);
}

//+------------------------------------------------------------------+
//| Show or hide an object via timeframes                            |
//+------------------------------------------------------------------+
void AIPanel::SetObjectVisible(const string name, const bool show)
{
   if(ObjectFind(0, name) >= 0)
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, show ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
}

//+------------------------------------------------------------------+
//| Delete info labels                                               |
//+------------------------------------------------------------------+
void AIPanel::ClearInfoLabels()
{
   for(int i = 0; i < m_infoLabelCount; i++)
   {
      if(m_infoLabels[i] != "" && ObjectFind(0, m_infoLabels[i]) >= 0)
         ObjectDelete(0, m_infoLabels[i]);
   }
   ArrayResize(m_infoLabels, 0);
   m_infoLabelCount = 0;
}

//+------------------------------------------------------------------+
//| Create panel and controls                                        |
//+------------------------------------------------------------------+
bool AIPanel::CreatePanel()
{
   m_panelW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 1;
   m_panelH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) - 1;
   if(m_panelW < 200) m_panelW = 300;
   if(m_panelH < 200) m_panelH = 400;

   m_chatTop    = m_tabHeight + m_margin;
   m_chatBottom = m_panelH - m_inputAreaHeight - m_margin;
   m_chatHeight = m_chatBottom - m_chatTop;
   if(m_chatHeight < (int)(50 * m_dpiScale)) m_chatHeight = (int)(50 * m_dpiScale);

// DPI-scaled sizes
   int tabBtnW    = (int)(80 * m_dpiScale);
   int tabBtnGap  = 2;
   int sendW      = (int)(65 * m_dpiScale);
   int sendH      = (int)(30 * m_dpiScale);
   int inputH     = (int)(30 * m_dpiScale);
   int scrlSize   = (int)(20 * m_dpiScale);

// Background rectangle
   string bgName = m_panelName + "_Bg";
   if(ObjectFind(0, bgName) >= 0)
      ObjectDelete(0, bgName);
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 0);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, m_panelW);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, m_panelH);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, m_clrBg);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, m_clrBorder);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   RegisterObject(bgName);

// Tab buttons
   CreateButton(m_panelName + "_TabChat", "Chat", 0, 0, tabBtnW, m_tabHeight, m_clrTabText, m_clrTabActive, 11);
   CreateButton(m_panelName + "_TabInfo", "Info", tabBtnW + tabBtnGap, 0, tabBtnW * 2 + tabBtnGap, m_tabHeight, m_clrTabText, m_clrTabInactive, 11);
   CreateButton(m_panelName + "_TabSession", "Session", tabBtnW * 2 + tabBtnGap * 2, 0, tabBtnW * 3 + tabBtnGap * 2, m_tabHeight, m_clrTabText, m_clrTabInactive, 11);
   CreateButton(m_panelName + "_TabTasks", "Tasks", tabBtnW * 3 + tabBtnGap * 3, 0, tabBtnW * 4 + tabBtnGap * 3, m_tabHeight, m_clrTabText, m_clrTabInactive, 11);

// Input area
   int inputY    = m_panelH - m_inputAreaHeight;
   int sendX     = m_panelW - sendW - m_margin;
   int copyGap   = (int)(6 * m_dpiScale);
   int copyX     = sendX - m_copyBtnW - copyGap;
   int inputX    = m_margin;
   int inputY_C  = inputY + (m_inputAreaHeight - inputH) / 2;

   CreateEditObj(m_panelName + "_Input", inputX, inputY_C, copyX - m_margin, inputY_C + inputH, m_clrAiText, m_clrInputBg, 11);
   CreateButton(m_panelName + "_Copy", "Copy", copyX, inputY_C, copyX + m_copyBtnW, inputY_C + sendH, m_clrTabText, m_clrTabInactive, 11);
   CreateButton(m_panelName + "_Send", "Send", sendX, inputY_C, sendX + sendW, inputY_C + sendH, m_clrSendText, m_clrSendBtn, 11);

// Scroll buttons
   int scrollY = m_chatTop + (int)(2 * m_dpiScale);
   int scrollX = m_panelW - scrlSize - m_margin;
   CreateButton(m_panelName + "_ScrlUp", "▲", scrollX, scrollY, scrollX + scrlSize, scrollY + scrlSize, m_clrTabText, m_clrTabInactive, 9);
   CreateButton(m_panelName + "_ScrlDn", "▼", scrollX, scrollY + scrlSize + (int)(2 * m_dpiScale), scrollX + scrlSize, scrollY + scrlSize * 2 + (int)(2 * m_dpiScale), m_clrTabText, m_clrTabInactive, 9);

// New Session button
   int newBtnH = (int)(28 * m_dpiScale);
   int newBtnY = m_chatTop + (int)(2 * m_dpiScale);
   int newBtnW = m_panelW - scrlSize - m_margin * 3;
   CreateButton(m_panelName + "_NewSession", "New Session", m_margin, newBtnY, m_margin + newBtnW, newBtnY + newBtnH, m_clrSendText, m_clrSendBtn, 11);
   m_sessionListTop = newBtnY + newBtnH + m_margin;

// Close button
   int closeSz = (int)(28 * m_dpiScale);
   int closeX = m_panelW - closeSz - m_margin;
   CreateButton(m_panelName + "_CloseX", "X", closeX, 0, closeX + closeSz, m_tabHeight, m_clrSendText, m_clrSendBtn, 11);

// Initial tab: Session
   m_isChatTab    = false;
   m_isInfoTab    = false;
   m_isSessionTab = true;
   m_isTaskTab    = false;
   CacheSessionList();
   ApplyTabState();
   RefreshSessionList();
   RefreshInputText();

   m_initialized = true;
   ChartRedraw();
   return true;
}

//+------------------------------------------------------------------+
//| Apply current tab visibility and colors                          |
//+------------------------------------------------------------------+
void AIPanel::ApplyTabState()
{
   ObjectSetInteger(0, m_panelName + "_TabChat", OBJPROP_BGCOLOR, m_isChatTab ? m_clrTabActive : m_clrTabInactive);
   ObjectSetInteger(0, m_panelName + "_TabInfo", OBJPROP_BGCOLOR, m_isInfoTab ? m_clrTabActive : m_clrTabInactive);
   ObjectSetInteger(0, m_panelName + "_TabSession", OBJPROP_BGCOLOR, m_isSessionTab ? m_clrTabActive : m_clrTabInactive);
   ObjectSetInteger(0, m_panelName + "_TabTasks", OBJPROP_BGCOLOR, m_isTaskTab ? m_clrTabActive : m_clrTabInactive);

   SetObjectVisible(m_panelName + "_Input", m_isChatTab);
   SetObjectVisible(m_panelName + "_Send", m_isChatTab);
   SetObjectVisible(m_panelName + "_Copy", m_isChatTab);
   SetObjectVisible(m_panelName + "_ScrlUp", true);
   SetObjectVisible(m_panelName + "_ScrlDn", true);
   SetObjectVisible(m_panelName + "_NewSession", m_isSessionTab);
   SetObjectVisible(m_panelName + "_CloseX", true);

   for(int i = 0; i < m_inputLabelCount; i++)
      SetObjectVisible(m_inputLabels[i], m_isChatTab);
   for(int i = 0; i < m_msgLabelCount; i++)
      SetObjectVisible(m_msgLabels[i], m_isChatTab);
   for(int i = 0; i < m_infoLabelCount; i++)
      SetObjectVisible(m_infoLabels[i], m_isInfoTab);
   for(int i = 0; i < m_sessionBtnCount; i++)
      SetObjectVisible(m_sessionBtns[i], m_isSessionTab);
   for(int i = 0; i < m_sessionDeleteBtnCount; i++)
      SetObjectVisible(m_sessionDeleteBtns[i], m_isSessionTab);
   for(int i = 0; i < m_taskLabelCount; i++)
      SetObjectVisible(m_taskLabels[i], m_isTaskTab);
   for(int i = 0; i < m_taskCancelBtnCount; i++)
      SetObjectVisible(m_taskCancelBtns[i], m_isTaskTab);
}

//+------------------------------------------------------------------+
//| Switch to Chat tab                                               |
//+------------------------------------------------------------------+
void AIPanel::SwitchToChat()
{
   m_isChatTab    = true;
   m_isInfoTab    = false;
   m_isSessionTab = false;
   m_isTaskTab    = false;
   m_inputFocused = true;
   m_copyFlashCounter = 0;
   ObjectSetString(0, m_panelName + "_Copy", OBJPROP_TEXT, "Copy");
   RefreshInputText();
   ApplyTabState();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Switch to Info tab                                               |
//+------------------------------------------------------------------+
void AIPanel::SwitchToInfo()
{
   m_isChatTab    = false;
   m_isInfoTab    = true;
   m_isSessionTab = false;
   m_isTaskTab    = false;
   m_inputFocused = false;
   RefreshInputText();
   m_infoScrollOffset = 0;
   PopulateInfoTab();
   ApplyTabState();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Switch to Session tab                                            |
//+------------------------------------------------------------------+
void AIPanel::SwitchToSession()
{
   m_isChatTab    = false;
   m_isInfoTab    = false;
   m_isSessionTab = true;
   m_isTaskTab    = false;
   m_inputFocused = false;
   RefreshInputText();
   RefreshSessionList();
   ApplyTabState();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Switch to Tasks tab                                              |
//+------------------------------------------------------------------+
void AIPanel::SwitchToTasks()
{
   m_isChatTab    = false;
   m_isInfoTab    = false;
   m_isSessionTab = false;
   m_isTaskTab    = true;
   m_inputFocused = false;
   RefreshInputText();
   m_taskScrollOffset = 0;
   RefreshTaskList();
   ApplyTabState();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Session/task visibility is handled by ApplyTabState()            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Format a session name into a display label                       |
//+------------------------------------------------------------------+
string AIPanel::SessionDisplayName(const string name, string preview)
{
   int pos = StringFind(name, "_");
   if(pos < 0) return name;
   long id = StringToInteger(StringSubstr(name, pos + 1));
   if(id <= 0) return name;

   string date = TimeToString((datetime)id, TIME_DATE | TIME_MINUTES);
   if(preview == "") return date;

   int panelW = m_panelW;
   int scrlSize = (int)(20 * m_dpiScale);
   int deleteW = (int)(26 * m_dpiScale);
   int deleteGap = (int)(4 * m_dpiScale);
   int btnW = panelW - scrlSize - m_margin * 3 - (int)(4 * m_dpiScale) - deleteW - deleteGap;
   double charWidth = (9.0 * m_dpi / 72.0) * 0.60;
   int maxPreviewChars = (int)(btnW / charWidth) - StringLen(date) - 2;
   if(maxPreviewChars < 4) return date;
   if(StringLen(preview) > maxPreviewChars)
      preview = StringSubstr(preview, 0, maxPreviewChars - 3) + "...";

   return preview + "  " + date;
}

//+------------------------------------------------------------------+
//| Cache saved session metadata                                    |
//+------------------------------------------------------------------+
void AIPanel::CacheSessionList()
{
   int count = sessionList(m_sessionNames);
   ArrayResize(m_sessionPreviews, count);
   for(int i = 0; i < count; i++)
      m_sessionPreviews[i] = sessionPreview(m_sessionNames[i]);
}

//+------------------------------------------------------------------+
//| Rebuild the session list buttons                                 |
//+------------------------------------------------------------------+
void AIPanel::RefreshSessionList()
{
   for(int i = 0; i < m_sessionBtnCount; i++)
   {
      if(m_sessionBtns[i] != "" && ObjectFind(0, m_sessionBtns[i]) >= 0)
         ObjectDelete(0, m_sessionBtns[i]);
   }
   for(int i = 0; i < m_sessionDeleteBtnCount; i++)
   {
      if(m_sessionDeleteBtns[i] != "" && ObjectFind(0, m_sessionDeleteBtns[i]) >= 0)
         ObjectDelete(0, m_sessionDeleteBtns[i]);
   }
   ArrayResize(m_sessionBtns, 0);
   ArrayResize(m_sessionDeleteBtns, 0);
   m_sessionBtnCount = 0;
   m_sessionDeleteBtnCount = 0;

   int count = ArraySize(m_sessionNames);
   if(count == 0)
   {
      m_sessionTotalHeight = 0;
      ChartRedraw();
      return;
   }

   int panelW = m_panelW;
   int scrlSize = (int)(20 * m_dpiScale);
   const int LINE_H = (int)(26 * m_dpiScale);
   const int gap = (int)(4 * m_dpiScale);
   const int deleteW = (int)(26 * m_dpiScale);
   const int deleteGap = (int)(4 * m_dpiScale);
   m_sessionTotalHeight = count * LINE_H + (count - 1) * gap;
   int maxScroll = MathMax(0, m_sessionTotalHeight - (m_chatBottom - m_sessionListTop));
   m_sessionScrollOffset = MathMin(maxScroll, MathMax(0, m_sessionScrollOffset));

   int yPos = m_sessionListTop - m_sessionScrollOffset;
   int btnX = m_margin + (int)(4 * m_dpiScale);
   int btnW = panelW - scrlSize - m_margin * 3 - (int)(4 * m_dpiScale) - deleteW - deleteGap;
   int deleteX = btnX + btnW + deleteGap;

   for(int i = 0; i < count; i++)
   {
      int yEnd = yPos + LINE_H;
      if(yEnd > m_sessionListTop && yPos < m_chatBottom)
      {
         int n = m_sessionBtnCount;
         ArrayResize(m_sessionBtns, n + 1);
         m_sessionBtnCount = n + 1;
         m_sessionBtns[n] = m_panelName + "_Sess" + IntegerToString(i);
         CreateButton(m_sessionBtns[n], SessionDisplayName(m_sessionNames[i], m_sessionPreviews[i]), btnX, yPos, btnX + btnW, yPos + LINE_H, m_clrAiText, m_clrTabInactive, 9);
         if(!m_isSessionTab)
            SetObjectVisible(m_sessionBtns[n], false);

         int d = m_sessionDeleteBtnCount;
         ArrayResize(m_sessionDeleteBtns, d + 1);
         m_sessionDeleteBtnCount = d + 1;
         m_sessionDeleteBtns[d] = m_panelName + "_SessDelete" + IntegerToString(i);
         CreateButton(m_sessionDeleteBtns[d], "X", deleteX, yPos, deleteX + deleteW, yPos + LINE_H, m_clrTabText, m_clrTabInactive, 9);
         if(!m_isSessionTab)
            SetObjectVisible(m_sessionDeleteBtns[d], false);
      }
      yPos += LINE_H + gap;
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Rebuild the scheduled task list                                 |
//+------------------------------------------------------------------+
void AIPanel::RefreshTaskList()
{
   for(int i = 0; i < m_taskLabelCount; i++)
   {
      if(m_taskLabels[i] != "" && ObjectFind(0, m_taskLabels[i]) >= 0)
         ObjectDelete(0, m_taskLabels[i]);
   }
   for(int i = 0; i < m_taskCancelBtnCount; i++)
   {
      if(m_taskCancelBtns[i] != "" && ObjectFind(0, m_taskCancelBtns[i]) >= 0)
         ObjectDelete(0, m_taskCancelBtns[i]);
   }
   ArrayResize(m_taskLabels, 0);
   ArrayResize(m_taskCancelBtns, 0);
   m_taskLabelCount = 0;
   m_taskCancelBtnCount = 0;

   if(CheckPointer(m_agent) != POINTER_DYNAMIC)
      return;

   CJAVal taskArray;
   if(!taskArray.Deserialize(m_agent.scheduledTasks()) || taskArray.m_type != jtARRAY)
      return;

   const int count = ArraySize(taskArray.m_e);
   const int panelW = m_panelW;
   const int scrlSize = (int)(20 * m_dpiScale);
   const int rowH = (int)(34 * m_dpiScale);
   const int cancelW = (int)(58 * m_dpiScale);
   const int labelX = m_margin + (int)(4 * m_dpiScale);
   const int cancelX = panelW - scrlSize - m_margin - cancelW;
   const int labelW = cancelX - labelX - (int)(4 * m_dpiScale);

   m_taskListTop = m_chatTop + (int)(4 * m_dpiScale);
   m_taskTotalHeight = MathMax(0, count * rowH);
   int maxScroll = MathMax(0, m_taskTotalHeight - m_chatHeight);
   m_taskScrollOffset = MathMin(maxScroll, MathMax(0, m_taskScrollOffset));
   int yPos = m_taskListTop - m_taskScrollOffset;

   if(count == 0)
   {
      ArrayResize(m_taskLabels, 1);
      m_taskLabelCount = 1;
      m_taskLabels[0] = m_panelName + "_TaskEmpty";
      CreateTextLabel(m_taskLabels[0], "No scheduled tasks", labelX, m_taskListTop, m_clrAiText, 10);
      if(!m_isTaskTab)
         SetObjectVisible(m_taskLabels[0], false);
      ChartRedraw();
      return;
   }

   for(int i = 0; i < count; i++)
   {
      int yEnd = yPos + rowH;
      if(yEnd > m_chatTop && yPos < m_chatBottom)
      {
         int labelIndex = m_taskLabelCount;
         ArrayResize(m_taskLabels, labelIndex + 1);
         m_taskLabelCount = labelIndex + 1;
         m_taskLabels[labelIndex] = m_panelName + "_Task" + IntegerToString(i);

         const long id = taskArray[i]["id"].ToInt();
         const string status = taskArray[i]["status"].ToStr();
         const string recurrence = taskArray[i]["recurrence"].ToStr();
         const string repeatText = recurrence == "none" || recurrence == "" ? "once" : recurrence;
         string text = StringFormat("#%d %s | %s | %s | %s | %s",
                                    (int)id,
                                    taskArray[i]["name"].ToStr(),
                                    taskArray[i]["execution_time"].ToStr(),
                                    repeatText,
                                    status,
                                    taskArray[i]["tool_name"].ToStr());
         int maxChars = MathMax(12, MathMin(MAX_OBJ_TEXT_CHARS, (int)(labelW / ((9.0 * m_dpi / 72.0) * 0.60))));
         if(StringLen(text) > maxChars)
            text = StringSubstr(text, 0, maxChars - 3) + "...";

         CreateTextLabel(m_taskLabels[labelIndex], text, labelX, yPos, m_clrAiText, 9);
         if(!m_isTaskTab)
            SetObjectVisible(m_taskLabels[labelIndex], false);

         if(status == "pending")
         {
            int buttonIndex = m_taskCancelBtnCount;
            ArrayResize(m_taskCancelBtns, buttonIndex + 1);
            m_taskCancelBtnCount = buttonIndex + 1;
            m_taskCancelBtns[buttonIndex] = m_panelName + "_TaskCancel" + IntegerToString((int)id);
            CreateButton(m_taskCancelBtns[buttonIndex], "Cancel", cancelX, yPos, cancelX + cancelW, yEnd, m_clrTabText, m_clrTabInactive, 9);
            if(!m_isTaskTab)
               SetObjectVisible(m_taskCancelBtns[buttonIndex], false);
         }
      }
      yPos += rowH;
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Start a new session and show the chat tab                        |
//+------------------------------------------------------------------+
void AIPanel::NewSession()
{
   if(m_requestPending) return;
   if(CheckPointer(m_agent) != POINTER_DYNAMIC) return;

   string name = m_agent.newSession();
   if(name == "") return;

   m_activeSessionName = name;
   CacheSessionList();
   ClearChatMessages();
   SwitchToChat();
}

//+------------------------------------------------------------------+
//| Load a saved session and show the chat tab                       |
//+------------------------------------------------------------------+
void AIPanel::LoadSession(string name)
{
   if(m_requestPending) return;
   if(CheckPointer(m_agent) != POINTER_DYNAMIC) return;

   if(!m_agent.loadSession(name)) return;

   m_activeSessionName = name;
   CacheSessionList();
   ClearChatMessages();
   LoadConversationFromAgent();
   SwitchToChat();
}

//+------------------------------------------------------------------+
//| Delete a saved session                                           |
//+------------------------------------------------------------------+
void AIPanel::DeleteSession(const string name)
{
   if(m_requestPending) return;
   if(CheckPointer(m_agent) != POINTER_DYNAMIC) return;

   if(name == "" || StringFind(name, "\\") >= 0 || StringFind(name, "/") >= 0)
      return;

   const string path = "metatrader-ai\\sessions\\" + name + ".json";
   if(FileIsExist(path, FILE_COMMON) && !FileDelete(path, FILE_COMMON))
      return;

   if(name == m_activeSessionName)
   {
      m_agent.reset();
      m_activeSessionName = m_agent.newSession();
      ClearChatMessages();
   }
   else if(m_agent.historyCount() <= 1)
      ClearChatMessages();
   CacheSessionList();
   RefreshSessionList();
}

//+------------------------------------------------------------------+
//| Refresh input text                                               |
//+------------------------------------------------------------------+
void AIPanel::RefreshInputText()
{
   const string inputName = m_panelName + "_Input";
   int sendW = (int)(65 * m_dpiScale);
   int copyGap = (int)(6 * m_dpiScale);
   int panelW = m_panelW;
   int inputPixelW = panelW - (int)(m_margin * 3) - sendW - m_copyBtnW - copyGap;
   if(inputPixelW < (int)(80 * m_dpiScale))
      inputPixelW = (int)(80 * m_dpiScale);
   if(ObjectFind(0, inputName) >= 0)
   {
      ObjectSetInteger(0, inputName, OBJPROP_XDISTANCE, m_margin);
      ObjectSetInteger(0, inputName, OBJPROP_XSIZE, inputPixelW);
   }

// Delete old input text labels
   for(int i = 0; i < m_inputLabelCount; i++)
   {
      if(m_inputLabels[i] != "" && ObjectFind(0, m_inputLabels[i]) >= 0)
         ObjectDelete(0, m_inputLabels[i]);
   }
   ArrayResize(m_inputLabels, 0);
   m_inputLabelCount = 0;

   int VIEW_MAX = MathMax(8, inputPixelW / CalibrateCharWidth(11) - 3);

   int len = StringLen(m_inputBuffer);

   if(m_inputCursorPos < 0)
      m_inputCursorPos = 0;
   if(m_inputCursorPos > len)
      m_inputCursorPos = len;

   int start = 0;
   if(len > VIEW_MAX)
   {
      start = m_inputCursorPos - VIEW_MAX / 2;
      if(start < 0)
         start = 0;
      if(start > len - VIEW_MAX)
         start = len - VIEW_MAX;
   }

   int viewLen = MathMin(VIEW_MAX, len - start);
   string view = StringSubstr(m_inputBuffer, start, viewLen);
   int cursorInView = m_inputCursorPos - start;

   if(cursorInView < 0)
      cursorInView = 0;
   if(cursorInView > StringLen(view))
      cursorInView = StringLen(view);

   string left  = StringSubstr(view, 0, cursorInView);
   string right = StringSubstr(view, cursorInView);
   string prefix = (start > 0) ? "<" : "";
   string suffix = ((start + viewLen) < len) ? ">" : "";
   string display = prefix + left + "|" + right + suffix;

   if(ObjectFind(0, inputName) >= 0)
      ObjectSetString(0, inputName, OBJPROP_TEXT, "");

// Render input as chunked labels
   int inputH = (int)(30 * m_dpiScale);
   int inputY_C = m_panelH - m_inputAreaHeight + (m_inputAreaHeight - inputH) / 2;
   int charW = CalibrateCharWidth(11);
   int dispLen = StringLen(display);
   int chunkCount = (dispLen + MAX_OBJ_TEXT_CHARS - 1) / MAX_OBJ_TEXT_CHARS;
   int chunkX = m_margin + (int)(4 * m_dpiScale);
   for(int c = 0; c < chunkCount; c++)
   {
      string chunk = StringSubstr(display, c * MAX_OBJ_TEXT_CHARS, MAX_OBJ_TEXT_CHARS);
      int n = m_inputLabelCount;
      ArrayResize(m_inputLabels, n + 1);
      m_inputLabelCount = n + 1;
      m_inputLabels[n] = m_panelName + "_InputC" + IntegerToString(c);
      CreateTextLabel(m_inputLabels[n], chunk, chunkX, inputY_C + (int)(8 * m_dpiScale), m_clrAiText, 11);
      if(!m_isChatTab)
         SetObjectVisible(m_inputLabels[n], false);
      ChartRedraw();
      int realW = (int)ObjectGetInteger(0, m_inputLabels[n], OBJPROP_XSIZE);
      if(realW <= 0)
         realW = MAX_OBJ_TEXT_CHARS * charW;
      chunkX += realW;
   }
}

//+------------------------------------------------------------------+
//| Insert text at cursor                                            |
//+------------------------------------------------------------------+
void AIPanel::InsertTextAtCursor(string text)
{
   if(StringLen(text) == 0)
      return;

   int remain = m_inputMaxChars - StringLen(m_inputBuffer);
   if(remain <= 0)
      return;

   if(StringLen(text) > remain)
      text = StringSubstr(text, 0, remain);

   string left = StringSubstr(m_inputBuffer, 0, m_inputCursorPos);
   string right = StringSubstr(m_inputBuffer, m_inputCursorPos);
   m_inputBuffer = left + text + right;
   m_inputCursorPos += StringLen(text);
}

//+------------------------------------------------------------------+
//| Convert a key code into a printable character                    |
//+------------------------------------------------------------------+
string AIPanel::KeyCodeToChar(const int keyCode, const bool shiftPressed)
{
// letters
   if(keyCode >= 0x41 && keyCode <= 0x5A)
   {
      int ch = shiftPressed ? keyCode : keyCode + 32;
      return CharToString((ushort)ch);
   }

// top-row digits
   if(keyCode >= 0x30 && keyCode <= 0x39)
   {
      if(!shiftPressed)
         return CharToString((ushort)keyCode);

      switch(keyCode)
      {
      case 0x30:
         return ")";
      case 0x31:
         return "!";
      case 0x32:
         return "@";
      case 0x33:
         return "#";
      case 0x34:
         return "$";
      case 0x35:
         return "%";
      case 0x36:
         return "^";
      case 0x37:
         return "&";
      case 0x38:
         return "*";
      case 0x39:
         return "(";
      }
   }

// numpad digits
   if(keyCode >= VK_NUMPAD0 && keyCode <= VK_NUMPAD9)
      return CharToString((ushort)(0x30 + (keyCode - VK_NUMPAD0)));

// punctuation
   switch(keyCode)
   {
   case VK_SPACE:
      return " ";
   case VK_DECIMAL:
      return ".";
   case VK_ADD:
      return "+";
   case VK_SUBTRACT:
      return "-";
   case VK_MULTIPLY:
      return "*";
   case VK_DIVIDE:
      return "/";
   case VK_OEM_1:
      return shiftPressed ? ":" : ";";
   case VK_OEM_PLUS:
      return shiftPressed ? "+" : "=";
   case VK_OEM_COMMA:
      return shiftPressed ? "<" : ",";
   case VK_OEM_MINUS:
      return shiftPressed ? "_" : "-";
   case VK_OEM_PERIOD:
      return shiftPressed ? ">" : ".";
   case VK_OEM_2:
      return shiftPressed ? "?" : "/";
   case VK_OEM_3:
      return shiftPressed ? "~" : "`";
   case VK_OEM_4:
      return shiftPressed ? "{" : "[";
   case VK_OEM_5:
      return shiftPressed ? "|" : "\\";
   case VK_OEM_6:
      return shiftPressed ? "}" : "]";
   case VK_OEM_7:
      return shiftPressed ? "\"" : "'";
   case VK_TAB:
      return "   ";
   }

   return "";
}

//+------------------------------------------------------------------+
//| Track modifier keys                                             |
//+------------------------------------------------------------------+
void AIPanel::SetModifierKeyState(const int keyCode, const bool down)
{
   if(keyCode == VK_SHIFT || keyCode == VK_LSHIFT || keyCode == VK_RSHIFT)
      m_shiftDown = down;
   else if(keyCode == VK_CONTROL || keyCode == VK_LCONTROL || keyCode == VK_RCONTROL)
      m_ctrlDown = down;
   else if(keyCode == VK_LWIN || keyCode == VK_RWIN)
      m_ctrlDown = down;
   else if(keyCode == VK_MENU || keyCode == VK_LMENU || keyCode == VK_RMENU)
      m_altDown = down;
}

//+------------------------------------------------------------------+
//| Handle buffered input                                            |
//+------------------------------------------------------------------+
bool AIPanel::HandleInputKey(const long keyCode)
{
   int key = (int)keyCode;
   int len = StringLen(m_inputBuffer);
   if(m_inputCursorPos < 0)
      m_inputCursorPos = 0;
   if(m_inputCursorPos > len)
      m_inputCursorPos = len;

   if(m_ctrlDown)
   {
      if(key == 0x43) // C
      {
         m_localClipboard = m_inputBuffer;
         return true;
      }

      if(key == 0x58) // X
      {
         m_localClipboard = m_inputBuffer;
         m_inputBuffer = "";
         m_inputCursorPos = 0;
         RefreshInputText();
         return true;
      }

      if(key == 0x56) // V
      {
         string pasted = m_localClipboard;
         if(StringLen(pasted) > 0)
         {
            StringReplace(pasted, "\r", "");
            StringReplace(pasted, "\n", " ");
            InsertTextAtCursor(pasted);
            RefreshInputText();
         }
         return true;
      }

      if(key == 0x41) // A
      {
         // Move caret to end
         m_inputCursorPos = len;
         RefreshInputText();
         return true;
      }

      return true;
   }

   if(m_altDown)
      return true;

   if(key == VK_LEFT)
   {
      if(m_inputCursorPos > 0)
      {
         m_inputCursorPos--;
         RefreshInputText();
      }
      return true;
   }

   if(key == VK_RIGHT)
   {
      if(m_inputCursorPos < len)
      {
         m_inputCursorPos++;
         RefreshInputText();
      }
      return true;
   }

   if(key == VK_HOME)
   {
      m_inputCursorPos = 0;
      RefreshInputText();
      return true;
   }

   if(key == VK_END)
   {
      m_inputCursorPos = len;
      RefreshInputText();
      return true;
   }

   if(key == VK_RETURN)
   {
      SendCurrentMessage();
      return true;
   }

   if(key == VK_BACK)
   {
      if(m_inputCursorPos > 0 && len > 0)
      {
         string left = StringSubstr(m_inputBuffer, 0, m_inputCursorPos - 1);
         string right = StringSubstr(m_inputBuffer, m_inputCursorPos);
         m_inputBuffer = left + right;
         m_inputCursorPos--;
         RefreshInputText();
      }
      return true;
   }

   if(key == VK_DELETE)
   {
      if(m_inputCursorPos < len)
      {
         string left = StringSubstr(m_inputBuffer, 0, m_inputCursorPos);
         string right = StringSubstr(m_inputBuffer, m_inputCursorPos + 1);
         m_inputBuffer = left + right;
         RefreshInputText();
      }
      return true;
   }

   if(key == VK_ESCAPE)
   {
      m_inputBuffer = "";
      m_inputCursorPos = 0;
      RefreshInputText();
      return true;
   }

   string ch = KeyCodeToChar(key, m_shiftDown);
   if(ch == "")
      return false;

   InsertTextAtCursor(ch);
   RefreshInputText();
   return true;
}

//+------------------------------------------------------------------+
//| Shared Chat label width                                         |
//+------------------------------------------------------------------+
int AIPanel::ChatLabelWidth()
{
   return m_panelW - (int)(12 * m_dpiScale) - (int)(20 * m_dpiScale);
}

//+------------------------------------------------------------------+
//| True rendered monospaced char width                             |
//+------------------------------------------------------------------+
int AIPanel::CalibrateCharWidth(const int fontSize)
{
   static int calibSize = 0;
   static int calibWidth = 0;
   if(calibSize == fontSize && calibWidth > 0)
      return calibWidth;

   const string calibName = m_panelName + "_CalibW";
   if(ObjectFind(0, calibName) >= 0)
      ObjectDelete(0, calibName);
   ObjectCreate(0, calibName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, calibName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, calibName, OBJPROP_XDISTANCE, 0);
   ObjectSetInteger(0, calibName, OBJPROP_YDISTANCE, 0);
   ObjectSetString(0, calibName, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, calibName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, calibName, OBJPROP_COLOR, clrNONE);
   ObjectSetString(0, calibName, OBJPROP_TEXT, "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW");
   ChartRedraw();

   int metric = (int)ObjectGetInteger(0, calibName, OBJPROP_XSIZE);
   ObjectDelete(0, calibName);

   if(metric > 60)
   {
      calibWidth = MathMax(1, (int)((double)metric / 50.0 * CHAT_RENDER_SCALE));
      calibSize = fontSize;
   }
   else
   {
      calibWidth = MathMax(1, (int)(fontSize * 0.70 * CHAT_RENDER_SCALE));
      calibSize = -fontSize;
   }
   return calibWidth;
}

//+------------------------------------------------------------------+
//| Max chars per line                                               |
//+------------------------------------------------------------------+
int AIPanel::MaxCharsPerLine()
{
   int labelW = ChatLabelWidth();
   int maxChars = labelW / CalibrateCharWidth(10);
   if(maxChars > 2)
      maxChars -= 2;
   return MathMax(10, maxChars);
}

//+------------------------------------------------------------------+
//| Word-wrap text into lines                                        |
//+------------------------------------------------------------------+
void AIPanel::WrapText(string text, int maxChars, string &lines[], int &lineCount)
{
   lineCount = 0;
   ArrayResize(lines, 0);
   if(StringLen(text) == 0) return;

// Keep as single line
   if(StringLen(text) <= maxChars)
   {
      lineCount = 1;
      ArrayResize(lines, 1);
      lines[0] = text;
      return;
   }

   string remaining = text;
   while(StringLen(remaining) > 0)
   {
      int len = StringLen(remaining);
      if(len <= maxChars)
      {
         ArrayResize(lines, lineCount + 1);
         lines[lineCount] = remaining;
         lineCount++;
         break;
      }

      // Check for newline break
      int nlPos = -1;
      for(int c = 0; c < maxChars && c < StringLen(remaining); c++)
      {
         if(StringSubstr(remaining, c, 1) == "\n")
         {
            nlPos = c;
            break;
         }
      }

      int breakPos;
      if(nlPos >= 0)
      {
         // Break before newline
         breakPos = nlPos;
      }
      else
      {
         // Find word-break point
         breakPos = maxChars;
         for(int c = maxChars - 1; c >= 0; c--)
         {
            if(StringSubstr(remaining, c, 1) == " " && c > 0)
            {
               breakPos = c;
               break;
            }
         }
      }

      // Ensure minimum break pos
      if(breakPos < 1)
         breakPos = 1;

      string line = StringSubstr(remaining, 0, breakPos);
      StringTrimRight(line);
      if(StringLen(line) > 0)
      {
         ArrayResize(lines, lineCount + 1);
         lines[lineCount] = line;
         lineCount++;
      }
      else if(nlPos == 0)
      {
         // Emit blank line
         ArrayResize(lines, lineCount + 1);
         lines[lineCount] = "";
         lineCount++;
      }

      // Skip past break point
      int skip = (nlPos >= 0) ? nlPos + 1 : breakPos;
      remaining = StringSubstr(remaining, skip);
      StringTrimLeft(remaining);
   }
}

//+------------------------------------------------------------------+
//| Add chat message                                                 |
//+------------------------------------------------------------------+
void AIPanel::AppendMessage(string role, string content)
{
   int idx = m_messageCount;
   ArrayResize(m_messages, m_messageCount + 1);
   m_messages[idx].role    = role;
   m_messages[idx].content = content;
   m_messages[idx].time    = FormatTimestamp();
   m_messageCount++;

// Calculate total height
   int maxChars = MaxCharsPerLine();
   int totalLines = 0;
   for(int m = 0; m < m_messageCount; m++)
   {
      string text = (m_messages[m].role == "user" ? "You: " : "AI: ") + m_messages[m].content;
      // Split by newlines
      string seg = text;
      while(StringLen(seg) > 0)
      {
         int nlAt = StringFind(seg, "\n");
         string segment;
         if(nlAt >= 0)
         {
            segment = StringSubstr(seg, 0, nlAt);
            seg = StringSubstr(seg, nlAt + 1);
         }
         else
         {
            segment = seg;
            seg = "";
         }
         // Lines per segment
         int segLen = StringLen(segment);
         if(segLen == 0)
         {
            totalLines++;  // Blank line
         }
         else
         {
            totalLines += (segLen + maxChars - 1) / MathMax(1, maxChars);
         }
      }
   }
   const int LINE_H = (int)(18 * m_dpiScale);
   m_chatTotalHeight = totalLines * LINE_H + m_messageCount * m_msgSpacing + 10;

// Auto-scroll to bottom
   int maxScroll = MathMax(0, m_chatTotalHeight - m_chatHeight);
   m_scrollOffset = maxScroll;
}

//+------------------------------------------------------------------+
//| Add chat message                                                 |
//+------------------------------------------------------------------+
void AIPanel::AddMessage(string role, string content)
{
   AppendMessage(role, content);
   RenderMessages();
}

//+------------------------------------------------------------------+
//| Clear the displayed chat messages                                |
//+------------------------------------------------------------------+
void AIPanel::ClearChatMessages()
{
   m_messageCount = 0;
   ArrayResize(m_messages, 0);
   m_chatTotalHeight = 0;
   m_scrollOffset = 0;
   RenderMessages();
}

//+------------------------------------------------------------------+
//| Rebuild the chat display from the agent history                  |
//+------------------------------------------------------------------+
void AIPanel::LoadConversationFromAgent()
{
   if(CheckPointer(m_agent) != POINTER_DYNAMIC) return;
   int n = m_agent.historyCount();
   for(int i = 0; i < n; i++)
   {
      string role, content;
      if(!m_agent.historyMessage(i, role, content)) continue;
      if(role != "user" && role != "assistant") continue;
      if(StringLen(content) == 0) continue;
      if(StringFind(content, "image_url") >= 0) continue;
      AppendMessage(role, content);
   }
   RenderMessages();
}

//+------------------------------------------------------------------+
//| Copy the conversation to the system clipboard                    |
//+------------------------------------------------------------------+
void AIPanel::CopyConversation()
{
   if(m_messageCount == 0) return;
   string text = "";
   for(int i = 0; i < m_messageCount; i++)
   {
      string prefix = (m_messages[i].role == "user" ? "You: " : "AI: ");
      text += prefix + m_messages[i].content + "\n";
   }
   StringTrimRight(text);
   if(StringLen(text) == 0) return;
   if(!MTTESTER::SetClipboard(text)) return;
   m_copyFlashCounter = 1000;
   ObjectSetString(0, m_panelName + "_Copy", OBJPROP_TEXT, "Copied!");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Render chat messages                                             |
//+------------------------------------------------------------------+
void AIPanel::RenderMessages()
{
   for(int i = 0; i < m_msgLabelCount; i++)
   {
      if(m_msgLabels[i] != "" && ObjectFind(0, m_msgLabels[i]) >= 0)
         ObjectDelete(0, m_msgLabels[i]);
   }
   ArrayResize(m_msgLabels, 0);
   m_msgLabelCount = 0;

   if(m_messageCount == 0) return;

   int maxChars = MaxCharsPerLine();
   const int LINE_H = (int)(18 * m_dpiScale);
   int labelX = m_margin + (int)(4 * m_dpiScale);
   int labelW = ChatLabelWidth();
   int msgFontSz = 10;

   int yPos = m_chatTop + 10 - m_scrollOffset;

   for(int i = 0; i < m_messageCount; i++)
   {
      string prefix = (m_messages[i].role == "user" ? "You: " : "AI: ");
      string fullText = prefix + m_messages[i].content;

      // Word-wrap message
      string wrapped[];
      int lineCount;
      WrapText(fullText, maxChars, wrapped, lineCount);

      for(int l = 0; l < lineCount; l++)
      {
         int yEnd = yPos + LINE_H;

         // Only visible labels
         if(yEnd > m_chatTop && yPos < m_chatBottom)
         {
            // Split into chunks under limit
            int lineLen = StringLen(wrapped[l]);
            int charW = CalibrateCharWidth(msgFontSz);
            int chunkCount = (lineLen + MAX_OBJ_TEXT_CHARS - 1) / MAX_OBJ_TEXT_CHARS;
            for(int c = 0; c < chunkCount; c++)
            {
               string chunk = StringSubstr(wrapped[l], c * MAX_OBJ_TEXT_CHARS, MAX_OBJ_TEXT_CHARS);
               int n = m_msgLabelCount;
               ArrayResize(m_msgLabels, n + 1);
               m_msgLabelCount = n + 1;

               string labelName = m_panelName + "_Msg" + IntegerToString(i) + "_L" + IntegerToString(l) + "_C" + IntegerToString(c);
               m_msgLabels[n] = labelName;
               CreateTextLabel(labelName, chunk, labelX + c * MAX_OBJ_TEXT_CHARS * charW, yPos, m_messages[i].role == "user" ? m_clrUserText : m_clrAiText, msgFontSz);
               if(!m_isChatTab)
                  SetObjectVisible(labelName, false);
            }
         }

         yPos += LINE_H;
      }

      yPos += m_msgSpacing;
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Add info row                                                     |
//+------------------------------------------------------------------+
void AIPanel::AddInfoRow(int &yPos, int col1X, int col1W, int col2X, int col2W, int labelH, bool isHeader, string key, string val)
{
   int n = m_infoLabelCount;

   ArrayResize(m_infoLabels, n + 2);
   m_infoLabelCount = n + 2;

   string keyName = m_panelName + "_InfoK" + IntegerToString(n);
   m_infoLabels[n] = keyName;
   CreateTextLabel(keyName, key, col1X, yPos, isHeader ? m_clrAccent : C'160,160,160', isHeader ? 11 : 9);
   if(!m_isInfoTab)
      SetObjectVisible(keyName, false);

   string valName = m_panelName + "_InfoV" + IntegerToString(n);
   m_infoLabels[n + 1] = valName;
// Truncate wide values
// Char width approx
   double cw = (9.0 * m_dpi / 72.0) * 0.60;
   int maxValChars = MathMin(MAX_OBJ_TEXT_CHARS, (int)((col2W - 4) / cw) - 1); // -1 for "…"
   if(maxValChars > 3 && StringLen(val) > maxValChars)
      val = StringSubstr(val, 0, maxValChars - 1) + "…";
   CreateTextLabel(valName, val, col2X, yPos, m_clrAiText, 9);
   if(!m_isInfoTab)
      SetObjectVisible(valName, false);

   yPos += labelH;
}

//+------------------------------------------------------------------+
//| Populate Info tab                                                |
//+------------------------------------------------------------------+
void AIPanel::PopulateInfoTab()
{
   ClearInfoLabels();

   int panelW = m_panelW;
   int labelH = (int)(16 * m_dpiScale);
   int headerH = (int)(18 * m_dpiScale);
   int sectionGap = (int)(4 * m_dpiScale);
   int col1X = m_margin + (int)(4 * m_dpiScale);
   int col1W = (int)(130 * m_dpiScale);
   int col2X = col1X + col1W;
   int col2W = panelW - col2X - m_margin - (int)(4 * m_dpiScale);
   int infoFontSz = (int)(9 * m_dpiScale);
   int headerFontSz = (int)(11 * m_dpiScale);

// Two-pass height calc
   struct InfoRow
   {
      string         key;
      string         val;
      bool           isHdr;
   };
   InfoRow rows[99] = {};
   int rowCount = 0;

   rows[rowCount].key = "Terminal Info";
   rows[rowCount].val = "";
   rows[rowCount].isHdr = true;
   rowCount++;
   rows[rowCount].key = "Name";
   rows[rowCount].val = TerminalInfoString(TERMINAL_NAME);
   rowCount++;
   rows[rowCount].key = "Data Path";
   rows[rowCount].val = TerminalInfoString(TERMINAL_DATA_PATH);
   rowCount++;
   rows[rowCount].key = "Build";
   rows[rowCount].val = IntegerToString((int)TerminalInfoInteger(TERMINAL_BUILD));
   rowCount++;
   rows[rowCount].key = "OS";
   rows[rowCount].val = TerminalInfoString(TERMINAL_OS_VERSION);
   rowCount++;
   rows[rowCount].key = "CPU";
   rows[rowCount].val = TerminalInfoString(TERMINAL_CPU_NAME);
   rowCount++;
   rows[rowCount].key = "Cores";
   rows[rowCount].val = IntegerToString((int)TerminalInfoInteger(TERMINAL_CPU_CORES));
   rowCount++;
   rows[rowCount].key = "X64";
   rows[rowCount].val = TerminalInfoInteger(TERMINAL_X64) ? "Yes" : "No";
   rowCount++;
   rows[rowCount].key = "Connected";
   rows[rowCount].val = TerminalInfoInteger(TERMINAL_CONNECTED) ? "Yes" : "No";
   rowCount++;
   rows[rowCount].key = "Ping (us)";
   rows[rowCount].val = IntegerToString((int)TerminalInfoInteger(TERMINAL_PING_LAST));
   rowCount++;
   rows[rowCount].key = "Width";
   rows[rowCount].val = IntegerToString((int)TerminalInfoInteger(TERMINAL_SCREEN_WIDTH));
   rowCount++;
   rows[rowCount].key = "Height";
   rows[rowCount].val = IntegerToString((int)TerminalInfoInteger(TERMINAL_SCREEN_HEIGHT));
   rowCount++;
   rows[rowCount].key = "Disk Space";
   rows[rowCount].val = IntegerToString((int)TerminalInfoInteger(TERMINAL_DISK_SPACE)) + " MB";
   rowCount++;
   rows[rowCount].key = "Memory Avail";
   rows[rowCount].val = IntegerToString((int)TerminalInfoInteger(TERMINAL_MEMORY_AVAILABLE)) + " MB";
   rowCount++;

   string symbol = _Symbol;
   int digits    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   rows[rowCount].key = "Symbol Info";
   rows[rowCount].val = "";
   rows[rowCount].isHdr = true;
   rowCount++;
   rows[rowCount].key = "Symbol";
   rows[rowCount].val = symbol;
   rowCount++;
   rows[rowCount].key = "Bid";
   rows[rowCount].val = DoubleToString(SymbolInfoDouble(symbol, SYMBOL_BID), digits);
   rowCount++;
   rows[rowCount].key = "Ask";
   rows[rowCount].val = DoubleToString(SymbolInfoDouble(symbol, SYMBOL_ASK), digits);
   rowCount++;
   rows[rowCount].key = "Spread";
   rows[rowCount].val = DoubleToString((SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID)) * MathPow(10, digits), 1);
   rowCount++;
   rows[rowCount].key = "Digits";
   rows[rowCount].val = IntegerToString(digits);
   rowCount++;
   rows[rowCount].key = "Point";
   rows[rowCount].val = DoubleToString(SymbolInfoDouble(symbol, SYMBOL_POINT), digits + 2);
   rowCount++;
   rows[rowCount].key = "Tick Value";
   rows[rowCount].val = DoubleToString(SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE), 2);
   rowCount++;
   rows[rowCount].key = "Tick Size";
   rows[rowCount].val = DoubleToString(SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE), digits + 2);
   rowCount++;
   rows[rowCount].key = "Max Lot";
   rows[rowCount].val = DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX), 2);
   rowCount++;
   rows[rowCount].key = "Min Lot";
   rows[rowCount].val = DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), 2);
   rowCount++;
   rows[rowCount].key = "Lot Step";
   rows[rowCount].val = DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP), 2);
   rowCount++;
   rows[rowCount].key = "Stops Lev";
   rows[rowCount].val = IntegerToString((int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL));
   rowCount++;
   rows[rowCount].key = "Freeze Lev";
   rows[rowCount].val = IntegerToString((int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL));
   rowCount++;
   rows[rowCount].key = "Exec Mode";
   rows[rowCount].val = EnumToString((ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE));
   rowCount++;

   rows[rowCount].key = "Account Info";
   rows[rowCount].val = "";
   rows[rowCount].isHdr = true;
   rowCount++;
   rows[rowCount].key = "Login";
   rows[rowCount].val = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
   rowCount++;
   rows[rowCount].key = "Name";
   rows[rowCount].val = AccountInfoString(ACCOUNT_NAME);
   rowCount++;
   rows[rowCount].key = "Company";
   rows[rowCount].val = AccountInfoString(ACCOUNT_COMPANY);
   rowCount++;
   rows[rowCount].key = "Currency";
   rows[rowCount].val = AccountInfoString(ACCOUNT_CURRENCY);
   rowCount++;
   rows[rowCount].key = "Balance";
   rows[rowCount].val = DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   rowCount++;
   rows[rowCount].key = "Equity";
   rows[rowCount].val = DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
   rowCount++;
   rows[rowCount].key = "Margin";
   rows[rowCount].val = DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2);
   rowCount++;
   rows[rowCount].key = "Free Margin";
   rows[rowCount].val = DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2);
   rowCount++;
   rows[rowCount].key = "Margin Lvl";
   rows[rowCount].val = DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2);
   rowCount++;
   rows[rowCount].key = "Profit";
   rows[rowCount].val = DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT), 2);
   rowCount++;
   rows[rowCount].key = "Leverage";
   rows[rowCount].val = IntegerToString((int)AccountInfoInteger(ACCOUNT_LEVERAGE));
   rowCount++;
   rows[rowCount].key = "Trade Allow";
   rows[rowCount].val = AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "Yes" : "No";
   rowCount++;

// Total content height
   m_infoTotalHeight = 0;
   for(int r = 0; r < rowCount; r++)
   {
      m_infoTotalHeight += (rows[r].isHdr ? headerH : labelH);
      if(r + 1 < rowCount && rows[r + 1].isHdr)
         m_infoTotalHeight += sectionGap;
   }

// Render visible rows
   int yPos = m_chatTop + (int)(4 * m_dpiScale) - m_infoScrollOffset;

   for(int r = 0; r < rowCount; r++)
   {
      int rowH = rows[r].isHdr ? headerH : labelH;
      int yEnd = yPos + rowH;

      // Only visible rows
      bool partiallyVisible = (yEnd > m_chatTop && yPos < m_chatBottom);
      if(partiallyVisible)
      {
         if(rows[r].isHdr)
            AddInfoRow(yPos, col1X, col1W, col2X, col2W, headerH, true, rows[r].key, rows[r].val);
         else
            AddInfoRow(yPos, col1X, col1W, col2X, col2W, labelH, false, rows[r].key, rows[r].val);
      }

      yPos += rowH;
      if(r + 1 < rowCount && rows[r + 1].isHdr)
         yPos += sectionGap;
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Send current message                                             |
//+------------------------------------------------------------------+
void AIPanel::SendCurrentMessage()
{
   if(m_requestPending) return;

   string inputText = m_inputBuffer;
   if(StringLen(inputText) == 0) return;

   StringTrimLeft(inputText);
   StringTrimRight(inputText);
   if(StringLen(inputText) == 0) return;

   m_inputBuffer = "";
   m_inputCursorPos = 0;
   RefreshInputText();

   AddMessage("user", inputText);

   if(CheckPointer(m_agent) == POINTER_DYNAMIC)
   {
      m_requestPending = true;
      m_pendingMsg = inputText;
      AddMessage("assistant", "Thinking...");
   }
}

//+------------------------------------------------------------------+
//| Complete AI request                                              |
//+------------------------------------------------------------------+
void AIPanel::CompletePending(const string response)
{
   if(!m_requestPending) return;

   m_requestPending = false;

   if(m_messageCount > 0)
   {
      m_messageCount--;
      ArrayResize(m_messages, m_messageCount);
   }

   AddMessage("assistant", response);
   CacheSessionList();
}

//+------------------------------------------------------------------+
//| Refresh info tab                                                 |
//+------------------------------------------------------------------+
void AIPanel::RefreshInfo()
{
   if(!m_isChatTab && m_initialized)
      PopulateInfoTab();
}

//+------------------------------------------------------------------+
//| Format timestamp                                                 |
//+------------------------------------------------------------------+
string AIPanel::FormatTimestamp()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
//| Dialog resize handler                                            |
//+------------------------------------------------------------------+
bool AIPanel::OnResize(void)
{
   m_panelW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 1;
   m_panelH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) - 1;
   if(m_panelW < 200) m_panelW = 300;
   if(m_panelH < 200) m_panelH = 400;
   m_chatTop    = m_tabHeight + m_margin;
   m_chatBottom = m_panelH - m_inputAreaHeight - m_margin;
   m_chatHeight = m_chatBottom - m_chatTop;
   if(m_chatHeight < (int)(50 * m_dpiScale))
      m_chatHeight = (int)(50 * m_dpiScale);
// Clamp scroll offsets
   m_scrollOffset    = MathMax(0, MathMin(m_scrollOffset,    m_chatHeight * 10));
   m_infoScrollOffset = MathMax(0, MathMin(m_infoScrollOffset, m_chatHeight * 10));
   m_sessionScrollOffset = MathMax(0, MathMin(m_sessionScrollOffset, m_chatHeight * 10));
   m_taskScrollOffset = MathMax(0, MathMin(m_taskScrollOffset, m_chatHeight * 10));
// Resize background rectangle
   string bgName = m_panelName + "_Bg";
   if(ObjectFind(0, bgName) >= 0)
   {
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, m_panelW);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, m_panelH);
   }
// Re-render tab content
   if(m_isChatTab)
      RenderMessages();
   else if(m_isSessionTab)
   {
      m_sessionScrollOffset = 0;
      RefreshSessionList();
   }
   else if(m_isTaskTab)
   {
      m_taskScrollOffset = 0;
      RefreshTaskList();
   }
   else
      PopulateInfoTab();

   RefreshInputText();

   ChartRedraw();
   return (true);
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void AIPanel::PanelChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_KEYDOWN || id == CHARTEVENT_KEYUP)
   {
      int key = (int)lparam;
      SetModifierKeyState(key, id == CHARTEVENT_KEYDOWN);

      if(id == CHARTEVENT_KEYDOWN && m_isChatTab && m_inputFocused)
         HandleInputKey(lparam);

      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == m_panelName + "_Input")
      {
         m_inputFocused = true;
         RefreshInputText();
      }
      else if(sparam == m_panelName + "_TabChat")
      {
         if(!m_isChatTab) SwitchToChat();
      }
      else if(sparam == m_panelName + "_TabInfo")
      {
         if(!m_isInfoTab) SwitchToInfo();
      }
      else if(sparam == m_panelName + "_TabSession")
      {
         if(!m_isSessionTab) SwitchToSession();
      }
      else if(sparam == m_panelName + "_TabTasks")
      {
         if(!m_isTaskTab) SwitchToTasks();
      }
      else if(sparam == m_panelName + "_NewSession")
      {
         NewSession();
      }
      else if(sparam == m_panelName + "_Copy")
      {
         CopyConversation();
      }
      else if(StringSubstr(sparam, 0, StringLen(m_panelName + "_SessDelete")) == m_panelName + "_SessDelete")
      {
         int idx = (int)StringToInteger(StringSubstr(sparam, StringLen(m_panelName + "_SessDelete")));
         if(idx >= 0 && idx < ArraySize(m_sessionNames))
            DeleteSession(m_sessionNames[idx]);
      }
      else if(StringSubstr(sparam, 0, StringLen(m_panelName + "_Sess")) == m_panelName + "_Sess")
      {
         int idx = (int)StringToInteger(StringSubstr(sparam, StringLen(m_panelName + "_Sess")));
         if(idx >= 0 && idx < ArraySize(m_sessionNames))
            LoadSession(m_sessionNames[idx]);
      }
      else if(StringSubstr(sparam, 0, StringLen(m_panelName + "_TaskCancel")) == m_panelName + "_TaskCancel")
      {
         uint id = (uint)StringToInteger(StringSubstr(sparam, StringLen(m_panelName + "_TaskCancel")));
         if(CheckPointer(m_agent) == POINTER_DYNAMIC && m_agent.cancelScheduledTask(id))
            RefreshTaskList();
      }
      else if(sparam == m_panelName + "_Send")
      {
         SendCurrentMessage();
      }
      else if(sparam == m_panelName + "_CloseX")
      {
         ExpertRemove();
      }
      else if(sparam == m_panelName + "_ScrlUp")
      {
         if(m_isChatTab)
         {
            m_scrollOffset = MathMax(0, m_scrollOffset - (int)(60 * m_dpiScale));
            RenderMessages();
         }
         else if(m_isSessionTab)
         {
            m_sessionScrollOffset = MathMax(0, m_sessionScrollOffset - (int)(60 * m_dpiScale));
            RefreshSessionList();
         }
         else if(m_isTaskTab)
         {
            m_taskScrollOffset = MathMax(0, m_taskScrollOffset - (int)(60 * m_dpiScale));
            RefreshTaskList();
         }
         else
         {
            m_infoScrollOffset = MathMax(0, m_infoScrollOffset - (int)(60 * m_dpiScale));
            PopulateInfoTab();
         }
      }
      else if(sparam == m_panelName + "_ScrlDn")
      {
         if(m_isChatTab)
         {
            int maxScroll = MathMax(0, m_chatTotalHeight - m_chatHeight);
            m_scrollOffset = MathMin(maxScroll, m_scrollOffset + (int)(60 * m_dpiScale));
            RenderMessages();
         }
         else if(m_isSessionTab)
         {
            int maxScroll = MathMax(0, m_sessionTotalHeight - (m_chatBottom - m_sessionListTop));
            m_sessionScrollOffset = MathMin(maxScroll, m_sessionScrollOffset + (int)(60 * m_dpiScale));
            RefreshSessionList();
         }
         else if(m_isTaskTab)
         {
            int maxScroll = MathMax(0, m_taskTotalHeight - m_chatHeight);
            m_taskScrollOffset = MathMin(maxScroll, m_taskScrollOffset + (int)(60 * m_dpiScale));
            RefreshTaskList();
         }
         else
         {
            int maxScroll = MathMax(0, m_infoTotalHeight + (int)(4 * m_dpiScale) - m_chatHeight);
            m_infoScrollOffset = MathMin(maxScroll, m_infoScrollOffset + (int)(60 * m_dpiScale));
            PopulateInfoTab();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Tick update                                                      |
//+------------------------------------------------------------------+
void AIPanel::OnTickUpdate()
{
   if(m_isChatTab && m_initialized)
   {
      if(m_copyFlashCounter > 0)
      {
         m_copyFlashCounter--;
         if(m_copyFlashCounter == 0)
            ObjectSetString(0, m_panelName + "_Copy", OBJPROP_TEXT, "Copy");
      }
      ChartRedraw();
   }
   else if(m_isInfoTab && m_initialized)
   {
      m_tickCounter++;
      if(m_tickCounter >= 10)
      {
         m_tickCounter = 0;
         PopulateInfoTab();
      }
   }
   else if(m_isTaskTab && m_initialized)
   {
      m_tickCounter++;
      if(m_tickCounter >= 10)
      {
         m_tickCounter = 0;
         RefreshTaskList();
      }
   }
}

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
bool     g_prevQuickNavigation = false;
bool     g_prevQuickNavigationKnown = false;
bool     g_subAgentHeadless = false;
bool     g_subAgentDone = false;
AIPanel  *panel;
Agent    *agent;
//+------------------------------------------------------------------+
