--[[
    Knight
    Mounted military unit produced at Barracks (requires Stable)
    Can be upgraded to Paladin (visual change only)
    Size: 1x1 tile, circular collision (slightly larger due to horse)
]]

local FlowField = require("flowfield")

local Knight = {}
Knight.__index = Knight

Knight.STATE_IDLE = "Idle"
Knight.STATE_MOVING = "Moving"
Knight.RADIUS = 16  -- Slightly larger than footman due to horse

function Knight.new(params)
    local self = setmetatable({}, Knight)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Knight.RADIUS
    self.speed = 130  -- Faster than footman (mounted)
    self.selected = false
    self.type = "knight"
    self.name = "Knight"
    self.state = Knight.STATE_IDLE
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    
    -- Paladin status (visual only)
    self.isPaladin = params.isPaladin or false
    if self.isPaladin then
        self.name = "Paladin"
    end
    
    return self
end

function Knight:upgradeToPaladin()
    self.isPaladin = true
    self.name = "Paladin"
end

function Knight:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Knight:wouldCollideWithBuilding(x, y, building)
    if not building.getWorldBounds then return false end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    return (distX * distX + distY * distY) < (self.radius * self.radius)
end

function Knight:getBuildingPenetration(x, y, building)
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

function Knight:canMoveTo(newX, newY, buildings)
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

function Knight:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
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

function Knight:getMoveDirection(targetWorldX, targetWorldY, buildings)
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

function Knight:update(dt, buildings)
    if self.state == Knight.STATE_MOVING then
        self:updateMoving(dt, buildings)
    end
end

function Knight:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Knight.STATE_IDLE
        return
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 8 then
        self.state = Knight.STATE_IDLE
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

function Knight:draw()
    local x, y = self:getScreenPos()
    
    -- Selection circle
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.circle("fill", x, y, self.radius + 4)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end
    
    -- Shadow (larger for horse)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x, y + 12, 14, 5)
    
    -- Horse body
    if self.isPaladin then
        love.graphics.setColor(0.9, 0.88, 0.85, 1)  -- White horse for paladin
    else
        love.graphics.setColor(0.45, 0.35, 0.28, 1)  -- Brown horse
    end
    love.graphics.ellipse("fill", x, y + 4, 14, 8)
    
    -- Horse legs
    love.graphics.setColor(0.35, 0.28, 0.22, 1)
    if self.isPaladin then
        love.graphics.setColor(0.8, 0.78, 0.75, 1)
    end
    love.graphics.rectangle("fill", x - 8, y + 6, 3, 8, 1)
    love.graphics.rectangle("fill", x - 3, y + 7, 3, 7, 1)
    love.graphics.rectangle("fill", x + 3, y + 7, 3, 7, 1)
    love.graphics.rectangle("fill", x + 8, y + 6, 3, 8, 1)
    
    -- Hooves
    love.graphics.setColor(0.25, 0.22, 0.2, 1)
    love.graphics.ellipse("fill", x - 7, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x - 2, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x + 4, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x + 9, y + 14, 2, 1.5)
    
    -- Horse neck and head
    if self.isPaladin then
        love.graphics.setColor(0.9, 0.88, 0.85, 1)
    else
        love.graphics.setColor(0.45, 0.35, 0.28, 1)
    end
    love.graphics.polygon("fill",
        x + 10, y + 2,
        x + 18, y - 8,
        x + 20, y - 6,
        x + 14, y + 4
    )
    -- Horse head
    love.graphics.ellipse("fill", x + 20, y - 8, 5, 4)
    -- Ear
    love.graphics.polygon("fill", x + 18, y - 12, x + 20, y - 16, x + 22, y - 11)
    
    -- Horse mane
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.92, 0.88, 1)
    else
        love.graphics.setColor(0.25, 0.2, 0.15, 1)
    end
    love.graphics.polygon("fill", x + 12, y - 2, x + 16, y - 10, x + 18, y - 6, x + 14, y + 2)
    
    -- Horse tail
    love.graphics.polygon("fill", x - 14, y + 2, x - 18, y + 8, x - 14, y + 10, x - 12, y + 6)
    
    -- Saddle
    if self.isPaladin then
        love.graphics.setColor(0.8, 0.7, 0.2, 1)  -- Gold saddle
    else
        love.graphics.setColor(0.5, 0.25, 0.15, 1)  -- Brown saddle
    end
    love.graphics.ellipse("fill", x, y - 2, 8, 5)
    
    -- Rider body (armor)
    if self.isPaladin then
        love.graphics.setColor(0.8, 0.75, 0.65, 1)  -- Shiny silver
    else
        love.graphics.setColor(0.5, 0.5, 0.55, 1)  -- Regular steel
    end
    love.graphics.rectangle("fill", x - 5, y - 14, 10, 12, 2)
    
    -- Rider cape
    if self.isPaladin then
        love.graphics.setColor(0.9, 0.85, 0.3, 1)  -- Gold cape
    else
        love.graphics.setColor(0.6, 0.2, 0.2, 1)  -- Red cape
    end
    love.graphics.polygon("fill", x - 4, y - 10, x - 10, y + 4, x - 2, y + 2)
    
    -- Tabard/surcoat
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.9, 0.4, 1)  -- Bright gold
        -- Cross emblem for paladin
        love.graphics.setColor(0.9, 0.85, 0.3, 1)
    else
        love.graphics.setColor(0.7, 0.15, 0.15, 1)
    end
    love.graphics.rectangle("fill", x - 3, y - 12, 6, 8, 1)
    
    -- Cross on tabard (paladin gets bigger cross)
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.92, 0.85, 1)
        love.graphics.rectangle("fill", x - 1, y - 11, 2, 6)
        love.graphics.rectangle("fill", x - 2, y - 9, 4, 2)
    else
        love.graphics.setColor(0.9, 0.8, 0.2, 1)
        love.graphics.rectangle("fill", x - 0.5, y - 10, 1, 4)
        love.graphics.rectangle("fill", x - 1.5, y - 8, 3, 1)
    end
    
    -- Pauldrons (shoulders)
    if self.isPaladin then
        love.graphics.setColor(0.85, 0.8, 0.7, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
    end
    love.graphics.ellipse("fill", x - 6, y - 12, 3, 2.5)
    love.graphics.ellipse("fill", x + 6, y - 12, 3, 2.5)
    
    -- Helmet
    if self.isPaladin then
        love.graphics.setColor(0.85, 0.8, 0.7, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
    end
    love.graphics.ellipse("fill", x, y - 18, 5, 6)
    
    -- Visor slit
    love.graphics.setColor(0.15, 0.15, 0.2, 1)
    love.graphics.rectangle("fill", x - 3, y - 19, 6, 2)
    
    -- Helmet plume
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.9, 0.4, 1)  -- Gold plume
    else
        love.graphics.setColor(0.8, 0.2, 0.2, 1)  -- Red plume
    end
    love.graphics.ellipse("fill", x, y - 26, 3, 6)
    
    -- Lance/weapon
    love.graphics.setColor(0.5, 0.4, 0.25, 1)
    love.graphics.rectangle("fill", x + 8, y - 22, 2, 28, 1)
    -- Lance tip
    love.graphics.setColor(0.7, 0.7, 0.75, 1)
    love.graphics.polygon("fill", x + 7, y - 22, x + 11, y - 22, x + 9, y - 28)
    
    -- Shield on left side
    if self.isPaladin then
        love.graphics.setColor(0.85, 0.8, 0.25, 1)  -- Gold shield
    else
        love.graphics.setColor(0.6, 0.2, 0.2, 1)  -- Red shield
    end
    love.graphics.ellipse("fill", x - 10, y - 8, 5, 7)
    -- Shield emblem
    if self.isPaladin then
        love.graphics.setColor(0.95, 0.92, 0.85, 1)
        love.graphics.rectangle("fill", x - 11, y - 10, 2, 5)
        love.graphics.rectangle("fill", x - 12, y - 8, 4, 2)
    else
        love.graphics.setColor(0.9, 0.8, 0.2, 1)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", x - 10, y - 8, 3, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Knight:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Knight:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Knight:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    self.state = Knight.STATE_MOVING
end

function Knight:getStateText()
    return self.state
end

function Knight:updateUI(resources, screenW, screenH, font) end
function Knight:drawUI() end
function Knight:mousepressed(x, y, button) end
function Knight:mousereleased(x, y, button) end

function Knight:drawOnMinimap(mapX, mapY, scale)
    if self.isPaladin then
        love.graphics.setColor(0.9, 0.8, 0.3, 1)
    else
        love.graphics.setColor(0.6, 0.45, 0.35, 1)
    end
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.6))
end

return Knight
