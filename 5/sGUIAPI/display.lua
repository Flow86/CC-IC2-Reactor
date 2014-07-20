--[[
GUI Library
Display Base Class
by hsun324
v0.1a
]]

Display = { }
Display.__index = Display

function Display:new(side)
  if side == nil then target = term
  elseif peripheral.getType(side) == "monitor" then target = peripheral.wrap(side)
  else target = term end
  
  if not target.isColor() then error("Selected target canvas is not color.") end
  
  target.setTextColor(colors.white)
  target.setBackgroundColor(colors.black)
  target.setCursorBlink(false)
  
  return setmetatable({
    side = side,
    canvas = target,
    children = { }
  }, Display)
end

function Display:render()
  self.canvas.clear()
  for key, child in pairs(self.children) do
    if child.visible then
      x, y = self:getCursorPos()
      child:render(self)
      
      self.canvas.setTextColor(colors.white)
      self.canvas.setBackgroundColor(colors.black)
      self.canvas.setCursorPos(x, y)
    end
  end
end

function Display:interceptEvent(event, p1, p2, p3, p4, p5)
  if event == "monitor_touch" and p1 == self.side then
    for key, child in pairs(self.children) do
      if child.visible and Util:pointWithin(Rectangle:new(p2, p3, 0, 0), child.position) then child:onClick(self, p2, p3) end
    end
  end
end

function Display:addChild(component)
  hash = tostring(component)
  if self.children[hash] == nil then
    self.children[hash] = component
    component.parent = self
  end
end

function Display:removeChild(child)
  hash = tostring(child)
  if self.children[hash] ~= nil then
    self.children[hash] = nil
    if child.parent == self then child.parent = nil end
  end
end

function Display:write(text)
  self.canvas.write(text)
end

function Display:getCursorPos()
  return self.canvas.getCursorPos()
end

function Display:setCursorPos(x, y)
  self.canvas.setCursorPos(x, y)
end

function Display:isColor()
  return true
end

function Display:getSize()
  return self.canvas.getSize()
end

function Display:setFGColor(color)
  if color == 0 then return end
  self.canvas.setTextColor(color)
end

function Display:setBGColor(color)
  if color == 0 then return end
  self.canvas.setBackgroundColor(color)
end

function Display:clear()
  self.canvas.clear()
end
