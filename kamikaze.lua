--[[
    Kamikaze
    Fast-moving demolition unit
    Size: 1x1 tile, circular collision
    Combat not implemented - just moves around fast
]]

local FlowField = require("flowfield")

local Kamikaze = {}
Kamikaze.__index = Kamikaze

Kamikaze.STATE_IDLE = "Idle"
Kamikaze.STATE_MOVING = "Moving"
Kamikaze.RADIUS = 12

function Kamikaze.new(params)
    local self = setmetatable({}, Kamikaze)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Kamikaze.RADIUS
    self.speed = 160  -- Very fast!
    self.selected = false
    self.type = "kamikaze"
    self.name = "Kamikaze"
    self.state = Kamikaze.STATE_IDLE
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    
    -- Animation
    self.fusePhase = 0
    
    return self
end

function Kamikaze:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Kamikaze:getBuildingPenetration(x, y, building)
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

function Kamikaze:canMoveTo(newX, newY, buildings)
    if self.map and not self.map:isWorldPosPassable(newX, newY) then
        return false
    end
    
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

function Kamikaze:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
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
    
    if self:canMoveTo(newX, self.worldY, buildings) then
        self.worldX = newX
        return true
    end
    if self:canMoveTo(self.worldX, newY, buildings) then
        self.worldY = newY
        return true
    end
    
    if self.lastMoveDirX and self.lastMoveDirY then
        local lastX = self.worldX + self.lastMoveDirX * moveSpeed
        local lastY = self.worldY + self.lastMoveDirY * moveSpeed
        if self:canMoveTo(lastX, lastY, buildings) then
            self.worldX = lastX
            self.worldY = lastY
            return true
        end
    end
    
    local cardinals = {
        {dx = 1, dy = 0}, {dx = -1, dy = 0},
        {dx = 0, dy = 1}, {dx = 0, dy = -1}
    }
    table.sort(cardinals, function(a, b)
        local dotA = a.dx * moveDirX + a.dy * moveDirY
        local dotB = b.dx * moveDirX + b.dy * moveDirY
        return dotA > dotB
    end)
    for _, dir in ipairs(cardinals) do
        local testX = self.worldX + dir.dx * moveSpeed
        local testY = self.worldY + dir.dy * moveSpeed
        if self:canMoveTo(testX, testY, buildings) then
            self.worldX = testX
            self.worldY = testY
            return true
        end
    end
    
    return false
end

function Kamikaze:getMoveDirection(targetWorldX, targetWorldY, buildings)
    if self.flowField then
        local dirX, dirY = self.flowField:getDirection(self.worldX, self.worldY, self.map)
        if dirX and dirY then
            return dirX, dirY
        end
    end
    
    local currentCost = math.huge
    if self.flowField then
        currentCost = self.flowField:getCost(self.worldX, self.worldY, self.map) or math.huge
    end
    
    local sampleOffsets = {
        {dx = 32, dy = 0}, {dx = -32, dy = 0},
        {dx = 0, dy = 32}, {dx = 0, dy = -32},
        {dx = 32, dy = 32}, {dx = -32, dy = 32},
        {dx = 32, dy = -32}, {dx = -32, dy = -32},
    }
    
    local bestDirX, bestDirY = nil, nil
    local bestCost = currentCost
    
    for _, offset in ipairs(sampleOffsets) do
        local sampleX = self.worldX + offset.dx
        local sampleY = self.worldY + offset.dy
        
        if self.map:isWorldPosPassable(sampleX, sampleY) then
            local sampleCost = self.flowField and self.flowField:getCost(sampleX, sampleY, self.map)
            if sampleCost and sampleCost < bestCost then
                bestCost = sampleCost
                local toSampleX = sampleX - self.worldX
                local toSampleY = sampleY - self.worldY
                local dist = math.sqrt(toSampleX * toSampleX + toSampleY * toSampleY)
                if dist > 0.1 then
                    bestDirX = toSampleX / dist
                    bestDirY = toSampleY / dist
                end
            end
        end
    end
    
    if bestDirX and bestDirY then
        return bestDirX, bestDirY
    end
    
    local dx = targetWorldX - self.worldX
    local dy = targetWorldY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > 0.1 then
        return dx / dist, dy / dist
    end
    
    return nil, nil
end

function Kamikaze:update(dt, buildings)
    -- Animate fuse
    self.fusePhase = self.fusePhase + dt * 8
    
    if self.state == Kamikaze.STATE_MOVING then
        self:updateMoving(dt, buildings)
    end
end

function Kamikaze:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Kamikaze.STATE_IDLE
        return
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 8 then
        self.state = Kamikaze.STATE_IDLE
        self.targetX = nil
        self.targetY = nil
        self.flowField = nil
        return
    end
    
    local moveDirX, moveDirY = self:getMoveDirection(self.targetX, self.targetY, buildings)
    
    if not moveDirX or not moveDirY then
        return
    end
    
    local moveSpeed = self.speed * dt
    self:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
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
    love.graphics.ellipse("fill", x, y + 10, 10, 4)
    
    -- Feet (running pose)
    love.graphics.setColor(0.4, 0.32, 0.22, 1)
    love.graphics.ellipse("fill", x - 6, y + 7, 4, 3)
    love.graphics.ellipse("fill", x + 6, y + 7, 4, 3)
    
    -- Legs
    love.graphics.setColor(0.5, 0.4, 0.3, 1)
    love.graphics.rectangle("fill", x - 7, y + 1, 5, 8, 1)
    love.graphics.rectangle("fill", x + 2, y + 1, 5, 8, 1)
    
    -- Body
    love.graphics.setColor(0.55, 0.35, 0.25, 1)
    love.graphics.rectangle("fill", x - 6, y - 8, 12, 12, 2)
    
    -- Barrel/bomb on back
    love.graphics.setColor(0.3, 0.28, 0.25, 1)
    love.graphics.ellipse("fill", x, y - 4, 8, 10)
    -- Barrel bands
    love.graphics.setColor(0.4, 0.38, 0.4, 1)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", x, y - 8, 8, 3)
    love.graphics.ellipse("line", x, y, 8, 3)
    
    -- Danger symbol on barrel
    love.graphics.setColor(0.9, 0.3, 0.2, 1)
    love.graphics.polygon("fill", x, y - 10, x - 4, y - 3, x + 4, y - 3)
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", x - 1, y - 8, 2, 3)
    love.graphics.circle("fill", x, y - 4, 1)
    
    -- Fuse on top
    love.graphics.setColor(0.6, 0.55, 0.45, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y - 14, x + 3, y - 18)
    
    -- Fuse spark (animated)
    local sparkBrightness = 0.5 + math.sin(self.fusePhase) * 0.5
    love.graphics.setColor(1, 0.8 * sparkBrightness, 0.2 * sparkBrightness, 1)
    love.graphics.circle("fill", x + 3, y - 18, 3)
    love.graphics.setColor(1, 0.6 * sparkBrightness, 0.1 * sparkBrightness, 0.6)
    love.graphics.circle("fill", x + 3, y - 18, 5)
    -- Spark particles
    love.graphics.setColor(1, 0.9, 0.3, sparkBrightness)
    love.graphics.circle("fill", x + 5 + math.sin(self.fusePhase * 1.3) * 2, y - 20, 1)
    love.graphics.circle("fill", x + 1 + math.cos(self.fusePhase * 1.7) * 2, y - 21, 1)
    
    -- Arms (holding fuse rope)
    love.graphics.setColor(0.85, 0.7, 0.55, 1)
    love.graphics.rectangle("fill", x - 10, y - 6, 5, 6, 1)
    love.graphics.rectangle("fill", x + 5, y - 6, 5, 6, 1)
    -- Hands
    love.graphics.circle("fill", x - 8, y, 3)
    love.graphics.circle("fill", x + 8, y, 3)
    
    -- Head
    love.graphics.setColor(0.85, 0.7, 0.55, 1)
    love.graphics.ellipse("fill", x, y - 14, 5, 6)
    
    -- Headband (red)
    love.graphics.setColor(0.9, 0.25, 0.2, 1)
    love.graphics.rectangle("fill", x - 6, y - 17, 12, 3, 1)
    -- Headband tails
    love.graphics.polygon("fill", x + 6, y - 17, x + 12, y - 14, x + 10, y - 12, x + 6, y - 14)
    love.graphics.polygon("fill", x + 8, y - 16, x + 14, y - 12, x + 11, y - 10, x + 8, y - 13)
    
    -- Face - determined expression
    love.graphics.setColor(0, 0, 0, 1)
    -- Angry eyebrows
    love.graphics.setLineWidth(1.5)
    love.graphics.line(x - 4, y - 16, x - 2, y - 15)
    love.graphics.line(x + 4, y - 16, x + 2, y - 15)
    -- Eyes
    love.graphics.circle("fill", x - 2, y - 14, 1.5)
    love.graphics.circle("fill", x + 2, y - 14, 1.5)
    -- Gritted teeth
    love.graphics.setColor(0.9, 0.9, 0.85, 1)
    love.graphics.rectangle("fill", x - 3, y - 11, 6, 2)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.line(x - 2, y - 11, x - 2, y - 9)
    love.graphics.line(x, y - 11, x, y - 9)
    love.graphics.line(x + 2, y - 11, x + 2, y - 9)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Kamikaze:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Kamikaze:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Kamikaze:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    self.state = Kamikaze.STATE_MOVING
end

function Kamikaze:getStateText()
    return self.state
end

function Kamikaze:updateUI(resources, screenW, screenH, font) end
function Kamikaze:drawUI() end
function Kamikaze:mousepressed(x, y, button) end
function Kamikaze:mousereleased(x, y, button) end

function Kamikaze:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.9, 0.4, 0.3, 1)
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.5))
end

return Kamikaze
