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

---@param tbl table
---@param indent? number
---@return string
function TableToString(tbl, indent)
  indent = indent or 0
  local indentStr = string.rep("  ", indent)
  local result = "{\n"
  for key, value in pairs(tbl) do
    local keyStr = tostring(key)
    local valueStr
    if type(value) == "table" then
      valueStr = TableToString(value, indent + 1)
    else
      valueStr = tostring(value)
    end
    result = result .. indentStr .. "  [" .. keyStr .. "] = " .. valueStr .. ",\n"
  end
  result = result .. indentStr .. "}"
  return result
end
