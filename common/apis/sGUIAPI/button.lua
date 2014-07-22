--[[
GUI Library
Button Base Class
by hsun324
v0.1a
]]

Button = { }
Button.__index = Button

function Button:new(labels, position, labelColor, buttonColor, callback, visible)
  if type(labels) ~= "table" then
    labels = { labels }
  end
  return setmetatable({
    labels = labels,
    position = position,
    labelColor = labelColor or 0,
    buttonColor = buttonColor or 0,
    callback = callback,
    visible = visible or true,
  }, Button)
end

function Button:render(target)
  if not self.visible then
    return
  end
  
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
    textY = math.floor((h - #self.labels ) / 2 + y)
    
    target:setFGColor(self.labelColor)
    for line = 1, #self.labels do
    	textX = math.floor(( w - #self.labels[line] ) / 2 + x + 0.5)
    	target:setCursorPos(textX, textY + line - 1)
    	target:write(self.labels[line])
    end
  end
end

function Button:onClick(caller, x, y)
  if self.visible and self.callback ~= nil then self.callback(self, x, y) end
end

function Button:setLabel(labels)
  if type(labels) ~= "table" then
    labels = { labels }
  end
  self.labels = labels
end

function Button:getLabel(nr)
	nr = nr or 0
	return self.labels[nr]
end