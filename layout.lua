

---@param title string
---@param rect Rectangle
---@return LayoutGroupBox
function CreateGroupBox(title, rect)
  return {
    Type = "GroupBox",
    Position = rect.Position:AsArray(),
    Size = XYPoint:new(rect:Width(), rect:Height()):AsArray(),
    Text = title,
    FontSize = 9,
    HTextAlign = "Left",
    VTextAlign = "Center",
    ZOrder = -1,
  }
end


---@param rect Rectangle
---@return LayoutText
function CreateTextInput(rect)
  return {
    Style = "Text",
    Position = rect.Position:AsArray(),
    Size = rect.Size:AsArray(),
    IsReadOnly = false,
    FontSize = 9,
  }
end

---@param text string
---@param rect Rectangle
---@return LayoutLabel
function CreateLabel(text, rect)
  return {
    Type = "Label",
    Text = text,
    Position = rect.Position:AsArray(),
    Size = rect.Size:AsArray(),
    FontSize = 9,
    HTextAlign = "Center",
    VTextAlign = "Center",
  }
end

---@param outerRect Rectangle
---@param size XYPoint
---@return LayoutKnob
function CreateKnob(outerRect, size)
  local knobSize = math.min(size:X(), size:Y())
  local knobBox = Rectangle.FromBottomCenter(outerRect:BottomCenter(), XYPoint:new(knobSize, knobSize))
  return {
    Style = "Knob",
    Position = knobBox.Position:AsArray(),
    Size = knobBox.Size:AsArray(),
  }
end


---@param props Properties
---@return table<string, DesignLayoutItem>
---@return DesignGraphicsItem[]
function GetControlLayout(props)
  ---@type table<string, DesignLayoutItem>
  local layout = {}
  ---@type DesignGraphicsItem[]
  local graphics = {}

  local CurrentPage = PageNames[props["page_index"].Value]
  if CurrentPage == "Control" then
    local inputCount = props["Max Input Count"].Value
    local outputCount = props["Max Output Count"].Value
    local columnWidth = 64
    local columnGap = 4
    local textFieldHeight = 16
    local knobHeight = 32
    local groupBoxPadding = XYPoint:new(4, 20)
    local yGap = 4
    local outerRect = Rectangle:new(
      XYPoint:new(0, 0),
      XYPoint:new(
        (columnWidth * inputCount) + (columnGap * (inputCount - 1)) + (groupBoxPadding:X() * 2),
        ((textFieldHeight + yGap) * 3) + (groupBoxPadding:Y() * 2)
      )
    )
    local textFieldRowOuterSize = XYPoint:new(outerRect:Width(), textFieldHeight + groupBoxPadding:Y())
    local inputLabelGroupBoxRect = Rectangle:new(outerRect.Position, textFieldRowOuterSize)
    local outputLabelGroupBoxRect = inputLabelGroupBoxRect + inputLabelGroupBoxRect:BottomLeft() + XYPoint:new(0, yGap)
    local crosspointGroupBoxRect = Rectangle:new(
      outputLabelGroupBoxRect:BottomLeft() + XYPoint:new(0, yGap),
      XYPoint:new(outerRect:Width(), knobHeight + groupBoxPadding:Y())
    )
    local bottomLabelRowRect = Rectangle:new(
      crosspointGroupBoxRect:BottomLeft() + XYPoint:new(0, yGap),
      textFieldRowOuterSize
    )

    local groupBoxRects = {
      inputLabelGroupBoxRect,
      outputLabelGroupBoxRect,
      crosspointGroupBoxRect,
      bottomLabelRowRect,
    }

    ---@type Rectangle[]
    local groupBoxInnerRects = {}
    for i, groupBoxRect in ipairs(groupBoxRects) do
      local innerHeight = i == 3 and knobHeight or textFieldHeight
      local innerRect = Rectangle.FromCenter(
        groupBoxRect:Center(),
        XYPoint:new(groupBoxRect:Width() - (groupBoxPadding:X() * 2), innerHeight)
      )
      table.insert(groupBoxInnerRects, innerRect)
    end

    ---@type Rectangle[][]
    local gridRects = {}
    for i, innerRect in ipairs(groupBoxInnerRects) do
      local numCols = (i == 1) and inputCount or outputCount
      local cellRows = innerRect:Divide(XYPoint:new(numCols, 1))
      table.insert(gridRects, cellRows[1])
    end

    local GroupBoxes = {
      CreateGroupBox("Input Labels", groupBoxRects[1]),
      CreateGroupBox("Output Labels", groupBoxRects[2]),
      CreateGroupBox("Crosspoint Controls", groupBoxRects[3]),
      CreateGroupBox("Labels", groupBoxRects[4]),
    }

    for _, groupBox in ipairs(GroupBoxes) do
      table.insert(graphics, groupBox)
    end

    for i = 1, inputCount do
      local gridRect = gridRects[1][i]
      layout["InputLabel_" .. i] = CreateTextInput(gridRect)
    end

    for i = 1, outputCount do
      local gridRect = gridRects[2][i]
      layout["OutputLabel_" .. i] = CreateTextInput(gridRect)
      local knobRect = gridRects[3][i]
      layout["Crosspoint_" .. i] = CreateKnob(knobRect, XYPoint:new(knobHeight, knobHeight))
      local labelRect = gridRects[4][i]
      local crosspointLabel = CreateLabel(tostring(i), labelRect)
      table.insert(graphics, crosspointLabel)
    end
  elseif CurrentPage == "Setup" then

    local labelSize = XYPoint:new(64, 16)
    local labelGap = XYPoint:new(4, 4)
    local textFieldSize = XYPoint:new(96, 16)

    local numRows = 4
    local totalHeight = (labelSize:Y() * numRows) + (labelGap:Y() * (numRows - 1))
    local outerRect = Rectangle:new(
      XYPoint:new(0, 0),
      XYPoint:new(
        labelSize:X() + labelGap:X() + textFieldSize:X(),
        totalHeight
      )
    )
    local rowOuterRectGrid = outerRect:Divide(XYPoint:new(1, numRows))

    ---@type Rectangle[]
    local rowOuterRects = {}
    for i = 1, numRows do
      table.insert(rowOuterRects, rowOuterRectGrid[i][1])
    end

    ---@type Rectangle[]
    local rowInnerRects = {}
    for i, rowOuterRect in ipairs(rowOuterRects) do
      local innerRect = Rectangle.FromCenter(
        rowOuterRect:Center(),
        XYPoint:new(outerRect:Width() - labelGap:X(), rowOuterRect:Height())
      )
      table.insert(rowInnerRects, innerRect)
    end
    local labelRects = {}
    local textFieldRects = {}
    for i, rowInnerRect in ipairs(rowInnerRects) do
      local labelRect = Rectangle:new(
        rowInnerRect.Position,
        XYPoint:new(labelSize:X(), rowInnerRect:Height())
      )
      table.insert(labelRects, labelRect)
      local textFieldRect = labelRect + XYPoint:new(labelSize:X() + labelGap:X(), 0)
      table.insert(textFieldRects, textFieldRect)
    end

    local labelNames = {
      "IP Address",
      "Port",
      "Telnet Enable",
      "Status",
    }

    ---@type LayoutLabel[]
    local labels = {}
    for i, labelText in ipairs(labelNames) do
      ---@type LayoutLabel
      local label = {
        Type = "Label",
        Text = labelText,
        Position = labelRects[i].Position:AsArray(),
        Size = labelRects[i].Size:AsArray(),
        FontSize = 9,
        HTextAlign = "Center",
        VTextAlign = "Center",
      }
      table.insert(labels, label)
    end

    ---@type LayoutText
    local ipGraphic = {
      Style = "Text",
      Position = textFieldRects[1].Position:AsArray(),
      Size = textFieldRects[1].Size:AsArray(),
      IsReadOnly = false,
      FontSize = 9,
    }

    ---@type LayoutText
    local portGraphic = {
      Style = "Text",
      Position = textFieldRects[2].Position:AsArray(),
      Size = textFieldRects[2].Size:AsArray(),
      IsReadOnly = false,
      FontSize = 9,
    }

    ---@type LayoutButton
    local telnetGraphic = {
      Style = "Button",
      ButtonStyle = "Toggle",
      Position = textFieldRects[3].Position:AsArray(),
      IsReadOnly = false,
      Size = textFieldRects[3].Size:AsArray(),
      FontSize = 9,
    }

    ---@type LayoutText
    local statusGraphic = {
      Style = "Text",
      Position = textFieldRects[4].Position:AsArray(),
      Size = textFieldRects[4].Size:AsArray(),
      IsReadOnly = true,
      FontSize = 9,
    }

    layout["IPAddress"] = ipGraphic
    layout["Port"] = portGraphic
    layout["TelnetEnable"] = telnetGraphic
    layout["Status"] = statusGraphic
    for _, label in ipairs(labels) do
      table.insert(graphics, label)
    end
  end

  return layout, graphics
end
