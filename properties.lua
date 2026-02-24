---@meta


---@return DesignProperty[]
function GetProperties()
  ---@class DesignProperties
  local DesignProperties = {
    ---@type DesignPropertyInteger
    ["Input Count"] = {
      Name = "Input Count",
      Type = "integer",
      Value = 12,
      Min = 1,
      Max = 128,
    },
    ---@type DesignPropertyInteger
    ["Output Count"] = {
      Name = "Output Count",
      Type = "integer",
      Value = 12,
      Min = 1,
      Max = 128,
    },
  }



  return {
    DesignProperties["Input Count"],
    DesignProperties["Output Count"],
  }
end

---@class Properties
---@field ["Input Count"] TextControllerControls
---@field ["Output Count"] TextControllerControls
