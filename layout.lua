
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
    local inputCount = props["Input Count"].Value
    local outputCount = props["Output Count"].Value
    local xOffset = 64
    local columnWidth = 64
    local columnGap = 4
    local textFieldHeight = 16
    local knobHeight = 32
    local groupBoxPadding = { 4, 4 }
    local yGap = 4

    local totalWidth = (columnWidth * inputCount) + (columnGap * (inputCount - 1))
    local totalHeight = math.max(textFieldHeight, knobHeight) + yGap

    ---@param title string
    ---@param yPosition number
    ---@return LayoutGroupBox
    function CreateGroupBox(title, yPosition)
       return {
        Type = "GroupBox",
        Position = { xOffset, yPosition },
        Size = { totalWidth + (groupBoxPadding[1] * 2), totalHeight + (groupBoxPadding[2] * 2) },
        Text = title,
        FontSize = 9,
        HTextAlign = "Left",
        VTextAlign = "Center",
        ZOrder = -1,
      }
    end

    local GroupBoxes = {
      CreateGroupBox("Input Labels", 0),
      CreateGroupBox("Output Labels", totalHeight + (groupBoxPadding[2] * 2) + yGap),
      CreateGroupBox("Crosspoint Controls", (totalHeight + (groupBoxPadding[2] * 2) + yGap) * 2),
    }

    for _, groupBox in ipairs(GroupBoxes) do
      table.insert(graphics, groupBox)
    end

    -- table.insert(graphics, CreateGroupBox("Input Labels", 0))
    -- table.insert(graphics, CreateGroupBox("Output Labels", totalHeight + (groupBoxPadding[2] * 2) + yGap))
    -- table.insert(graphics, CreateGroupBox("Crosspoint Controls", (totalHeight + (groupBoxPadding[2] * 2) + yGap) * 2))

    -- ---@type LayoutGroupBox
    -- local groupBox = {
    --   Type = "GroupBox",
    --   Position = { xOffset, 0 },
    --   Size = { totalWidth + (groupBoxPadding[1] * 2), totalHeight + (groupBoxPadding[2] * 2) },
    --   Text = "Input Labels",
    --   FontSize = 9,
    --   HTextAlign = "Left",
    --   VTextAlign = "Center",
    --   ZOrder = -1,
    -- }
    -- table.insert(graphics, groupBox)
    -- groupBox.Position = { xOffset, groupBox.Position[2] + groupBox.Size[2] + yGap }
    -- groupBox.Text = "Output Labels"
    -- table.insert(graphics, groupBox)
    -- groupBox.Position = { xOffset, groupBox.Position[2] + groupBox.Size[2] + yGap }
    -- groupBox.Text = "Crosspoint Controls"
    -- table.insert(graphics, groupBox)


    for i = 1, inputCount do
      layout["InputLabel_" .. i] = {
        Style = "Text",
        Position = {
          xOffset + groupBoxPadding[1] + ((i - 1) * (columnWidth + columnGap)),
          GroupBoxes[1].Position[2] + GroupBoxes[1].Size[2],
        },
        Size = { columnWidth, textFieldHeight },
        FontSize = 9,
        HTextAlign = "Center",
        VTextAlign = "Center",
      }
    end

    for i = 1, outputCount do
      layout["OutputLabel_" .. i] = {
        Style = "Text",
        Position = {
          xOffset + groupBoxPadding[1] + ((i - 1) * (columnWidth + columnGap)),
          GroupBoxes[2].Position[2] + GroupBoxes[2].Size[2],
        },
        Size = { columnWidth, textFieldHeight },
        FontSize = 9,
        HTextAlign = "Center",
        VTextAlign = "Center",
      }

      layout["Crosspoint_" .. i] = {
        Style = "Knob",
        Position = {
          xOffset + groupBoxPadding[1] + ((i - 1) * (columnWidth + columnGap)) - ((knobHeight - columnWidth) / 2),
          GroupBoxes[3].Position[2] + GroupBoxes[3].Size[2],
        },
        Size = { knobHeight, knobHeight },
      }

      -- one row with labelled numbers below

      ---@type LayoutLabel
      local label = {
        Type = "Label",
        Text = tostring(i),
        Position = {
          xOffset + groupBoxPadding[1] + ((i - 1) * (columnWidth + columnGap)),
          GroupBoxes[3].Position[2] + (GroupBoxes[3].Size[2] * 3) + (yGap * 3)
        },
        Size = { columnWidth, textFieldHeight },
        FontSize = 9,
        HTextAlign = "Center",
        VTextAlign = "Center",
      }
      table.insert(graphics, label)
    end
  elseif CurrentPage == "Setup" then

    local labelWidth = 64
    local labelHeight = 16
    local labelYGap = 4
    local labelXGap = 4

    ---@type LayoutLabel[]
    local labels = {
      {
        Type = "Label",
        Text = "IP Address",
        Position = { 0, 0 },
        Size = { labelWidth, labelHeight },
        FontSize = 9,
      },
      {
        Type = "Label",
        Text = "Port",
        Position = { 0, labelHeight + labelYGap },
        Size = { labelWidth, labelHeight },
        FontSize = 9,
      },
      {
        Type = "Label",
        Text = "Telnet Enable",
        Position = { 0, (labelHeight + labelYGap) * 2 },
        Size = { labelWidth, labelHeight },
        FontSize = 9,
      },
      {
        Type = "Label",
        Text = "Status",
        Position = { 0, (labelHeight + labelYGap) * 3 },
        Size = { labelWidth, labelHeight },
        FontSize = 9,
      }
    }

    ---@type LayoutText
    local ipGraphic = {
      Style = "Text",
      Position = { labelWidth + labelXGap, 0 },
      Size = { 96, 16 },
      IsReadOnly = false,
      FontSize = 9,
    }

    ---@type LayoutText
    local portGraphic = {
      Style = "Text",
      Position = { labelWidth + labelXGap, labelHeight + labelYGap },
      Size = { 96, 16 },
      IsReadOnly = false,
      FontSize = 9,
    }

    ---@type LayoutButton
    local telnetGraphic = {
      Style = "Button",
      ButtonStyle = "Toggle",
      Position = { labelWidth + labelXGap, (labelHeight + labelYGap) * 2 },
      IsReadOnly = false,
      Size = { 96, 16 },
      FontSize = 9,
    }

    ---@type LayoutText
    local statusGraphic = {
      Style = "Text",
      Position = { labelWidth + labelXGap, (labelHeight + labelYGap) * 3 },
      Size = { 96, 16 },
      IsReadOnly = true,
      FontSize = 9,
    }

    -- table.insert(graphics, ipGraphic)
    -- table.insert(graphics, portGraphic)
    -- table.insert(graphics, telnetGraphic)
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
