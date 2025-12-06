--[[
    Flying Scout
    Aerial unit that ignores terrain collision (can fly over trees)
    Still collides with buildings
    Size: 1x1 tile, circular collision
]]

local FlowField = require("flowfield")

local FlyingScout = {}
FlyingScout.__index = FlyingScout

FlyingScout.STATE_IDLE = "Idle"
FlyingScout.STATE_MOVING = "Moving"
FlyingScout.RADIUS = 12

function FlyingScout.new(params)
    local self = setmetatable({}, FlyingScout)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = FlyingScout.RADIUS
    self.speed = 120  -- Fast flyer
    self.selected = false
    self.type = "flyingscout"
    self.name = "Flying Scout"
    self.state = FlyingScout.STATE_IDLE
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    
    -- Animation
    self.wingPhase = 0
    self.bobPhase = math.random() * math.pi * 2
    
    return self
end

function FlyingScout:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function FlyingScout:getBuildingPenetration(x, y, building)
    if not building.getWorldBounds then return 0 end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    local dist = math.sqrt(distX * distX + distY * distY)
    if dist < self.radius then
        return self.radius - dist
    end
    return 0
end

-- Flying units ignore terrain but still respect buildings and map bounds
function FlyingScout:canMoveTo(newX, newY, buildings)
    -- Check map bounds
    if self.map then
        local mapWidth = self.map.width * self.map.tileSize
        local mapHeight = self.map.height * self.map.tileSize
        if newX < self.radius or newX > mapWidth - self.radius or
           newY < self.radius or newY > mapHeight - self.radius then
            return false
        end
    end
    
    -- Check building collision (flying units still can't go through buildings)
    if not buildings then return true end
    
    for _, b in ipairs(buildings) do
        local currentPen = self:getBuildingPenetration(self.worldX, self.worldY, b)
        local newPen = self:getBuildingPenetration(newX, newY, b)
        
        if newPen > 0 then
            if currentPen > 0 then
                if newPen >= currentPen then
                    return false
                end
            else
                return false
            end
        end
    end
    
    return true
end

function FlyingScout:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
    local moveX = moveDirX * moveSpeed
    local moveY = moveDirY * moveSpeed
    local newX = self.worldX + moveX
    local newY = self.worldY + moveY
    
    if self:canMoveTo(newX, newY, buildings) then
        self.worldX = newX
        self.worldY = newY
        self.lastMoveDirX = moveDirX
        self.lastMoveDirY = moveDirY
        return true
    end
    
    -- Try sliding around buildings
    if self:canMoveTo(newX, self.worldY, buildings) then
        self.worldX = newX
        return true
    end
    if self:canMoveTo(self.worldX, newY, buildings) then
        self.worldY = newY
        return true
    end
    
    return false
end

function FlyingScout:update(dt, buildings)
    -- Animate wings and bobbing
    self.wingPhase = self.wingPhase + dt * 15
    self.bobPhase = self.bobPhase + dt * 3
    
    if self.state == FlyingScout.STATE_MOVING then
        self:updateMoving(dt, buildings)
    end
end

function FlyingScout:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = FlyingScout.STATE_IDLE
        return
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 8 then
        self.state = FlyingScout.STATE_IDLE
        self.targetX = nil
        self.targetY = nil
        self.flowField = nil
        return
    end
    
    -- Flying units use direct movement (no pathfinding needed for terrain)
    local moveDirX = dx / dist
    local moveDirY = dy / dist
    
    local moveSpeed = self.speed * dt
    self:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
end

function FlyingScout:draw()
    local x, y = self:getScreenPos()
    
    -- Bobbing effect
    local bobOffset = math.sin(self.bobPhase) * 3
    y = y + bobOffset
    
    -- Selection circle
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.circle("fill", x, y, self.radius + 4)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end
    
    -- Shadow on ground (offset and smaller to show height)
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.ellipse("fill", x + 5, y + 20 - bobOffset, 8, 3)
    
    -- Wing flap animation
    local wingAngle = math.sin(self.wingPhase) * 0.4
    
    -- Left wing
    love.graphics.setColor(0.5, 0.55, 0.6, 1)
    love.graphics.push()
    love.graphics.translate(x - 4, y)
    love.graphics.rotate(-0.3 + wingAngle)
    love.graphics.ellipse("fill", -10, 0, 12, 4)
    love.graphics.pop()
    
    -- Right wing
    love.graphics.push()
    love.graphics.translate(x + 4, y)
    love.graphics.rotate(0.3 - wingAngle)
    love.graphics.ellipse("fill", 10, 0, 12, 4)
    love.graphics.pop()
    
    -- Wing detail (feathers)
    love.graphics.setColor(0.45, 0.5, 0.55, 1)
    love.graphics.push()
    love.graphics.translate(x - 4, y)
    love.graphics.rotate(-0.3 + wingAngle)
    love.graphics.ellipse("fill", -8, 0, 8, 2)
    love.graphics.pop()
    
    love.graphics.push()
    love.graphics.translate(x + 4, y)
    love.graphics.rotate(0.3 - wingAngle)
    love.graphics.ellipse("fill", 8, 0, 8, 2)
    love.graphics.pop()
    
    -- Body
    love.graphics.setColor(0.55, 0.5, 0.45, 1)
    love.graphics.ellipse("fill", x, y, 6, 10)
    
    -- Head
    love.graphics.setColor(0.6, 0.55, 0.5, 1)
    love.graphics.circle("fill", x, y - 8, 5)
    
    -- Beak
    love.graphics.setColor(0.8, 0.6, 0.2, 1)
    love.graphics.polygon("fill", x, y - 8, x + 6, y - 7, x, y - 5)
    
    -- Eyes
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.circle("fill", x - 2, y - 9, 1.5)
    love.graphics.circle("fill", x + 2, y - 9, 1.5)
    
    -- Eye shine
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", x - 1.5, y - 9.5, 0.5)
    love.graphics.circle("fill", x + 2.5, y - 9.5, 0.5)
    
    -- Tail feathers
    love.graphics.setColor(0.5, 0.45, 0.4, 1)
    love.graphics.polygon("fill", x - 3, y + 8, x, y + 15, x + 3, y + 8)
    love.graphics.setColor(0.45, 0.4, 0.35, 1)
    love.graphics.polygon("fill", x - 1, y + 8, x, y + 13, x + 1, y + 8)
    
    -- Rider/scout on back (small figure)
    love.graphics.setColor(0.4, 0.5, 0.4, 1)  -- Green cloak
    love.graphics.ellipse("fill", x, y - 2, 4, 5)
    -- Head
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.circle("fill", x, y - 6, 3)
    -- Goggles
    love.graphics.setColor(0.3, 0.25, 0.2, 1)
    love.graphics.ellipse("fill", x - 1.5, y - 6, 2, 1.5)
    love.graphics.ellipse("fill", x + 1.5, y - 6, 2, 1.5)
    love.graphics.setColor(0.5, 0.6, 0.7, 0.8)
    love.graphics.ellipse("fill", x - 1.5, y - 6, 1.5, 1)
    love.graphics.ellipse("fill", x + 1.5, y - 6, 1.5, 1)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function FlyingScout:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function FlyingScout:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function FlyingScout:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.flowField = flowField  -- Not really used but kept for consistency
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    self.state = FlyingScout.STATE_MOVING
end

function FlyingScout:getStateText()
    return self.state
end

function FlyingScout:updateUI(resources, screenW, screenH, font) end
function FlyingScout:drawUI() end
function FlyingScout:mousepressed(x, y, button) end
function FlyingScout:mousereleased(x, y, button) end

function FlyingScout:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.5, 0.6, 0.7, 1)
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.5))
end

return FlyingScout
