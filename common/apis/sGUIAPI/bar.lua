--[[
GUI Library
Bar Base Class
by hsun324
v0.1a
]]

Bar = { }
Bar.__index = Bar

function Bar:new(label, unit, position, textColor, barFGColor, barBGColor, callback)
  if label then
    if position.h < 3 then position.h = 3 end
  else
    if position.h < 2 then position.h = 2 end
  end
  
  return setmetatable({
    label = label,
    position = position,
    textColor = textColor or 0,
    fgColor = barFGColor or 0,
    bgColor = barBGColor or 0,
    visible = true,
    unit = unit,
    total = 1,
    amount = 0,
    callback = callback
  }, Bar)
end

function Bar:render(target)
  if self.amount > self.total then self.amount = self.total end
  
  x = self.position.x
  y = self.position.y + 1
  w = self.position.w
  barHeight = self.position.h - 2
  
  target:setFGColor(self.textColor)
  
  if self.label ~= nil then
  	target:setCursorPos(x, y - 1)
  	target:write(self.label)
  end
  
  amountLabel = self.amount.."/"..self.total
  if self.unit ~= nil then amountLabel = amountLabel.." "..self.unit end
  target:setCursorPos(x + w - #amountLabel, y + barHeight)
  target:write(amountLabel)
  
  if self.bgColor ~= 0 then
    spaceLine = string.rep(" ", w)
    target:setBGColor(self.bgColor)
    for line = 1, barHeight do
      target:setCursorPos(x, y + line - 1)
      target:write(spaceLine)
    end
  end
  
  if self.fgColor ~= 0 then
    target:setBGColor(self.fgColor)
    indTotal = self.total / barHeight
    for line = 1, barHeight do
      if indTotal * line <= self.amount then
        indAmount = indTotal
      elseif indTotal * line - self.amount >= indTotal then
        indAmount = 0
      else
        indAmount = self.amount - indTotal * (line - 1)
      end
      
      target:setCursorPos(x, y + line - 1)
      target:write(string.rep(" ", math.floor(indAmount * w / indTotal)))
    end
  end
end

function Bar:onClick(caller, x, y)
  if self.callback ~= nil then self.callback(self, x, y) end
end