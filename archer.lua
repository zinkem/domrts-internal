--[[
    Archer
    Ranged military unit that can move around the map
    Size: 1x1 tile, circular collision
    Behavior: Same as footman (moves, selectable), combat not implemented
]]

local FlowField = require("flowfield")

local Archer = {}
Archer.__index = Archer

Archer.STATE_IDLE = "Idle"
Archer.STATE_MOVING = "Moving"
Archer.RADIUS = 14

function Archer.new(params)
    local self = setmetatable({}, Archer)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Archer.RADIUS
    self.speed = 90  -- Slightly faster than footman
    self.selected = false
    self.type = "archer"
    self.name = "Archer"
    self.state = Archer.STATE_IDLE
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    
    return self
end

function Archer:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Archer:wouldCollideWithBuilding(x, y, building)
    if not building.getWorldBounds then return false end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    return (distX * distX + distY * distY) < (self.radius * self.radius)
end

function Archer:getBuildingPenetration(x, y, building)
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

function Archer:canMoveTo(newX, newY, buildings)
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

function Archer:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
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
    
    -- Try sliding
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
    
    -- Corner momentum
    if self.lastMoveDirX and self.lastMoveDirY then
        local lastX = self.worldX + self.lastMoveDirX * moveSpeed
        local lastY = self.worldY + self.lastMoveDirY * moveSpeed
        if self:canMoveTo(lastX, lastY, buildings) then
            self.worldX = lastX
            self.worldY = lastY
            return true
        end
        if self.lastMoveDirX ~= 0 and self:canMoveTo(lastX, self.worldY, buildings) then
            self.worldX = lastX
            self.lastMoveDirY = 0
            return true
        end
        if self.lastMoveDirY ~= 0 and self:canMoveTo(self.worldX, lastY, buildings) then
            self.worldY = lastY
            self.lastMoveDirX = 0
            return true
        end
    end
    
    -- Cardinal fallbacks
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
    
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    return false
end

function Archer:getMoveDirection(targetWorldX, targetWorldY, buildings)
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

function Archer:update(dt, buildings)
    if self.state == Archer.STATE_MOVING then
        self:updateMoving(dt, buildings)
    end
end

function Archer:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Archer.STATE_IDLE
        return
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 8 then
        self.state = Archer.STATE_IDLE
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

function Archer:draw()
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
    love.graphics.ellipse("fill", x, y + 10, 11, 4)
    
    -- Feet (leather boots)
    love.graphics.setColor(0.45, 0.35, 0.25, 1)
    love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
    
    -- Legs (cloth pants)
    love.graphics.setColor(0.35, 0.45, 0.35, 1)
    love.graphics.rectangle("fill", x - 6, y + 1, 5, 9, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 9, 1)
    
    -- Quiver on back
    love.graphics.setColor(0.5, 0.38, 0.25, 1)
    love.graphics.rectangle("fill", x + 5, y - 12, 7, 18, 2)
    -- Arrows in quiver
    love.graphics.setColor(0.55, 0.45, 0.3, 1)
    love.graphics.line(x + 7, y - 14, x + 7, y - 18)
    love.graphics.line(x + 9, y - 13, x + 9, y - 17)
    love.graphics.line(x + 11, y - 14, x + 11, y - 19)
    -- Arrow fletching
    love.graphics.setColor(0.7, 0.2, 0.2, 1)
    love.graphics.polygon("fill", x + 6, y - 18, x + 8, y - 18, x + 7, y - 20)
    love.graphics.polygon("fill", x + 8, y - 17, x + 10, y - 17, x + 9, y - 19)
    love.graphics.polygon("fill", x + 10, y - 19, x + 12, y - 19, x + 11, y - 21)
    
    -- Body (green tunic)
    love.graphics.setColor(0.25, 0.45, 0.3, 1)
    love.graphics.rectangle("fill", x - 7, y - 8, 14, 12, 2)
    
    -- Belt
    love.graphics.setColor(0.45, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", x - 7, y, 14, 3)
    love.graphics.setColor(0.6, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", x - 2, y, 4, 3)  -- Belt buckle
    
    -- Sleeves
    love.graphics.setColor(0.25, 0.45, 0.3, 1)
    love.graphics.ellipse("fill", x - 9, y - 4, 3, 5)
    love.graphics.ellipse("fill", x + 9, y - 4, 3, 5)
    
    -- Arms (skin)
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.rectangle("fill", x - 11, y - 2, 4, 8, 1)
    love.graphics.rectangle("fill", x + 7, y - 2, 4, 8, 1)
    
    -- Hands
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.circle("fill", x - 10, y + 6, 3)
    love.graphics.circle("fill", x + 9, y + 6, 3)
    
    -- Bow (held in left hand)
    love.graphics.setColor(0.5, 0.35, 0.2, 1)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", x - 14, y - 2, 10, math.pi * 0.5, math.pi * 1.5, 12)
    -- Bowstring
    love.graphics.setColor(0.8, 0.75, 0.65, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x - 14, y - 12, x - 14, y + 8)
    
    -- Head
    love.graphics.setColor(0.85, 0.72, 0.58, 1)
    love.graphics.ellipse("fill", x, y - 12, 6, 7)
    
    -- Hood/cap (green)
    love.graphics.setColor(0.2, 0.38, 0.25, 1)
    love.graphics.arc("fill", x, y - 12, 7, math.pi, 2 * math.pi)
    love.graphics.setColor(0.22, 0.4, 0.28, 1)
    love.graphics.polygon("fill", x - 7, y - 12, x + 7, y - 12, x, y - 22)
    
    -- Face details
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", x - 2, y - 13, 1.5)
    love.graphics.circle("fill", x + 2, y - 13, 1.5)
    love.graphics.setColor(0.7, 0.55, 0.45, 1)
    love.graphics.ellipse("fill", x, y - 10, 1.5, 1)
    
    -- Feather on hood
    love.graphics.setColor(0.8, 0.2, 0.15, 1)
    love.graphics.polygon("fill", x + 3, y - 18, x + 6, y - 25, x + 4, y - 18)
    love.graphics.setColor(0.9, 0.3, 0.2, 1)
    love.graphics.polygon("fill", x + 4, y - 18, x + 8, y - 23, x + 5, y - 18)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Archer:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Archer:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Archer:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    self.state = Archer.STATE_MOVING
end

function Archer:getStateText()
    return self.state
end

function Archer:updateUI(resources, screenW, screenH, font) end
function Archer:drawUI() end
function Archer:mousepressed(x, y, button) end
function Archer:mousereleased(x, y, button) end

function Archer:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.3, 0.7, 0.4, 1)
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.5))
end

return Archer
