--[[
    Unit - Base class for all mobile units
    
    Provides shared functionality:
    - Movement and pathfinding
    - Building collision (consistent with pathfinding)
    - Selection handling
    - Minimap drawing
    
    Units inherit from this and override:
    - RADIUS, SPEED (class constants)
    - type, name (instance properties)
    - draw() (visual appearance)
    - Any special behavior
]]

local Pathfinding = require("pathfinding")

local Unit = {}
Unit.__index = Unit

-- Default values (override in subclasses)
Unit.RADIUS = 14
Unit.SPEED = 60

-- States
Unit.STATE_IDLE = "Idle"
Unit.STATE_MOVING = "Moving"

function Unit.new(params)
    local self = setmetatable({}, Unit)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = self.RADIUS or Unit.RADIUS
    self.speed = self.SPEED or Unit.SPEED
    self.selected = false
    self.type = "unit"
    self.name = "Unit"
    self.state = Unit.STATE_IDLE
    
    -- Movement
    self.targetX = nil
    self.targetY = nil
    self.path = nil
    self.currentWaypoint = 1
    
    return self
end

--[[
    COLLISION DETECTION
    
    Uses circle-to-rectangle collision.
    The rectangle is the building's world bounds.
]]

-- Get the world bounds of a building consistently
-- Returns x, y, width, height (not x1,y1,x2,y2)
function Unit:getBuildingRect(building)
    if building.getWorldBounds then
        local x1, y1, x2, y2 = building:getWorldBounds()
        return x1, y1, x2 - x1, y2 - y1
    elseif building.gridX and building.gridY and building.gridSize and self.map then
        local x = (building.gridX - 1) * self.map.tileSize
        local y = (building.gridY - 1) * self.map.tileSize
        local size = building.gridSize * self.map.tileSize
        return x, y, size, size
    end
    return nil
end

-- Check if a point (circle center) collides with a building
-- Returns penetration depth (0 if no collision)
function Unit:getBuildingPenetration(x, y, building)
    local bx, by, bw, bh = self:getBuildingRect(building)
    if not bx then return 0 end
    
    -- Find closest point on rectangle to circle center
    local closestX = math.max(bx, math.min(x, bx + bw))
    local closestY = math.max(by, math.min(y, by + bh))
    
    local distX = x - closestX
    local distY = y - closestY
    local dist = math.sqrt(distX * distX + distY * distY)
    
    if dist < self.radius then
        return self.radius - dist
    end
    return 0
end

-- Check if unit can move to a new position
function Unit:canMoveTo(newX, newY, buildings)
    -- Check map bounds and passability
    if self.map then
        if not self.map:isWorldPosPassable(newX, newY) then
            return false
        end
    end
    
    if not buildings then return true end
    
    -- Check building collision
    for _, building in ipairs(buildings) do
        local currentPen = self:getBuildingPenetration(self.worldX, self.worldY, building)
        local newPen = self:getBuildingPenetration(newX, newY, building)
        
        -- Can't move INTO a building
        if newPen > 0 and currentPen == 0 then
            return false
        end
        
        -- If already overlapping, can only move to REDUCE penetration
        if newPen > 0 and currentPen > 0 and newPen >= currentPen then
            return false
        end
    end
    
    return true
end

-- Check if unit is touching a building (within threshold)
function Unit:isTouchingBuilding(building, threshold)
    threshold = threshold or 4
    local bx, by, bw, bh = self:getBuildingRect(building)
    if not bx then return false end
    
    local closestX = math.max(bx, math.min(self.worldX, bx + bw))
    local closestY = math.max(by, math.min(self.worldY, by + bh))
    
    local distX = self.worldX - closestX
    local distY = self.worldY - closestY
    local dist = math.sqrt(distX * distX + distY * distY)
    
    return dist <= (self.radius + threshold)
end

--[[
    MOVEMENT
    
    Uses line-of-sight pathfinding.
    Destination is ALWAYS the clicked point.
    Waypoints are ONLY for navigating around obstacles.
]]

-- Try to move in a direction at full speed
-- If blocked, try alternative directions that maintain speed
function Unit:tryMove(dirX, dirY, moveSpeed, buildings)
    local moveX = dirX * moveSpeed
    local moveY = dirY * moveSpeed
    local newX = self.worldX + moveX
    local newY = self.worldY + moveY
    
    -- First try direct movement
    if self:canMoveTo(newX, newY, buildings) then
        self.worldX = newX
        self.worldY = newY
        return true
    end
    
    -- Blocked - try 8 alternative directions at FULL SPEED
    local alternatives = {
        {dx = 1, dy = 0},
        {dx = -1, dy = 0},
        {dx = 0, dy = 1},
        {dx = 0, dy = -1},
        {dx = 0.707, dy = 0.707},
        {dx = -0.707, dy = 0.707},
        {dx = 0.707, dy = -0.707},
        {dx = -0.707, dy = -0.707},
    }
    
    -- Sort by alignment with intended direction
    table.sort(alternatives, function(a, b)
        local dotA = a.dx * dirX + a.dy * dirY
        local dotB = b.dx * dirX + b.dy * dirY
        return dotA > dotB
    end)
    
    -- Try each alternative
    for _, alt in ipairs(alternatives) do
        local dot = alt.dx * dirX + alt.dy * dirY
        if dot > 0.1 then  -- Only somewhat aligned directions
            local altX = self.worldX + alt.dx * moveSpeed
            local altY = self.worldY + alt.dy * moveSpeed
            if self:canMoveTo(altX, altY, buildings) then
                self.worldX = altX
                self.worldY = altY
                return true
            end
        end
    end
    
    -- Try smaller movements
    for fraction = 0.75, 0.25, -0.25 do
        local smallX = self.worldX + moveX * fraction
        local smallY = self.worldY + moveY * fraction
        if self:canMoveTo(smallX, smallY, buildings) then
            self.worldX = smallX
            self.worldY = smallY
            return true
        end
    end
    
    return false
end

-- Get direction to current waypoint
function Unit:getMoveDirection(buildings)
    if not self.path or not self.currentWaypoint then
        return nil, nil
    end
    
    -- Check if we've reached current waypoint
    if Pathfinding.reachedWaypoint(self.worldX, self.worldY, self.path, self.currentWaypoint, 12) then
        -- Before advancing, check if we can see the NEXT waypoint
        local nextWp = self.currentWaypoint + 1
        if nextWp <= #self.path then
            local nextTarget = self.path[nextWp]
            -- Only advance if we have clear line of sight to next waypoint
            if Pathfinding.canSee(self.worldX, self.worldY, nextTarget.x, nextTarget.y, buildings, self.map, self.radius) then
                self.currentWaypoint = nextWp
            end
            -- If we can't see next waypoint, stay on current one and keep moving toward it
        else
            -- Last waypoint, advance anyway
            self.currentWaypoint = nextWp
        end
    end
    
    -- Get direction to current waypoint
    return Pathfinding.getDirection(self.worldX, self.worldY, self.path, self.currentWaypoint)
end

-- Compute path to target
function Unit:computePath(targetX, targetY, buildings)
    return Pathfinding.findPath(self.worldX, self.worldY, targetX, targetY, buildings, self.map, self.radius)
end

-- Main movement update
function Unit:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Unit.STATE_IDLE
        return
    end
    
    -- Check if we've reached the destination
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 8 then
        self.state = Unit.STATE_IDLE
        self.targetX = nil
        self.targetY = nil
        self.path = nil
        return
    end
    
    -- Compute path if we don't have one
    if not self.path then
        self.path = self:computePath(self.targetX, self.targetY, buildings)
        self.currentWaypoint = 1
    end
    
    -- Get movement direction
    local moveDirX, moveDirY = self:getMoveDirection(buildings)
    
    -- Fallback to direct movement if no path
    if not moveDirX then
        if dist > 1 then
            moveDirX = dx / dist
            moveDirY = dy / dist
        else
            return
        end
    end
    
    -- Move
    local moveSpeed = self.speed * dt
    self:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
end

-- Set movement target
function Unit:moveTo(worldX, worldY)
    self.targetX = worldX
    self.targetY = worldY
    self.path = nil
    self.currentWaypoint = 1
    self.state = Unit.STATE_MOVING
end

--[[
    UPDATE & DRAW
]]

function Unit:update(dt, buildings)
    if self.state == Unit.STATE_MOVING then
        self:updateMoving(dt, buildings)
    end
end

function Unit:draw()
    -- Override in subclass
    local x, y = self:getScreenPos()
    love.graphics.setColor(1, 0, 1, 1)  -- Magenta = missing draw override
    love.graphics.circle("fill", x, y, self.radius)
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    SELECTION & POSITION
]]

function Unit:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Unit:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Unit:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Unit:getStateText()
    return self.state
end

--[[
    UI STUBS (override if needed)
]]

function Unit:updateUI(resources, screenW, screenH, font) end
function Unit:drawUI() end
function Unit:mousepressed(x, y, button) end
function Unit:mousereleased(x, y, button) end

--[[
    MINIMAP
]]

function Unit:drawOnMinimap(mapX, mapY, scale)
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.setColor(0.2, 0.8, 0.2, 1)  -- Green for player units
    love.graphics.circle("fill", mmX, mmY, 2)
end

return Unit
