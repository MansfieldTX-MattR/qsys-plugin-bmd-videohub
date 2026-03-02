

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

AllowRXDebugPrint = false



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
function VideoHubState:reset()
  self.preludeParsed = false
  self.currentSection = nil
  self.readEnabled = false
  self.ackOrNakLine = nil
  -- self.ackOrNakEvent:Clear()
  self.responseReady:Trigger()
end

---@return boolean
function VideoHubState:IsReady()
  return self.preludeParsed and self.readEnabled and TelnetInstance:IsConnected()
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


---@alias VideoHubCommandSectionMapKey "SetInputLabels" | "SetOutputLabels" | "SetVideoOutputRouting"

VideoHubCommandSectionMap = {
  SetInputLabels = VideoHubSections.InputLabels,
  SetOutputLabels = VideoHubSections.OutputLabels,
  SetVideoOutputRouting = VideoHubSections.Crosspoints,
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
    local txLines = VideoHub.FormatCommandPairs(labelPairs)
    local cmd = VideoHub.FormatCommand("SetInputLabels", txLines)
    TelnetSendCommand("SetInputLabels", cmd)
  end,

  ---@param outputIndex number
  ---@param label string
  SetOutputLabel = function (outputIndex, label)
    return VideoHub.SetOutputLabels({{outputIndex, label}})
  end,

  ---@param outputPairs [number, string][]
  SetOutputLabels = function(outputPairs)
    local txLines = VideoHub.FormatCommandPairs(outputPairs)
    local cmd = VideoHub.FormatCommand("SetOutputLabels", txLines)
    TelnetSendCommand("SetOutputLabels", cmd)
  end,

  ---@param outputIndex number
  ---@param inputIndex number
  SetCrosspoint = function (outputIndex, inputIndex)
    return VideoHub.SetCrosspoints({{outputIndex, inputIndex}})
  end,

  ---@param routingPairs [number, number][]
  SetCrosspoints = function(routingPairs)
    local txLines = VideoHub.FormatCommandPairs(routingPairs)
    local cmd = VideoHub.FormatCommand("SetVideoOutputRouting", txLines)
    TelnetSendCommand("SetVideoOutputRouting", cmd)
  end,

  --- Helper function to format command pairs into lines of "key value" for the given command sections
  ---@param pairs [number|string, number|string][]
  ---@return string[]
  FormatCommandPairs = function(pairs)

    ---@param value number|string
    ---@return string
    function FormatNumber(value)
      if type(value) == "string" then return value end
      return string.format("%d", value - 1)
    end

    local lines = {}
    for _, pair in ipairs(pairs) do
      local key, value = pair[1], pair[2]
      key, value = FormatNumber(key), FormatNumber(value)
      table.insert(lines, key.." "..value)
    end
    return lines
  end,

  --- Helper function to format a command given a section and lines, adding the appropriate header and newlines
  ---@param section VideoHubCommandSectionMapKey
  ---@param lines string[]
  ---@return string
  FormatCommand = function(section, lines)
    local sectionHeader = VideoHubCommandSectionMap[section]
    local txLines = {sectionHeader}
    for _, line in ipairs(lines) do
      table.insert(txLines, line)
    end
    local cmd = table.concat(txLines, "\n")
    cmd = cmd .. "\n\n"
    return cmd
  end,
}

function VideoHub.reset()
  DebugPrint("===================== Resetting VideoHub state ====================")
  VideoHub.Preamble.ProtocolVersion = nil
  VideoHub.Device = VideoHubDevice:new()
  VideoHub.InputLabels = {}
  VideoHub.OutputLabels = {}
  VideoHub.Crosspoints = {}
end


---@class VideoHubChangeEvents
---@field PreludeParsed Event
---@field Preamble Event
---@field Device Event
---@field InputLabels Event
---@field OutputLabels Event
---@field Crosspoints Event
VideoHubChangeEvents = {
  PreludeParsed = Event:new(),
  Preamble = Event:new(),
  Device = Event:new(),
  InputLabels = Event:new(),
  OutputLabels = Event:new(),
  Crosspoints = Event:new(),
}
function VideoHubChangeEvents:reset()
  self.PreludeParsed:Trigger()
  self.Preamble:Trigger()
  self.Device:Trigger()
  self.InputLabels:Trigger()
  self.OutputLabels:Trigger()
  self.Crosspoints:Trigger()
end


---@type { [VideoHubField]: fun(string) }
VideoHubSectionParsers = {
  Preamble = function(line)
    if Parser.lineStartsWith(line, "Version:") then
      VideoHub.Preamble.ProtocolVersion = Parser.splitValue(line)
      VideoHubChangeEvents.Preamble:Trigger()
    end
  end,
  Device = function(line)

    ---@generic T
    ---@param arr T[]
    ---@param length number
    ---@param fillValue T
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
      if value == nil then
        error("Failed to parse video input count: "..tostring(line))
      end
      valueChanged = (VideoHub.Device.InputCount ~= value)
      VideoHub.Device.InputCount = value
      if #VideoHub.InputLabels < value then
        fillArray(VideoHub.InputLabels, value, "")
      end
    elseif Parser.lineStartsWith(line, "Video outputs:") then
      value = tonumber(Parser.splitValue(line))
      if value == nil then
        error("Failed to parse video output count: "..tostring(line))
      end
      valueChanged = (VideoHub.Device.OutputCount ~= value)
      if #VideoHub.OutputLabels < value then
        fillArray(VideoHub.OutputLabels, value, "")
      end
      if #VideoHub.Crosspoints < value then
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
      VideoHub.InputLabels[index] = label
      VideoHubChangeEvents.InputLabels:Trigger()
    end
  end,
  OutputLabels = function(line)
    local index, label = Parser.parseLabelLine(line)
    if index and label then
      VideoHub.OutputLabels[index] = label
      VideoHubChangeEvents.OutputLabels:Trigger()
    end
  end,
  Crosspoints = function(line)
    local outputIndex, inputIndex = Parser.parseRoutingLine(line)
    if outputIndex and inputIndex then
      VideoHub.Crosspoints[outputIndex] = inputIndex
      VideoHubChangeEvents.Crosspoints:Trigger()
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
  if AllowRXDebugPrint then
    DebugPrint("RX: "..rxData)
  end

  for line in TelnetRXBuffer:gmatch("([^\r\n]+)") do
    if Parser.lineStartsWith(line, "END PRELUDE:") then
      DebugPrint("End of prelude detected")
      local prevValue = VideoHubState.preludeParsed
      VideoHubState.preludeParsed = true
      VideoHubState.currentSection = nil
      TelnetRXBuffer = ""
      if not prevValue then
        VideoHubChangeEvents.PreludeParsed:Trigger()
      end
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
      DebugPrint("No ACK/NAK received for Ping command, assuming disconnection")
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
    if not VideoHubState:IsReady() then
      DebugPrint("WARNING: Cannot send command, prelude not parsed yet.  Command: "..cmdName)
      return
    end
    VideoHubState.lastCommandSent = cmdName
    TelnetInstance:Send(cmd)
    DebugPrint("TX: "..cmd)
  else
    DebugPrint("Telnet not connected, cannot send command")
  end
end

TelnetInstance.Events.Disconnected:RegisterCallback(function()
  if PingTimer:IsRunning() then
    PingTimer:Stop()
  end
  Controls.TelnetActive.Boolean = false
  VideoHubState:reset()
  VideoHubChangeEvents:reset()
  TelnetRXBuffer = ""
end)

TelnetInstance.Events.Connected:RegisterCallback(function()
  Controls.TelnetActive.Boolean = true
end)

TelnetInstance.Events.BeforeConnect:RegisterCallback(function()
  VideoHubState:reset()
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


VideoHubChangeEvents.PreludeParsed:RegisterCallback(function()
  if VideoHubState:IsReady() then
    -- Send a ping immediately after prelude is parsed to ensure we can communicate with the device and to kick off status retrieval
    VideoHub.SendPing()
    if not PingTimer:IsRunning() then
      PingTimer:Start(PingInterval)
    end
  end
end)



function Initialization()  -- function called at start of runtime
  DebugPrint("Initializing plugin")
  TelnetInstance:SetEnabled(Controls.TelnetEnable.Boolean)
  TelnetInstance:SetPort(Controls.Port.String)
  TelnetInstance:SetIP(Controls.IPAddress.String)
end



---@param t Timer
PingTimer.EventHandler = function(t)
  if TelnetInstance:IsConnected() and TelnetInstance:IsEnabled() and VideoHubState:IsReady() then
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
  DebugPrint("Telnet Enable changed to "..tostring(TelnetInstance:IsEnabled()))
end

VideoHubChangeEvents.Preamble:RegisterCallback(function()
  Controls.DeviceProtocolVersion.String = VideoHub.Preamble.ProtocolVersion or ""
end)

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
    for j, buttonControl in ipairs(RouteMatrixButtons[i]) do
      buttonControl.Boolean = (inputIndex == j)
    end
  end
end)

---@type TextControllerControls[]
InputLabelControls = {}

---@type TextControllerControls[]
OutputLabelControls = {}


---@type TextControllerControls[]
CrosspointControls = {}

---@type TextControllerControls[][]
RouteMatrixButtons = {}

for i = 1, MaxInputCount do
  InputLabelControls[i] = Controls.InputLabels[i]
end

for i = 1, MaxOutputCount do
  OutputLabelControls[i] = Controls.OutputLabels[i]
  CrosspointControls[i] = Controls.Crosspoints[i]
end

function GatherRouteMatrixButtons()
  local btnIndex = 1
  for outputIndex = 1, MaxOutputCount do
    RouteMatrixButtons[outputIndex] = {}
    for inputIndex = 1, MaxInputCount do
      local btnControl = Controls.RouteMatrixButtons[btnIndex]
      RouteMatrixButtons[outputIndex][inputIndex] = btnControl
      btnIndex = btnIndex + 1
    end
  end
end
GatherRouteMatrixButtons()


function SetupRouteMatrixButtonHandlers()
  for outputIndex, inputControls in ipairs(RouteMatrixButtons) do
    for inputIndex, buttonControl in ipairs(inputControls) do
      ---@ param ctl TextControllerControls
      buttonControl.EventHandler = function(ctl)
        if VideoHub.Device.OutputCount < outputIndex or VideoHub.Device.InputCount < inputIndex then
          return
        end
        if ControlsLockedOut() then
          local prevValue = not ctl.Boolean
          Timer.CallAfter(function() ctl.Boolean = prevValue end, 0.1)
          return
        end
        VideoHub.SetCrosspoint(outputIndex, inputIndex)
      end
    end
  end
end
SetupRouteMatrixButtonHandlers()


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
    DebugPrint("Input "..i.." label changed to "..label..", current is "..VideoHub.InputLabels[i])
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
    DebugPrint("Output "..i.." label changed to "..label..", current is "..VideoHub.OutputLabels[i])
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
    DebugPrint("Output "..i.." changed to input "..inputIndex..", current is "..VideoHub.Crosspoints[i])
    if VideoHub.Crosspoints[i] == inputIndex then
      return
    end
    VideoHub.SetCrosspoint(i, inputIndex)
  end
end

-- Start at runtime
Initialization()  -- calls the Initialization function at the start of runtime
