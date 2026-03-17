---@class XYPoint
---@field private x number
---@field private y number
---@operator add(XYPoint): XYPoint
---@operator sub(XYPoint): XYPoint
---@operator mul(XYPoint|number): XYPoint
---@operator div(XYPoint|number): XYPoint
XYPoint = {}

---@param x number
---@param y number
---@return XYPoint
function XYPoint:new(x, y)
  local obj = { x = x, y = y }
  setmetatable(obj, self)
  self.__index = self
  return obj
end

--- Checks if the given object is an instance of the XYPoint class.
---@param obj any
---@return boolean
function XYPoint:IsInstance(obj)
  if type(obj) ~= "table" then return false end
  return getmetatable(obj) == XYPoint
end

function XYPoint:X()
  return self.x
end

function XYPoint:Y()
  return self.y
end

---@return number, number
function XYPoint:Unpack()
  return self.x, self.y
end

---@return number[]
function XYPoint:AsArray()
  return { self.x, self.y }
end

---@param other any
---@return boolean
function XYPoint:Equals(other)
  if not XYPoint:IsInstance(other) then return false end
  return self.x == other:X() and self.y == other:Y()
end
XYPoint.__eq = XYPoint.Equals

---@param other XYPoint|number
---@return XYPoint
function XYPoint:Add(other)
  local otherX, otherY
  if type(other) == "number" then
    otherX, otherY = other, other
  elseif type(other) == "table" then
    otherX, otherY = other:X(), other:Y()
  else
    error("Invalid argument for addition")
  end
  return XYPoint:new(self:X() + otherX, self:Y() + otherY)
end
XYPoint.__add = XYPoint.Add

---@param other XYPoint|number
---@return XYPoint
function XYPoint:Subtract(other)
  local otherX, otherY
  if type(other) == "number" then
    otherX, otherY = other, other
  elseif type(other) == "table" then
    otherX, otherY = other:X(), other:Y()
  else
    error("Invalid argument for subtraction")
  end
  return XYPoint:new(self:X() - otherX, self:Y() - otherY)
end
XYPoint.__sub = XYPoint.Subtract

---@param other XYPoint|number
---@return XYPoint
function XYPoint:Multiply(other)
  local otherX, otherY
  if type(other) == "number" then
    otherX, otherY = other, other
  elseif type(other) == "table" then
    otherX, otherY = other:X(), other:Y()
  else
    error("Invalid argument for multiplication")
  end
  return XYPoint:new(self:X() * otherX, self:Y() * otherY)
end
XYPoint.__mul = XYPoint.Multiply


---@param other XYPoint|number
---@return XYPoint
function XYPoint:Divide(other)
  local otherX, otherY
  if type(other) == "number" then
    otherX, otherY = other, other
  elseif type(other) == "table" then
    otherX, otherY = other:X(), other:Y()
  else
    error("Invalid argument for division")
  end
  return XYPoint:new(self:X() / otherX, self:Y() / otherY)
end
XYPoint.__div = XYPoint.Divide


---@alias PaddingTable {top?: number, right?: number, bottom?: number, left?: number}
---@alias Padding PaddingTable|number|XYPoint


---@class Rectangle
---@field Position XYPoint
---@field Size XYPoint
---@operator add(XYPoint): Rectangle
---@operator sub(XYPoint): Rectangle
---@operator div(XYPoint): Rectangle[]
Rectangle = {}

---@param position XYPoint
---@param size XYPoint
---@return Rectangle
function Rectangle:new(position, size)
  local obj = { Position = XYPoint:new(position:X(), position:Y()), Size = XYPoint:new(size:X(), size:Y()) }
  setmetatable(obj, self)
  self.__index = self
  return obj
end


--- Checks if the given object is an instance of the Rectangle class.
---@param obj any
---@return boolean
function Rectangle:IsInstance(obj)
  if type(obj) ~= "table" then return false end
  return getmetatable(obj) == Rectangle
end


---@param centerPos XYPoint
---@param size XYPoint
---@return Rectangle
function Rectangle.FromCenter(centerPos, size)
  local xy = centerPos - (size / 2)
  return Rectangle:new(xy, size)
end

---@param bottomCenterPos XYPoint
---@param size XYPoint
---@return Rectangle
function Rectangle.FromBottomCenter(bottomCenterPos, size)
  local xy = bottomCenterPos - XYPoint:new(size:X() / 2, size:Y())
  return Rectangle:new(xy, size)
end


---@param leftTop XYPoint
---@param rightBottom XYPoint
---@return Rectangle
function Rectangle.FromBounds(leftTop, rightBottom)
  local position = leftTop
  local size = rightBottom - leftTop
  return Rectangle:new(position, size)
end


---@param padding Padding
---@return PaddingTable
function Rectangle.ParsePadding(padding)
  ---@type PaddingTable
  local appliedPadding = {
    top = 0,
    right = 0,
    bottom = 0,
    left = 0,
  }
  if type(padding) == "number" then
    appliedPadding.top = padding
    appliedPadding.right = padding
    appliedPadding.bottom = padding
    appliedPadding.left = padding
  elseif XYPoint:IsInstance(padding) then
    ---@cast padding XYPoint
    appliedPadding.top = padding:Y()
    appliedPadding.right = padding:X()
    appliedPadding.bottom = padding:Y()
    appliedPadding.left = padding:X()
  elseif type(padding) == "table" then
    appliedPadding.top = padding.top or 0
    appliedPadding.right = padding.right or 0
    appliedPadding.bottom = padding.bottom or 0
    appliedPadding.left = padding.left or 0
  else
    error("Invalid padding value")
  end
  return appliedPadding
end

---@param padding Padding
---@return Rectangle
function Rectangle:WithInnerPadding(padding)
  local appliedPadding = self.ParsePadding(padding)
  local posOffset = XYPoint:new(appliedPadding.left, appliedPadding.top)
  local sizeOffset = XYPoint:new(appliedPadding.left + appliedPadding.right, appliedPadding.top + appliedPadding.bottom)
  return Rectangle:new(self.Position + posOffset, self.Size - sizeOffset)
end

---@param padding Padding
---@return Rectangle
function Rectangle:WithOuterPadding(padding)
  local appliedPadding = self.ParsePadding(padding)
  local posOffset = XYPoint:new(-appliedPadding.left, -appliedPadding.top)
  local sizeOffset = XYPoint:new(appliedPadding.left + appliedPadding.right, appliedPadding.top + appliedPadding.bottom)
  return Rectangle:new(self.Position + posOffset, self.Size + sizeOffset)
end


function Rectangle:Right()
  return self.Position:X() + self.Size:X()
end

function Rectangle:Bottom()
  return self.Position:Y() + self.Size:Y()
end

function Rectangle:Left()
  return self.Position:X()
end

function Rectangle:Top()
  return self.Position:Y()
end

function Rectangle:Width()
  return self.Size:X()
end

function Rectangle:Height()
  return self.Size:Y()
end


function Rectangle:TopLeft()
  return self.Position
end

function Rectangle:TopRight()
  return XYPoint:new(self:Right(), self:Top())
end

function Rectangle:BottomRight()
  return XYPoint:new(self:Right(), self:Bottom())
end

function Rectangle:BottomLeft()
  return XYPoint:new(self:Left(), self:Bottom())
end

function Rectangle:BottomCenter()
  return XYPoint:new(self:CenterX(), self:Bottom())
end

---@return XYPoint
function Rectangle:Center()
  return XYPoint:new(self:CenterX(), self:CenterY())
end

function Rectangle:CenterX()
  return self.Position:X() + (self:Width() / 2)
end

function Rectangle:CenterY()
  return self.Position:Y() + (self:Height() / 2)
end

---@param other any
---@return boolean
function Rectangle:Equals(other)
  if not Rectangle:IsInstance(other) then return false end
  return self.Position:Equals(other.Position) and self.Size:Equals(other.Size)
end
Rectangle.__eq = Rectangle.Equals

---@param other XYPoint
---@return Rectangle
function Rectangle:Add(other)
  local newPosition = self.Position + other
  return Rectangle:new(newPosition, self.Size)
end
Rectangle.__add = Rectangle.Add

---@param other XYPoint
---@return Rectangle
function Rectangle:Subtract(other)
  local newPosition = self.Position - other
  return Rectangle:new(newPosition, self.Size)
end
Rectangle.__sub = Rectangle.Subtract


---@alias RectangleArray Rectangle[]
---@alias RectangleGrid Rectangle[][]

---@param xyCount XYPoint
---@param spacing? XYPoint optional spacing between the rectangles in the grid
---@return Rectangle[][] grid of rectangles dividing the original rectangle into equal parts.  The shape of the array will be (rows, columns) based on the y and x values of xyCount respectively.
function Rectangle:Divide(xyCount, spacing)
  local cellSize = self.Size / xyCount
  if spacing then
    local totalSpacing = spacing * (xyCount - XYPoint:new(1, 1))
    cellSize = (self.Size - totalSpacing) / xyCount
    if cellSize:X() <= 0 or cellSize:Y() <= 0 then
      error("Spacing is too large for the given rectangle and xyCount")
    end
  end
  ---@type Rectangle[][]
  local cellRows = {}
  for row = 1, xyCount:Y() do
    ---@type Rectangle[]
    local cellRow = {}
    for column = 1, xyCount:X() do
      local cellPosition = self.Position + (cellSize * XYPoint:new(column - 1, row - 1))
      if spacing then
        cellPosition = cellPosition + (spacing * XYPoint:new(column - 1, row - 1))
      end
      table.insert(cellRow, Rectangle:new(cellPosition, cellSize))
    end
    table.insert(cellRows, cellRow)
  end

  return cellRows
end
Rectangle.__div = Rectangle.Divide

--- Subdivide the rectangle into `count` rows (across the y-axis)
---@param count integer
---@param spacing? XYPoint optional spacing between the rectangles in the grid
---@return Rectangle[]
function Rectangle:MakeRows(count, spacing)
  local cells = self:Divide(XYPoint:new(1, count), spacing)
  -- Extract the first column from each row to get a single array of rectangles
  local columnCells = {}
  for _, row in ipairs(cells) do
    table.insert(columnCells, row[1])
  end
  return columnCells
end

--- Subdivide the rectangle into `count` columns (across the x-axis)
---@param count integer
---@param spacing? XYPoint optional spacing between the rectangles in the grid
---@return Rectangle[]
function Rectangle:MakeColumns(count, spacing)
  local cells = self:Divide(XYPoint:new(count, 1), spacing)
  return cells[1]
end


-- This is needed for testing purposes to allow the classes to be imported
-- into the test files without causing errors in the actual plugin environment.
if os.getenv("TEST_ENV") then
  return {
    XYPoint = XYPoint,
    Rectangle = Rectangle
  }
end
