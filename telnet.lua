---@class TelnetState
--- A class representing the state of the telnet client, including whether it is enabled, active, and its current status.
---@field Enabled boolean Whether the telnet client is enabled (should attempt to connect when IP/port are set)
---@field Active boolean Whether the telnet client is currently connected and active (has completed setup)
---@field IsSetup boolean Whether the telnet setup sequence has been completed (used to track if we need to respond to setup commands)
---@field Status StatusType The current status of the telnet client
---@field IP string The configured IP address for the telnet connection
---@field Port integer The configured port number for the telnet connection
TelnetState = {}
function TelnetState:new()
  local o = {
    Enabled = false,
    Active = false,
    IsSetup = false,
    Status = StatusType.NotPresent,
    IP = "",
    Port = -1,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


---@class TelnetClientEvents
--- A class representing the various events that a TelnetClient can trigger.
--- Each event is an instance of the Event class and can be subscribed to with callback functions.
---@field BeforeConnect Event Triggered before attempting to connect
---@field AfterConnect Event Triggered after attempting to connect (regardless of success)
---@field Connected Event Triggered when a connection is successfully established (after setup)
---@field SocketError Event Triggered when a socket error occurs
---@field Disconnected Event Triggered when the connection is closed
---@field DataReceived Event Triggered when data is received
---@field StatusChanged Event Triggered when the status changes
TelnetClientEvents = {}

---@return TelnetClientEvents
function TelnetClientEvents:new()
  local o = {
    BeforeConnect = Event:new(),
    AfterConnect = Event:new(),
    Connected = Event:new(),
    SocketError = Event:new(),
    Disconnected = Event:new(),
    DataReceived = Event:new(),
    StatusChanged = Event:new(),
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


---@class TelnetClient
--- A class representing a telnet client that can connect to a server, send and receive data, and manage its connection state.
--- The TelnetClient class encapsulates all functionality related to managing a telnet connection,
--- including connecting, disconnecting, sending data, and handling incoming data.
--- It also provides events that can be subscribed to for reacting to connection and data events.
---@field private Socket TcpSocketInstance The underlying TCP socket used for communication
---@field State TelnetState The current state of the telnet client
---@field IsSetup boolean Whether the telnet setup sequence has been completed
---@field RXData? string The most recently received data from the socket
---@field EOLChar string The end-of-line character(s) to use for sending commands
---@field IACChar integer The byte value representing the Telnet IAC (Interpret As Command) character
---@field TelSetResp table[] A table of telnet setup response commands to send during setup
---@field Events TelnetClientEvents Events that can be subscribed to for connection and data events
---@field DataHandler? fun(data: string) An optional callback function that is called with incoming data as an argument
TelnetClient = {}

---@return TelnetClient
function TelnetClient:new()
  local o = {
    Socket = TcpSocket.New(),
    State = TelnetState:new(),
    RXData = nil,
    EOLChar = "\n",
    IACChar = 0xFF,
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
    },
    Events = TelnetClientEvents:new(),
    DataHandler = nil,
  }
  o.Socket.Connected = function()
    o.Events.Connected:Set()
    print("Socket Connected")
  end
  o.Socket.Reconnect = function()
    print("Socket Reconnect Triggered")
  end
  o.Socket.Error = function()
    o:resetInternalState()
    o.Events.SocketError:Set()
    print("Socket Error")
  end
  o.Socket.Timeout = function()
    print("Socket Timeout")
  end
  o.Socket.Data = function()
    o:HandleIncomingData()
  end
  setmetatable(o, self)
  self.__index = self
  return o
end


---@private
function TelnetClient:resetInternalState()
  -- self.State.Active = false
  self.State.IsSetup = false
  -- self:SetStatus(StatusType.NotPresent)
  self.RXData = nil
end


--- Sets the end-of-line character(s) to use when sending commands. Default is "\n".
---@param eol string
function TelnetClient:SetEOLChar(eol)
  self.EOLChar = eol
end


--- Sets the DataHandler callback function
---@param handler fun(data: string)
function TelnetClient:SetDataHandler(handler)
  self.DataHandler = handler
end


--- Set the current status of the telnet client and trigger the StatusChanged event if it has changed
---@param newStatus StatusType
function TelnetClient:SetStatus(newStatus)
  if self.State.Status ~= newStatus then
    self.State.Status = newStatus
    self.Events.StatusChanged:Trigger()
  end
end

---@param ip string
---@return boolean, string
function TelnetClient:ValidateIP(ip)
  if ip == nil or ip == "" then
    return false, ""
  end
  return true, ip
end

---@param portStrOrInt string|integer|nil
---@return boolean, integer
function TelnetClient:ValidatePort(portStrOrInt)
  local port = tonumber(portStrOrInt)
  if port == nil then
    return false, -1
  end
  if port < 1 or port > 65535 then
    return false, -1
  end
  return true, port
end

--- Validates the given IP address and port number.
--- Returns a boolean indicating validity, the valid IP, and the valid port (or -1 if invalid).
---@param ip string
---@param portStrOrIntOrNil string|integer|nil
---@return boolean, string, integer
function TelnetClient:ValidateIPAndPort(ip, portStrOrIntOrNil)
  local validIP, validPort
  local ipValid, ipResult = self:ValidateIP(ip)
  if not ipValid then return false, "", -1 end
  validIP = ipResult

  local portValid, portResult = self:ValidatePort(portStrOrIntOrNil)
  if not portValid then return false, "", -1 end
  validPort = portResult

  return true, validIP, validPort
end


--- Sets the IP address for the telnet client. If the client is currently enabled, it will attempt to connect with the new IP.
--- Returns true if the IP was valid and set successfully, false otherwise.
---@param ip string
---@return boolean
function TelnetClient:SetIP(ip)
  local valid, validIP = self:ValidateIP(ip)
  if not valid then return false end
  self.State.IP = validIP
  if self.State.Enabled then
    self:Connect()
  end
  return true
end

--- Sets the port number for the telnet client. If the client is currently enabled, it will attempt to connect with the new port.
--- Returns true if the port was valid and set successfully, false otherwise.
---@param portStrOrInt string|integer|nil
---@return boolean
function TelnetClient:SetPort(portStrOrInt)
  local valid, validPort = self:ValidatePort(portStrOrInt)
  if not valid then return false end
  self.State.Port = validPort
  if self.State.Enabled then
    self:Connect()
  end
  return true
end


--- Sets the IP address and port for the telnet client.
--- If the client is currently enabled, it will attempt to connect with the new settings.
--- Returns true if the IP and port were valid and set successfully, false otherwise.
---@param ip string
---@param portStrOrIntOrNil string|integer|nil
---@return boolean
function TelnetClient:SetIPAndPort(ip, portStrOrIntOrNil)
  local ipValid = self:SetIP(ip)
  local portValid = self:SetPort(portStrOrIntOrNil)
  return ipValid and portValid
end


--- Get the currently configured IP address
---@return string
function TelnetClient:GetIP()
  return self.State.IP
end


--- Get the currently configured port number
---@return integer
function TelnetClient:GetPort()
  return self.State.Port
end


--- Enable or disable the telnet client.
--- If enabling, it will attempt to connect with the current IP and port settings.
--- If disabling, it will disconnect if currently connected.
---@param enabled boolean
function TelnetClient:SetEnabled(enabled)
  self.State.Enabled = enabled
  if enabled then
    self:Connect()
  else
    self:Disconnect()
  end
end


--- Check if the telnet client is currently enabled
---@return boolean
function TelnetClient:IsEnabled()
  return self.State.Enabled
end


--- Attempt to connect to the configured IP and port.
--- If already connected, it will disconnect first.
--- Returns true if the connection process was initiated (valid IP/port and enabled), false otherwise.
function TelnetClient:Connect()
  if self.Socket.IsConnected then self:Disconnect() end
  self:resetInternalState()

  local valid, ip, port = self:ValidateIPAndPort(self.State.IP, self.State.Port)
  if not valid then return false end
  if not self.State.Enabled then return end
  self:SetStatus(StatusType.Initializing)
  self.Events.BeforeConnect:Trigger()
  self.Socket:Connect(ip, port)
  self.Events.AfterConnect:Trigger()
end


--- Disconnect the telnet client if currently connected, and reset internal state.
--- Triggers the Disconnected event if it was active.
function TelnetClient:Disconnect()
  if self.Socket.IsConnected then
    self.Socket:Disconnect()
  end
  if self.State.Active then
    self.State.Active = false
    self.Events.Disconnected:Trigger()
  end
  if self.State.Enabled then
    self:SetStatus(StatusType.Missing)
  else
    self:SetStatus(StatusType.NotPresent)
  end
  self:resetInternalState()
end


--- Sends data to the telnet server if connected. Prints an error message if not connected.
---@param data string
function TelnetClient:Send(data)
  if self.Socket.IsConnected then
    self.Socket:Write(data)
  else
    print("Cannot send data, socket not connected")
  end
end

function TelnetClient:IsConnected()
  return self.Socket.IsConnected
end

function TelnetClient:IsActive()
  return self.State.Active
end

function TelnetClient:GetStatus()
  return self.State.Status
end

---@private
function TelnetClient:HandleSetup()
  local data={}
  for _,resp in ipairs(self.TelSetResp) do
    table.insert(data,string.pack("BBB",self.IACChar,resp.cmd,resp.opt))
  end
  self.Socket:Write(table.concat(data))
  self.State.IsSetup = true
end

---@private
function TelnetClient:HandleIncomingData()
  local rx = self.Socket:Read(self.Socket.BufferLength)
  self.RXData = rx
  if not self.State.Enabled then return end
  if not self.State.IsSetup then
    self:HandleSetup()
  end
  if not self.State.Active then
    self.State.Active = true
    self:SetStatus(StatusType.OK)
    self.Events.Connected:Trigger()
  end
  if self.DataHandler then
    self.DataHandler(rx)
  end
  self.Events.DataReceived:Trigger()
end
