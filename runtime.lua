

function ControlsLockedOut()
  return Controls.ControlLockout.Boolean
end

---@diagnostic disable-next-line: undefined-global
MaxInputCount = Properties["Max Input Count"].Value or 12
---@diagnostic disable-next-line: undefined-global
MaxOutputCount = Properties["Max Output Count"].Value or 12
---@diagnostic disable-next-line: undefined-global
ShowRoutingControls = Properties["Show Routing Controls"].Value

Controls.TelnetActive.Boolean = false
Controls.Status.Value = StatusType.NotPresent

PingTimer = Timer.New()
PingInterval = 30  -- seconds

CommandQueueTimer = Timer.New()

---@type "Ping" | "GetStatus" | nil
PingLastCommand = nil

EOL = "\n"
TelnetInstance = TelnetClient:new()
TelnetInstance:SetEOLChar(EOL)

TelnetRXBuffer = ""

AllowRXDebugPrint = false



---@alias VideoHubCommand "GetStatus" | "SetInputLabels" | "SetOutputLabels" | "SetVideoOutputRouting" | "Ping" | "BatchCommand"
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


---@alias CommandQueueCommand { cmdName: VideoHubCommandSectionMapKey, cmdArgs: [integer, integer|string][] }


---@type CommandQueueClass<CommandQueueCommand>
CommandQueue = CommandQueueClass:new(CommandQueueTimer, 0.1)
CommandQueue:setFormatCallback(function(commands)
  return VideoHub.FormatMultipleCommandsWithArgs(commands)
end)
CommandQueue:setSendCallback(function(cmdStr)
  TelnetSendCommand("BatchCommand", cmdStr)
end)



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
    if not CommandQueue:isEmpty() then return end
    local sections = {
      "GetInputLabels",
      "GetOutputLabels",
      "GetVideoOutputRouting",
    }
    for _, section in ipairs(sections) do
      CommandQueue:enqueue({ cmdName = section, cmdArgs = nil })
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
    CommandQueue:enqueue({ cmdName = "SetInputLabels", cmdArgs = labelPairs })
  end,

  ---@param outputIndex number
  ---@param label string
  SetOutputLabel = function (outputIndex, label)
    return VideoHub.SetOutputLabels({{outputIndex, label}})
  end,

  ---@param outputPairs [number, string][]
  SetOutputLabels = function(outputPairs)
    CommandQueue:enqueue({ cmdName = "SetOutputLabels", cmdArgs = outputPairs })
  end,

  ---@param outputIndex number
  ---@param inputIndex number
  SetCrosspoint = function (outputIndex, inputIndex)
    return VideoHub.SetCrosspoints({{outputIndex, inputIndex}})
  end,

  ---@param routingPairs [number, number][]
  SetCrosspoints = function(routingPairs)
    CommandQueue:enqueue({ cmdName = "SetVideoOutputRouting", cmdArgs = routingPairs })
  end,

  ---@param key number|string
  ---@param value number|string
  ---@return string
  ---@return string
  FormatCommandPair = function(key, value)
    local function FormatNumber(v)
      if type(v) == "string" then return v end
      return string.format("%d", v - 1)
    end
    return FormatNumber(key), FormatNumber(value)
  end,

  --- Helper function to format command pairs into lines of "key value" for the given command sections
  ---@param pairs [number|string, number|string][]
  ---@return string[]
  FormatCommandPairs = function(pairs)
    local lines = {}
    for _, pair in ipairs(pairs) do
      local key, value = VideoHub.FormatCommandPair(pair[1], pair[2])
      table.insert(lines, key.." "..value)
    end
    return lines
  end,

  --- Helper function to format a command with arguments, using the appropriate section header and newlines
  ---@param cmdName VideoHubCommandSectionMapKey
  ---@param args [number|string, number|string][] # array of key value pairs, where key and value are either numbers or strings.  Numbers will be formatted as 0-based indices, strings will be used as-is
  ---@param noFinalNewline? boolean # if true, only add a single newline at the end instead of two, allowing multiple commands to be concatenated together
  ---@return string
  FormatCommandWithArgs = function(cmdName, args, noFinalNewline)
    local argLines = {}
    if args then
      argLines = VideoHub.FormatCommandPairs(args)
    else
      table.insert(argLines, "")
    end
    return VideoHub.FormatCommand(cmdName, argLines, noFinalNewline)
  end,

  --- Helper function to format multiple commands with arguments, concatenating them together with appropriate section headers and newlines
  ---@param cmds CommandQueueCommand[] # array of commands with their arguments
  ---@param noFinalNewline? boolean # if true, only add a single newline at the end instead of two, allowing multiple command batches to be concatenated together
  ---@return string
  FormatMultipleCommandsWithArgs = function(cmds, noFinalNewline)

    ---@type { [VideoHubCommandSectionMapKey]: table<string, string> }
    local commandsBySection = {}
    ---@type VideoHubCommandSectionMapKey[]
    local commandsWithoutArgs = {}
    for _, cmd in ipairs(cmds) do
      if not commandsBySection[cmd.cmdName] then
        commandsBySection[cmd.cmdName] = {}
      end
      if cmd.cmdArgs ~= nil and #cmd.cmdArgs > 0 then
        -- ensure unique keys per command (taking the last value if duplicates are found)
        for _, pair in ipairs(cmd.cmdArgs) do
          local key, value = VideoHub.FormatCommandPair(pair[1], pair[2])
          commandsBySection[cmd.cmdName][key] = value
        end
      else
        table.insert(commandsWithoutArgs, cmd.cmdName)
      end
    end
    -- remove any empty items in `commandsBySection` that are in `commandsWithoutArgs`
    for _, cmdName in ipairs(commandsWithoutArgs) do
      if commandsBySection[cmdName] and next(commandsBySection[cmdName]) == nil then
        commandsBySection[cmdName] = nil
      end
    end
    -- remove any commands in `commandsWithoutArgs` that have args in `commandsBySection`
    local finalCommandsWithoutArgs = {}
    for _, cmdName in ipairs(commandsWithoutArgs) do
      if not commandsBySection[cmdName] then
        table.insert(finalCommandsWithoutArgs, cmdName)
      end
    end

    -- now format the commands with their args into the final command strings
    local lines = {}
    for cmdName, cmdArgs in pairs(commandsBySection) do
      ---@type [string, string][]
      local cmdArgsList = {}
      for key, value in pairs(cmdArgs) do
        table.insert(cmdArgsList, {key, value})
      end
      local cmdLines = VideoHub.FormatCommandWithArgs(cmdName, cmdArgsList, true)
      table.insert(lines, cmdLines)
    end
    for _, cmdName in ipairs(finalCommandsWithoutArgs) do
      local cmdLines = VideoHub.FormatCommandWithArgs(cmdName, {}, false)
      table.insert(lines, cmdLines)
    end
    local fullCmd = table.concat(lines, "")
    if noFinalNewline then
      fullCmd = fullCmd .. "\n"
    else
      fullCmd = fullCmd .. "\n\n"
    end
    return fullCmd
  end,

  --- Helper function to format a command given a section and lines, adding the appropriate header and newlines
  ---@param section VideoHubCommandSectionMapKey
  ---@param lines string[]
  ---@param noFinalNewline? boolean # if true, only add a single newline at the end instead of two, allowing multiple commands to be concatenated together
  ---@return string
  FormatCommand = function(section, lines, noFinalNewline)
    local sectionHeader = VideoHubCommandSectionMap[section]
    local txLines = {sectionHeader}
    for _, line in ipairs(lines) do
      table.insert(txLines, line)
    end
    local cmd = table.concat(txLines, "\n")
    if noFinalNewline then
      cmd = cmd .. "\n"
    else
      cmd = cmd .. "\n\n"
    end
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
  CommandQueue:setEnabled(false)
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
    CommandQueue:setEnabled(true)
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
  for i, label in ipairs(VideoHub.InputLabels) do
    if i > MaxInputCount then
      DebugPrint("Warning: received input label for index "..i.." but no corresponding control exists")
      goto continue
    end
    InputLabelControls[i].String = label
    ::continue::
  end
end)

VideoHubChangeEvents.OutputLabels:RegisterCallback(function()
  for i, label in ipairs(VideoHub.OutputLabels) do
    if i > MaxOutputCount then
      DebugPrint("Warning: received output label for index "..i.." but no corresponding control exists")
      goto continue
    end
    OutputLabelControls[i].String = label
    ::continue::
  end
end)

VideoHubChangeEvents.Crosspoints:RegisterCallback(function()
  for i, inputIndex in ipairs(VideoHub.Crosspoints) do
    if i > MaxOutputCount then
      DebugPrint("Warning: received crosspoint for output index "..i.." but no corresponding control exists")
      goto continue
    end
    CrosspointControls[i].Value = inputIndex
    if ShowRoutingControls then
      for j, buttonControl in ipairs(RouteMatrixButtons[i]) do
        if j > MaxInputCount then
          DebugPrint("Warning: received crosspoint for output index "..i.." input index "..j.." but no corresponding button control exists")
        else
          buttonControl.Boolean = (inputIndex == j)
        end
      end
    end
    ::continue::
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
if ShowRoutingControls then
  GatherRouteMatrixButtons()
end


function SetupRouteMatrixButtonHandlers()
  for outputIndex, inputControls in ipairs(RouteMatrixButtons) do
    if outputIndex > MaxOutputCount then
      DebugPrint("Warning: More output button controls than MaxOutputCount, skipping handlers for output index "..outputIndex)
      goto continueOutput
    end
    for inputIndex, buttonControl in ipairs(inputControls) do
      if inputIndex > MaxInputCount then
        DebugPrint("Warning: More input button controls than MaxInputCount, skipping handlers for input index "..inputIndex.." on output index "..outputIndex)
        goto continueInput
      end
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
      ::continueInput::
    end
    ::continueOutput::
  end
end
if ShowRoutingControls then
  SetupRouteMatrixButtonHandlers()
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
