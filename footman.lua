--[[
    Footman
    Military unit that can move around the map
    Cannot enter mines, buildings, or traverse trees
    Size: 1x1 tile, circular collision
]]

local FlowField = require("flowfield")

local Footman = {}
Footman.__index = Footman

Footman.STATE_IDLE = "Idle"
Footman.STATE_MOVING = "Moving"
Footman.RADIUS = 14

function Footman.new(params)
    local self = setmetatable({}, Footman)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Footman.RADIUS
    self.speed = 100
    self.selected = false
    self.type = "footman"
    self.name = "Footman"
    self.state = Footman.STATE_IDLE
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil  -- Flow field for pathfinding
    self.lastMoveDirX = nil  -- Track last successful move for corner navigation
    self.lastMoveDirY = nil
    
    return self
end

function Footman:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Footman:wouldCollideWithBuilding(x, y, building)
    if not building.getWorldBounds then return false end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    return (distX * distX + distY * distY) < (self.radius * self.radius)
end

function Footman:getBuildingPenetration(x, y, building)
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

function Footman:canMoveTo(newX, newY, buildings)
    -- Check tree collision
    if self.map and not self.map:isWorldPosPassable(newX, newY) then
        return false
    end
    
    if not buildings then return true end
    
    for _, b in ipairs(buildings) do
        local currentPen = self:getBuildingPenetration(self.worldX, self.worldY, b)
        local newPen = self:getBuildingPenetration(newX, newY, b)
        
        if newPen > 0 then
            if currentPen > 0 then
                -- Already inside - only allow if reducing penetration
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

-- Try to move in the given direction, with sliding and cardinal fallbacks
function Footman:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
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
    
    -- Corner case: try momentum
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
    
    -- Last resort: try cardinals sorted by alignment with intended direction
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
    
    -- Corner escape: try larger steps to clear tight corners
    local escapeStep = self.radius * 0.5
    for _, dir in ipairs(cardinals) do
        local testX = self.worldX + dir.dx * escapeStep
        local testY = self.worldY + dir.dy * escapeStep
        if self:canMoveTo(testX, testY, buildings) then
            self.worldX = testX
            self.worldY = testY
            self.lastMoveDirX = dir.dx
            self.lastMoveDirY = dir.dy
            return true
        end
    end
    
    -- Final escape: try diagonals
    local diagonals = {
        {dx = 1, dy = 1}, {dx = -1, dy = 1},
        {dx = 1, dy = -1}, {dx = -1, dy = -1}
    }
    table.sort(diagonals, function(a, b)
        local dotA = a.dx * moveDirX + a.dy * moveDirY
        local dotB = b.dx * moveDirX + b.dy * moveDirY
        return dotA > dotB
    end)
    for _, dir in ipairs(diagonals) do
        local testX = self.worldX + dir.dx * escapeStep * 0.707
        local testY = self.worldY + dir.dy * escapeStep * 0.707
        if self:canMoveTo(testX, testY, buildings) then
            self.worldX = testX
            self.worldY = testY
            self.lastMoveDirX = dir.dx
            self.lastMoveDirY = dir.dy
            return true
        end
    end
    
    -- Truly stuck
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    return false
end

-- Get flow field direction, with fallback to sample nearby tiles if current tile has no direction
-- Get movement direction using flow field with nearby tile sampling fallback
function Footman:getMoveDirection(targetWorldX, targetWorldY, buildings)
    -- First, try flow field at current position
    if self.flowField then
        local dirX, dirY = self.flowField:getDirection(self.worldX, self.worldY, self.map)
        if dirX and dirY then
            return dirX, dirY
        end
    end
    
    -- Flow field returned nil - sample nearby tiles to find one with lower cost
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
    
    -- No better nearby tile - use direct movement
    local dx = targetWorldX - self.worldX
    local dy = targetWorldY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > 0.1 then
        return dx / dist, dy / dist
    end
    
    return nil, nil
end

function Footman:update(dt, buildings)
    if self.state == Footman.STATE_MOVING then
        self:updateMoving(dt, buildings)
    end
end

function Footman:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Footman.STATE_IDLE
        return
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 8 then
        self.state = Footman.STATE_IDLE
        self.targetX = nil
        self.targetY = nil
        self.flowField = nil
        return
    end
    
    -- Get movement direction (flow field with fallback)
    local moveDirX, moveDirY = self:getMoveDirection(self.targetX, self.targetY, buildings)
    
    if not moveDirX or not moveDirY then
        return
    end
    
    -- Movement with sliding and cardinal fallbacks
    local moveSpeed = self.speed * dt
    self:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
end

function Footman:draw()
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
    
    -- Feet (armored boots)
    love.graphics.setColor(0.4, 0.4, 0.45, 1)
    love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
    
    -- Legs (chainmail/armor)
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.rectangle("fill", x - 6, y + 1, 5, 9, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 9, 1)
    
    -- Shield (left side)
    love.graphics.setColor(0.6, 0.2, 0.2, 1)  -- Red shield
    love.graphics.ellipse("fill", x - 12, y - 2, 6, 10)
    love.graphics.setColor(0.8, 0.75, 0.2, 1)  -- Gold trim
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", x - 12, y - 2, 6, 10)
    -- Shield emblem (lion/cross)
    love.graphics.setColor(0.9, 0.85, 0.3, 1)
    love.graphics.rectangle("fill", x - 13, y - 6, 2, 8)
    love.graphics.rectangle("fill", x - 15, y - 3, 6, 2)
    
    -- Body (chainmail)
    love.graphics.setColor(0.55, 0.55, 0.6, 1)
    love.graphics.rectangle("fill", x - 7, y - 8, 14, 12, 2)
    
    -- Tabard (red cloth over armor)
    love.graphics.setColor(0.7, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", x - 5, y - 6, 10, 10, 1)
    -- Tabard emblem
    love.graphics.setColor(0.9, 0.8, 0.2, 1)
    love.graphics.rectangle("fill", x - 1, y - 5, 2, 8)
    love.graphics.rectangle("fill", x - 3, y - 2, 6, 2)
    
    -- Shoulders (pauldrons)
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.ellipse("fill", x - 9, y - 6, 4, 3)
    love.graphics.ellipse("fill", x + 9, y - 6, 4, 3)
    
    -- Sword arm (right)
    love.graphics.setColor(0.55, 0.55, 0.6, 1)
    love.graphics.rectangle("fill", x + 6, y - 6, 5, 10, 1)
    
    -- Gauntlet/hand
    love.graphics.setColor(0.45, 0.45, 0.5, 1)
    love.graphics.circle("fill", x + 9, y + 4, 3)
    
    -- Sword
    love.graphics.setColor(0.5, 0.4, 0.25, 1)  -- Handle
    love.graphics.rectangle("fill", x + 11, y, 2, 8, 1)
    love.graphics.setColor(0.75, 0.7, 0.6, 1)  -- Blade
    love.graphics.polygon("fill", 
        x + 10, y - 2,
        x + 14, y - 2,
        x + 13, y - 16,
        x + 11, y - 16
    )
    love.graphics.setColor(0.9, 0.85, 0.5, 1)  -- Cross guard
    love.graphics.rectangle("fill", x + 8, y - 2, 8, 3, 1)
    
    -- Head/Helmet
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.ellipse("fill", x, y - 12, 7, 8)
    
    -- Helmet visor
    love.graphics.setColor(0.4, 0.4, 0.45, 1)
    love.graphics.rectangle("fill", x - 5, y - 14, 10, 5, 1)
    
    -- Visor slit (eyes)
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", x - 4, y - 13, 8, 2)
    
    -- Helmet crest/plume
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.ellipse("fill", x, y - 20, 3, 6)
    love.graphics.setColor(0.9, 0.25, 0.25, 1)
    love.graphics.ellipse("fill", x, y - 21, 2, 4)
    
    -- Helmet highlight
    love.graphics.setColor(0.7, 0.7, 0.75, 0.5)
    love.graphics.arc("fill", x - 2, y - 14, 4, math.pi, math.pi * 1.5)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Footman:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Footman:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Footman:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    self.state = Footman.STATE_MOVING
end

function Footman:getStateText()
    return self.state
end

function Footman:updateUI(resources, screenW, screenH, font) end
function Footman:drawUI() end
function Footman:mousepressed(x, y, button) end
function Footman:mousereleased(x, y, button) end

function Footman:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.8, 0.3, 0.3, 1)
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.5))
end

return Footman
