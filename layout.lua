

---@param title string
---@param rect Rectangle
---@param VTextAlign? VAlignmentName
---@param options? LayoutGraphicsOptions
---@return LayoutGroupBox
function CreateGroupBox(title, rect, VTextAlign, options)
  options = options or {}
  local o = {
    Type = "GroupBox",
    Position = rect.Position:AsArray(),
    Size = XYPoint:new(rect:Width(), rect:Height()):AsArray(),
    Text = title,
    FontSize = 9,
    HTextAlign = "Left",
    VTextAlign = VTextAlign or "Center",
  }
  for k, v in pairs(options) do
    o[k] = v
  end
  return o
end


---@param rect Rectangle
---@param prettyName? string
---@param options? LayoutItemOptions
---@return LayoutText
function CreateTextInput(rect, prettyName, options)
  options = options or {}
  local o = {
    Style = "Text",
    Position = rect.Position:AsArray(),
    Size = rect.Size:AsArray(),
    IsReadOnly = false,
    FontSize = 9,
  }
  for k, v in pairs(options) do
    o[k] = v
  end
  if prettyName then
    o.PrettyName = prettyName
  end
  return o
end

---@param text string
---@param rect Rectangle
---@param options? LayoutGraphicsOptions
---@return LayoutLabel
function CreateLabel(text, rect, options)
  options = options or {}
  local o = {
    Type = "Label",
    Text = text,
    Position = rect.Position:AsArray(),
    Size = rect.Size:AsArray(),
    FontSize = 9,
    HTextAlign = "Center",
    VTextAlign = "Center",
  }
  for k, v in pairs(options) do
    o[k] = v
  end
  return o
end

---@param outerRect Rectangle
---@param size XYPoint
---@param prettyName? string
---@param options? LayoutItemOptions
---@return LayoutKnob
function CreateKnob(outerRect, size, prettyName, options)
  options = options or {}
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
  for k, v in pairs(options) do
    o[k] = v
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

  ---@type { Input: integer, Output: integer }
  local maxCounts = {
    Input = props["Max Input Count"].Value or 12,
    Output = props["Max Output Count"].Value or 12,
  }

  local CurrentPage = PageNames[props["page_index"].Value]

  ---@param labelType "Input" | "Output"
  function BuildLabelPage(labelType)
    local count = maxCounts[labelType]
    local numRows = 1
    local countPerRow = count
    local maxOuterWidth = 1200
    local textFieldSize = XYPoint:new(72, 16)
    local textFieldLabelSize = XYPoint:new(64, 16)
    local rowGap = 4
    local rowWidth = textFieldSize:X() * count
    if rowWidth > maxOuterWidth then
      -- Find a count per row that fits inside the maxOuterWidth and fills all rows with an equal number of labels
      local numIters = 0
      while 1 do
        numIters = numIters + 1
        numRows = numRows + 1
        countPerRow = math.floor(count / numRows)
        rowWidth = textFieldSize:X() * countPerRow
        if countPerRow % numRows == 0 and rowWidth <= maxOuterWidth then
          break
        end
        if numIters > 100 then
          error("Could not find a suitable layout for labels")
        end
      end
    end

    local rowRect = Rectangle:new(
      XYPoint:new(0, 12),
      XYPoint:new(rowWidth, (textFieldSize:Y() + textFieldLabelSize:Y()))
    )

    for rowIndex = 1, numRows do
      local rowCells = rowRect:DivideVertically(countPerRow)
      if #rowCells ~= countPerRow then
        error(string.format("Expected %i cells in row, got %i", countPerRow, #rowCells))
      end
      for columnIndex, cellRect in ipairs(rowCells) do
        local labelIndex = ((rowIndex - 1) * countPerRow) + columnIndex
        if labelIndex > count then break end
        local prettyName = string.format("%sLabels~%i", labelType, labelIndex)
        local textFieldRect = Rectangle:new(cellRect.Position, textFieldSize)
        local labelRect = Rectangle.FromBottomCenter(
          cellRect:BottomCenter(), textFieldLabelSize
        )
        layout[string.format("%sLabels %i", labelType, labelIndex)] = CreateTextInput(textFieldRect, prettyName)
        local label = CreateLabel(tostring(labelIndex), labelRect)
        table.insert(graphics, label)
      end
      rowRect = rowRect + XYPoint:new(0, rowRect:Height() + rowGap)
    end
  end
  if CurrentPage == "Input Labels" then
    BuildLabelPage("Input")
  elseif CurrentPage == "Output Labels" then
    BuildLabelPage("Output")
  elseif CurrentPage == "Route" then
    local inputCount = maxCounts["Input"]
    local outputCount = maxCounts["Output"]
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
    local outputNumberLabelCells = outputNumberLabelRowRect:DivideVertically(outputCount)
    local outputLabelRowRect = Rectangle:new(
      outputNumberLabelRowRect:BottomLeft() + XYPoint:new(0, upperRowYSpacing),
      outputNumberLabelRowRect.Size
    )
    local outputLabelCells = outputLabelRowRect:DivideVertically(outputCount)
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
      -- Add a hidden layout item for crosspoints so their pins are created
      layout["Crosspoints " .. i] = {
        Style = "None",
        Position = {0, 0},
        Size = {0, 0},
        PrettyName = string.format("Crosspoints~%i", i),
      }
      local numberLabel = CreateLabel(tostring(i), outputNumberLabelCells[i])
      table.insert(graphics, numberLabel)
      local prettyName = string.format("OutputLabels~%i", i)
      layout["OutputLabels " .. i] = CreateTextInput(outputLabelCells[i], prettyName)
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
    local rowOuterRects = outerRect:DivideHorizontally(numRows)

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
