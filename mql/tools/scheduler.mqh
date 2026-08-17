//+------------------------------------------------------------------+
//|                                                  scheduler.mqh   |
//|                                      Copyright 2026,JBlanked LLC |
//|                                         https://www.jblanked.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026,JBlanked LLC"
#property link      "https://www.jblanked.com"
#property strict

#include "../schedule.mqh"
#include "tool.mqh"

//+------------------------------------------------------------------+
//| Parameters for schedule_task                                    |
//+------------------------------------------------------------------+
Parameters *toolScheduleTaskParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("name", "string", "A short human-readable task name", true));
   p.add(new Property("execution_time", "string", "Broker/server time in YYYY.MM.DD HH:MM:SS format. Call get_server_time first when resolving relative times such as today.", true));
   p.add(new Property("tool_name", "string", "The exact existing tool to execute at the scheduled time, such as order_send or order_send_pips", true));
   p.add(new Property("arguments", "string", "A JSON object string containing the exact arguments for tool_name", true));
   p.add(new Property("recurrence", "string", "Optional recurrence rule: none (default), daily, weekdays, or weekly", false));
   return p;
}

//+------------------------------------------------------------------+
//| Tool — schedule one tool call                                   |
//+------------------------------------------------------------------+
class ToolScheduleTask : public Tool
{
private:
   Schedule *m_schedule;

public:
   ToolScheduleTask(Schedule *schedule) : Tool("schedule_task", "Schedule one existing tool call for a future broker/server time. Use recurrence none, daily, weekdays, or weekly. Recurring missed occurrences are skipped; one-time missed tasks expire. Do not schedule scheduler control tools.", toolScheduleTaskParams())
   {
      m_schedule = schedule;
   }

   virtual string execute(CJAVal &json) override
   {
      if(CheckPointer(m_schedule) != POINTER_DYNAMIC)
         return "{\"error\":\"scheduler unavailable\"}";

      const string toolName = json["tool_name"].ToStr();
      if(toolName == "schedule_task" || toolName == "list_scheduled_tasks" || toolName == "cancel_scheduled_task" || toolName == "get_server_time")
         return "{\"error\":\"scheduler control tools cannot be scheduled\"}";

      const string executionText = json["execution_time"].ToStr();
      const datetime executionTime = StringToTime(executionText);
      if(executionTime <= 0)
         return "{\"error\":\"invalid execution_time; use YYYY.MM.DD HH:MM:SS broker/server time\"}";
      if(executionTime <= TimeCurrent())
         return "{\"error\":\"execution_time must be in the future; missed times expire\"}";

      const string arguments = json["arguments"].ToStr();
      CJAVal parsedArguments;
      if(StringLen(arguments) == 0 || !parsedArguments.Deserialize(arguments) || parsedArguments.m_type != jtOBJ)
         return "{\"error\":\"arguments must be a valid JSON object string\"}";

      string recurrence = json["recurrence"].ToStr();
      StringToLower(recurrence);
      if(recurrence == "")
         recurrence = "none";
      if(recurrence != "none" && recurrence != "daily" && recurrence != "weekdays" && recurrence != "weekly")
         return "{\"error\":\"invalid recurrence; use none, daily, weekdays, or weekly\"}";

      ScheduleTask task;
      task.executionTime = executionTime;
      task.finished      = false;
      task.id            = 0;
      task.name          = json["name"].ToStr();
      task.toolName      = toolName;
      task.arguments     = arguments;
      task.repeat        = recurrence != "none";
      task.started       = false;
      task.expired       = false;
      task.cancelled     = false;
      task.result        = "";
      task.recurrence    = recurrence;
      task.lastExecutionTime = 0;

      if(!m_schedule.addTask(task))
         return "{\"error\":\"failed to save scheduled task\"}";

      CJAVal result;
      result["scheduled"]      = true;
      result["id"]             = (long)task.id;
      result["name"]           = task.name;
      result["execution_time"] = TimeToString(task.executionTime, TIME_DATE | TIME_SECONDS);
      result["tool_name"]      = task.toolName;
      result["recurrence"]     = task.recurrence;
      result["server_time"]    = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      return result.Serialize();
   }
};

//+------------------------------------------------------------------+
//| Tool — list scheduled tasks                                     |
//+------------------------------------------------------------------+
class ToolListScheduledTasks : public Tool
{
private:
   Schedule *m_schedule;

public:
   ToolListScheduledTasks(Schedule *schedule) : Tool("list_scheduled_tasks", "List scheduled tasks with ids, broker/server execution times, statuses, target tools, and results.", NULL)
   {
      m_schedule = schedule;
   }

   virtual string execute(CJAVal &json) override
   {
      if(CheckPointer(m_schedule) != POINTER_DYNAMIC)
         return "{\"error\":\"scheduler unavailable\"}";
      return m_schedule.list();
   }
};

//+------------------------------------------------------------------+
//| Tool — cancel a scheduled task                                  |
//+------------------------------------------------------------------+
Parameters *toolCancelScheduledTaskParams(void)
{
   Parameters *p = new Parameters();
   p.add(new Property("id", "integer", "The scheduled task id", true));
   return p;
}

class ToolCancelScheduledTask : public Tool
{
private:
   Schedule *m_schedule;

public:
   ToolCancelScheduledTask(Schedule *schedule) : Tool("cancel_scheduled_task", "Cancel one pending scheduled task by id. Finished, expired, or already started tasks cannot be cancelled.", toolCancelScheduledTaskParams())
   {
      m_schedule = schedule;
   }

   virtual string execute(CJAVal &json) override
   {
      if(CheckPointer(m_schedule) != POINTER_DYNAMIC)
         return "{\"error\":\"scheduler unavailable\"}";

      const uint id = (uint)json["id"].ToInt();
      if(!m_schedule.cancelTask(id))
         return "{\"error\":\"task not found or cannot be cancelled\"}";

      CJAVal result;
      result["cancelled"] = true;
      result["id"] = (long)id;
      return result.Serialize();
   }
};

//+------------------------------------------------------------------+
//| Tool — get broker/server time                                   |
//+------------------------------------------------------------------+
class ToolGetServerTime : public Tool
{
public:
   ToolGetServerTime() : Tool("get_server_time", "Get the current broker/server TimeCurrent value. Use this before scheduling relative times such as today at 08:00.", NULL) {}

   virtual string execute(CJAVal &json) override
   {
      CJAVal result;
      result["server_time"] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      result["unix_time"] = (long)TimeCurrent();
      return result.Serialize();
   }
};
//+------------------------------------------------------------------+
