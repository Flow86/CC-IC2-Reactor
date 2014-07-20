--[[
GUI Library
Label Base Class
by hsun324
v0.1a
]]

Label = { }
Label.__index = Label

function Label:new(text, position, textColor, bgColor, callback)
  return setmetatable({
    text = text,
    position = position,
    textColor = textColor or 0,
    bgColor = bgColor or 0,
    visible = true,
    active = false,
    callback = callback
  }, Label)
end

function Label:render(target)
  if self.textColor ~= 0 then
    target:setFGColor(self.textColor)
    if self.bgColor ~= 0 then target:setBGColor(self.bgColor) end
    target:setCursorPos(self.position.x, self.position.y)
    target:write(self.text)
  end
end

function Label:onClick(caller, x, y)
  if self.callback ~= nil then self.callback(self, x, y) end
end