--[[
    Archer - Ranged unit with bow
    Inherits from Unit base class
]]

local Unit = require("unit")

local Archer = setmetatable({}, {__index = Unit})
Archer.__index = Archer

Archer.RADIUS = 14
Archer.SPEED = 80

function Archer.new(params)
    local self = Unit.new(params)
    setmetatable(self, Archer)
    
    self.radius = Archer.RADIUS
    self.speed = Archer.SPEED
    self.type = "archer"
    self.name = "Archer"
    
    return self
end

function Archer:draw()
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
    
    -- Feet
    love.graphics.setColor(0.45, 0.35, 0.25, 1)
    love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
    
    -- Legs
    love.graphics.setColor(0.35, 0.45, 0.35, 1)
    love.graphics.rectangle("fill", x - 6, y + 1, 5, 9, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 9, 1)
    
    -- Quiver on back
    love.graphics.setColor(0.5, 0.38, 0.25, 1)
    love.graphics.rectangle("fill", x + 5, y - 12, 7, 18, 2)
    love.graphics.setColor(0.55, 0.45, 0.3, 1)
    love.graphics.line(x + 7, y - 14, x + 7, y - 18)
    love.graphics.line(x + 9, y - 13, x + 9, y - 17)
    love.graphics.line(x + 11, y - 14, x + 11, y - 19)
    love.graphics.setColor(0.7, 0.2, 0.2, 1)
    love.graphics.polygon("fill", x + 6, y - 18, x + 8, y - 18, x + 7, y - 20)
    love.graphics.polygon("fill", x + 8, y - 17, x + 10, y - 17, x + 9, y - 19)
    
    -- Body (green tunic)
    love.graphics.setColor(0.25, 0.45, 0.3, 1)
    love.graphics.rectangle("fill", x - 7, y - 8, 14, 12, 2)
    
    -- Belt
    love.graphics.setColor(0.45, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", x - 7, y, 14, 3)
    love.graphics.setColor(0.6, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", x - 2, y, 4, 3)
    
    -- Arms
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.rectangle("fill", x - 11, y - 2, 4, 8, 1)
    love.graphics.circle("fill", x - 10, y + 6, 3)
    love.graphics.circle("fill", x + 9, y + 6, 3)
    
    -- Bow
    love.graphics.setColor(0.5, 0.35, 0.2, 1)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", x - 14, y - 2, 10, math.pi * 0.5, math.pi * 1.5, 12)
    love.graphics.setColor(0.8, 0.75, 0.65, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x - 14, y - 12, x - 14, y + 8)
    
    -- Head
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.ellipse("fill", x, y - 12, 6, 7)
    
    -- Hood
    love.graphics.setColor(0.2, 0.38, 0.25, 1)
    love.graphics.arc("fill", x, y - 12, 7, math.pi, 2 * math.pi)
    love.graphics.polygon("fill", x - 7, y - 12, x + 7, y - 12, x, y - 22)
    
    -- Face
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", x - 2, y - 13, 1.5)
    love.graphics.circle("fill", x + 2, y - 13, 1.5)
    
    -- Feather
    love.graphics.setColor(0.8, 0.2, 0.15, 1)
    love.graphics.polygon("fill", x + 3, y - 18, x + 6, y - 25, x + 4, y - 18)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Archer:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.2, 0.6, 0.3, 1)
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.circle("fill", mmX, mmY, math.max(2, 3))
end

return Archer
