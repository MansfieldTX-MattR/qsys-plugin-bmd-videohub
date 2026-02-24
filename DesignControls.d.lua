---@meta

---@alias ControlTypeName
---| "Button"
---| "Knob"
---| "Indicator"
---| "Text"


---@alias PinStyleName
---| "Input"
---| "Output"
---| "Both"
---| "None"


---@alias ButtonTypeName
---| "Toggle"
---| "Momentary"
---| "Trigger"
---| "StateTrigger"
---| "On"
---| "Off"
---| "Custom"


---@alias IconTypeName
---| "SVG"
---| "Image"
---| "Icon"


---@alias ControlUnitName
---| "dB"
---| "Hz"
---| "Float"
---| "Integer"
---| "Pan"
---| "Percent"
---| "Position"
---| "Seconds"


---@alias IndicatorTypeName
---| "Led"
---| "Meter"
---| "Text"
---| "Status"



---@class DesignControlBase<T>
---@field Name string
---@field ControlType ControlTypeName
---@field DefaultValue? T
---@field UserPin? boolean
---@field PinStyle? PinStyleName
---@field Count? integer


---@class DesignControlButton : DesignControlBase<boolean>
---@field ControlType "Button"
---@field ButtonType? ButtonTypeName
---@field Icon? string
---@field IconType? IconTypeName
---@field Min? number
---@field Max? number


---@class DesignControlKnob : DesignControlBase<number>
---@field ControlType "Knob"
---@field ControlUnit ControlUnitName
---@field Min? number
---@field Max? number


-- -@class DesignControlIndicator<T> : DesignControlBase<T>
-- -@field IndicatorType IndicatorTypeName

---@class DesignControlLedIndicator : DesignControlBase<boolean>
---@field ControlType "Indicator"
---@field IndicatorType "Led"


---@class DesignControlMeterIndicator : DesignControlBase<number>
---@field ControlType "Indicator"
---@field IndicatorType "Meter"

---@class DesignControlTextIndicator : DesignControlBase<string>
---@field ControlType "Indicator"
---@field IndicatorType "Text"

---@class DesignControlStatusIndicator : DesignControlBase<string>
---@field ControlType "Indicator"
---@field IndicatorType "Status"

---@class DesignControlText : DesignControlBase<string>
---@field ControlType "Text"


---@alias DesignControl
---| DesignControlButton
---| DesignControlKnob
---| DesignControlLedIndicator
---| DesignControlMeterIndicator
---| DesignControlTextIndicator
---| DesignControlStatusIndicator
---| DesignControlText
