require "telescope"

---@module "events"
local events = require "src.lib.events"


context("events", function()
  context("Event", function()
    test("should be set and cleared properly", function()
      local event = events.Event:new()
      assert_false(event:IsSet())
      event:Set()
      assert_true(event:IsSet())
      event:Clear()
      assert_false(event:IsSet())
    end)
    test("should trigger callbacks when set", function()
      local event = events.Event:new()
      local callbackCalled = false
      event:RegisterCallback(function() callbackCalled = true end)
      event:Set()
      assert_true(callbackCalled)
    end)
    test("should not trigger callbacks when already set", function()
      local event = events.Event:new()
      local callbackCallCount = 0
      event:RegisterCallback(function() callbackCallCount = callbackCallCount + 1 end)
      event:Set()
      event:Set() -- should not trigger again
      assert_equal(1, callbackCallCount)
    end)
    test("should trigger callbacks when set then cleared and set again", function()
      local event = events.Event:new()
      local callbackCallCount = 0
      event:RegisterCallback(function() callbackCallCount = callbackCallCount + 1 end)
      event:Set()
      event:Clear()
      event:Set()
      assert_equal(2, callbackCallCount)
    end)
    test("should call registered callbacks when triggered", function()
      local event = events.Event:new()
      local callbackCalled = false
      event:RegisterCallback(function() callbackCalled = true end)
      event:Trigger()
      assert_true(callbackCalled)
    end)
    test("should clear the event after being triggered", function()
      local event = events.Event:new()
      event:Trigger()
      assert_false(event:IsSet())
    end)
  end)
end)
