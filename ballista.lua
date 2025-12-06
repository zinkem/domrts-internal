--[[
    Ballista
    Slow-moving siege weapon
    Size: 1x1 tile (larger visual), circular collision
    Combat not implemented - just moves around
]]

local FlowField = require("flowfield")

local Ballista = {}
Ballista.__index = Ballista

Ballista.STATE_IDLE = "Idle"
Ballista.STATE_MOVING = "Moving"
Ballista.RADIUS = 18  -- Larger collision

function Ballista.new(params)
    local self = setmetatable({}, Ballista)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Ballista.RADIUS
    self.speed = 40  -- Very slow
    self.selected = false
    self.type = "ballista"
    self.name = "Ballista"
    self.state = Ballista.STATE_IDLE
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    
    return self
end

function Ballista:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Ballista:getBuildingPenetration(x, y, building)
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

function Ballista:canMoveTo(newX, newY, buildings)
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

function Ballista:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
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
        self.lastMoveDirX = moveDirX > 0 and 1 or -1
        self.lastMoveDirY = 0
        return true
    end
    if self:canMoveTo(self.worldX, newY, buildings) then
        self.worldY = newY
        self.lastMoveDirX = 0
        self.lastMoveDirY = moveDirY > 0 and 1 or -1
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
            self.lastMoveDirX = dir.dx
            self.lastMoveDirY = dir.dy
            return true
        end
    end
    
    return false
end

function Ballista:getMoveDirection(targetWorldX, targetWorldY, buildings)
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

function Ballista:update(dt, buildings)
    if self.state == Ballista.STATE_MOVING then
        self:updateMoving(dt, buildings)
    end
end

function Ballista:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Ballista.STATE_IDLE
        return
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 10 then
        self.state = Ballista.STATE_IDLE
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

function Ballista:draw()
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
    love.graphics.ellipse("fill", x, y + 14, 16, 5)
    
    -- Wheels
    love.graphics.setColor(0.45, 0.35, 0.22, 1)
    love.graphics.circle("fill", x - 14, y + 8, 8)
    love.graphics.circle("fill", x + 14, y + 8, 8)
    -- Wheel spokes
    love.graphics.setColor(0.38, 0.28, 0.18, 1)
    love.graphics.setLineWidth(2)
    for i = 0, 3 do
        local angle = i * math.pi / 4
        love.graphics.line(x - 14, y + 8, x - 14 + math.cos(angle) * 6, y + 8 + math.sin(angle) * 6)
        love.graphics.line(x + 14, y + 8, x + 14 + math.cos(angle) * 6, y + 8 + math.sin(angle) * 6)
    end
    -- Wheel hubs
    love.graphics.setColor(0.5, 0.45, 0.4, 1)
    love.graphics.circle("fill", x - 14, y + 8, 3)
    love.graphics.circle("fill", x + 14, y + 8, 3)
    
    -- Axle
    love.graphics.setColor(0.4, 0.32, 0.2, 1)
    love.graphics.rectangle("fill", x - 16, y + 6, 32, 4, 1)
    
    -- Main frame/base
    love.graphics.setColor(0.5, 0.4, 0.28, 1)
    love.graphics.rectangle("fill", x - 12, y - 4, 24, 12, 2)
    
    -- Side supports
    love.graphics.setColor(0.48, 0.38, 0.25, 1)
    love.graphics.polygon("fill", x - 10, y - 4, x - 14, y - 18, x - 8, y - 18, x - 6, y - 4)
    love.graphics.polygon("fill", x + 10, y - 4, x + 14, y - 18, x + 8, y - 18, x + 6, y - 4)
    
    -- Crossbar
    love.graphics.setColor(0.52, 0.42, 0.28, 1)
    love.graphics.rectangle("fill", x - 15, y - 20, 30, 5, 1)
    
    -- Bow arms (ballista arms)
    love.graphics.setColor(0.55, 0.45, 0.3, 1)
    love.graphics.polygon("fill", x - 15, y - 17, x - 28, y - 10, x - 26, y - 6, x - 13, y - 14)
    love.graphics.polygon("fill", x + 15, y - 17, x + 28, y - 10, x + 26, y - 6, x + 13, y - 14)
    
    -- Bowstring
    love.graphics.setColor(0.7, 0.65, 0.55, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x - 26, y - 8, x, y - 5, x + 26, y - 8)
    
    -- Bolt/projectile loaded
    love.graphics.setColor(0.45, 0.35, 0.22, 1)
    love.graphics.rectangle("fill", x - 2, y - 8, 20, 3, 1)
    -- Bolt tip
    love.graphics.setColor(0.6, 0.58, 0.62, 1)
    love.graphics.polygon("fill", x + 18, y - 9, x + 25, y - 6.5, x + 18, y - 4)
    -- Bolt fletching
    love.graphics.setColor(0.7, 0.25, 0.2, 1)
    love.graphics.polygon("fill", x - 2, y - 10, x - 6, y - 6.5, x - 2, y - 3)
    
    -- Trigger mechanism
    love.graphics.setColor(0.5, 0.48, 0.52, 1)
    love.graphics.rectangle("fill", x - 4, y, 8, 6, 1)
    love.graphics.setColor(0.55, 0.52, 0.55, 1)
    love.graphics.circle("fill", x, y + 3, 3)
    
    -- Winding mechanism (back)
    love.graphics.setColor(0.45, 0.42, 0.48, 1)
    love.graphics.circle("fill", x, y + 2, 5)
    love.graphics.setColor(0.4, 0.38, 0.42, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y + 2, 5)
    -- Handle
    love.graphics.setColor(0.5, 0.4, 0.28, 1)
    love.graphics.rectangle("fill", x + 4, y, 8, 3, 1)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Ballista:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Ballista:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Ballista:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    self.state = Ballista.STATE_MOVING
end

function Ballista:getStateText()
    return self.state
end

function Ballista:updateUI(resources, screenW, screenH, font) end
function Ballista:drawUI() end
function Ballista:mousepressed(x, y, button) end
function Ballista:mousereleased(x, y, button) end

function Ballista:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.6, 0.5, 0.35, 1)
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.rectangle("fill", x - scale * 0.4, y - scale * 0.4, scale * 0.8, scale * 0.8)
end

return Ballista
