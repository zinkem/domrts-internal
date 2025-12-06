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
    
    -- Desert Warrior color palette
    local tealDark = {0.10, 0.25, 0.35}
    local tealMid = {0.15, 0.40, 0.50}
    local tealLight = {0.25, 0.55, 0.65}
    local goldDark = {0.45, 0.35, 0.15}
    local goldMid = {0.72, 0.58, 0.22}
    local goldLight = {0.92, 0.78, 0.35}
    local skin = {0.82, 0.65, 0.50}
    local leather = {0.40, 0.30, 0.20}
    
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
    love.graphics.ellipse("fill", x, y + 10, 11, 4)
    
    -- Feet (strappy sandals)
    love.graphics.setColor(leather[1], leather[2], leather[3], 1)
    love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 0.7)
    love.graphics.ellipse("line", x - 5, y + 8, 4, 3)
    
    -- Legs (teal flowing pants)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.rectangle("fill", x - 6, y + 1, 5, 9, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 9, 1)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 0.4)
    love.graphics.rectangle("fill", x - 5, y + 2, 2, 7, 1)
    
    -- Quiver on back (ornate with gold trim)
    love.graphics.setColor(leather[1], leather[2], leather[3], 1)
    love.graphics.rectangle("fill", x + 5, y - 12, 7, 18, 2)
    -- Gold trim on quiver
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.rectangle("fill", x + 5, y - 12, 7, 2)
    love.graphics.rectangle("fill", x + 5, y + 4, 7, 2)
    -- Arrow shafts
    love.graphics.setColor(0.6, 0.5, 0.35, 1)
    love.graphics.line(x + 7, y - 14, x + 7, y - 18)
    love.graphics.line(x + 9, y - 13, x + 9, y - 17)
    love.graphics.line(x + 11, y - 14, x + 11, y - 19)
    -- Arrow fletching (teal feathers)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    love.graphics.polygon("fill", x + 6, y - 18, x + 8, y - 18, x + 7, y - 20)
    love.graphics.polygon("fill", x + 8, y - 17, x + 10, y - 17, x + 9, y - 19)
    love.graphics.polygon("fill", x + 10, y - 19, x + 12, y - 19, x + 11, y - 21)
    
    -- Body (teal tunic with gold trim)
    love.graphics.setColor(tealDark[1], tealDark[2], tealDark[3], 1)
    love.graphics.rectangle("fill", x - 7, y - 8, 14, 12, 2)
    -- Gold chest plate (lighter armor for mobility)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 0.8)
    love.graphics.rectangle("fill", x - 5, y - 6, 10, 6, 1)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.5)
    love.graphics.rectangle("fill", x - 4, y - 5, 8, 2, 1)
    
    -- Belt (gold)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.rectangle("fill", x - 7, y, 14, 3)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.rectangle("fill", x - 2, y, 4, 3)
    
    -- Left arm (holding bow)
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.rectangle("fill", x - 11, y - 2, 4, 8, 1)
    love.graphics.circle("fill", x - 10, y + 6, 3)
    -- Gold bracer
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.rectangle("fill", x - 11, y + 2, 4, 3)
    
    -- Right hand
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.circle("fill", x + 9, y + 6, 3)
    
    -- Bow (ornate gold-inlaid)
    love.graphics.setColor(leather[1] + 0.1, leather[2] + 0.05, leather[3], 1)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", x - 14, y - 2, 10, math.pi * 0.5, math.pi * 1.5, 12)
    -- Gold inlay on bow
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.arc("line", x - 14, y - 2, 9, math.pi * 0.6, math.pi * 1.4, 8)
    -- Bowstring
    love.graphics.setColor(0.85, 0.8, 0.7, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x - 14, y - 12, x - 14, y + 8)
    
    -- Head
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.ellipse("fill", x, y - 12, 6, 7)
    
    -- Hair (teal/blue flowing)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.arc("fill", x, y - 12, 7, math.pi, 2 * math.pi)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    love.graphics.ellipse("fill", x + 5, y - 14, 4, 2)
    love.graphics.ellipse("fill", x + 8, y - 12, 3, 2)
    
    -- Gold headband with gem
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.rectangle("fill", x - 6, y - 14, 12, 2)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    love.graphics.circle("fill", x, y - 13, 1.5)  -- Gem
    
    -- Face
    love.graphics.setColor(0.15, 0.1, 0.05, 1)
    love.graphics.circle("fill", x - 2, y - 12, 1.5)
    love.graphics.circle("fill", x + 2, y - 12, 1.5)
    
    -- Decorative feather (teal)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    love.graphics.polygon("fill", x + 3, y - 16, x + 5, y - 23, x + 4, y - 16)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.line(x + 4, y - 16, x + 4.5, y - 21)
    
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
