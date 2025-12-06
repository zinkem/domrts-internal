--[[
    Ballista - Slow siege weapon
    Inherits from Unit base class
]]

local Unit = require("unit")

local Ballista = setmetatable({}, {__index = Unit})
Ballista.__index = Ballista

Ballista.RADIUS = 18  -- Larger siege weapon
Ballista.SPEED = 40   -- Very slow

function Ballista.new(params)
    local self = Unit.new(params)
    setmetatable(self, Ballista)
    
    self.radius = Ballista.RADIUS
    self.speed = Ballista.SPEED
    self.type = "ballista"
    self.name = "Ballista"
    
    return self
end

function Ballista:draw()
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
    love.graphics.ellipse("fill", x, y + 10, 16, 6)
    
    -- Wheels
    love.graphics.setColor(0.4, 0.3, 0.2, 1)
    love.graphics.circle("fill", x - 12, y + 8, 6)
    love.graphics.circle("fill", x + 12, y + 8, 6)
    love.graphics.setColor(0.3, 0.25, 0.18, 1)
    love.graphics.circle("fill", x - 12, y + 8, 3)
    love.graphics.circle("fill", x + 12, y + 8, 3)
    -- Wheel spokes
    love.graphics.setLineWidth(2)
    love.graphics.line(x - 16, y + 8, x - 8, y + 8)
    love.graphics.line(x - 12, y + 4, x - 12, y + 12)
    love.graphics.line(x + 8, y + 8, x + 16, y + 8)
    love.graphics.line(x + 12, y + 4, x + 12, y + 12)
    
    -- Base frame
    love.graphics.setColor(0.45, 0.35, 0.25, 1)
    love.graphics.rectangle("fill", x - 14, y - 2, 28, 10, 2)
    
    -- Crossbow arms
    love.graphics.setColor(0.5, 0.4, 0.3, 1)
    love.graphics.setLineWidth(4)
    love.graphics.line(x - 18, y - 8, x, y + 2)
    love.graphics.line(x + 18, y - 8, x, y + 2)
    
    -- Bowstring
    love.graphics.setColor(0.7, 0.65, 0.55, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x - 18, y - 8, x, y - 4)
    love.graphics.line(x + 18, y - 8, x, y - 4)
    
    -- Bolt
    love.graphics.setColor(0.5, 0.4, 0.3, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(x, y - 4, x, y - 20)
    -- Bolt head
    love.graphics.setColor(0.6, 0.6, 0.65, 1)
    love.graphics.polygon("fill", x - 3, y - 20, x + 3, y - 20, x, y - 26)
    -- Fletching
    love.graphics.setColor(0.7, 0.2, 0.2, 1)
    love.graphics.polygon("fill", x - 4, y - 6, x, y - 4, x - 4, y - 2)
    love.graphics.polygon("fill", x + 4, y - 6, x, y - 4, x + 4, y - 2)
    
    -- Aiming mechanism
    love.graphics.setColor(0.55, 0.5, 0.55, 1)
    love.graphics.rectangle("fill", x - 3, y, 6, 6, 1)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Ballista:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.6, 0.5, 0.3, 1)
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.rectangle("fill", mmX - 2, mmY - 2, 4, 4)
end

return Ballista
