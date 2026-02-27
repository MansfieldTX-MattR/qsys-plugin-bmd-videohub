

---@param title string
---@param rect Rectangle
---@param VTextAlign? VAlignmentName
---@return LayoutGroupBox
function CreateGroupBox(title, rect, VTextAlign)
  return {
    Type = "GroupBox",
    Position = rect.Position:AsArray(),
    Size = XYPoint:new(rect:Width(), rect:Height()):AsArray(),
    Text = title,
    FontSize = 9,
    HTextAlign = "Left",
    VTextAlign = VTextAlign or "Center",
    ZOrder = -1,
  }
end


---@param rect Rectangle
---@param prettyName? string
---@return LayoutText
function CreateTextInput(rect, prettyName)
  local o = {
    Style = "Text",
    Position = rect.Position:AsArray(),
    Size = rect.Size:AsArray(),
    IsReadOnly = false,
    FontSize = 9,
  }
  if prettyName then
    o.PrettyName = prettyName
  end
  return o
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
---@param prettyName? string
---@return LayoutKnob
function CreateKnob(outerRect, size, prettyName)
  local knobSize = math.min(size:X(), size:Y())
  local knobBox = Rectangle.FromBottomCenter(outerRect:BottomCenter(), XYPoint:new(knobSize, knobSize))
  local o = {
    Style = "Knob",
    Position = knobBox.Position:AsArray(),
    Size = knobBox.Size:AsArray(),
  }
  if prettyName then
    o.PrettyName = prettyName
  end
  return o
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
      -- The `~` in "PrettyName" creates a sub-tree for the pins in the UI
      local prettyName = string.format("InputLabels~%i", i)
      -- Since the control is an array (count>1), the key becomes `<ControlName> <index>`
      layout["InputLabels " .. i] = CreateTextInput(gridRect, prettyName)
    end

    for i = 1, outputCount do
      local gridRect = gridRects[2][i]
      local prettyName = string.format("OutputLabels~%i", i)
      layout["OutputLabels " .. i] = CreateTextInput(gridRect, prettyName)
      local knobRect = gridRects[3][i]
      prettyName = string.format("Crosspoints~%i", i)
      layout["Crosspoints " .. i] = CreateKnob(knobRect, XYPoint:new(knobHeight, knobHeight), prettyName)
      local labelRect = gridRects[4][i]
      local crosspointLabel = CreateLabel(tostring(i), labelRect)
      table.insert(graphics, crosspointLabel)
    end
  elseif CurrentPage == "Route" then
    local inputCount = props["Max Input Count"].Value or 12
    local outputCount = props["Max Output Count"].Value or 12
    local routeTableCellSize = XYPoint:new(36, 16)
    local inputLabelSize = XYPoint:new(64, 16)
    local inputLabelRightPadding = 4
    local outputNumberLabelSize = XYPoint:new(36, 16)
    local outputLabelSize = XYPoint:new(36, 16)
    local upperRowYSpacing = 20

    local outputNumberLabelRowRect = Rectangle:new(
      XYPoint:new(inputLabelSize:X() + inputLabelRightPadding, upperRowYSpacing),
      XYPoint:new(outputNumberLabelSize:X() * outputCount, outputNumberLabelSize:Y())
    )
    local outputNumberLabelCells = outputNumberLabelRowRect:Divide(XYPoint:new(outputCount, 1))
    local outputLabelRowRect = Rectangle:new(
      outputNumberLabelRowRect:BottomLeft() + XYPoint:new(0, upperRowYSpacing),
      outputNumberLabelRowRect.Size
    )
    local outputLabelCells = outputLabelRowRect / (XYPoint:new(outputCount, 1))
    local routeTableRect = Rectangle:new(
      outputLabelRowRect:BottomLeft() + XYPoint:new(0, upperRowYSpacing),
      routeTableCellSize * XYPoint:new(outputCount, inputCount)
    )
    local routeTableCells = routeTableRect / (XYPoint:new(outputCount, inputCount))
    local routeTableGroupBoxRect = Rectangle.FromBounds(
      XYPoint:new(inputLabelSize:X() + inputLabelRightPadding, 0),
      routeTableRect:BottomRight() + XYPoint:new(inputLabelRightPadding, inputLabelRightPadding)
    )
    local routeTableGroupBox = CreateGroupBox("Output", routeTableGroupBoxRect, "Top")
    table.insert(graphics, routeTableGroupBox)
    local inputLabelRect = Rectangle:new(
      XYPoint:new(0, routeTableRect:Top()),
      inputLabelSize
    )

    local inputNumberRect = Rectangle:new(
      XYPoint:new(routeTableRect:Right() + inputLabelRightPadding, routeTableRect:Top()),
      routeTableCellSize
    )

    for i = 1, inputCount do
      local prettyName = string.format("InputLabels~%i", i)
      layout["InputLabels " .. i] = CreateTextInput(inputLabelRect, prettyName)
      inputLabelRect = inputLabelRect + XYPoint:new(0, inputLabelRect:Height())
      local numberLabel = CreateLabel(tostring(i), inputNumberRect)
      table.insert(graphics, numberLabel)
      inputNumberRect = inputNumberRect + XYPoint:new(0, inputNumberRect:Height())
    end

    local k = 1
    for i = 1, outputCount do
      local numberLabel = CreateLabel(tostring(i), outputNumberLabelCells[1][i])
      table.insert(graphics, numberLabel)
      local prettyName = string.format("OutputLabels~%i", i)
      layout["OutputLabels " .. i] = CreateTextInput(outputLabelCells[1][i], prettyName)
      for j = 1, inputCount do
        prettyName = string.format("RouteMatrixButtons~Output %i~Input %i", i, j)

        ---@type LayoutButton
        local routeButton = {
          Style = "Button",
          ButtonStyle = "Toggle",
          Position = routeTableCells[j][i].Position:AsArray(),
          Size = routeTableCells[j][i].Size:AsArray(),
          PrettyName = prettyName,
          CornerRadius = 2,
          Margin = 2,
        }
        layout[string.format("RouteMatrixButtons %i", k)] = routeButton
        k = k + 1
      end
    end
  elseif CurrentPage == "Setup" then

    local labelSize = XYPoint:new(96, 16)
    local labelGap = XYPoint:new(4, 4)
    local textFieldSize = XYPoint:new(180, 16)

    local numRows = 11
    local totalHeight = (labelSize:Y() * numRows) + (labelGap:Y() * (numRows - 1))
    local outerRect = Rectangle:new(
      XYPoint:new(0, 0),
      XYPoint:new(
        (labelSize + labelGap + textFieldSize):X(),
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
        XYPoint:new(outerRect:Width() - (labelGap:X() * 2), textFieldSize:Y())
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
      local textFieldRect = Rectangle:new(
        labelRect:TopRight() + XYPoint:new(labelGap:X(), 0),
        textFieldSize
      )
      table.insert(textFieldRects, textFieldRect)
    end

    local labelNames = {
      "IP Address",
      "Port",
      "Telnet Enable",
      "Status",
      "Device Model",
      "Device Name",
      "Device ID",
      "Num Inputs",
      "Num Outputs",
      "Protocol Version",
      "Control Lockout",
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
        HTextAlign = "Left",
        VTextAlign = "Center",
        StrokeColor = {105, 105, 105},
        StrokeWidth = 1,
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

    ---@type { [string]: LayoutText }
    local deviceTexts = {
      DeviceModel = {
        Style = "Text",
        Position = textFieldRects[5].Position:AsArray(),
        Size = textFieldRects[5].Size:AsArray(),
        IsReadOnly = true,
        FontSize = 9,
      },
      DeviceName = {
        Style = "Text",
        Position = textFieldRects[6].Position:AsArray(),
        Size = textFieldRects[6].Size:AsArray(),
        IsReadOnly = true,
        FontSize = 9,
      },
      DeviceId = {
        Style = "Text",
        Position = textFieldRects[7].Position:AsArray(),
        Size = textFieldRects[7].Size:AsArray(),
        IsReadOnly = true,
        FontSize = 9,
      },
      NumInputs = {
        Style = "Text",
        Position = textFieldRects[8].Position:AsArray(),
        Size = textFieldRects[8].Size:AsArray(),
        IsReadOnly = true,
        FontSize = 9,
        Color = {255, 255, 255},
        TextBoxStyle = "Normal",
      },
      NumOutputs = {
        Style = "Text",
        Position = textFieldRects[9].Position:AsArray(),
        Size = textFieldRects[9].Size:AsArray(),
        IsReadOnly = true,
        FontSize = 9,
        Color = {255, 255, 255},
        TextBoxStyle = "Normal",
      },
      ProtocolVersion = {
        Style = "Text",
        Position = textFieldRects[10].Position:AsArray(),
        Size = textFieldRects[10].Size:AsArray(),
        IsReadOnly = true,
        FontSize = 9,
        Color = {255, 255, 255},
        TextBoxStyle = "Normal",
      },
    }

    for key, label in pairs(deviceTexts) do
      layout[key] = label
    end

    ---@type LayoutButton
    local controlLockoutGraphic = {
      Style = "Button",
      ButtonStyle = "Toggle",
      Position = textFieldRects[11].Position:AsArray(),
      IsReadOnly = false,
      Size = textFieldRects[11].Size:AsArray(),
      FontSize = 9,
    }


    layout["IPAddress"] = ipGraphic
    layout["Port"] = portGraphic
    layout["TelnetEnable"] = telnetGraphic
    layout["Status"] = statusGraphic
    layout["ControlLockout"] = controlLockoutGraphic
    layout["DeviceProtocolVersion"] = deviceTexts.ProtocolVersion
    for _, label in ipairs(labels) do
      table.insert(graphics, label)
    end
  end

  return layout, graphics
end
