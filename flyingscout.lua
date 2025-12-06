--[[
    Flying Scout - Aerial unit that ignores terrain
    Inherits from Unit base class
    Special: Can fly over trees and water, only buildings block
]]

local Unit = require("unit")

local FlyingScout = setmetatable({}, {__index = Unit})
FlyingScout.__index = FlyingScout

FlyingScout.RADIUS = 12
FlyingScout.SPEED = 110

function FlyingScout.new(params)
    local self = Unit.new(params)
    setmetatable(self, FlyingScout)
    
    self.radius = FlyingScout.RADIUS
    self.speed = FlyingScout.SPEED
    self.type = "flyingscout"
    self.name = "Flying Scout"
    
    -- Animation
    self.wingPhase = 0
    self.bobPhase = math.random() * math.pi * 2
    
    return self
end

-- Override canMoveTo: Flying units ignore terrain, only check buildings and bounds
function FlyingScout:canMoveTo(newX, newY, buildings)
    -- Check map bounds only (not passability)
    if self.map then
        local mapWidth = self.map.width * self.map.tileSize
        local mapHeight = self.map.height * self.map.tileSize
        if newX < self.radius or newX > mapWidth - self.radius or
           newY < self.radius or newY > mapHeight - self.radius then
            return false
        end
    end
    
    -- Still check building collision
    if buildings then
        for _, building in ipairs(buildings) do
            local currentPen = self:getBuildingPenetration(self.worldX, self.worldY, building)
            local newPen = self:getBuildingPenetration(newX, newY, building)
            
            if newPen > 0 and currentPen == 0 then
                return false
            end
            if newPen > 0 and currentPen > 0 and newPen >= currentPen then
                return false
            end
        end
    end
    
    return true
end

function FlyingScout:update(dt, buildings)
    -- Animate
    self.wingPhase = (self.wingPhase or 0) + dt * 15
    self.bobPhase = (self.bobPhase or 0) + dt * 3
    
    -- Call parent update
    Unit.update(self, dt, buildings)
end

function FlyingScout:draw()
    local x, y = self:getScreenPos()
    
    -- Desert Warrior color palette
    local tealDark = {0.10, 0.25, 0.35}
    local tealMid = {0.15, 0.40, 0.50}
    local tealLight = {0.25, 0.55, 0.65}
    local goldDark = {0.45, 0.35, 0.15}
    local goldMid = {0.72, 0.58, 0.22}
    local goldLight = {0.92, 0.78, 0.35}
    local sand = {0.75, 0.65, 0.50}
    local sandDark = {0.55, 0.45, 0.35}
    
    -- Bobbing effect
    local bobOffset = math.sin(self.bobPhase or 0) * 3
    y = y + bobOffset
    
    -- Selection circle
    if self.selected then
        love.graphics.setColor(0.3, 0.7, 0.8, 0.4)
        love.graphics.circle("fill", x, y, self.radius + 4)
        love.graphics.setColor(0.3, 0.8, 0.9, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end
    
    -- Shadow on ground (doesn't bob)
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.ellipse("fill", x, y - bobOffset + 15, 8, 3)
    
    -- Wing animation
    local wingAngle = math.sin(self.wingPhase or 0) * 0.4
    
    -- Wings (teal feathers with gold tips)
    -- Left wing
    love.graphics.push()
    love.graphics.translate(x - 4, y)
    love.graphics.rotate(-0.3 + wingAngle)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.ellipse("fill", -8, 0, 12, 5)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 0.7)
    love.graphics.ellipse("fill", -6, -1, 8, 3)
    -- Gold tips
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.ellipse("fill", -16, 0, 4, 2)
    love.graphics.pop()
    
    -- Right wing
    love.graphics.push()
    love.graphics.translate(x + 4, y)
    love.graphics.rotate(0.3 - wingAngle)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.ellipse("fill", 8, 0, 12, 5)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 0.7)
    love.graphics.ellipse("fill", 6, -1, 8, 3)
    -- Gold tips
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.ellipse("fill", 16, 0, 4, 2)
    love.graphics.pop()
    
    -- Body (sandy/gold falcon body)
    love.graphics.setColor(sand[1], sand[2], sand[3], 1)
    love.graphics.ellipse("fill", x, y, 6, 10)
    -- Chest markings
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.6)
    love.graphics.ellipse("fill", x, y - 2, 4, 5)
    
    -- Head (desert falcon)
    love.graphics.setColor(sandDark[1], sandDark[2], sandDark[3], 1)
    love.graphics.circle("fill", x, y - 10, 5)
    -- White face markings (like a falcon)
    love.graphics.setColor(0.95, 0.92, 0.88, 1)
    love.graphics.arc("fill", x, y - 10, 4, math.pi * 0.7, math.pi * 1.3)
    
    -- Beak (gold)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.polygon("fill", x, y - 10, x + 7, y - 11, x, y - 8)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.6)
    love.graphics.line(x + 1, y - 10, x + 5, y - 10.5)
    
    -- Eye (fierce falcon eye)
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.circle("fill", x - 1, y - 11, 1.5)
    love.graphics.setColor(goldLight[1], goldLight[2], goldLight[3], 0.8)
    love.graphics.circle("fill", x - 1.5, y - 11.5, 0.5)
    
    -- Teal crest/head feathers
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.polygon("fill", x - 2, y - 14, x + 2, y - 14, x, y - 18)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 1)
    love.graphics.polygon("fill", x - 1, y - 14, x + 1, y - 14, x, y - 16)
    
    -- Tail feathers (teal)
    love.graphics.setColor(tealMid[1], tealMid[2], tealMid[3], 1)
    love.graphics.polygon("fill", x - 3, y + 8, x + 3, y + 8, x, y + 14)
    love.graphics.setColor(tealLight[1], tealLight[2], tealLight[3], 0.7)
    love.graphics.polygon("fill", x - 1, y + 8, x + 1, y + 8, x, y + 12)
    
    -- Gold leg band (shows it's trained)
    love.graphics.setColor(goldMid[1], goldMid[2], goldMid[3], 1)
    love.graphics.rectangle("fill", x - 2, y + 6, 4, 2)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function FlyingScout:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.6, 0.8, 0.9, 1)
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.circle("fill", mmX, mmY, math.max(2, 3))
end

return FlyingScout
