

function ControlsLockedOut()
  return Controls.ControlLockout.Boolean
end

---@diagnostic disable-next-line: undefined-global
MaxInputCount = Properties["Max Input Count"].Value or 12
---@diagnostic disable-next-line: undefined-global
MaxOutputCount = Properties["Max Output Count"].Value or 12

Controls.TelnetActive.Boolean = false
Controls.Status.Value = StatusType.NotPresent

PingTimer = Timer.New()
PingInterval = 30  -- seconds

---@type "Ping" | "GetStatus" | nil
PingLastCommand = nil

EOL = "\n"
TelnetInstance = TelnetClient:new()
TelnetInstance:SetEOLChar(EOL)

TelnetRXBuffer = ""




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
---@field Model string
---@field Name string
---@field UniqueId string
---@field InputCount number
---@field OutputCount number
VideoHubDevice = {}
function VideoHubDevice:new()
  local o = {
    Model = "",
    Name = "",
    UniqueId = "",
    InputCount = 0,
    OutputCount = 0,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@class VideoHub
VideoHub = {
  Preamble = {
    ---@type string?
    ProtocolVersion = nil,
  },
  Device = VideoHubDevice:new(),
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

function VideoHub.reset()
  VideoHub.Preamble.ProtocolVersion = nil
  VideoHub.Device = VideoHubDevice:new()
  VideoHub.InputLabels = {}
  VideoHub.OutputLabels = {}
  VideoHub.Crosspoints = {}
end


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
    if Parser.lineStartsWith(line, "Model name:") then
      value = Parser.splitValue(line)
      valueChanged = (VideoHub.Device.Model ~= value)
      VideoHub.Device.Model = value
    elseif Parser.lineStartsWith(line, "Friendly name:") then
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
      TelnetInstance:SetStatus(StatusType.Compromised)
      TelnetInstance:Connect()
    end
  end
end

TelnetInstance:SetDataHandler(ParseIncomingData)



---@param cmdName VideoHubCommand
---@param cmd string
function TelnetSendCommand(cmdName, cmd)  -- function to send a command over the telnet session
  if TelnetInstance:IsConnected() then
    VideoHubState.lastCommandSent = cmdName
    TelnetInstance:Send(cmd)
    DebugPrint("TX: "..cmd)
  else
    print("Telnet not connected, cannot send command")
  end
end

TelnetInstance.Events.Disconnected:RegisterCallback(function()
  if PingTimer:IsRunning() then
    PingTimer:Stop()
  end
  Controls.TelnetActive.Boolean = false
  VideoHubState.reset()
  VideoHubChangeEvents.reset()
  TelnetRXBuffer = ""
end)

TelnetInstance.Events.Connected:RegisterCallback(function()
  Controls.TelnetActive.Boolean = true
  PingTimer:Start(PingInterval)
end)

TelnetInstance.Events.BeforeConnect:RegisterCallback(function()
  VideoHubState.reset()
  VideoHub.reset()
end)

TelnetInstance.Events.AfterConnect:RegisterCallback(function()
  VideoHubState.readEnabled = true
end)

TelnetInstance.Events.StatusChanged:RegisterCallback(function()
  local status = TelnetInstance:GetStatus()
  local isActive = TelnetInstance:IsActive() or status == StatusType.OK
  Controls.TelnetActive.Boolean = isActive
  Controls.Status.Value = status
end)


function Initialization()  -- function called at start of runtime
  print("Initializing plugin")
  TelnetInstance:SetEnabled(Controls.TelnetEnable.Boolean)
  TelnetInstance:SetPort(Controls.Port.String)
  TelnetInstance:SetIP(Controls.IPAddress.String)
end



---@param t Timer
PingTimer.EventHandler = function(t)
  if TelnetInstance:IsConnected() and TelnetInstance:IsEnabled() then
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
  TelnetInstance:SetIP(Controls.IPAddress.String)
end


Controls.Port.EventHandler = function()
  TelnetInstance:SetPort(Controls.Port.String)
end

Controls.TelnetEnable.EventHandler = function()
  TelnetInstance:SetEnabled(Controls.TelnetEnable.Boolean)
  print("Telnet Enable changed to "..tostring(TelnetInstance:IsEnabled()))
end


VideoHubChangeEvents.Device:RegisterCallback(function()
  Controls.DeviceModel.String = VideoHub.Device.Model
  Controls.DeviceName.String = VideoHub.Device.Name
  Controls.DeviceId.String = VideoHub.Device.UniqueId
  Controls.NumInputs.Value = VideoHub.Device.InputCount
  Controls.NumOutputs.Value = VideoHub.Device.OutputCount
end)


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

for i = 1, MaxInputCount do
  InputLabelControls[i] = Controls.InputLabels[i]
end

for i = 1, MaxOutputCount do
  OutputLabelControls[i] = Controls.OutputLabels[i]
  CrosspointControls[i] = Controls.Crosspoints[i]
end


for i, inputLabelControl in ipairs(InputLabelControls) do

  ---@ param ctl TextControllerControls
  inputLabelControl.EventHandler = function(ctl)
    if VideoHub.Device.InputCount < i then
      return
    end
    if ControlsLockedOut() then
      local currentLabel = VideoHub.InputLabels[i]
      Timer.CallAfter(function() ctl.String = currentLabel end, 0.1)
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
    if ControlsLockedOut() then
      local currentLabel = VideoHub.OutputLabels[i]
      Timer.CallAfter(function() ctl.String = currentLabel end, 0.1)
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
    if ControlsLockedOut() then
      local currentInputIndex = VideoHub.Crosspoints[i]
      Timer.CallAfter(function() ctl.Value = currentInputIndex end, 0.1)
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
