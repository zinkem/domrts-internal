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
    
    -- Desert Warrior color palette
    local tealDark = {0.10, 0.25, 0.35}
    local tealMid = {0.15, 0.40, 0.50}
    local tealLight = {0.25, 0.55, 0.65}
    local goldDark = {0.45, 0.35, 0.15}
    local goldMid = {0.72, 0.58, 0.22}
    local goldLight = {0.92, 0.78, 0.35}
    local skin = {0.82, 0.65, 0.50}
    local skinShadow = {0.65, 0.50, 0.38}
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
    love.graphics.ellipse("fill", x, y + 10, 12, 4)
    
    -- Feet (gold-trimmed sandals)
    love.graphics.setColor(leather[1], leather[2], leather[3], 1)
    love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.ellipse("line", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("line", x + 5, y + 8, 4, 3)
    
    -- Legs (teal flowing fabric)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.rectangle("fill", x - 6, y + 1, 5, 9, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 9, 1)
    -- Fabric highlight
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 0.5)
    love.graphics.rectangle("fill", x - 5, y + 2, 2, 7, 1)
    
    -- Shield on left arm (ornate bronze/gold)
    love.graphics.setColor(0.35, 0.28, 0.18, 1)  -- Dark bronze base
    love.graphics.ellipse("fill", x - 12, y - 2, 7, 11)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", x - 12, y - 2, 7, 11)
    -- Shield design (concentric)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.ellipse("line", x - 12, y - 2, 4, 7)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.circle("fill", x - 12, y - 2, 2.5)
    -- Shield highlight
    love.graphics.setColor(1, 0.9, 0.6, 0.4)
    love.graphics.arc("fill", x - 13, y - 4, 5, math.pi * 1.2, math.pi * 1.7)
    
    -- Body (gold breastplate over teal)
    love.graphics.setColor(tealDark[1], tealDark[2], tealDark[3], 1)
    love.graphics.rectangle("fill", x - 8, y - 8, 16, 12, 2)
    -- Gold armor plates
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.rectangle("fill", x - 6, y - 7, 12, 8, 2)
    -- Armor detail
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.6)
    love.graphics.rectangle("fill", x - 5, y - 6, 10, 2, 1)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.line(x, y - 7, x, y + 1)
    
    -- Belt (ornate gold)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.rectangle("fill", x - 7, y, 14, 3)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.rectangle("fill", x - 2, y, 4, 3)  -- Buckle
    love.graphics.setColor(0.4, 0.25, 0.1, 1)
    love.graphics.rectangle("fill", x - 1, y + 0.5, 2, 2)  -- Buckle center
    
    -- Shoulder pauldron (gold)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.ellipse("fill", x - 8, y - 6, 4, 3)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.5)
    love.graphics.arc("fill", x - 8, y - 7, 3, math.pi, math.pi * 1.5)
    
    -- Right arm holding sword
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.ellipse("fill", x + 8, y - 5, 4, 3)  -- Shoulder
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.rectangle("fill", x + 6, y - 2, 5, 8, 1)  -- Arm
    -- Gold bracer
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.rectangle("fill", x + 6, y + 2, 5, 3, 1)
    
    -- Hand
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.circle("fill", x + 9, y + 6, 3)
    
    -- Sword (curved scimitar style)
    love.graphics.setColor(0.75, 0.75, 0.8, 1)
    love.graphics.setLineWidth(3)
    -- Curved blade
    love.graphics.line(x + 9, y + 4, x + 7, y - 6, x + 9, y - 14)
    love.graphics.setColor(0.9, 0.9, 0.95, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 8, y + 2, x + 6, y - 5, x + 8, y - 12)
    -- Gold hilt
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 9, y + 4, x + 9, y + 7)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.line(x + 5, y + 4, x + 13, y + 4)  -- Crossguard
    
    -- Head
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.ellipse("fill", x, y - 12, 6, 7)
    
    -- Flowing blue hair (like the warrior)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.ellipse("fill", x, y - 15, 7, 5)
    -- Hair flowing back
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    love.graphics.ellipse("fill", x + 6, y - 14, 5, 3)
    love.graphics.ellipse("fill", x + 9, y - 12, 4, 2)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.ellipse("fill", x + 4, y - 15, 4, 3)
    
    -- Gold headband
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.rectangle("fill", x - 6, y - 15, 12, 2)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.circle("fill", x, y - 14, 2)  -- Center gem
    love.graphics.setColor(tealBright and tealBright[1] or 0.3, 0.7, 0.8, 1)
    love.graphics.circle("fill", x, y - 14, 1)  -- Gem highlight
    
    -- Eyes
    love.graphics.setColor(0.15, 0.1, 0.05, 1)
    love.graphics.circle("fill", x - 2, y - 12, 1.5)
    love.graphics.circle("fill", x + 2, y - 12, 1.5)
    
    -- Teal cloth flowing from belt
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 0.9)
    love.graphics.polygon("fill", x - 2, y + 3, x + 2, y + 3, x + 3, y + 10, x - 3, y + 10)
    
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
