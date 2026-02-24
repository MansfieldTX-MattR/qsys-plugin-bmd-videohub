---@meta

---@alias PropertyTypeName
---| "string"
---| "integer"
---| "double"
---| "boolean"
---| "enum"

---@class DesignPropertyBase<T>
---@field Name string
---@field Type PropertyTypeName
---@field Value T
---@field Min? T
---@field Max? T
---@field Choices? T[]
---@field Header? string
---@field Comment? string


---@class DesignPropertyString : DesignPropertyBase<string>
---@field Type "string"


---@class DesignPropertyNumeric<T> : DesignPropertyBase<T>
---@field Type "integer" | "double"
---@field Min T
---@field Max T

---@class DesignPropertyInteger : DesignPropertyNumeric<integer>
---@field Type "integer"

---@class DesignPropertyDouble : DesignPropertyNumeric<number>
---@field Type "double"

---@class DesignPropertyBoolean : DesignPropertyBase<boolean>
---@field Type "boolean"

---@class DesignPropertyEnum : DesignPropertyBase<string>
---@field Type "enum"
---@field Choices string[]


---@alias DesignProperty
---| DesignPropertyString
---| DesignPropertyInteger
---| DesignPropertyDouble
---| DesignPropertyBoolean
---| DesignPropertyEnum



---@return DesignProperty[]
function GetProperties() end
