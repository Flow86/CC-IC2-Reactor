--[[
GUI Library
Util Base Class
by hsun324
v0.1a
]]

Util = { }
Util.__index = Util

function Util:pointWithin(point, rectangle)
  return rectangle.x <= point.x and rectangle.x + rectangle.w > point.x and
         rectangle.y <= point.y and rectangle.y + rectangle.h > point.y
end
