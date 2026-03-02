--- @enum StatusType
StatusType = {
  OK = 0,
  Compromised = 1,
  Fault = 2,
  NotPresent = 3,
  Missing = 4,
  Initializing = 5,
}

---@alias StatusTypeName "OK" | "Compromised" | "Fault" | "NotPresent" | "Missing" | "Initializing"

---@param status StatusType
---@return StatusTypeName
function StatusTypeToString(status)
  for key, value in pairs(StatusType) do
    if value == status then
      return key
    end
  end
  error("Invalid status type: "..tostring(status))
end


function DebugPrint(msg)
  print("[DEBUG] "..msg)
end
