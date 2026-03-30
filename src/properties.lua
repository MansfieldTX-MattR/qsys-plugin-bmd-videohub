---@meta


---@return DesignProperty[]
function GetProperties()
  ---@class DesignProperties
  local DesignProperties = {
    ---@type DesignPropertyInteger
    ["Max Input Count"] = {
      Name = "Max Input Count",
      Type = "integer",
      Value = 12,
      Min = 1,
      Max = 128,
    },
    ---@type DesignPropertyInteger
    ["Max Output Count"] = {
      Name = "Max Output Count",
      Type = "integer",
      Value = 12,
      Min = 1,
      Max = 128,
    },
    ---@type DesignPropertyEnum
    ["Selection Controls"] = {
      Name = "Selection Controls",
      Type = "enum",
      Value = "Crosspoint Buttons",
      Choices = {"Crosspoint Buttons", "Knobs", "Combo Boxes"},
    },
    ---@type DesignPropertyBoolean
    ["Show Routing Controls"] = {
      Name = "Show Routing Controls",
      Type = "boolean",
      Value = true,
    },
  }



  return {
    DesignProperties["Max Input Count"],
    DesignProperties["Max Output Count"],
    DesignProperties["Selection Controls"],
    DesignProperties["Show Routing Controls"],
  }
end

---@class Properties
---@field ["Max Input Count"] TextControllerControls
---@field ["Max Output Count"] TextControllerControls
---@field ["Selection Controls"] TextControllerControls
---@field ["Show Routing Controls"] TextControllerControls


---@alias SelectionControlType "Crosspoint Buttons" | "Knobs" | "Combo Boxes"

---@param props Properties
---@return SelectionControlType
function GetSelectionControlType(props)
  local selectionControlValue = props["Selection Controls"].Value
  if selectionControlValue == "Crosspoint Buttons" then
    return "Crosspoint Buttons"
  elseif selectionControlValue == "Knobs" then
    return "Knobs"
  elseif selectionControlValue == "Combo Boxes" then
    return "Combo Boxes"
  else
    error("Invalid Selection Control Type: " .. tostring(selectionControlValue))
  end
end
