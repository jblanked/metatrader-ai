//+------------------------------------------------------------------+
//|                                                     schedule.mqh |
//|                                          Copyright 2026,JBlanked |
//|                                        https://www.jblanked.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked"
#property link      "https://www.jblanked.com/"
#property strict

#include "tools/file.mqh"

#define SCHEDULE_FOLDER "metatrader-ai\\schedule"
#define SCHEDULE_FILE "metatrader-ai\\schedule\\tasks.json"
#define SCHEDULE_WINDOW_SECONDS 5

//+------------------------------------------------------------------+
//| Struct representing a scheduled task                              |
//+------------------------------------------------------------------+
struct ScheduleTask
{
public:
   datetime          executionTime;
   bool              finished;
   uint              id;
   string            name;
   bool              repeat;
   bool              started;
   bool              expired;
   bool              cancelled;
   string            toolName;
   string            arguments;
   string            result;
   string            recurrence;
   datetime          lastExecutionTime;
   bool              shouldExecute(datetime currentTime)
   {
      if(finished || started || expired || cancelled)
         return false;
      return currentTime >= executionTime && currentTime < executionTime + SCHEDULE_WINDOW_SECONDS;
   }
   string            status()
   {
      if(cancelled) return "cancelled";
      if(expired)   return "expired";
      if(finished)  return "finished";
      if(started)   return "started";
      return "pending";
   }
};

//+------------------------------------------------------------------+
//| Class representing a schedule                                    |
//+------------------------------------------------------------------+
class Schedule
{
public:
   ScheduleTask      tasks[];

                     Schedule();
                    ~Schedule();
   bool              addTask(ScheduleTask &task);
   bool              taskAt(int index, ScheduleTask &task);
   int               count();
   bool              markStarted(uint id);
   bool              finishTask(uint id, string result);
   bool              cancelTask(uint id);
   void              expireMissedTasks(datetime currentTime);
   string            list();
private:
   uint              currentId;
   uint              taskCount;
   bool              save();
   bool              load();
   datetime          nextOccurrence(datetime occurrence, string recurrenceRule);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
Schedule::Schedule() : currentId(1), taskCount(0)
{
   FolderCreate(SCHEDULE_FOLDER, FILE_COMMON);
   load();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
Schedule::~Schedule()
{
   ArrayFree(tasks);
}

//+------------------------------------------------------------------+
//| Add a task to the schedule                                       |
//+------------------------------------------------------------------+
bool Schedule::addTask(ScheduleTask &task)
{
   task.id = currentId++;
   ArrayResize(tasks, taskCount + 1);
   tasks[taskCount] = task;
   taskCount++;
   return save();
}

//+------------------------------------------------------------------+
//| Read a task from the schedule                                    |
//+------------------------------------------------------------------+
bool Schedule::taskAt(int index, ScheduleTask &task)
{
   if(index < 0 || index >= (int)taskCount)
      return false;
   task = tasks[index];
   return true;
}

//+------------------------------------------------------------------+
//| Return the number of tasks                                       |
//+------------------------------------------------------------------+
int Schedule::count()
{
   return (int)taskCount;
}

//+------------------------------------------------------------------+
//| Mark a task as started                                           |
//+------------------------------------------------------------------+
bool Schedule::markStarted(uint id)
{
   for(uint i = 0; i < taskCount; i++)
   {
      if(tasks[i].id == id && tasks[i].shouldExecute(TimeCurrent()))
      {
         tasks[i].started = true;
         return save();
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Mark a task as finished                                          |
//+------------------------------------------------------------------+
bool Schedule::finishTask(uint id, string result)
{
   for(uint i = 0; i < taskCount; i++)
   {
      if(tasks[i].id == id && tasks[i].started)
      {
         tasks[i].lastExecutionTime = tasks[i].executionTime;
         tasks[i].result = result;
         if(tasks[i].recurrence != "none" && tasks[i].recurrence != "")
         {
            tasks[i].executionTime = nextOccurrence(tasks[i].executionTime, tasks[i].recurrence);
            tasks[i].started = false;
            tasks[i].finished = false;
         }
         else
         {
            tasks[i].finished = true;
         }
         return save();
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Cancel a pending task                                            |
//+------------------------------------------------------------------+
bool Schedule::cancelTask(uint id)
{
   for(uint i = 0; i < taskCount; i++)
   {
      if(tasks[i].id == id && !tasks[i].finished && !tasks[i].started && !tasks[i].expired && !tasks[i].cancelled)
      {
         tasks[i].cancelled = true;
         return save();
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expire tasks whose window was missed                             |
//+------------------------------------------------------------------+
void Schedule::expireMissedTasks(datetime currentTime)
{
   bool changed = false;
   for(uint i = 0; i < taskCount; i++)
   {
      if(tasks[i].finished || tasks[i].started || tasks[i].expired || tasks[i].cancelled)
         continue;

      if(tasks[i].recurrence != "none" && tasks[i].recurrence != "")
      {
         bool advanced = false;
         while(currentTime >= tasks[i].executionTime + SCHEDULE_WINDOW_SECONDS)
         {
            tasks[i].lastExecutionTime = tasks[i].executionTime;
            tasks[i].executionTime = nextOccurrence(tasks[i].executionTime, tasks[i].recurrence);
            advanced = true;
         }
         if(advanced)
            changed = true;
      }
      else if(currentTime >= tasks[i].executionTime + SCHEDULE_WINDOW_SECONDS)
      {
         tasks[i].expired = true;
         changed = true;
      }
   }
   if(changed)
      save();
}

//+------------------------------------------------------------------+
//| List all scheduled tasks                                         |
//+------------------------------------------------------------------+
string Schedule::list()
{
   expireMissedTasks(TimeCurrent());

   CJAVal result;
   result.m_type = jtARRAY;
   for(uint i = 0; i < taskCount; i++)
   {
      CJAVal item;
      item["id"] = (long)tasks[i].id;
      item["name"] = tasks[i].name;
      item["execution_time"] = TimeToString(tasks[i].executionTime, TIME_DATE | TIME_SECONDS);
      item["tool_name"] = tasks[i].toolName;
      item["arguments"] = tasks[i].arguments;
      item["recurrence"] = tasks[i].recurrence;
      item["last_execution_time"] = tasks[i].lastExecutionTime > 0 ? TimeToString(tasks[i].lastExecutionTime, TIME_DATE | TIME_SECONDS) : "";
      item["status"] = tasks[i].status();
      item["result"] = tasks[i].result;
      result.Add(item);
   }
   return result.Serialize();
}

//+------------------------------------------------------------------+
//| Save schedule to common files                                   |
//+------------------------------------------------------------------+
bool Schedule::save()
{
   CJAVal json;
   json.m_type = jtARRAY;
   for(uint i = 0; i < taskCount; i++)
   {
      CJAVal item;
      item["id"] = (long)tasks[i].id;
      item["executionTime"] = (long)tasks[i].executionTime;
      item["finished"] = tasks[i].finished;
      item["name"] = tasks[i].name;
      item["repeat"] = tasks[i].repeat;
      item["started"] = tasks[i].started;
      item["expired"] = tasks[i].expired;
      item["cancelled"] = tasks[i].cancelled;
      item["toolName"] = tasks[i].toolName;
      item["arguments"] = tasks[i].arguments;
      item["result"] = tasks[i].result;
      item["recurrence"] = tasks[i].recurrence;
      item["lastExecutionTime"] = (long)tasks[i].lastExecutionTime;
      json.Add(item);
   }

   int handle = FileOpen(SCHEDULE_FILE, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("Failed to save schedule: %d", GetLastError());
      return false;
   }
   FileWriteString(handle, json.Serialize());
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Load schedule from common files                                 |
//+------------------------------------------------------------------+
bool Schedule::load()
{
   if(!FileIsExist(SCHEDULE_FILE, FILE_COMMON))
      return true;

   int handle = FileOpen(SCHEDULE_FILE, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;

   string content = "";
   while(!FileIsEnding(handle))
   {
      content += FileReadString(handle);
      if(!FileIsEnding(handle))
         content += "\n";
   }
   FileClose(handle);

   CJAVal json;
   if(content == "" || !json.Deserialize(content) || json.m_type != jtARRAY)
      return false;

   taskCount = 0;
   currentId = 1;
   ArrayResize(tasks, 0);
   int storedCount = ArraySize(json.m_e);
   for(int i = 0; i < storedCount; i++)
   {
      ScheduleTask task;
      task.id = (uint)json[i]["id"].ToInt();
      task.executionTime = (datetime)json[i]["executionTime"].ToInt();
      task.finished = json[i]["finished"].ToBool();
      task.name = json[i]["name"].ToStr();
      task.repeat = json[i]["repeat"].ToBool();
      task.started = json[i]["started"].ToBool();
      task.expired = json[i]["expired"].ToBool();
      task.cancelled = json[i]["cancelled"].ToBool();
      task.toolName = json[i]["toolName"].ToStr();
      task.arguments = json[i]["arguments"].ToStr();
      task.result = json[i]["result"].ToStr();
      task.recurrence = json[i]["recurrence"].ToStr();
      if(task.recurrence == "")
         task.recurrence = task.repeat ? "daily" : "none";
      task.lastExecutionTime = (datetime)json[i]["lastExecutionTime"].ToInt();
      ArrayResize(tasks, taskCount + 1);
      tasks[taskCount] = task;
      taskCount++;
      if(task.id >= currentId)
         currentId = task.id + 1;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Calculate the next recurrence time                              |
//+------------------------------------------------------------------+
datetime Schedule::nextOccurrence(datetime occurrence, string recurrenceRule)
{
   if(recurrenceRule == "weekly")
      return occurrence + 7 * 24 * 60 * 60;

   datetime next = occurrence + 24 * 60 * 60;
   if(recurrenceRule != "weekdays")
      return next;

   MqlDateTime date;
   while(TimeToStruct(next, date) && (date.day_of_week == 0 || date.day_of_week == 6))
      next += 24 * 60 * 60;
   return next;
}