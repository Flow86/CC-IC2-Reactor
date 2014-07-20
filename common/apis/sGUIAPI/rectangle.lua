--[[
GUI Library
Rectangle Base Class
by hsun324
v0.1a
]]

Rectangle = { }
Rectangle.__index = Rectangle

function Rectangle:new(x, y, w, h)
  return setmetatable({
    x = x or 1,
    y = y or 1,
    w = w or 1,
    h = h or 1
  }, Rectangle)
end