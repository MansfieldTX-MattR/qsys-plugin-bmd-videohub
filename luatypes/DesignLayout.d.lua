---@meta


---@alias Point integer[]
---@alias ColorRGB integer[]
---@alias ColorRGBA integer[]
---@alias Color ColorRGB|ColorRGBA

---@alias ControlStyleName
---| "Fader"
---| "Knob"
---| "Button"
---| "Text"
---| "Meter"
---| "Led"
---| "ListBox"
---| "ComboBox"
---| "None"

---@alias HAlignmentName
---| "Left"
---| "Center"
---| "Right"

---@alias VAlignmentName
---| "Top"
---| "Center"
---| "Bottom"

---@alias ButtonStyleName
---| "Toggle"
---| "Momentary"
---| "Trigger"
---| "StateTrigger"
---| "On"
---| "Off"
---| "Custom"

---@alias ButtonVisualStyleName
---| "Flat"
---| "Gloss"

---@alias MeterStyleName
---| "Level"
---| "Reduction"
---| "Gain"
---| "Standard"

---@alias TextBoxStyleName
---| "Normal"
---| "Meter"
---| "NoBackground"

---@alias GraphicsTableTypeName
---| "Label"
---| "GroupBox"
---| "Header"
---| "Image"
---| "Svg"


---@class LayoutBase
---@field Position Point
---@field Size Point
---@field Style ControlStyleName
---@field ClassName? string
---@field Color? Color
---@field Font? string
---@field FontSize? integer
---@field FontStyle? string
---@field HTextAlign? HAlignmentName
---@field IsReadOnly? boolean
---@field Margin? integer
---@field Padding? integer
---@field PrettyName? string
---@field Radius? integer
---@field StrokeColor? Color
---@field StrokeWidth? integer
---@field VTextAlign? VAlignmentName
---@field ZOrder? integer


---@class LayoutHiddenItem : LayoutBase
---@field Style "None"


---@class LayoutButton : LayoutBase
---@field Style "Button"
---@field ButtonStyle ButtonStyleName
---@field ButtonVisualStyle? ButtonVisualStyleName
---@field CornerRadius? integer
---@field CustomButtonUp? string
---@field CustomButtonDown? string
---@field Legend? string
---@field OffColor? Color
---@field UnlinkOffColor? Color
---@field WordWrap? boolean


---@class LayoutFader : LayoutBase
---@field Style "Fader"
---@field ShowTextBox? boolean


---@class LayoutMeter : LayoutBase
---@field Style "Meter"
---@field BackgroundColor? Color
---@field MeterStyle? MeterStyleName
---@field ShowTextBox? boolean


---@class LayoutKnob : LayoutBase
---@field Style "Knob"



---@class LayoutText : LayoutBase
---@field Style "Text"
---@field CornerRadius? integer
---@field TextBoxStyle? TextBoxStyleName
---@field WordWrap? boolean



---@class LayoutGraphicsTable
---@field Position Point
---@field Size Point
---@field Type GraphicsTableTypeName
---@field ZOrder? integer


---@class LayoutGroupBox : LayoutGraphicsTable
---@field Type "GroupBox"
---@field CornerRadius? integer
---@field Radius? integer
---@field Text? string
---@field Font? string
---@field FontSize? integer
---@field FontStyle? string
---@field HTextAlign? HAlignmentName
---@field StrokeWidth? integer
---@field StrokeColor? Color|string
---@field Color? Color
---@field Fill? Color


---@class LayoutHeader : LayoutGraphicsTable
---@field Type "Header"
---@field Text? string
---@field Font? string
---@field FontSize? integer
---@field FontStyle? string
---@field HTextAlign? HAlignmentName
---@field Color? Color

---@class LayoutImage : LayoutGraphicsTable
---@field Type "Image"
---@field Image string

---@class LayoutLabel : LayoutGraphicsTable
---@field Type "Label"
---@field Color? Color
---@field CornerRadius? integer
---@field Radius? integer
---@field Margin? integer
---@field Padding? integer
---@field Text? string
---@field Font? string
---@field Fill? Color
---@field FontSize? integer
---@field FontStyle? string
---@field HTextAlign? HAlignmentName
---@field VTextAlign? VAlignmentName
---@field StrokeWidth? integer
---@field StrokeColor? Color|string


---@alias DesignLayoutItem =
---| LayoutHiddenItem
---| LayoutButton
---| LayoutFader
---| LayoutMeter
---| LayoutText
---| LayoutKnob

---@alias DesignGraphicsItem =
---| LayoutGroupBox
---| LayoutHeader
---| LayoutImage
---| LayoutLabel


---@class GetControlLayoutProps
---@field page_index TextControllerControls

---@param props GetControlLayoutProps
---@return table<string, DesignLayoutItem>
---@return DesignGraphicsItem[]
function GetControlLayout(props) end
