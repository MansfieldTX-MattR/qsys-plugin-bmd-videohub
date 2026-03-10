
---@class Event
---@field waiters function[]
---@field callbacks function[]
---@field flag boolean
Event = {}
function Event:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  o.waiters = {}
  o.callbacks = {}
  o.flag = false
  return o
end

---@return nil
function Event:Set()
  if self.flag then return end
  self.flag = true
  local waiters = self.waiters
  self.waiters = {}
  for _, waiter in ipairs(waiters) do
    waiter()
  end
  -- local callbacks_copy = shallowCopy(self.callbacks)
  for _, callback in ipairs(self.callbacks) do
    callback()
  end
end

---@return nil
function Event:Trigger()
  if self.flag then self:Clear() end
  self:Set()
  self:Clear()
end

---@return nil
function Event:Clear()
  self.flag = false
end

---@return boolean
function Event:IsSet()
  return self.flag
end

-- ---@param waiter function
-- function Event:Wait(waiter)
--   if self.flag then
--     waiter()
--   else
--     local co = coroutine.create(function(w)
--       w()
--     end)
--     table.insert(self.waiters, function()
--       coroutine.resume(co, waiter)
--     end)
--   end
-- end

---@param callback function
function Event:RegisterCallback(callback)
  table.insert(self.callbacks, callback)
end


-- This is needed for testing purposes to allow the classes to be imported
-- into the test files without causing errors in the actual plugin environment.
if os.getenv("TEST_ENV") then
  return {
    Event = Event
  }
end
