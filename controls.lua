

---@param props Properties
---@return DesignControl[]
function GetControls(props)

  -- ---@type DesignControlStatusIndicator
  -- local statusControl = {
  --   Name = "Status",
  --   ControlType = "Indicator",
  --   IndicatorType = "Status",
  --   PinStyle = "Output",
  --   UserPin = true,
  --   Count = 1,
  -- }
  -- ---@type DesignControl[]
  -- local controls = {
  --   statusControl,
  -- }

  local inputCount = props["Max Input Count"].Value or 12
  local outputCount = props["Max Output Count"].Value or 12

  ---@type DesignControl[]
  local controls = {
    {
      Name = "Status",
      ControlType = "Indicator",
      IndicatorType = "Status",
      PinStyle = "Output",
      UserPin = true,
      Count = 1,
    },
    {
      Name = "IPAddress",
      ControlType = "Text",
      PinStyle = "Input",
      UserPin = true,
    },
    {
      Name = "Port",
      ControlType = "Text",
      DefaultValue = "9990",
      PinStyle = "Input",
      UserPin = true,
    },
    {
      Name = "TelnetEnable",
      ControlType = "Button",
      ButtonType = "Toggle",
      DefaultValue = true,
      PinStyle = "Input",
      UserPin = true,
    },
    {
      Name = "TelnetActive",
      ControlType = "Indicator",
      IndicatorType = "Led",
      PinStyle = "Output",
      UserPin = true,
      Count = 1,
    },
    {
      Name = "ControlLockout",
      ControlType = "Button",
      ButtonType = "Toggle",
      DefaultValue = false,
      PinStyle = "Input",
      UserPin = true,
    },
    {
      Name = "DeviceModel",
      ControlType = "Text",
      PinStyle = "Output",
      UserPin = true,
    },
    {
      Name = "DeviceName",
      ControlType = "Text",
      PinStyle = "Output",
      UserPin = true,
    },
    {
      Name = "DeviceId",
      ControlType = "Text",
      PinStyle = "Output",
      UserPin = true,
    },
    {
      Name = "DeviceProtocolVersion",
      ControlType = "Text",
      PinStyle = "Output",
      UserPin = true,
    },
    {
      Name = "NumInputs",
      ControlType = "Knob",
      ControlUnit = "Integer",
      Min = 1,
      Max = inputCount,
      PinStyle = "Output",
      UserPin = true,
    },
    {
      Name = "NumOutputs",
      ControlType = "Knob",
      ControlUnit = "Integer",
      Min = 1,
      Max = outputCount,
      PinStyle = "Output",
      UserPin = true,
    },
    {
      Name = "InputLabels",
      ControlType = "Text",
      PinStyle = "Both",
      UserPin = true,
      Count = inputCount,
    },
    {
      Name = "OutputLabels",
      ControlType = "Text",
      PinStyle = "Both",
      UserPin = true,
      Count = outputCount,
    },
    {
      Name = "Crosspoints",
      ControlType = "Knob",
      ControlUnit = "Integer",
      Min = 1,
      Max = inputCount,
      PinStyle = "Both",
      UserPin = true,
      Count = outputCount,
    }
  }

  -- -@class Controls
  -- -@field Status TextControllerControls
  -- -@field IPAddress TextControllerControls
  -- -@field Port TextControllerControls
  -- -@field TelnetActive TextControllerControls

  return controls
end
