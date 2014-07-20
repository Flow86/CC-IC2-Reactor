--[[
GUI Library
Rule Base Class
by hsun324
v0.1a
]]

Rule = {
  VERTICAL = 1,
  HORIZONTAL = 2
}
Rule.__index = Rule

function Rule:new(kind, position, color, callback)
  return setmetatable({
    kind = kind,
    position = position,
    color = color or 0,
    visible = true,
    callback = callback
  }, Rule)
end

function Rule:render(target)
  if self.color ~= 0 then
    target:setBGColor(self.color)
    if self.kind == Rule.HORIZONTAL then
      local spacesOutput = string.rep(" ", self.position.w)
      target:setCursorPos(self.position.x, self.position.y)
      target:write(spacesOutput)
    elseif self.kind == Rule.VERTICAL then
      for line = 1, self.position.h do
        target:setCursorPos(self.position.x, self.position.y + line - 1)
        target:write(" ")
      end
    end
  end
end

function Rule:onClick(caller, x, y)
  if self.callback ~= nil then self.callback(self) end
end