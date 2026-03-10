require("telescope")



---@module "commandqueue"
local commandqueue = require "lib.commandqueue"

--- This is a mock implementation of the QSys Timer interface for testing purposes.
--- No actual timing functionality is implemented, and the EventHandler is called immediately when Start is called.
---@class FakeTimer
---@field private isRunning boolean
---@field EventHandler function|nil
---@field private delay number
local FakeTimer = {}
---@return FakeTimer
function FakeTimer:new()
  local obj = {
    isRunning = false,
    EventHandler = nil,
    delay = nil
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function FakeTimer:IsRunning()
  return self.isRunning
end

function FakeTimer:Start(delay)
  self.isRunning = true
  self.delay = delay
  if self.EventHandler then
    self.EventHandler()
  end
end

function FakeTimer:Stop()
  self.isRunning = false
  self.delay = nil
end



context("commandqueue", function()
  context("QueueList", function()
    test("should be able to push and pop values", function()
      local queue = commandqueue.QueueList:new()
      queue:pushRight(1)
      queue:pushRight(2)
      queue:pushRight(3)
      assert_equal(1, queue:popLeft())
      assert_equal(2, queue:popLeft())
      assert_equal(3, queue:popLeft())
    end)
    test("should be able to pop from the right", function()
      local queue = commandqueue.QueueList:new()
      queue:pushRight(1)
      queue:pushRight(2)
      queue:pushRight(3)
      assert_equal(3, queue:popRight())
      assert_equal(2, queue:popRight())
      assert_equal(1, queue:popRight())
    end)
    test("should be able to pop all values", function()
      local queue = commandqueue.QueueList:new()
      queue:pushRight(1)
      queue:pushRight(2)
      queue:pushRight(3)
      local allValues = queue:popAll()
      assert_equal(1, allValues[1])
      assert_equal(2, allValues[2])
      assert_equal(3, allValues[3])
    end)
    test("should be able to check if the queue is empty", function()
      local queue = commandqueue.QueueList:new()
      assert_equal(true, queue:isEmpty())
      queue:pushRight(1)
      assert_equal(false, queue:isEmpty())
      queue:popLeft()
      assert_equal(true, queue:isEmpty())
    end)
    test("should be able to get the size of the queue", function()
      local queue = commandqueue.QueueList:new()
      assert_equal(0, queue:size())
      queue:pushRight(1)
      assert_equal(1, queue:size())
      queue:pushRight(2)
      assert_equal(2, queue:size())
      queue:popLeft()
      assert_equal(1, queue:size())
      queue:popLeft()
      assert_equal(0, queue:size())
    end)
    test("should error when popping from an empty queue", function()
      local queue = commandqueue.QueueList:new()
      assert_error(function() queue:popLeft() end)
      assert_error(function() queue:popRight() end)
    end)
    test("should be able to clear the queue", function()
      local queue = commandqueue.QueueList:new()
      queue:pushRight(1)
      queue:pushRight(2)
      queue:pushRight(3)
      queue:clear()
      assert_equal(true, queue:isEmpty())
    end)
  end)
  context("CommandQueueClass", function()
    test("should not process commands when disabled", function()
      local timer = FakeTimer:new()
      local processedCommands = {}

      ---@type CommandQueueClass<integer>
      local queue = commandqueue.CommandQueueClass:new(timer --[[@as TimerInstance ]])
      queue:setFormatCallback(function(commands)
        assert_equal(1, #commands)
        return tostring(commands[1])
      end)
      queue:setSendCallback(function(formattedCommand)
        table.insert(processedCommands, formattedCommand)
      end)
      queue:setEnabled(false)
      queue:enqueue(1)
      assert_true(queue:isEmpty())
      queue:enqueue(2)
      assert_true(queue:isEmpty())
      queue:enqueue(3)
      assert_true(queue:isEmpty())
      assert_equal(0, #processedCommands)
    end)
    test("should process commands in order", function()
      local timer = FakeTimer:new()
      local processedCommands = {}

      ---@type CommandQueueClass<integer>
      local queue = commandqueue.CommandQueueClass:new(timer --[[@as TimerInstance ]])
      queue:setFormatCallback(function(commands)
        assert_equal(1, #commands)
        return tostring(commands[1])
      end)
      queue:setSendCallback(function(formattedCommand)
        table.insert(processedCommands, formattedCommand)
      end)
      queue:setEnabled(true)
      queue:enqueue(1)
      queue:enqueue(2)
      queue:enqueue(3)
      assert_equal("1", processedCommands[1])
      assert_equal("2", processedCommands[2])
      assert_equal("3", processedCommands[3])
      assert_true(queue:isEmpty())
    end)
    test("should stop timer when queue is empty", function()
      local timer = FakeTimer:new()

      ---@type CommandQueueClass<integer>
      local queue = commandqueue.CommandQueueClass:new(timer --[[@as TimerInstance ]])
      queue:setFormatCallback(function(commands)
        assert_equal(1, #commands)
        return tostring(commands[1])
      end)
      queue:setSendCallback(function(formattedCommand) end)
      queue:setEnabled(true)
      queue:enqueue(1)
      assert_true(timer:IsRunning())
      queue:enqueue(2)
      assert_true(timer:IsRunning())
      queue:enqueue(3)
      assert_true(timer:IsRunning())
      -- simulate timer triggering
      timer.EventHandler()
      assert_false(timer:IsRunning())
    end)
  end)
end)
