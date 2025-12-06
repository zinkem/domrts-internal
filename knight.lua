--[[
    Knight - Mounted cavalry unit
    Inherits from Unit base class
    Can be upgraded to Paladin (visual change)
]]

local Unit = require("unit")

local Knight = setmetatable({}, {__index = Unit})
Knight.__index = Knight

Knight.RADIUS = 16  -- Larger due to horse
Knight.SPEED = 120

function Knight.new(params)
    local self = Unit.new(params)
    setmetatable(self, Knight)
    
    self.radius = Knight.RADIUS
    self.speed = Knight.SPEED
    self.type = "knight"
    self.name = "Knight"
    self.isPaladin = params.isPaladin or false
    
    if self.isPaladin then
        self.name = "Paladin"
    end
    
    return self
end

function Knight:draw()
    local x, y = self:getScreenPos()
    
    -- Selection circle
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.circle("fill", x, y, self.radius + 4)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x, y + 12, 14, 5)
    
    -- Horse body
    if self.isPaladin then
        love.graphics.setColor(0.9, 0.88, 0.85, 1)  -- White horse
    else
        love.graphics.setColor(0.45, 0.35, 0.28, 1)  -- Brown horse
    end
    love.graphics.ellipse("fill", x, y + 4, 14, 8)
    
    -- Horse legs
    local legColor = self.isPaladin and {0.8, 0.78, 0.75, 1} or {0.35, 0.28, 0.22, 1}
    love.graphics.setColor(unpack(legColor))
    love.graphics.rectangle("fill", x - 8, y + 6, 3, 8, 1)
    love.graphics.rectangle("fill", x - 3, y + 7, 3, 7, 1)
    love.graphics.rectangle("fill", x + 3, y + 7, 3, 7, 1)
    love.graphics.rectangle("fill", x + 8, y + 6, 3, 8, 1)
    
    -- Hooves
    love.graphics.setColor(0.25, 0.22, 0.2, 1)
    love.graphics.ellipse("fill", x - 7, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x - 2, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x + 4, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x + 9, y + 14, 2, 1.5)
    
    -- Horse neck and head
    if self.isPaladin then
        love.graphics.setColor(0.9, 0.88, 0.85, 1)
    else
        love.graphics.setColor(0.45, 0.35, 0.28, 1)
    end
    love.graphics.polygon("fill", x + 10, y + 2, x + 18, y - 8, x + 20, y - 6, x + 14, y + 4)
    love.graphics.ellipse("fill", x + 20, y - 8, 5, 4)
    love.graphics.polygon("fill", x + 18, y - 12, x + 20, y - 16, x + 22, y - 11)
    
    -- Mane
    local maneColor = self.isPaladin and {0.95, 0.92, 0.88, 1} or {0.25, 0.2, 0.15, 1}
    love.graphics.setColor(unpack(maneColor))
    love.graphics.polygon("fill", x + 12, y - 2, x + 16, y - 10, x + 18, y - 6, x + 14, y + 2)
    love.graphics.polygon("fill", x - 14, y + 2, x - 18, y + 8, x - 14, y + 10, x - 12, y + 6)
    
    -- Saddle
    if self.isPaladin then
        love.graphics.setColor(0.8, 0.7, 0.2, 1)
    else
        love.graphics.setColor(0.5, 0.25, 0.15, 1)
    end
    love.graphics.ellipse("fill", x, y - 2, 8, 5)
    
    -- Rider armor
    if self.isPaladin then
        love.graphics.setColor(0.8, 0.75, 0.65, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
    end
    love.graphics.rectangle("fill", x - 5, y - 14, 10, 12, 2)
    
    -- Cape
    if self.isPaladin then
        love.graphics.setColor(0.9, 0.85, 0.3, 1)
    else
        love.graphics.setColor(0.6, 0.2, 0.2, 1)
    end
    love.graphics.polygon("fill", x - 4, y - 10, x - 10, y + 4, x - 2, y + 2)
    
    -- Head/helmet
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.ellipse("fill", x, y - 18, 5, 6)
    
    -- Helmet plume
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.9, 0.4, 1)
    else
        love.graphics.setColor(0.7, 0.15, 0.15, 1)
    end
    love.graphics.polygon("fill", x - 2, y - 24, x + 4, y - 28, x + 2, y - 18)
    
    -- Lance
    love.graphics.setColor(0.5, 0.4, 0.3, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(x + 8, y - 8, x + 20, y - 30)
    love.graphics.setColor(0.7, 0.7, 0.75, 1)
    love.graphics.polygon("fill", x + 19, y - 30, x + 21, y - 30, x + 20, y - 36)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Knight:drawOnMinimap(mapX, mapY, scale)
    if self.isPaladin then
        love.graphics.setColor(0.9, 0.85, 0.3, 1)
    else
        love.graphics.setColor(0.4, 0.4, 0.7, 1)
    end
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.circle("fill", mmX, mmY, math.max(2, 3))
end

return Knight
