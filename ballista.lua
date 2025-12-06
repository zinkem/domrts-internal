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
    
    -- Desert Warrior color palette
    local tealDark = {0.10, 0.25, 0.35}
    local tealMid = {0.15, 0.40, 0.50}
    local tealLight = {0.25, 0.55, 0.65}
    local goldDark = {0.45, 0.35, 0.15}
    local goldMid = {0.72, 0.58, 0.22}
    local goldLight = {0.92, 0.78, 0.35}
    local wood = {0.50, 0.38, 0.25}
    local woodDark = {0.35, 0.25, 0.15}
    
    -- Selection circle
    if self.selected then
        love.graphics.setColor(0.3, 0.7, 0.8, 0.4)
        love.graphics.circle("fill", x, y, self.radius + 4)
        love.graphics.setColor(0.3, 0.8, 0.9, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x, y + 10, 16, 6)
    
    -- Wheels (wood with gold hub)
    love.graphics.setColor(wood[1], wood[2], wood[3], 1)
    love.graphics.circle("fill", x - 12, y + 8, 6)
    love.graphics.circle("fill", x + 12, y + 8, 6)
    -- Gold hubs
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.circle("fill", x - 12, y + 8, 2.5)
    love.graphics.circle("fill", x + 12, y + 8, 2.5)
    -- Wheel spokes
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x - 16, y + 8, x - 8, y + 8)
    love.graphics.line(x - 12, y + 4, x - 12, y + 12)
    love.graphics.line(x + 8, y + 8, x + 16, y + 8)
    love.graphics.line(x + 12, y + 4, x + 12, y + 12)
    -- Gold wheel rims
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", x - 12, y + 8, 6)
    love.graphics.circle("line", x + 12, y + 8, 6)
    
    -- Base frame (wood with gold trim)
    love.graphics.setColor(wood[1], wood[2], wood[3], 1)
    love.graphics.rectangle("fill", x - 14, y - 2, 28, 10, 2)
    -- Gold trim
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.rectangle("fill", x - 14, y - 2, 28, 2)
    love.graphics.rectangle("fill", x - 14, y + 6, 28, 2)
    
    -- Teal banner on side
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.polygon("fill", x - 16, y - 2, x - 14, y - 2, x - 14, y + 8, x - 18, y + 10)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x - 16, y - 2, x - 14, y - 2)
    
    -- Crossbow arms (gold-reinforced)
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    love.graphics.setLineWidth(5)
    love.graphics.line(x - 18, y - 8, x, y + 2)
    love.graphics.line(x + 18, y - 8, x, y + 2)
    -- Gold bands on arms
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x - 14, y - 5, x - 12, y - 3)
    love.graphics.line(x + 14, y - 5, x + 12, y - 3)
    -- Gold tips
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.circle("fill", x - 18, y - 8, 3)
    love.graphics.circle("fill", x + 18, y - 8, 3)
    
    -- Bowstring
    love.graphics.setColor(0.75, 0.70, 0.60, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x - 18, y - 8, x, y - 4)
    love.graphics.line(x + 18, y - 8, x, y - 4)
    
    -- Bolt (gold-tipped)
    love.graphics.setColor(wood[1], wood[2], wood[3], 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(x, y - 4, x, y - 20)
    -- Gold bolt head
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.polygon("fill", x - 3, y - 20, x + 3, y - 20, x, y - 28)
    love.graphics.setColor(0.85, 0.85, 0.9, 0.6)
    love.graphics.line(x - 1, y - 21, x, y - 26)
    -- Teal fletching
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    love.graphics.polygon("fill", x - 4, y - 6, x, y - 4, x - 4, y - 2)
    love.graphics.polygon("fill", x + 4, y - 6, x, y - 4, x + 4, y - 2)
    
    -- Aiming mechanism (gold)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.rectangle("fill", x - 3, y, 6, 6, 1)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.5)
    love.graphics.rectangle("fill", x - 2, y + 1, 4, 2, 1)
    
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
