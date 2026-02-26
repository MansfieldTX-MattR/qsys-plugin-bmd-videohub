--- @enum StatusType
StatusType = {
  OK = 0,
  Compromised = 1,
  Fault = 2,
  NotPresent = 3,
  Missing = 4,
  Initializing = 5,
}


function DebugPrint(msg)
  print("[DEBUG] "..msg)
end
