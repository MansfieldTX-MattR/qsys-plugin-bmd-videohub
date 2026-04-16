

---@class QueueList<T>
---@field private first integer
---@field private last integer
QueueList = {}
function QueueList:new()
  local o = {first = 0, last = -1}
  setmetatable(o, self)
  self.__index = self
  return o
end

---@param value T
function QueueList:pushLeft(value)
  local first = self.first - 1
  self.first = first
  self[first] = value
end

---@param value T
function QueueList:pushRight(value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

---@return T
function QueueList:popLeft()
  local first = self.first
  if first > self.last then error("list is empty") end
  local value = self[first]
  self[first] = nil        -- to allow garbage collection
  self.first = first + 1
  if self:isEmpty() then
    self.first = 0
    self.last = -1
  end
  return value
end

---@return T
function QueueList:popRight()
  local last = self.last
  if self.first > last then error("list is empty") end
  local value = self[last]
  self[last] = nil         -- to allow garbage collection
  self.last = last - 1
  if self:isEmpty() then
    self.first = 0
    self.last = -1
  end
  return value
end

---@return T[]
function QueueList:popAll()
  local values = {}
  while not self:isEmpty() do
    table.insert(values, self:popLeft())
  end
  return values
end

function QueueList:isEmpty()
  return self.first > self.last
end

---@return integer
function QueueList:size()
  if self:isEmpty() then
    return 0
  else
    return self.last - self.first + 1
  end
end

function QueueList:clear()
  while not self:isEmpty() do
    self:popLeft()
  end
end




---@class CommandQueueClass<T>
---@field private timer TimerInstance
---@field private timerInterval number
---@field private timerGuard boolean
---@field private enabled boolean
---@field private processing boolean
---@field private queue QueueList<T>
---@field private formatCallback? fun(commands: T[]): string
---@field private sendCallback? fun(commandStr: string)
CommandQueueClass = {}

---@param timer TimerInstance
---@param timerInterval? number
---@return CommandQueueClass
function CommandQueueClass:new(timer, timerInterval)
  if timerInterval == nil then timerInterval = 0.1 end
  local o = {
    timer = timer,
    timerGuard = false,
    timerInterval = timerInterval,
    processing = false,
    enabled = false,
    queue = QueueList:new(),
    formatCallback = nil,
    sendCallback = nil,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@param formatCallback fun(commands: T[]): string
function CommandQueueClass:setFormatCallback(formatCallback)
  self.formatCallback = formatCallback
end

---@param sendCallback fun(commandStr: string)
function CommandQueueClass:setSendCallback(sendCallback)
  self.sendCallback = sendCallback
end

---@param enabled boolean
function CommandQueueClass:setEnabled(enabled)
  self.enabled = enabled
  if not enabled then
    self.queue:clear()
    if self.timer:IsRunning() then
      self.timer:Stop()
    end
  else
    self.timer.EventHandler = function()
      local status, err = pcall(function() self:processNext() end)
      if not status then
        if self.timer:IsRunning() then
          self.timer:Stop()
        end
        self.processing = false
        DebugPrint("Error in CommandQueueClass timer event handler: "..tostring(err))
      end
    end
  end
end

function CommandQueueClass:isEnabled()
  return self.enabled
end

function CommandQueueClass:clear()
  self.queue:clear()
end

---@return integer
function CommandQueueClass:size()
  return self.queue:size()
end

---@return boolean
function CommandQueueClass:isEmpty()
  return self.queue:isEmpty()
end

---@param command T
function CommandQueueClass:enqueue(command)
  if not self.enabled then
    DebugPrint("CommandQueueClass is disabled, cannot enqueue command: "..tostring(command))
    return
  end
  self.timerGuard = true
  self.queue:pushRight(command)
  local commandDebugStr = tostring(command)
  if type(command) == "table" then
    commandDebugStr = TableToString(command)
  end
  DebugPrint("Enqueued command: "..commandDebugStr..". Queue size is now: "..self.queue:size())
  self:retriggerTimer()
  self.timerGuard = false
end

---@private
function CommandQueueClass:retriggerTimer()
  if self.timer:IsRunning() then
    self.timer:Stop()
  end
  self.timer:Start(self.timerInterval)
end

---@private
function CommandQueueClass:processNext()
  if self.processing then
    DebugPrint("CommandQueueClass:processNext - already processing, skipping this call to avoid reentrancy")
    return
  end
  self.processing = true
  local function StopTimerIfNotRetriggered()
    if self.timer:IsRunning() and not self.timerGuard then
      self.timer:Stop()
    end
  end
  if not self.enabled then
    DebugPrint("CommandQueueClass is disabled, cannot process commands")
    StopTimerIfNotRetriggered()
    self.processing = false
    return
  end
  if self.queue:isEmpty() then
    DebugPrint("CommandQueueClass queue is empty, nothing to process")
    StopTimerIfNotRetriggered()
    self.processing = false
    return
  end
  if self.formatCallback == nil then
    StopTimerIfNotRetriggered()
    self.processing = false
    error("CommandQueueClass formatCallback is not set")
  end
  if not self.sendCallback then
    StopTimerIfNotRetriggered()
    self.processing = false
    error("CommandQueueClass sendCallback is not set")
  end
  local commands = self.queue:popAll()
  if not self.queue:isEmpty() then
    StopTimerIfNotRetriggered()
    self.processing = false
    error("CommandQueueClass:processNext - expected queue to be empty after popping all commands, but it is not. Remaining size: "..self.queue:size())
  end

  local fullCmd = self.formatCallback(commands)
  self.sendCallback(fullCmd)

  -- After processing, another call to enqueue may have been made.
  -- Only stop the timer if it wasn't retriggered during processing to avoid stopping a new timer that was started after processing.
  StopTimerIfNotRetriggered()
  self.processing = false
end


-- This is needed for testing purposes to allow the classes to be imported
-- into the test files without causing errors in the actual plugin environment.
if os.getenv("TEST_ENV") then
  function DebugPrint(msg)
    print("[CommandQueueClass DEBUG] "..tostring(msg))
  end
  return {
    QueueList = QueueList,
    CommandQueueClass = CommandQueueClass
  }
end
