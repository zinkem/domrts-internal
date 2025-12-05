--[[
    Peon
    Worker unit that moves, harvests gold, and builds structures
    Size: 1x1 tile, free movement (not grid-aligned), circular collision
]]

local Button = require("button")
local FlowField = require("flowfield")

local Peon = {}
Peon.__index = Peon

-- States
Peon.STATE_IDLE = "Idle"
Peon.STATE_MOVING = "Moving"
Peon.STATE_HARVESTING = "Harvesting"
Peon.STATE_RETURNING = "Returning"
Peon.STATE_CHOPPING = "Chopping"
Peon.STATE_BUILDING = "Building"

Peon.RADIUS = 14  -- Fits inside 1 tile (32x32 pixels)

function Peon.new(params)
    local self = setmetatable({}, Peon)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Peon.RADIUS
    self.speed = 60
    self.selected = false
    self.type = "peon"
    self.name = "Peon"
    self.state = Peon.STATE_IDLE
    
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil  -- Flow field for pathfinding
    self.lastMoveDirX = nil  -- Track last successful move for corner navigation
    self.lastMoveDirY = nil
    
    -- Gold harvesting
    self.carryingGold = 0
    self.harvestAmount = 10
    self.harvestTime = 1.0
    self.harvestTimer = 0
    self.targetMine = nil
    self.targetTownHall = nil
    self.visible = true
    
    -- Lumber harvesting
    self.carryingLumber = 0
    self.choppingAmount = 10
    self.choppingTime = 5.0
    self.choppingTimer = 0
    self.targetTreeX = nil
    self.targetTreeY = nil
    
    -- Building
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildingType = nil
    self.buildCallback = nil
    self.buildEntryX = nil  -- Position when entering building site
    self.buildEntryY = nil
    
    -- UI
    self.buildFarmButton = nil
    self.buildBarracksButton = nil
    
    return self
end

function Peon:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Peon:wouldCollideWithBuilding(x, y, building)
    if not building.getWorldBounds then return false end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    return (distX * distX + distY * distY) < (self.radius * self.radius)
end

function Peon:getBuildingPenetration(x, y, building)
    if not building.getWorldBounds then return 0 end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    local dist = math.sqrt(distX * distX + distY * distY)
    if dist < self.radius then
        return self.radius - dist  -- penetration depth
    end
    return 0
end

-- Check if peon is touching (adjacent to) a building without being inside
-- Returns true if peon is within contactBuffer pixels of building edge
function Peon:isTouchingBuilding(building, contactBuffer)
    contactBuffer = contactBuffer or 4
    if not building.getWorldBounds then return false end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(self.worldX, bx2))
    local closestY = math.max(by1, math.min(self.worldY, by2))
    local distX = self.worldX - closestX
    local distY = self.worldY - closestY
    local dist = math.sqrt(distX * distX + distY * distY)
    -- Touching means within radius + buffer distance of building edge
    return dist <= self.radius + contactBuffer
end

function Peon:canMoveTo(newX, newY, buildings)
    -- Check tree collision
    if self.map then
        local targetGridX, targetGridY = self.map:worldToGrid(newX, newY)
        local isTargetTree = self.targetTreeX and targetGridX == self.targetTreeX and targetGridY == self.targetTreeY
        if not isTargetTree and not self.map:isWorldPosPassable(newX, newY) then
            return false
        end
    end
    
    if not buildings then return true end
    
    for _, b in ipairs(buildings) do
        local currentPen = self:getBuildingPenetration(self.worldX, self.worldY, b)
        local newPen = self:getBuildingPenetration(newX, newY, b)
        
        if newPen > 0 then
            -- Would be inside building
            if currentPen > 0 then
                -- Already inside - only allow if reducing penetration (escaping)
                if newPen >= currentPen then
                    return false
                end
            else
                -- Not inside currently, don't allow entering
                return false
            end
        end
    end
    
    return true
end

-- Try to move in the given direction, with sliding and cardinal fallbacks
-- Returns true if moved, false if stuck
function Peon:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
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
    local escapeStep = self.radius * 0.5  -- Half the radius
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
    
    -- Final escape: try diagonals (might help slip past corners)
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

-- Get movement direction using flow field with nearby tile sampling fallback
-- Returns normalized dx, dy or nil if no path
function Peon:getMoveDirection(targetWorldX, targetWorldY, buildings)
    -- First, try flow field at current position
    if self.flowField then
        local dirX, dirY = self.flowField:getDirection(self.worldX, self.worldY, self.map)
        if dirX and dirY then
            return dirX, dirY
        end
    end
    
    -- Flow field returned nil - sample nearby tiles to find one with valid direction
    -- Key: only consider tiles with LOWER cost (closer to destination)
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
    local bestCost = currentCost  -- Only accept tiles with lower cost than current!
    
    for _, offset in ipairs(sampleOffsets) do
        local sampleX = self.worldX + offset.dx
        local sampleY = self.worldY + offset.dy
        
        if self.map:isWorldPosPassable(sampleX, sampleY) then
            local sampleCost = self.flowField and self.flowField:getCost(sampleX, sampleY, self.map)
            if sampleCost and sampleCost < bestCost then
                -- This tile is closer to destination - move toward it
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
    
    -- No better nearby tile found - we're likely at destination or stuck
    -- Use direct movement for final approach (contact detection will trigger)
    local dx = targetWorldX - self.worldX
    local dy = targetWorldY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > 0.1 then
        return dx / dist, dy / dist
    end
    
    return nil, nil
end

function Peon:update(dt, townHall, buildings)
    local goldDeposited = 0
    local lumberDeposited = 0
    
    if self.state == Peon.STATE_MOVING then
        self:updateMoving(dt, buildings)
    elseif self.state == Peon.STATE_HARVESTING then
        self:updateHarvesting(dt)
    elseif self.state == Peon.STATE_CHOPPING then
        self:updateChopping(dt)
    elseif self.state == Peon.STATE_RETURNING then
        goldDeposited, lumberDeposited = self:updateReturning(dt, townHall, buildings)
    end
    -- STATE_BUILDING: peon waits, handled externally
    
    return goldDeposited, lumberDeposited
end

function Peon:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Peon.STATE_IDLE
        return
    end
    
    -- Check for contact-based arrival (mines, town hall for returning)
    -- This happens BEFORE distance checks to handle collision-blocked movement
    if self.targetMine and not self.targetMine.depleted then
        if self:isTouchingBuilding(self.targetMine, 4) then
            self.state = Peon.STATE_HARVESTING
            self.harvestTimer = 0
            self.visible = false
            self.flowField = nil
            return
        end
    end
    
    -- Check tree arrival - adjacent to tree tile
    if self.targetTreeX and self.map:isTileTree(self.targetTreeX, self.targetTreeY) then
        local treeWorldX, treeWorldY = self.map:getTileWorldCenter(self.targetTreeX, self.targetTreeY)
        local tdx = treeWorldX - self.worldX
        local tdy = treeWorldY - self.worldY
        local tdist = math.sqrt(tdx * tdx + tdy * tdy)
        -- Tree tile is 32 pixels, so touching is radius + 16 + small buffer
        if tdist <= self.radius + 20 then
            self.state = Peon.STATE_CHOPPING
            self.choppingTimer = 0
            self.flowField = nil
            return
        end
    end
    
    -- Check build site arrival
    if self.buildTargetX and self.buildCallback then
        local buildWorldX, buildWorldY = self.map:gridToWorld(self.buildTargetX, self.buildTargetY)
        local bdx = (buildWorldX + 16) - self.worldX
        local bdy = (buildWorldY + 16) - self.worldY
        local bdist = math.sqrt(bdx * bdx + bdy * bdy)
        if bdist <= 40 then
            self.buildEntryX = self.worldX
            self.buildEntryY = self.worldY
            self.state = Peon.STATE_BUILDING
            self.visible = false
            self.flowField = nil
            self.buildCallback(self.buildTargetX, self.buildTargetY, self.buildingType, self)
            self.buildCallback = nil
            return
        end
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    -- Simple move arrival (no special target)
    local arriveThreshold = 8
    if not self.targetMine and not self.targetTreeX and not self.buildTargetX then
        if dist <= arriveThreshold then
            self.state = Peon.STATE_IDLE
            self.targetX = nil
            self.targetY = nil
            self.flowField = nil
            return
        end
    end
    
    -- Get movement direction (flow field with A* fallback)
    local moveDirX, moveDirY = self:getMoveDirection(self.targetX, self.targetY, buildings)
    
    if not moveDirX or not moveDirY then
        return
    end
    
    -- Movement with sliding and cardinal fallbacks
    local moveSpeed = self.speed * dt
    self:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
end

function Peon:updateHarvesting(dt)
    self.harvestTimer = self.harvestTimer + dt
    if self.harvestTimer >= self.harvestTime then
        self.visible = true
        if self.targetMine and not self.targetMine.depleted then
            self.carryingGold = self.targetMine:extractGold(self.harvestAmount)
        end
        self.state = Peon.STATE_RETURNING
        self.flowField = nil
        self.harvestTimer = 0
    end
end

function Peon:updateChopping(dt)
    self.choppingTimer = self.choppingTimer + dt
    if self.choppingTimer >= self.choppingTime then
        self.carryingLumber = self.choppingAmount
        self.state = Peon.STATE_RETURNING
        self.flowField = nil
        self.choppingTimer = 0
    end
end

function Peon:updateReturning(dt, townHall, buildings)
    if not townHall then
        self.state = Peon.STATE_IDLE
        return 0, 0
    end
    
    self.targetTownHall = townHall
    
    -- Check for contact-based arrival at town hall
    if self:isTouchingBuilding(townHall, 4) then
        -- Deposit resources
        local goldDeposited = self.carryingGold
        local lumberDeposited = self.carryingLumber
        self.carryingGold = 0
        self.carryingLumber = 0
        
        -- Continue harvesting if we have a valid target
        if self.targetMine and not self.targetMine.depleted then
            -- Generate flow field to mine
            local mineField = FlowField.getField(self.targetMine.gridX + 1, self.targetMine.gridY + 1, self.map, buildings)
            self:goToMine(self.targetMine, mineField)
        elseif self.targetTreeX and self.map:isTileTree(self.targetTreeX, self.targetTreeY) then
            -- Generate flow field to tree
            local treeField = FlowField.getField(self.targetTreeX, self.targetTreeY, self.map, buildings)
            self:goToTree(self.targetTreeX, self.targetTreeY, treeField)
        else
            self.state = Peon.STATE_IDLE
            self.targetMine = nil
            self.targetTreeX = nil
            self.targetTreeY = nil
            self.flowField = nil
        end
        
        return goldDeposited, lumberDeposited
    end
    
    -- Get or create flow field to town hall
    if not self.flowField then
        local thGridX, thGridY = self.map:worldToGrid(townHall:getWorldCenter())
        self.flowField = FlowField.getField(thGridX, thGridY, self.map, buildings)
    end
    
    -- Get movement direction (flow field with A* fallback)
    local targetX, targetY = townHall:getWorldCenter()
    local moveDirX, moveDirY = self:getMoveDirection(targetX, targetY, buildings)
    
    if not moveDirX or not moveDirY then
        return 0, 0
    end
    
    -- Movement with sliding and cardinal fallbacks
    local moveSpeed = self.speed * dt
    self:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
    
    return 0, 0
end

function Peon:finishBuilding()
    self.visible = true
    self.state = Peon.STATE_IDLE
    
    -- Find closest empty tile around the completed building
    if self.buildTargetX and self.buildTargetY and self.map then
        -- Determine building size based on type
        local buildingSize = 2  -- Default for farm
        if self.buildingType == "barracks" then
            buildingSize = 3
        end
        
        -- Get building world position
        local buildWorldX, buildWorldY = self.map:gridToWorld(self.buildTargetX, self.buildTargetY)
        local buildCenterX = buildWorldX + (buildingSize * 32) / 2
        local buildCenterY = buildWorldY + (buildingSize * 32) / 2
        
        -- Entry position (or building center if no entry recorded)
        local entryX = self.buildEntryX or buildCenterX
        local entryY = self.buildEntryY or buildCenterY
        
        -- Search adjacent tiles around the building perimeter
        local bestX, bestY = nil, nil
        local bestDist = math.huge
        
        for dy = -1, buildingSize do
            for dx = -1, buildingSize do
                -- Only check perimeter tiles (not inside building)
                local isPerimeter = dx == -1 or dy == -1 or dx == buildingSize or dy == buildingSize
                if isPerimeter then
                    local tileGridX = self.buildTargetX + dx
                    local tileGridY = self.buildTargetY + dy
                    local tileWorldX, tileWorldY = self.map:gridToWorld(tileGridX, tileGridY)
                    local tileCenterX = tileWorldX + 16
                    local tileCenterY = tileWorldY + 16
                    
                    -- Check if tile is passable
                    if self.map:isWorldPosPassable(tileCenterX, tileCenterY) then
                        local distX = tileCenterX - entryX
                        local distY = tileCenterY - entryY
                        local dist = distX * distX + distY * distY
                        if dist < bestDist then
                            bestDist = dist
                            bestX = tileCenterX
                            bestY = tileCenterY
                        end
                    end
                end
            end
        end
        
        -- Place peon at best position found
        if bestX and bestY then
            self.worldX = bestX
            self.worldY = bestY
        end
    end
    
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildingType = nil
    self.buildEntryX = nil
    self.buildEntryY = nil
    self.flowField = nil
end

function Peon:draw()
    if not self.visible then return end
    
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
    
    -- Feet (brown boots)
    love.graphics.setColor(0.35, 0.25, 0.15, 1)
    love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
    
    -- Legs (brown pants)
    love.graphics.setColor(0.45, 0.35, 0.25, 1)
    love.graphics.rectangle("fill", x - 6, y + 2, 5, 8, 1)
    love.graphics.rectangle("fill", x + 1, y + 2, 5, 8, 1)
    
    -- Body/tunic
    if self.carryingGold > 0 then
        love.graphics.setColor(0.7, 0.55, 0.2, 1)  -- Golden tint when carrying gold
    elseif self.carryingLumber > 0 then
        love.graphics.setColor(0.5, 0.4, 0.25, 1)  -- Brown tint when carrying lumber
    else
        love.graphics.setColor(0.6, 0.5, 0.35, 1)  -- Normal tan tunic
    end
    love.graphics.rectangle("fill", x - 7, y - 6, 14, 10, 2)
    
    -- Tunic details (belt)
    love.graphics.setColor(0.35, 0.25, 0.15, 1)
    love.graphics.rectangle("fill", x - 7, y, 14, 2)
    love.graphics.setColor(0.8, 0.7, 0.2, 1)
    love.graphics.circle("fill", x, y + 1, 2)  -- Belt buckle
    
    -- Arms
    love.graphics.setColor(0.6, 0.5, 0.35, 1)
    love.graphics.rectangle("fill", x - 10, y - 4, 4, 8, 1)
    love.graphics.rectangle("fill", x + 6, y - 4, 4, 8, 1)
    
    -- Hands (skin tone)
    love.graphics.setColor(0.85, 0.7, 0.55, 1)
    love.graphics.circle("fill", x - 9, y + 4, 3)
    love.graphics.circle("fill", x + 9, y + 4, 3)
    
    -- Head
    love.graphics.setColor(0.85, 0.7, 0.55, 1)
    love.graphics.ellipse("fill", x, y - 10, 6, 7)
    
    -- Hood/cap
    love.graphics.setColor(0.5, 0.4, 0.3, 1)
    love.graphics.arc("fill", x, y - 10, 7, math.pi, 2 * math.pi)
    love.graphics.rectangle("fill", x - 7, y - 12, 14, 4, 1)
    
    -- Face details
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", x - 2, y - 11, 1.5)  -- Left eye
    love.graphics.circle("fill", x + 2, y - 11, 1.5)  -- Right eye
    love.graphics.setColor(0.7, 0.5, 0.4, 1)
    love.graphics.ellipse("fill", x, y - 8, 2, 1.5)  -- Nose
    
    -- Tool based on state/carrying
    if self.state == Peon.STATE_CHOPPING or self.carryingLumber > 0 then
        -- Axe
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + 10, y - 8, 2, 14, 1)  -- Handle
        love.graphics.setColor(0.6, 0.6, 0.65, 1)
        love.graphics.polygon("fill", x + 9, y - 8, x + 16, y - 6, x + 16, y - 2, x + 9, y - 4)  -- Blade
    elseif self.state == Peon.STATE_HARVESTING or self.carryingGold > 0 then
        -- Pickaxe
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + 10, y - 6, 2, 12, 1)  -- Handle
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.polygon("fill", x + 8, y - 8, x + 18, y - 6, x + 14, y - 2)  -- Pick head
    end
    
    -- Carried resources on back
    if self.carryingGold > 0 then
        -- Gold sack
        love.graphics.setColor(0.7, 0.55, 0.15, 1)
        love.graphics.ellipse("fill", x, y - 2, 6, 5)
        love.graphics.setColor(0.9, 0.8, 0.2, 1)
        love.graphics.circle("fill", x - 2, y - 3, 3)
        love.graphics.circle("fill", x + 2, y - 1, 2)
    elseif self.carryingLumber > 0 then
        -- Lumber bundle
        love.graphics.setColor(0.55, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", x - 4, y - 14, 3, 12, 1)
        love.graphics.rectangle("fill", x - 1, y - 16, 3, 14, 1)
        love.graphics.rectangle("fill", x + 2, y - 13, 3, 11, 1)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Peon:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Peon:isInBox(x1, y1, x2, y2)
    if not self.visible then return false end
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Peon:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.targetMine = nil
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    self.state = Peon.STATE_MOVING
end

function Peon:goToMine(mine, flowField)
    self.targetMine = mine
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    -- Target the center - updateMoving will stop at the edge
    local cx, cy = mine:getWorldCenter()
    self.targetX = cx
    self.targetY = cy
    self.state = Peon.STATE_MOVING
end

function Peon:goToTree(gridX, gridY, flowField)
    self.targetTreeX = gridX
    self.targetTreeY = gridY
    self.targetMine = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    if self.map then
        self.targetX, self.targetY = self.map:getTileWorldCenter(gridX, gridY)
    end
    self.state = Peon.STATE_MOVING
end

function Peon:goToBuild(gridX, gridY, buildingType, callback, flowField)
    self.buildTargetX = gridX
    self.buildTargetY = gridY
    self.buildingType = buildingType
    self.buildCallback = callback
    self.targetMine = nil
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.flowField = flowField
    self.lastMoveDirX = nil
    self.lastMoveDirY = nil
    if self.map then
        self.targetX, self.targetY = self.map:gridToWorld(gridX, gridY)
        self.targetX = self.targetX + 16
        self.targetY = self.targetY + 16
    end
    self.state = Peon.STATE_MOVING
end

function Peon:getStateText()
    if self.state == Peon.STATE_RETURNING then
        if self.carryingGold > 0 then return "Carrying Gold"
        elseif self.carryingLumber > 0 then return "Carrying Lumber" end
    elseif self.state == Peon.STATE_CHOPPING then
        return "Chopping"
    elseif self.state == Peon.STATE_BUILDING then
        return "Building"
    end
    return self.state
end

function Peon:updateUI(resources, screenW, screenH, font, startBuildCallback)
    if self.selected and self.state ~= Peon.STATE_BUILDING then
        local panelX = screenW - 180
        local buttonY = 70 + 145
        
        local Farm = require("farm")
        local Barracks = require("barracks")
        
        if not self.buildFarmButton then
            self.buildFarmButton = Button.new({
                x = panelX + 10, y = buttonY, width = 150, height = 35,
                text = "Farm (250g 50l)", font = font,
                colors = {
                    normal = {0.3, 0.5, 0.35, 1}, hover = {0.4, 0.6, 0.45, 1},
                    pressed = {0.2, 0.4, 0.25, 1}, text = {1, 1, 1, 1}, border = {0.2, 0.4, 0.25, 1}
                },
                onClick = function()
                    if startBuildCallback then startBuildCallback(self, "farm") end
                end
            })
        end
        
        if not self.buildBarracksButton then
            self.buildBarracksButton = Button.new({
                x = panelX + 10, y = buttonY + 40, width = 150, height = 35,
                text = "Barracks (400g 100l)", font = font,
                colors = {
                    normal = {0.5, 0.35, 0.35, 1}, hover = {0.6, 0.45, 0.45, 1},
                    pressed = {0.4, 0.25, 0.25, 1}, text = {1, 1, 1, 1}, border = {0.4, 0.25, 0.25, 1}
                },
                onClick = function()
                    if startBuildCallback then startBuildCallback(self, "barracks") end
                end
            })
        end
        
        local canFarm = resources.gold >= Farm.COST_GOLD and resources.lumber >= Farm.COST_LUMBER
        local canBarracks = resources.gold >= Barracks.COST_GOLD and resources.lumber >= Barracks.COST_LUMBER
        local canGiveOrders = self.state == Peon.STATE_IDLE or self.state == Peon.STATE_MOVING
        
        self.buildFarmButton:setEnabled(canFarm and canGiveOrders)
        self.buildBarracksButton:setEnabled(canBarracks and canGiveOrders)
        self.buildFarmButton:update(0)
        self.buildBarracksButton:update(0)
    else
        self.buildFarmButton = nil
        self.buildBarracksButton = nil
    end
end

function Peon:drawUI()
    if self.selected and self.state ~= Peon.STATE_BUILDING then
        if self.buildFarmButton then self.buildFarmButton:draw() end
        if self.buildBarracksButton then self.buildBarracksButton:draw() end
    end
end

function Peon:mousepressed(x, y, button)
    if self.buildFarmButton then self.buildFarmButton:mousepressed(x, y, button) end
    if self.buildBarracksButton then self.buildBarracksButton:mousepressed(x, y, button) end
end

function Peon:mousereleased(x, y, button)
    if self.buildFarmButton then self.buildFarmButton:mousereleased(x, y, button) end
    if self.buildBarracksButton then self.buildBarracksButton:mousereleased(x, y, button) end
end

function Peon:drawOnMinimap(mapX, mapY, scale)
    if not self.visible then return end
    love.graphics.setColor(0.3, 0.8, 0.3, 1)
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.5))
end

return Peon
