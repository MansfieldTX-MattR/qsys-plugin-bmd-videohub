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

---@param other XYPoint
---@return XYPoint
function XYPoint:Add(other)
  return XYPoint:new(self:X() + other:X(), self:Y() + other:Y())
end
XYPoint.__add = XYPoint.Add

---@param other XYPoint
---@return XYPoint
function XYPoint:Subtract(other)
  return XYPoint:new(self:X() - other:X(), self:Y() - other:Y())
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
---@return Rectangle[][] grid of rectangles dividing the original rectangle into equal parts.  The shape of the array will be (rows, columns) based on the y and x values of xyCount respectively.
function Rectangle:Divide(xyCount)
  local cellSize = self.Size / xyCount

  ---@type Rectangle[][]
  local cellRows = {}
  for row = 1, xyCount:Y() do
    ---@type Rectangle[]
    local cellRow = {}
    for column = 1, xyCount:X() do
      local cellPosition = self.Position + (cellSize * XYPoint:new(column - 1, row - 1))
      table.insert(cellRow, Rectangle:new(cellPosition, cellSize))
    end
    table.insert(cellRows, cellRow)
  end

  return cellRows
end
Rectangle.__div = Rectangle.Divide

--- Subdivide the rectangle into `count` horizontal slices
---@param count integer
---@return Rectangle[]
function Rectangle:DivideHorizontally(count)
  local cells = self:Divide(XYPoint:new(1, count))
  -- Extract the first column from each row to get a single array of rectangles
  local columnCells = {}
  for _, row in ipairs(cells) do
    table.insert(columnCells, row[1])
  end
  return columnCells
end

--- Subdivide the rectangle into `count` vertical slices
---@param count integer
---@return Rectangle[]
function Rectangle:DivideVertically(count)
  local cells = self:Divide(XYPoint:new(count, 1))
  return cells[1]
end
