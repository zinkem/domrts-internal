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
    love.graphics.ellipse("fill", x, y + 8, 10, 4)
    
    -- Feet
    love.graphics.setColor(0.4, 0.3, 0.2, 1)
    love.graphics.ellipse("fill", x - 4, y + 6, 3, 2)
    love.graphics.ellipse("fill", x + 4, y + 6, 3, 2)
    
    -- Legs
    love.graphics.setColor(0.5, 0.4, 0.35, 1)
    love.graphics.rectangle("fill", x - 5, y, 4, 7, 1)
    love.graphics.rectangle("fill", x + 1, y, 4, 7, 1)
    
    -- Body
    love.graphics.setColor(0.6, 0.5, 0.4, 1)
    love.graphics.rectangle("fill", x - 6, y - 8, 12, 10, 2)
    
    -- Arms holding barrel
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.rectangle("fill", x - 9, y - 6, 4, 6, 1)
    love.graphics.rectangle("fill", x + 5, y - 6, 4, 6, 1)
    
    -- Barrel (bomb)
    love.graphics.setColor(0.3, 0.25, 0.2, 1)
    love.graphics.ellipse("fill", x, y - 4, 8, 10)
    -- Barrel bands
    love.graphics.setColor(0.4, 0.35, 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", x, y - 4, 8, 0, math.pi, 8)
    love.graphics.arc("line", x, y - 8, 7, 0, math.pi, 8)
    
    -- Fuse
    love.graphics.setColor(0.6, 0.55, 0.45, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y - 14, x + 3, y - 18)
    
    -- Fuse spark (animated)
    local sparkBright = 0.5 + 0.5 * math.sin(self.fusePhase or 0)
    love.graphics.setColor(1, 0.8 * sparkBright, 0.2 * sparkBright, 1)
    love.graphics.circle("fill", x + 3, y - 18, 3)
    love.graphics.setColor(1, 0.5, 0.1, 0.5)
    love.graphics.circle("fill", x + 3, y - 18, 5)
    
    -- Head
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.ellipse("fill", x, y - 14, 5, 6)
    
    -- Crazy eyes
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", x - 2, y - 15, 2.5)
    love.graphics.circle("fill", x + 2, y - 15, 2.5)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", x - 2, y - 15, 1.5)
    love.graphics.circle("fill", x + 2, y - 15, 1.5)
    
    -- Headband
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x - 6, y - 18, 12, 3)
    -- Headband tail
    love.graphics.polygon("fill", x + 6, y - 17, x + 12, y - 15, x + 6, y - 15)
    
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
