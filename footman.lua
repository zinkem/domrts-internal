--[[
    Footman - Basic melee soldier
    Inherits from Unit base class
]]

local Unit = require("unit")

local Footman = setmetatable({}, {__index = Unit})
Footman.__index = Footman

-- Class constants
Footman.RADIUS = 14
Footman.SPEED = 70

function Footman.new(params)
    local self = Unit.new(params)
    setmetatable(self, Footman)
    
    self.radius = Footman.RADIUS
    self.speed = Footman.SPEED
    self.type = "footman"
    self.name = "Footman"
    
    return self
end

function Footman:draw()
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
    love.graphics.ellipse("fill", x, y + 10, 11, 4)
    
    -- Feet (leather boots)
    love.graphics.setColor(0.4, 0.3, 0.2, 1)
    love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
    
    -- Legs (chainmail)
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.rectangle("fill", x - 6, y + 1, 5, 9, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 9, 1)
    
    -- Shield on left arm
    love.graphics.setColor(0.6, 0.3, 0.15, 1)
    love.graphics.ellipse("fill", x - 12, y - 2, 6, 10)
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", x - 12, y - 2, 6, 10)
    love.graphics.setColor(0.8, 0.7, 0.2, 1)
    love.graphics.circle("fill", x - 12, y - 2, 3)
    
    -- Body (chainmail)
    love.graphics.setColor(0.55, 0.55, 0.6, 1)
    love.graphics.rectangle("fill", x - 7, y - 8, 14, 12, 2)
    
    -- Belt
    love.graphics.setColor(0.45, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", x - 7, y, 14, 3)
    love.graphics.setColor(0.6, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", x - 2, y, 4, 3)
    
    -- Right arm holding sword
    love.graphics.setColor(0.55, 0.55, 0.6, 1)
    love.graphics.ellipse("fill", x + 9, y - 4, 3, 5)
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.rectangle("fill", x + 7, y - 2, 4, 8, 1)
    
    -- Hand
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.circle("fill", x + 9, y + 6, 3)
    
    -- Sword
    love.graphics.setColor(0.7, 0.7, 0.75, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(x + 9, y + 4, x + 9, y - 14)
    love.graphics.setColor(0.5, 0.4, 0.25, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 9, y + 4, x + 9, y + 8)
    love.graphics.setColor(0.7, 0.6, 0.3, 1)
    love.graphics.line(x + 5, y + 4, x + 13, y + 4)
    
    -- Head
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.ellipse("fill", x, y - 12, 6, 7)
    
    -- Helmet
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.arc("fill", x, y - 14, 7, math.pi, 2 * math.pi)
    love.graphics.rectangle("fill", x - 1, y - 14, 2, 6)
    
    -- Eyes
    love.graphics.setColor(0.2, 0.15, 0.1, 1)
    love.graphics.circle("fill", x - 3, y - 12, 1.5)
    love.graphics.circle("fill", x + 3, y - 12, 1.5)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Footman:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.3, 0.7, 0.4, 1)
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.circle("fill", mmX, mmY, math.max(2, 3))
end

return Footman
