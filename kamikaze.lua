--[[
    Kamikaze - Fast explosive unit
    Inherits from Unit base class
]]

local Unit = require("unit")

local Kamikaze = setmetatable({}, {__index = Unit})
Kamikaze.__index = Kamikaze

Kamikaze.RADIUS = 12
Kamikaze.SPEED = 100  -- Fast!

function Kamikaze.new(params)
    local self = Unit.new(params)
    setmetatable(self, Kamikaze)
    
    self.radius = Kamikaze.RADIUS
    self.speed = Kamikaze.SPEED
    self.type = "kamikaze"
    self.name = "Kamikaze"
    self.fusePhase = 0  -- For animated fuse
    
    return self
end

function Kamikaze:update(dt, buildings)
    -- Animate fuse
    self.fusePhase = (self.fusePhase or 0) + dt * 8
    
    -- Call parent update
    Unit.update(self, dt, buildings)
end

function Kamikaze:draw()
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
    love.graphics.ellipse("fill", x, y + 8, 10, 4)
    
    -- Feet (sandals)
    love.graphics.setColor(leather[1], leather[2], leather[3], 1)
    love.graphics.ellipse("fill", x - 4, y + 6, 3, 2)
    love.graphics.ellipse("fill", x + 4, y + 6, 3, 2)
    
    -- Legs (teal pants)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.rectangle("fill", x - 5, y, 4, 7, 1)
    love.graphics.rectangle("fill", x + 1, y, 4, 7, 1)
    
    -- Body (teal tunic)
    love.graphics.setColor(tealDark[1], tealDark[2], tealDark[3], 1)
    love.graphics.rectangle("fill", x - 6, y - 8, 12, 10, 2)
    -- Gold belt
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.rectangle("fill", x - 6, y - 1, 12, 2)
    
    -- Arms holding barrel
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.rectangle("fill", x - 9, y - 6, 4, 6, 1)
    love.graphics.rectangle("fill", x + 5, y - 6, 4, 6, 1)
    -- Gold bracers
    love.graphics.setColor(goldDark[1], goldDark[2], goldDark[3], 1)
    love.graphics.rectangle("fill", x - 9, y - 2, 4, 2)
    love.graphics.rectangle("fill", x + 5, y - 2, 4, 2)
    
    -- Barrel (bomb) - decorated with gold bands
    love.graphics.setColor(0.25, 0.2, 0.15, 1)
    love.graphics.ellipse("fill", x, y - 4, 8, 10)
    -- Gold barrel bands
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", x, y - 4, 8, 0, math.pi, 8)
    love.graphics.arc("line", x, y - 8, 7, 0, math.pi, 8)
    -- Danger symbol
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.8)
    love.graphics.polygon("fill", x - 3, y - 2, x + 3, y - 2, x, y - 7)
    
    -- Fuse
    love.graphics.setColor(0.6, 0.55, 0.45, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y - 14, x + 3, y - 18)
    
    -- Fuse spark (animated) - gold/orange
    local sparkBright = 0.5 + 0.5 * math.sin(self.fusePhase or 0)
    love.graphics.setColor(1, 0.7 + 0.2 * sparkBright, 0.2 * sparkBright, 1)
    love.graphics.circle("fill", x + 3, y - 18, 3)
    love.graphics.setColor(goldLight[1], goldLight[2] * sparkBright, 0.1, 0.5)
    love.graphics.circle("fill", x + 3, y - 18, 5)
    
    -- Head
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.ellipse("fill", x, y - 14, 5, 6)
    
    -- Teal hair
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.arc("fill", x, y - 14, 5, math.pi, 2 * math.pi)
    
    -- Determined eyes
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", x - 2, y - 15, 2)
    love.graphics.circle("fill", x + 2, y - 15, 2)
    love.graphics.setColor(0.1, 0.08, 0.05, 1)
    love.graphics.circle("fill", x - 2, y - 15, 1.2)
    love.graphics.circle("fill", x + 2, y - 15, 1.2)
    -- Fierce eyebrows
    love.graphics.setColor(tealDark[1], tealDark[2], tealDark[3], 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(x - 4, y - 17, x - 1, y - 16.5)
    love.graphics.line(x + 4, y - 17, x + 1, y - 16.5)
    
    -- Teal headband with gold emblem
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.rectangle("fill", x - 6, y - 18, 12, 3)
    -- Gold sun emblem on headband
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.circle("fill", x, y - 16.5, 2)
    -- Headband tail (flowing)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    love.graphics.polygon("fill", x + 6, y - 17, x + 14, y - 14, x + 6, y - 15)
    love.graphics.polygon("fill", x + 10, y - 15, x + 16, y - 13, x + 10, y - 13)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Kamikaze:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.8, 0.3, 0.2, 1)
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.circle("fill", mmX, mmY, math.max(2, 3))
end

return Kamikaze
