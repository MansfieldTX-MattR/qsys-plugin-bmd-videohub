--- @enum StatusType
StatusType = {
  OK = 0,
  Compromised = 1,
  Fault = 2,
  NotPresent = 3,
  Missing = 4,
  Initializing = 5,
}



Controls.TelnetActive.Boolean = false
Controls.Status.Value = StatusType.NotPresent

PingTimer = Timer.New()
PingInterval = 30  -- seconds

---@type "Ping" | "GetStatus" | nil
PingLastCommand = nil

---@class TelnetState
TelnetState = {
  Enabled = Controls.TelnetEnable.Boolean,
  Active = false,
  IsSetup = false,
  Status = StatusType.NotPresent,
  IP = "",
  Port = -1,
}

---@param newStatus StatusType
TelnetState.SetStatus = function(newStatus)
  if TelnetState.Status ~= newStatus then
    TelnetState.Status = newStatus
    Controls.Status.Value = newStatus
  end
end

TelnetRXBuffer = ""

function DebugPrint(msg)
  print("[DEBUG] "..msg)
end


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

---@alias VideoHubCommand "GetStatus" | "SetInputLabels" | "SetOutputLabels" | "SetVideoOutputRouting" | "Ping"
---@alias VideoHubField "Device"|"InputLabels"|"OutputLabels"|"Crosspoints"
---@alias VideoHubSection VideoHubField | "Preamble" | "OutputLocks" | "Configuration"

--- @type { [VideoHubCommand]: boolean }
VideoHubCommandsWithAckNak = {
  SetInputLabels = true,
  SetOutputLabels = true,
  SetVideoOutputRouting = true,
  Ping = true,
}


---@class VideoHubState
VideoHubState = {
  -- ACK_or_NAK_line = nil,
  -- ACK_or_NAK_callback = nil,
  ---@type string?
  ackOrNakLine = nil,
  -- ackOrNakEvent = Event:new(),

  ---@type VideoHubCommand?
  lastCommandSent = nil,
  -- waitingForResponse = false, -- flag set after sending a command, cleared ACK_or_NAK_line is received

  ---@type VideoHubSection?
  currentSection = nil,       -- current section being parsed
  preludeParsed = false,       -- flag set when prelude has been fully parsed
  responseReady = Event:new(),
  readEnabled = false
}
function VideoHubState.reset()
  VideoHubState.preludeParsed = false
  VideoHubState.currentSection = nil
  VideoHubState.readEnabled = false
  VideoHubState.ackOrNakLine = nil
  -- VideoHubState.ackOrNakEvent:Clear()
  VideoHubState.responseReady:Trigger()
end




---@type { [VideoHubSection]: string }
VideoHubSections = {
  Preamble = "PROTOCOL PREAMBLE:",
  Device = "VIDEOHUB DEVICE:",
  Network = "NETWORK:",
  NetworkInterface = "NETWORK INTERFACE:",
  InputLabels = "INPUT LABELS:",
  OutputLabels = "OUTPUT LABELS:",
  OutputLocks = "VIDEO OUTPUT LOCKS:",
  Crosspoints = "VIDEO OUTPUT ROUTING:",
  Configuration = "CONFIGURATION:",
}

---@class VideoHubDevice
VideoHubDevice = {
  Model = "",
  Name = "",
  UniqueId = "",
  InputCount = 0,
  OutputCount = 0,
}

---@class VideoHub
VideoHub = {
  Preamble = {
    ---@type string?
    ProtocolVersion = nil,
  },
  Device = VideoHubDevice,
  -- Device = {
  --   ---@type string?
  --   Model = nil,
  --   ---@type string?
  --   Name = nil,
  --   ---@type string?
  --   UniqueId = nil,
  --   ---@type number
  --   InputCount = 0,
  --   ---@type number
  --   OutputCount = 0,
  -- },
  ---@type string[]
  InputLabels = {},
  ---@type string[]
  OutputLabels = {},
  ---@type number[]
  Crosspoints = {},

  RequestStatus = function()
    local sections = {
      VideoHubSections.InputLabels,
      VideoHubSections.OutputLabels,
      VideoHubSections.Crosspoints,
    }
    for _, section in ipairs(sections) do
      local cmd = section .. "\n\n"
      TelnetSendCommand("GetStatus", cmd)
      -- TelnetWaitForResponse()
    end
  end,

  SendPing = function()
    local cmd = "PING:\n\n"
    TelnetSendCommand("Ping", cmd)
  end,

  ---@param inputIndex number
  ---@param label string
  SetInputLabel = function (inputIndex, label)
    return VideoHub.SetInputLabels({{inputIndex, label}})
  end,

  ---@param labelPairs [number, string][]
  SetInputLabels = function(labelPairs)
    local txLines = {VideoHubSections.InputLabels}
    for _, pair in ipairs(labelPairs) do
      local inputIndex = pair[1]
      local label = pair[2]
      table.insert(txLines, string.format("%d %s", inputIndex - 1, label))
    end
    local cmd = table.concat(txLines, "\n")
    cmd = cmd .. "\n\n"
    TelnetSendCommand("SetInputLabels", cmd)
    -- local ack = TelnetWaitForAckOrNak()
    -- if ack then
    --   for _, pair in ipairs(labelPairs) do
    --     local inputIndex = pair[1]
    --     local label = pair[2]
    --     VideoHub.InputLabels[inputIndex] = label
    --     VideoHubChangeEvents.InputLabels:Trigger()
    --   end
    -- end
    -- return ack
  end,

  ---@param outputIndex number
  ---@param label string
  SetOutputLabel = function (outputIndex, label)
    return VideoHub.SetOutputLabels({{outputIndex, label}})
  end,

  ---@param outputPairs [number, string][]
  SetOutputLabels = function(outputPairs)
    local txLines = {VideoHubSections.OutputLabels}
    for _, pair in ipairs(outputPairs) do
      local outputIndex = pair[1]
      local label = pair[2]
      table.insert(txLines, string.format("%d %s", outputIndex - 1, label))
    end
    local cmd = table.concat(txLines, "\n")
    cmd = cmd .. "\n\n"
    TelnetSendCommand("SetOutputLabels", cmd)
    -- local ack = TelnetWaitForAckOrNak()
    -- if ack then
    --   for _, pair in ipairs(outputPairs) do
    --     local outputIndex = pair[1]
    --     local label = pair[2]
    --     VideoHub.OutputLabels[outputIndex] = label
    --     VideoHubChangeEvents.OutputLabels:Trigger()
    --   end
    -- end
    -- return ack
  end,

  ---@param outputIndex number
  ---@param inputIndex number
  SetCrosspoint = function (outputIndex, inputIndex)
    return VideoHub.SetCrosspoints({{outputIndex, inputIndex}})
  end,

  ---@param routingPairs [number, number][]
  SetCrosspoints = function(routingPairs)
    local txLines = {VideoHubSections.Crosspoints}
    for _, pair in ipairs(routingPairs) do
      local outputIndex = pair[1]
      local inputIndex = pair[2]
      table.insert(txLines, string.format("%d %d", outputIndex - 1, inputIndex - 1))
    end
    local cmd = table.concat(txLines, "\n")
    cmd = cmd .. "\n\n"
    TelnetSendCommand("SetVideoOutputRouting", cmd)
    -- local ack = TelnetWaitForAckOrNak()
    -- if ack then
    --   for _, pair in ipairs(routingPairs) do
    --     local outputIndex = pair[1]
    --     local inputIndex = pair[2]
    --     VideoHub.Crosspoints[outputIndex] = inputIndex
    --   end
    -- end
    -- VideoHubChangeEvents.Crosspoints:Trigger()
    -- return ack
  end,
}


---@class VideoHubChangeEvents
---@field Device Event
---@field InputLabels Event
---@field OutputLabels Event
---@field Crosspoints Event
VideoHubChangeEvents = {
  Device = Event:new(),
  InputLabels = Event:new(),
  OutputLabels = Event:new(),
  Crosspoints = Event:new(),
}
function VideoHubChangeEvents.reset()
  VideoHubChangeEvents.Device:Trigger()
  VideoHubChangeEvents.InputLabels:Trigger()
  VideoHubChangeEvents.OutputLabels:Trigger()
  VideoHubChangeEvents.Crosspoints:Trigger()
end


---@type { [VideoHubField]: fun(string) }
VideoHubSectionParsers = {
  Preamble = function(line)
    if Parser.lineStartsWith(line, "Version:") then
      VideoHub.Preamble.ProtocolVersion = Parser.splitValue(line)
    end
  end,
  Device = function(line)
    local function fillArray(arr, length, fillValue)
      for i = 1, length do
        arr[i] = fillValue
      end
    end

    local value = nil
    local valueChanged = false

    ---@type string?
    local key = nil
    if Parser.lineStartsWith(line, "Model Name:") then
      value = Parser.splitValue(line)
      valueChanged = (VideoHub.Device.Model ~= value)
      VideoHub.Device.Model = value
    elseif Parser.lineStartsWith(line, "Friendly Name:") then
      value = Parser.splitValue(line)
      valueChanged = (VideoHub.Device.Name ~= value)
      VideoHub.Device.Name = value
    elseif Parser.lineStartsWith(line, "Unique ID:") then
      value = Parser.splitValue(line)
      valueChanged = (VideoHub.Device.UniqueId ~= value)
      VideoHub.Device.UniqueId = value
    elseif Parser.lineStartsWith(line, "Video inputs:") then
      value = tonumber(Parser.splitValue(line))
      valueChanged = (VideoHub.Device.InputCount ~= value)
      VideoHub.Device.InputCount = value
      if #VideoHub.InputLabels ~= value then
        fillArray(VideoHub.InputLabels, value, "")
      end
    elseif Parser.lineStartsWith(line, "Video outputs:") then
      value = tonumber(Parser.splitValue(line))
      valueChanged = (VideoHub.Device.OutputCount ~= value)
      if #VideoHub.OutputLabels ~= value then
        fillArray(VideoHub.OutputLabels, value, "")
      end
      if #VideoHub.Crosspoints ~= value then
        fillArray(VideoHub.Crosspoints, value, 1)
      end
      VideoHub.Device.OutputCount = value
    end
    if valueChanged then
      VideoHubChangeEvents.Device:Trigger()
    end
  end,
  InputLabels = function(line)
    local index, label = Parser.parseLabelLine(line)
    if index and label then
      if VideoHub.InputLabels[index] ~= label then
        VideoHub.InputLabels[index] = label
        VideoHubChangeEvents.InputLabels:Trigger()
      end
    end
  end,
  OutputLabels = function(line)
    local index, label = Parser.parseLabelLine(line)
    if index and label then
      if VideoHub.OutputLabels[index] ~= label then
        VideoHub.OutputLabels[index] = label
        VideoHubChangeEvents.OutputLabels:Trigger()
      end
    end
  end,
  Crosspoints = function(line)
    local outputIndex, inputIndex = Parser.parseRoutingLine(line)
    if outputIndex and inputIndex then
      if VideoHub.Crosspoints[outputIndex] ~= inputIndex then
        VideoHub.Crosspoints[outputIndex] = inputIndex
        VideoHubChangeEvents.Crosspoints:Trigger()
      end
    end
  end,
  Network = function(line)
    -- Currently ignoring network section
  end,
  NetworkInterface = function(line)
    -- Currently ignoring network interface section
  end,
  Configuration = function(line)
    -- Currently ignoring configuration section
  end,
}


-- Constants
Telnet = TcpSocket.New()  -- create new TCP object
Port = 9990  -- port of the telnet server
EOL = "\r"  -- End Of Line character
IAC = 0xFF  -- telnet Interpret As Command character
TelSetResp = {  -- table of telnet setup options, these are examples of WONT options.
  {cmd=0xFC,opt=0x18},
  {cmd=0xFC,opt=0x20},
  {cmd=0xFC,opt=0x23},
  {cmd=0xFC,opt=0x27},
  {cmd=0xFC,opt=0x03},
  {cmd=0xFC,opt=0x01},
  {cmd=0xFC,opt=0x1F},
  {cmd=0xFC,opt=0x05},
  {cmd=0xFC,opt=0x21}
}






-- ---@param preludeOnly boolean
-- ---@return string?
-- function TelnetWaitForResponse(preludeOnly)
--   -- local preludeOnly = arg[1] or false
--   while VideoHubState.readEnabled do
--     VideoHubState.responseReady:Wait(function() end)
--     VideoHubState.responseReady:Clear()
--     if preludeOnly then
--       if VideoHubState.preludeParsed then
--         break
--       else
--         goto continue
--       end
--     end
--     if VideoHubState.ackOrNakLine ~= nil then
--       local response = VideoHubState.ackOrNakLine
--       VideoHubState.ackOrNakLine = nil
--       VideoHubState.ackOrNakEvent:Clear()
--       return response
--     end
--   end
--     ::continue::
-- end

-- ---@return boolean
-- function TelnetWaitForAckOrNak()
--   if not TelnetActive then
--     print("Telnet not connected, cannot wait for ACK/NAK")
--     return false
--   end
--   -- local function waiter()
--   --   VideoHubState.ackOrNakEvent:Wait(function()
--   --     local response = VideoHubState.ackOrNakLine
--   --     VideoHubState.ackOrNakLine = nil
--   --     VideoHubState.ackOrNakEvent:Clear()
--   --     local result = response ~= nil and Parser.lineStartsWith(response, "ACK")
--   --     return result
--   --   end)
--   -- end
--   -- return waiter()



-- end


-- Parsing logic

--- @class Parser
Parser = {
  ---@param line string
  ---@param prefix string
  ---@return boolean
  lineStartsWith = function(line, prefix)
    return line:sub(1, #prefix) == prefix
  end,

  ---@param line string
  ---@param substring string
  ---@return boolean
  lineContains = function(line, substring)
    return line:find(substring, 1, true) ~= nil
  end,

  ---@param line string
  ---@return string
  stripNewlines = function(line)
    -- return line:gsub("\r", ""):gsub("\n", "")
    local s, _ = line:gsub(EOL, "")
    return s
  end,

  ---@param line string
  ---@return string
  splitValue = function(line)
    -- take a line in the format "Key: Value" and the value with all leading/trailing spaces removed
    local _, _, value = line:find(":%s*(.-)%s*$")
    return value
  end,

  ---@param line string
  ---@return number?, string?
  parseLabelLine = function(line)
    -- Expecting lines like "0 Camera 1"
    -- Returns index (number) and label (string) making sure to use 1-based indexing
    local _, _, indexStr, label = line:find("^(%d+)%s+(.-)%s*$")
    if indexStr and label then
      local index = tonumber(indexStr)
      if index == nil then
        error("Failed to parse label index: " .. tostring(indexStr))
      end
      return index + 1, label  -- convert 0-based index to 1-based index
    end
    return nil, nil
  end,

  ---@param line string
  ---@return number?, number?
  parseRoutingLine = function(line)
    -- Expecting lines like "0 1"
    -- Returns outputIndex (number) and inputIndex (number) making sure to use 1-based indexing
    local _, _, outputStr, inputStr = line:find("^(%d+)%s+(%d+)%s*$")
    if outputStr and inputStr then
      local outputIndex = tonumber(outputStr)
      local inputIndex = tonumber(inputStr)
      if outputIndex == nil or inputIndex == nil then
        error("Failed to parse routing line: " .. tostring(line))
      end
      return outputIndex + 1, inputIndex + 1  -- convert 0-based index to 1-based index
    end
    return nil, nil
  end,
}


---@param rxData string
function ParseIncomingData(rxData)
  if rxData==nil or rxData=="" then return end
  TelnetRXBuffer=TelnetRXBuffer..rxData
  local sectionParsed = false
  local lastCommandSent = VideoHubState.lastCommandSent
  VideoHubState.ackOrNakLine = nil
  if VideoHubState.preludeParsed then
    DebugPrint("RX: "..rxData)
  end

  for line in TelnetRXBuffer:gmatch("([^\r\n]+)") do
    if Parser.lineStartsWith(line, "END PRELUDE:") then
      DebugPrint("End of prelude detected")
      VideoHubState.preludeParsed = true
      VideoHubState.currentSection = nil
      TelnetRXBuffer = ""
      break
    end
    line = Parser.stripNewlines(line)
    if Parser.lineStartsWith(line, 'ACK') or Parser.lineStartsWith(line, 'NAK') then
      DebugPrint("ACK/NAK line detected: "..line)
      local commandInAckNak = VideoHubCommandsWithAckNak[lastCommandSent] ~= nil
      if lastCommandSent and commandInAckNak then
        DebugPrint("Got ACK/NAK for command: "..tostring(lastCommandSent))
      else
        DebugPrint("Ignoring ACK/NAK line for command without ACK/NAK: "..tostring(lastCommandSent))
      end
      VideoHubState.ackOrNakLine = line
      -- VideoHubState.ackOrNakEvent:Set()
      TelnetRXBuffer = ""
      break
      -- goto continue
    end
    for sectionName, sectionHeader in pairs(VideoHubSections) do
      if Parser.lineStartsWith(line, sectionHeader) then
        DebugPrint("Section header detected: "..sectionHeader)
        VideoHubState.currentSection = sectionName
        goto continue
      end
    end
    if VideoHubState.currentSection == nil then
      goto continue
    else
      local handler = VideoHubSectionParsers[VideoHubState.currentSection]
      if handler then
        handler(line)
        sectionParsed = true
      end
      sectionParsed = true
    end
    ::continue::
  end
  DebugPrint("End of RX data parsing: preludeParsed="..tostring(VideoHubState.preludeParsed)..", currentSection="..tostring(VideoHubState.currentSection)..", sectionParsed="..tostring(sectionParsed))
  VideoHubState.responseReady:Set()
  if not VideoHubState.preludeParsed then return end
  if VideoHubState.currentSection ~= nil and sectionParsed then
    VideoHubState.currentSection = nil
  end
  if lastCommandSent == "Ping" then
    if VideoHubState.ackOrNakLine == nil then
      print("No ACK/NAK received for Ping command, assuming disconnection")
      TelnetState.SetStatus(StatusType.Compromised)
      Connect()
    end
  end
end


-- Telnet setup and command functions

function TelnetSetup()  -- function to pack and send the do/dont/will/wont bits
  print("Setting up telnet session")
  local data={}
  for _,resp in ipairs(TelSetResp) do
    table.insert(data,string.pack("BBB",IAC,resp.cmd,resp.opt))
  end
  Telnet:Write(table.concat(data))
end



---@param cmdName VideoHubCommand
---@param cmd string
function TelnetSendCommand(cmdName, cmd)  -- function to send a command over the telnet session
  if TelnetIsConnected() then
    VideoHubState.lastCommandSent = cmdName
    Telnet:Write(cmd)
    DebugPrint("TX: "..cmd)
  else
    print("Telnet not connected, cannot send command")
  end
end


function Disconnected()  -- function called when disconnected from the
  print("Telnet session disconnected")
  if PingTimer:IsRunning() then
    PingTimer:Stop()
  end
  if TelnetState.Enabled then
    TelnetState.SetStatus(StatusType.Missing)
  else
    TelnetState.SetStatus(StatusType.NotPresent)
  end

  TelnetState.Active = false
  Controls.TelnetActive.Boolean = false
  TelnetState.IsSetup = false
  VideoHubState.reset()
  VideoHubChangeEvents.reset()
  TelnetRXBuffer = ""

end

function Connected()  -- function called when the telnet session is first active
  print("Telnet session active")
  -- TelnetWaitForResponse(true)  -- wait for prelude to be parsed
  -- print("Telnet prelude parsed")
  TelnetState.SetStatus(StatusType.OK)
  Controls.TelnetActive.Boolean = true
  VideoHub.SendPing()
  PingTimer:Start(PingInterval)
end

---@return boolean
function TelnetIsConnected()  -- returns true when the telnet session flag is high
  return TelnetState.Active
end


---@return boolean isValid
---@return string ip
---@return number port
function ValidateIPAndPort()
  local ip = Controls.IPAddress.String
  if ip == nil or ip == "" then
    print("IP address not set")
    return false, "", -1
  end
  local portStr = Controls.Port.String
  if portStr == nil or portStr == "" then
    print("Port not set")
    return false, "", -1
  end
  local port = tonumber(portStr)
  if port == nil then
    print("Invalid port number: "..tostring(portStr))
    return false, "", -1
  end
  return true, ip, port
end

function Connect()  -- function to connect the TCP socket
  if Telnet.IsConnected then Telnet:Disconnect() Disconnected() end
  if not TelnetState.Enabled then return end
  local isValid, ip, port = ValidateIPAndPort()
  TelnetState.IP = ip
  TelnetState.Port = port
  if not isValid then
    print("Invalid IP or port, cannot connect")
    return
  end
  TelnetState.SetStatus(StatusType.Initializing)
  Telnet:Connect(ip, port)
  VideoHubState.readEnabled = true
end

function Initialization()  -- function called at start of runtime
  print("Initializing plugin")
  if TelnetState.Enabled then
    Connect()
  end
end


function HandleRXData()  -- function that reads and parses the TCP socket
  local rx=Telnet:Read(Telnet.BufferLength)  -- assign the contents of the buffer to a variable
  -- DebugPrint("BFR: "..TelnetRXBuffer)
  -- DebugPrint("RX: "..rx)
  if not TelnetState.Enabled then return end
  if TelnetState.IsSetup==false then
    TelnetSetup()
    TelnetState.IsSetup=true
  end
  if TelnetState.Active==false then
    TelnetState.Active=true
    Controls.TelnetActive.Boolean = true
    Connected()
  end
  ParseIncomingData(rx)
end



-- TCP socket callbacks
Telnet.Connected=function()  -- function called when the TCP socket is connected
  print("Socket connected")
end

Telnet.Reconnect=function()  -- function called when the TCP socket is reconnected
  print("Socket reconnecting...")
end

Telnet.Closed=function() -- function called when the TCP socket is closed
  print("Socket closed")
  Disconnected()
end

Telnet.Error=function()  -- function called when the TCP socket has an error
  print("Socket error")
  Disconnected()
end

Telnet.Timeout=function()  -- function called when the TCP socket times out
  print("Socket timeout")
  Disconnected()
end

Telnet.Data=HandleRXData  -- HandleRXData is called when Telnet has data


-- EventHandlers
-- IPAddress.EventHandler = Connect
-- UserName.EventHandler = Connect
-- Password.EventHandler = Connect

---@param t Timer
PingTimer.EventHandler = function(t)
  if TelnetIsConnected() and TelnetState.Enabled then
    if PingLastCommand == "Ping" then
      PingLastCommand = "GetStatus"
      VideoHub.RequestStatus()
    else
      PingLastCommand = "Ping"
      VideoHub.SendPing()
    end
  end
end


Controls.IPAddress.EventHandler = function()
  local ip = Controls.IPAddress.String
  if ip == TelnetState.IP then
    return
  end
  if TelnetState.Enabled then
    Connect()
  end
end

Controls.Port.EventHandler = function()
  local isValid, _, port = ValidateIPAndPort()
  if not isValid then return end
  if port == TelnetState.Port then
    return
  end
  if TelnetState.Enabled then
    Connect()
  end
end

Controls.TelnetEnable.EventHandler = function()
  TelnetState.Enabled = Controls.TelnetEnable.Boolean
  print("Telnet Enable changed to "..tostring(TelnetState.Enabled))
  if TelnetState.Enabled and not TelnetState.Active then
    Connect()
  elseif not TelnetState.Enabled then
    -- Telnet.Data = function() end  -- disable data handler to prevent parsing during disconnect
    if Telnet.IsConnected then
      Telnet:Disconnect()
      Disconnected()
    end
  end
end

VideoHubChangeEvents.InputLabels:RegisterCallback(function()
  -- print("Input label changed")
  for i, label in ipairs(VideoHub.InputLabels) do
    -- Controls["InputLabels "..i].String = label
    InputLabelControls[i].String = label
  end
end)

VideoHubChangeEvents.OutputLabels:RegisterCallback(function()
  -- print("Output label changed")
  for i, label in ipairs(VideoHub.OutputLabels) do
    -- Controls["OutputLabels "..i].String = label
    OutputLabelControls[i].String = label
  end
end)

VideoHubChangeEvents.Crosspoints:RegisterCallback(function()
  -- print("Crosspoint changed")
  for i, inputIndex in ipairs(VideoHub.Crosspoints) do
    -- Controls["Crosspoints "..i].Value = inputIndex
    CrosspointControls[i].Value = inputIndex
  end
end)

---@type TextControllerControls[]
InputLabelControls = {}

---@type TextControllerControls[]
OutputLabelControls = {}


---@type TextControllerControls[]
CrosspointControls = {}

for i = 1, Properties["Max Input Count"].Value or 12 do
  InputLabelControls[i] = Controls["InputLabel_"..i]
end

for i = 1, Properties["Max Output Count"].Value or 12 do
  OutputLabelControls[i] = Controls["OutputLabel_"..i]
  CrosspointControls[i] = Controls["Crosspoint_"..i]
end


for i, inputLabelControl in ipairs(InputLabelControls) do

  ---@ param ctl TextControllerControls
  inputLabelControl.EventHandler = function(ctl)
    if VideoHub.Device.InputCount < i then
      return
    end
    local label = ctl.String
    print("Input "..i.." label changed to "..label..", current is "..VideoHub.InputLabels[i])
    if VideoHub.InputLabels[i] == label then
      return
    end
    VideoHub.SetInputLabel(i, label)
  end
end

for i, outputLabelControl in ipairs(OutputLabelControls) do
  ---@ param ctl TextControllerControls
  outputLabelControl.EventHandler = function(ctl)
    if VideoHub.Device.OutputCount < i then
      return
    end
    local label = ctl.String
    print("Output "..i.." label changed to "..label..", current is "..VideoHub.OutputLabels[i])
    if VideoHub.OutputLabels[i] == label then
      return
    end
    VideoHub.SetOutputLabel(i, label)
  end
end

for i, outputIndex in ipairs(CrosspointControls) do
  ---@ param ctl TextControllerControls
  outputIndex.EventHandler = function(ctl)
    if VideoHub.Device.OutputCount < i then
      return
    end
    local inputIndex = ctl.Value
    print("Output "..i.." changed to input "..inputIndex..", current is "..VideoHub.Crosspoints[i])
    if VideoHub.Crosspoints[i] == inputIndex then
      return
    end
    VideoHub.SetCrosspoint(i, inputIndex)
  end
end

-- Start at runtime
Initialization()  -- calls the Initialization function at the start of runtime
