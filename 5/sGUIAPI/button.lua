--[[
GUI Library
Button Base Class
by hsun324
v0.1a
]]

Button = { }
Button.__index = Button

function Button:new(label, position, labelColor, buttonColor, callback)
  return setmetatable({
    label = label,
    position = position,
    labelColor = labelColor or 0,
    buttonColor = buttonColor or 0,
    callback = callback,
    visible = true
  }, Button)
end

function Button:render(target)
  x = self.position.x
  y = self.position.y
  w = self.position.w
  h = self.position.h
  
  if self.buttonColor ~= 0 then
    target:setBGColor(self.buttonColor)
    
    spacesOutput = string.rep(" ", w)
    for line = 1, h do
      target:setCursorPos(x, y + line - 1)
      target:write(spacesOutput)
    end
  end
  
  if self.labelColor ~= 0 then
    textX = math.floor(( w - #self.label ) / 2 + x + 0.5)
    textY = math.floor(h / 2 + y)
    
    target:setFGColor(self.labelColor) 
    target:setCursorPos(textX, textY)
    target:write(self.label)
  end
end

function Button:onClick(caller, x, y)
  if self.callback ~= nil then self.callback(self, x, y) end
end