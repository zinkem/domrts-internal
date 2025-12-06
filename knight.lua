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
    
    -- Desert Warrior color palette
    local tealDark = {0.10, 0.25, 0.35}
    local tealMid = {0.15, 0.40, 0.50}
    local tealLight = {0.25, 0.55, 0.65}
    local goldDark = {0.45, 0.35, 0.15}
    local goldMid = {0.72, 0.58, 0.22}
    local goldLight = {0.92, 0.78, 0.35}
    local skin = {0.82, 0.65, 0.50}
    local sand = {0.75, 0.65, 0.50}
    local sandDark = {0.55, 0.45, 0.35}
    
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
    love.graphics.ellipse("fill", x, y + 12, 14, 5)
    
    -- Horse body (desert horse - sandy colored, white for paladin)
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.92, 0.88, 1)  -- White/cream horse
    else
        love.graphics.setColor(sand[1], sand[2], sand[3], 1)  -- Sandy horse
    end
    love.graphics.ellipse("fill", x, y + 4, 14, 8)
    
    -- Horse legs
    local legColor = self.isPaladin and {0.9, 0.88, 0.85, 1} or {sandDark[1], sandDark[2], sandDark[3], 1}
    love.graphics.setColor(unpack(legColor))
    love.graphics.rectangle("fill", x - 8, y + 6, 3, 8, 1)
    love.graphics.rectangle("fill", x - 3, y + 7, 3, 7, 1)
    love.graphics.rectangle("fill", x + 3, y + 7, 3, 7, 1)
    love.graphics.rectangle("fill", x + 8, y + 6, 3, 8, 1)
    
    -- Gold leg guards on horse
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 0.8)
    love.graphics.rectangle("fill", x - 8, y + 10, 3, 2)
    love.graphics.rectangle("fill", x + 8, y + 10, 3, 2)
    
    -- Hooves
    love.graphics.setColor(0.25, 0.22, 0.2, 1)
    love.graphics.ellipse("fill", x - 7, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x - 2, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x + 4, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x + 9, y + 14, 2, 1.5)
    
    -- Horse neck and head
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.92, 0.88, 1)
    else
        love.graphics.setColor(sand[1], sand[2], sand[3], 1)
    end
    love.graphics.polygon("fill", x + 10, y + 2, x + 18, y - 8, x + 20, y - 6, x + 14, y + 4)
    love.graphics.ellipse("fill", x + 20, y - 8, 5, 4)
    love.graphics.polygon("fill", x + 18, y - 12, x + 20, y - 16, x + 22, y - 11)
    
    -- Horse eye
    love.graphics.setColor(0.15, 0.1, 0.05, 1)
    love.graphics.circle("fill", x + 21, y - 9, 1)
    
    -- Mane (dark brown/black flowing)
    love.graphics.setColor(0.2, 0.15, 0.1, 1)
    love.graphics.polygon("fill", x + 12, y - 2, x + 16, y - 10, x + 18, y - 6, x + 14, y + 2)
    -- Tail
    love.graphics.polygon("fill", x - 14, y + 2, x - 18, y + 8, x - 14, y + 10, x - 12, y + 6)
    
    -- Horse decorations (gold bridle)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(x + 18, y - 6, x + 24, y - 8)
    love.graphics.circle("fill", x + 18, y - 7, 2)
    
    -- Teal horse blanket under saddle
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.polygon("fill", x - 10, y - 2, x + 10, y - 2, x + 12, y + 6, x - 12, y + 6)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.rectangle("fill", x - 10, y + 4, 20, 2)  -- Gold trim
    
    -- Saddle (gold/bronze)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.ellipse("fill", x, y - 2, 8, 5)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.5)
    love.graphics.ellipse("fill", x - 2, y - 3, 4, 2)
    
    -- Rider armor (gold breastplate)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.rectangle("fill", x - 5, y - 14, 10, 12, 2)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.6)
    love.graphics.rectangle("fill", x - 4, y - 13, 8, 4, 1)
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.line(x, y - 14, x, y - 3)
    
    -- Cape (teal for knight, gold for paladin)
    if self.isPaladin then
        love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    else
        love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    end
    love.graphics.polygon("fill", x - 4, y - 10, x - 12, y + 4, x - 2, y + 2)
    -- Cape highlight
    if self.isPaladin then
        love.graphics.setColor(1, 0.95, 0.6, 0.5)
    else
        love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 0.5)
    end
    love.graphics.polygon("fill", x - 4, y - 10, x - 8, y, x - 3, y - 2)
    
    -- Head/helmet (gold)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.ellipse("fill", x, y - 18, 5, 6)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.6)
    love.graphics.arc("fill", x, y - 19, 4, math.pi, math.pi * 1.8)
    
    -- Helmet plume (teal for knight, gold/white for paladin)
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.92, 0.85, 1)
    else
        love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    end
    love.graphics.polygon("fill", x - 2, y - 24, x + 4, y - 28, x + 2, y - 18)
    
    -- Lance (gold-tipped)
    love.graphics.setColor(0.45, 0.35, 0.25, 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(x + 8, y - 8, x + 20, y - 30)
    -- Gold tip
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 1)
    love.graphics.polygon("fill", x + 19, y - 30, x + 21, y - 30, x + 20, y - 36)
    -- Gold bands on lance
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 12, y - 16, x + 14, y - 18)
    
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
