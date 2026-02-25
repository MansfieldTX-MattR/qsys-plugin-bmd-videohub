

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
      Name = "NumInputs",
      ControlType = "Knob",
      ControlUnit = "Integer",
      Min = 1,
      Max = props["Max Input Count"].Value,
      PinStyle = "Output",
      UserPin = true,
    },
    {
      Name = "NumOutputs",
      ControlType = "Knob",
      ControlUnit = "Integer",
      Min = 1,
      Max = props["Max Output Count"].Value,
      PinStyle = "Output",
      UserPin = true,
    },
    -- {
    --   Name = "InputLabels",
    --   ControlType = "Text",

    -- }
  }

  ---@type DesignControlKnob[]
  local crosspointControls = {}

  ---@type DesignControlText[]
  local inputLabels = {}

  ---@type DesignControlText[]
  local outputLabels = {}

  local inputCount = props["Max Input Count"].Value or 12
  local outputCount = props["Max Output Count"].Value or 12

  for i = 1, inputCount do
    ---@type DesignControlText
    local inputLabelControl = {
      Name = "InputLabel_" .. i,
      ControlType = "Text",
      PinStyle = "Both",
      UserPin = true,
    }
    table.insert(inputLabels, inputLabelControl)

    ---@type DesignControlText
    local outputLabelControl = {
      Name = "OutputLabel_" .. i,
      ControlType = "Text",
      PinStyle = "Both",
      UserPin = true,
    }
    table.insert(outputLabels, outputLabelControl)

    ---@type DesignControlKnob
    local crosspointControl = {
      Name = "Crosspoint_" .. i,
      ControlType = "Knob",
      ControlUnit = "Integer",
      Min = 1,
      Max = outputCount,
      PinStyle = "Both",
      UserPin = true,
    }
    table.insert(crosspointControls, crosspointControl)
  end
  function MergeTables(t1, t2)
    for _, v in ipairs(t2) do
      table.insert(t1, v)
    end
    return t1
  end
  controls = MergeTables(controls, inputLabels)
  controls = MergeTables(controls, outputLabels)
  controls = MergeTables(controls, crosspointControls)

  -- -@class Controls
  -- -@field Status TextControllerControls
  -- -@field IPAddress TextControllerControls
  -- -@field Port TextControllerControls
  -- -@field TelnetActive TextControllerControls

  return controls
end
