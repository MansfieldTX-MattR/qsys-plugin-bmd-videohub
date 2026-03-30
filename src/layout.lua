

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

---@param rect Rectangle
---@param prettyName? string
---@param options? LayoutItemOptions
---@return LayoutComboBox
function CreateComboBox(rect, prettyName, options)
  options = options or {}
  local o = {
    Style = "ComboBox",
    Position = rect.Position:AsArray(),
    Size = rect.Size:AsArray(),
    Color = {194, 194, 194},
    StrokeColor = {105, 105, 105},
    StrokeWidth = 1,
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
  local showRoutingControls = props["Show Routing Controls"].Value
  local selectionControlType = GetSelectionControlType(props)

  local CurrentPage = PageNames[props["page_index"].Value]

  -- Add a hidden layout item for crosspoints so their pins are created
  for i = 1, maxCounts["Output"] do
    layout["Crosspoints " .. i] = {
      Style = "None",
      Position = {0, 0},
      Size = {0, 0},
      PrettyName = string.format("Crosspoints~%i", i),
    }
  end

  ---@param labelType "Input" | "Output"
  ---@param xOffset number
  ---@return Rectangle
  function BuildLabelGrid(labelType, xOffset)
    local count = maxCounts[labelType]
    local numCols = 1
    local countPerColumn = count
    local maxOuterHeight = 800
    local textFieldSize = XYPoint:new(72, 16)
    local textFieldLabelSize = XYPoint:new(40, 16)
    local totalFieldSize = XYPoint:new(textFieldLabelSize:X() + textFieldSize:X(), textFieldSize:Y())
    local colHeight = totalFieldSize:Y() * countPerColumn
    if colHeight > maxOuterHeight then
      -- Find a count per column that fits inside the maxOuterHeight and results in enough columns to fit all labels
      local numIters = 0
      while 1 do
        numIters = numIters + 1
        numCols = numCols + 1
        countPerColumn = math.floor(count / numCols)
        colHeight = totalFieldSize:Y() * countPerColumn
        if countPerColumn * numCols >= count and colHeight <= maxOuterHeight then
          break
        end
        if numIters > 100 then
          error("Could not find a suitable layout for labels")
        end
      end
    end

    local rowRect = Rectangle:new(
      XYPoint:new(xOffset + 4, 20),
      XYPoint:new(
        totalFieldSize:X() * numCols,
        colHeight
      )
    )
    local groupBoxRect = rowRect:WithOuterPadding({
      left = 4,
      top = 20,
      right = 4,
      bottom = 4,
    })

    local groupBox = CreateGroupBox(labelType, groupBoxRect, "Top", {
      Color = {0, 0, 0},
      StrokeWidth = 1,
      CornerRadius = 8
    })
    table.insert(graphics, groupBox)
    local colRects = rowRect:MakeColumns(numCols)
    for columnIndex, colRect in ipairs(colRects) do
      local rowCells = colRect:MakeRows(countPerColumn)
      for rowIndex, cellRect in ipairs(rowCells) do
        local labelIndex = ((columnIndex - 1) * countPerColumn) + rowIndex
        if labelIndex > count then break end
        local prettyName = string.format("%sLabels~%i", labelType, labelIndex)
        local labelRect = Rectangle:new(
          cellRect.Position,
          textFieldLabelSize
        )
        local textFieldRect = Rectangle:new(labelRect:TopRight(), textFieldSize)
        labelRect = labelRect:WithInnerPadding({ right = 4 })
        layout[string.format("%sLabels %i", labelType, labelIndex)] = CreateTextInput(textFieldRect, prettyName)
        local label = CreateLabel(tostring(labelIndex), labelRect, {
          HTextAlign = "Right",
          VTextAlign = "Center",
        })
        table.insert(graphics, label)
      end
    end
    return groupBoxRect
  end
  if CurrentPage == "Labels" then
    local inputRect = BuildLabelGrid("Input", 0)
    BuildLabelGrid("Output", inputRect:Right() + 20)
  elseif CurrentPage == "Route" then
    local inputCount = maxCounts["Input"]
    local outputCount = maxCounts["Output"]
    if not showRoutingControls then
      return layout, graphics
    end
    if selectionControlType == "Knobs" or selectionControlType == "Combo Boxes" then
      local fieldSize = XYPoint:new(36, 36)
      if selectionControlType == "Knobs" then
        fieldSize = XYPoint:new(36, 36)
      elseif selectionControlType == "Combo Boxes" then
        fieldSize = XYPoint:new(36, 16)
      end
      local maxFieldsPerRow = 20
      local fieldLabelSize = XYPoint:new(36, 16)
      local fieldNumberLabelSize = XYPoint:new(36, 16)
      local totalFieldSize = fieldSize + XYPoint:new(0, fieldLabelSize:Y()) + XYPoint:new(0, fieldNumberLabelSize:Y())
      local fieldRects = {
        ["Input Select"] = Rectangle:new(XYPoint:new(0, 0), fieldSize),
        ["Output Label"] = Rectangle:new(XYPoint:new(0, fieldSize:Y()), fieldLabelSize),
        ["Output #"] = Rectangle:new(XYPoint:new(0, fieldSize:Y() + fieldLabelSize:Y()), fieldNumberLabelSize),
      }

      local numRows = math.ceil(outputCount / maxFieldsPerRow)
      local numCols = math.min(outputCount, maxFieldsPerRow)
      local rowGap = 20
      local controlsRect = Rectangle:new(
        XYPoint:new(72, 20),
        totalFieldSize * XYPoint:new(numCols, numRows) + XYPoint:new(0, (numRows - 1) * rowGap)
      )
      local leftLabelWidth = 64

      ---@type table<string, Rectangle>
      local leftLabelRects = {}
      for key, fieldRect in pairs(fieldRects) do
        leftLabelRects[key] = Rectangle:new(
          XYPoint:new(0, fieldRect:Top()),
          XYPoint:new(leftLabelWidth, fieldRect:Height())
        )
      end

      local rowRects = controlsRect:MakeRows(numRows, rowGap)
      for rowIndex, rowRect in ipairs(rowRects) do
        for key, rect in pairs(leftLabelRects) do
          local labelText = key
          local label = CreateLabel(labelText, rect + XYPoint:new(0, rowRect:Top()), {
            HTextAlign = "Right",
            VTextAlign = "Center",
          })
          table.insert(graphics, label)
        end
        local groupBox = CreateGroupBox("", rowRect:WithOuterPadding(4), "Top", {
          StrokeColor = {160, 160, 160},
          StrokeWidth = 1,
        })
        table.insert(graphics, groupBox)

        local colRects = rowRect:MakeColumns(numCols)
        for colIndex, colRect in ipairs(colRects) do
          local outputIndex = ((rowIndex - 1) * numCols) + colIndex
          if outputIndex > outputCount then break end
          local fieldRect = fieldRects["Input Select"] + colRect.Position
          local numberLabelRect = fieldRects["Output #"] + colRect.Position
          local textFieldRect = fieldRects["Output Label"] + colRect.Position
          local textFieldPrettyName = string.format("OutputLabels~%i", outputIndex)
          layout[string.format("OutputLabels %i", outputIndex)] = CreateTextInput(textFieldRect, textFieldPrettyName, {
            FontSize = 9,
            Color = {255, 255, 255, 0},
            TextColor = {0, 0, 0},
            StrokeColor = {105, 105, 105},
            StrokeWidth = 1,
            WordWrap = true,
            TextBoxStyle = "Normal",
          })
          local prettyName = string.format("Crosspoints~%i", outputIndex)
          --- NOTE: We're overwriting the "Crosspoints X" items built at the start of this function.
          --- This is intentional so we don't have to alter runtime logic
          local field
          if selectionControlType == "Knobs" then
            field = CreateKnob(fieldRect, fieldSize, prettyName)
          elseif selectionControlType == "Combo Boxes" then
            field = CreateComboBox(fieldRect, prettyName)
          end
          layout[string.format("Crosspoints %i", outputIndex)] = field
          local numberLabel = CreateLabel(tostring(outputIndex), numberLabelRect, {
            HTextAlign = "Center",
            VTextAlign = "Bottom",
          })
          table.insert(graphics, numberLabel)
        end
      end
    elseif selectionControlType == "Crosspoint Buttons" then
      local routeTableCellSize = XYPoint:new(36, 16)
      local inputLabelSize = XYPoint:new(64, 16)
      local inputLabelRightPadding = 4
      local outputNumberLabelSize = XYPoint:new(36, 16)
      local outputLabelSize = XYPoint:new(36, 32)
      local upperRowYSpacing = 20

      local inputLabelOuterWidth = inputLabelSize:X() + inputLabelRightPadding * 2
      local routeTableOuterX = inputLabelOuterWidth + inputLabelRightPadding
      local routeTableInnerX = routeTableOuterX + inputLabelRightPadding

      local outputNumberLabelRowRect = Rectangle:new(
      XYPoint:new(routeTableInnerX, upperRowYSpacing),
        XYPoint:new(outputNumberLabelSize:X() * outputCount, outputNumberLabelSize:Y())
      )
      local outputNumberLabelCells = outputNumberLabelRowRect:MakeColumns(outputCount)
      local outputLabelRowRect = Rectangle:new(
        outputNumberLabelRowRect:BottomLeft() + XYPoint:new(0, upperRowYSpacing),
        XYPoint:new(outputNumberLabelRowRect:Width(), outputLabelSize:Y())
      )
      local outputLabelCells = outputLabelRowRect:MakeColumns(outputCount)
      local routeTableRect = Rectangle:new(
        outputLabelRowRect:BottomLeft() + XYPoint:new(0, upperRowYSpacing),
        routeTableCellSize * XYPoint:new(outputCount, inputCount)
      )
      local routeTableCells = routeTableRect / (XYPoint:new(outputCount, inputCount))
      local routeTableGroupBoxRect = Rectangle.FromBounds(
        XYPoint:new(routeTableOuterX, 0),
        routeTableRect:BottomRight() + XYPoint:new(inputLabelRightPadding, inputLabelRightPadding)
      )
      local routeTableGroupBox = CreateGroupBox("Output", routeTableGroupBoxRect, "Top", {
        Color = {0, 0, 0},
        StrokeWidth = 1,
        CornerRadius = 8
      })
      table.insert(graphics, routeTableGroupBox)

      local inputLabelRect = Rectangle:new(
        XYPoint:new(inputLabelRightPadding, routeTableRect:Top()),
        inputLabelSize * XYPoint:new(1, inputCount)
      )
      local inputLabelCells = inputLabelRect:MakeRows(inputCount)
      local inputLabelGroupBoxRect = Rectangle.FromBounds(
        XYPoint:new(0, inputLabelRect:Top() - upperRowYSpacing),
        XYPoint:new(
          inputLabelRect:Right() + inputLabelRightPadding,
          inputLabelRect:Top() + inputLabelRect:Height() + inputLabelRightPadding
        )
      )
      table.insert(graphics, CreateGroupBox("Input", inputLabelGroupBoxRect, "Top"))

      local inputNumberRect = Rectangle:new(
        XYPoint:new(routeTableRect:Right() + inputLabelRightPadding, routeTableRect:Top()),
        routeTableCellSize
      )

      for i = 1, inputCount do
        local prettyName = string.format("InputLabels~%i", i)
        layout["InputLabels " .. i] = CreateTextInput(inputLabelCells[i], prettyName, {
          FontSize = 9,
          Color = {255, 255, 255, 0},
          TextColor = {0, 0, 0},
          StrokeColor = {105, 105, 105},
          StrokeWidth = 1,
          WordWrap = true,
          TextBoxStyle = "Normal",
        })
        local numberLabel = CreateLabel(tostring(i), inputNumberRect)
        table.insert(graphics, numberLabel)
        inputNumberRect = inputNumberRect + XYPoint:new(0, inputNumberRect:Height())
      end

      local k = 1
      for i = 1, outputCount do
        local numberLabel = CreateLabel(tostring(i), outputNumberLabelCells[i])
        table.insert(graphics, numberLabel)
        local prettyName = string.format("OutputLabels~%i", i)
        layout["OutputLabels " .. i] = CreateTextInput(outputLabelCells[i], prettyName, {
          FontSize = 9,
          Color = {255, 255, 255, 0},
          TextColor = {0, 0, 0},
          StrokeColor = {105, 105, 105},
          StrokeWidth = 1,
          WordWrap = true,
          TextBoxStyle = "Normal",
        })
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
    local rowOuterRects = outerRect:MakeRows(numRows)

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
