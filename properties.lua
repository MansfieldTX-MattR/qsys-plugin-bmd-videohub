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
  }



  return {
    DesignProperties["Max Input Count"],
    DesignProperties["Max Output Count"],
  }
end

---@class Properties
---@field ["Max Input Count"] TextControllerControls
---@field ["Max Output Count"] TextControllerControls
