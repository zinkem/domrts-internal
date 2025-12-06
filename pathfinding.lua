--[[
    Simple Line-of-Sight Pathfinding
    
    CORE PRINCIPLE: The destination is ALWAYS where the user clicked.
    Waypoints are ONLY for navigating around obstacles.
    The path ALWAYS ends at the goal.
    
    Algorithm:
    1. Try direct line to goal
    2. If blocked by building, add a corner waypoint to go around it
    3. Repeat until we have line of sight to goal
    4. Final waypoint is ALWAYS the goal
]]

local Pathfinding = {}

-- Check if a line segment intersects a rectangle
-- Returns true if blocked
local function lineIntersectsRect(x1, y1, x2, y2, rx, ry, rw, rh)
    -- Parametric line: P = P1 + t(P2-P1), t in [0,1]
    local dx = x2 - x1
    local dy = y2 - y1
    
    -- Check each edge of rectangle
    local tmin = 0
    local tmax = 1
    
    -- X edges
    if dx ~= 0 then
        local t1 = (rx - x1) / dx
        local t2 = (rx + rw - x1) / dx
        if t1 > t2 then t1, t2 = t2, t1 end
        tmin = math.max(tmin, t1)
        tmax = math.min(tmax, t2)
    else
        if x1 < rx or x1 > rx + rw then
            return false
        end
    end
    
    -- Y edges
    if dy ~= 0 then
        local t1 = (ry - y1) / dy
        local t2 = (ry + rh - y1) / dy
        if t1 > t2 then t1, t2 = t2, t1 end
        tmin = math.max(tmin, t1)
        tmax = math.min(tmax, t2)
    else
        if y1 < ry or y1 > ry + rh then
            return false
        end
    end
    
    return tmax >= tmin
end

-- Get building bounds in world coordinates with padding
-- Uses getWorldBounds() if available for consistency with collision
local function getBuildingRect(building, map, padding)
    local x, y, w, h
    
    if building.getWorldBounds then
        -- Use the building's own bounds calculation (most accurate)
        local x1, y1, x2, y2 = building:getWorldBounds()
        x, y, w, h = x1, y1, x2 - x1, y2 - y1
    elseif building.gridX and building.gridY and building.gridSize and map then
        -- Fall back to grid calculation
        x = (building.gridX - 1) * map.tileSize
        y = (building.gridY - 1) * map.tileSize
        w = building.gridSize * map.tileSize
        h = w
    else
        return nil
    end
    
    -- Apply padding (expand rectangle on all sides)
    return x - padding, y - padding, w + padding * 2, h + padding * 2
end

-- Find the first building that blocks a line from start to goal
local function findBlockingBuilding(startX, startY, goalX, goalY, buildings, map, padding)
    if not buildings then return nil end
    
    for _, building in ipairs(buildings) do
        local rx, ry, rw, rh = getBuildingRect(building, map, padding)
        if rx then
            if lineIntersectsRect(startX, startY, goalX, goalY, rx, ry, rw, rh) then
                return building, rx, ry, rw, rh
            end
        end
    end
    return nil
end

-- Check if a point is inside any building
local function pointInsideBuilding(x, y, buildings, map, padding)
    if not buildings then return false end
    
    for _, building in ipairs(buildings) do
        local rx, ry, rw, rh = getBuildingRect(building, map, padding)
        if rx then
            if x >= rx and x <= rx + rw and y >= ry and y <= ry + rh then
                return true
            end
        end
    end
    return false
end

-- Get the 4 corners around a building
-- rx, ry, rw, rh is the PADDED rect (already includes unit radius)
-- We need corners OUTSIDE this padded area so unit can actually reach them
local function getBuildingCorners(rx, ry, rw, rh, unitRadius)
    -- Corners must be far enough that unit center can reach them without collision
    -- Add a healthy margin beyond the padded rect
    local margin = math.max(unitRadius, 16)
    return {
        {x = rx - margin, y = ry - margin},             -- top-left
        {x = rx + rw + margin, y = ry - margin},        -- top-right
        {x = rx - margin, y = ry + rh + margin},        -- bottom-left
        {x = rx + rw + margin, y = ry + rh + margin}    -- bottom-right
    }
end

--[[
    Find path from start to goal.
    
    Returns a list of waypoints. The LAST waypoint is ALWAYS the goal.
    Intermediate waypoints are corners to navigate around buildings.
]]
function Pathfinding.findPath(startX, startY, goalX, goalY, buildings, map, unitRadius)
    unitRadius = unitRadius or 14
    local path = {}
    local maxIterations = 20
    
    local currentX, currentY = startX, startY
    
    for i = 1, maxIterations do
        -- Check if we have direct line of sight to goal
        local blocker, rx, ry, rw, rh = findBlockingBuilding(currentX, currentY, goalX, goalY, buildings, map, unitRadius)
        
        if not blocker then
            -- Clear path to goal! Add it and we're done.
            table.insert(path, {x = goalX, y = goalY})
            return path
        end
        
        -- Building in the way - find a corner to go around
        local corners = getBuildingCorners(rx, ry, rw, rh, unitRadius)
        
        local bestCorner = nil
        local bestScore = math.huge
        
        for _, corner in ipairs(corners) do
            -- Can we see this corner from current position?
            local blockerToCorner = findBlockingBuilding(currentX, currentY, corner.x, corner.y, buildings, map, unitRadius)
            
            -- Is this corner not inside another building?
            local cornerInsideBuilding = pointInsideBuilding(corner.x, corner.y, buildings, map, unitRadius)
            
            if not blockerToCorner and not cornerInsideBuilding then
                -- Valid corner - score by total path length
                local distToCorner = math.sqrt((corner.x - currentX)^2 + (corner.y - currentY)^2)
                local distToGoal = math.sqrt((goalX - corner.x)^2 + (goalY - corner.y)^2)
                local score = distToCorner + distToGoal
                
                -- Prefer corners that have line of sight to goal (big bonus)
                local cornerToGoal = findBlockingBuilding(corner.x, corner.y, goalX, goalY, buildings, map, unitRadius)
                if not cornerToGoal then
                    score = score - 1000
                end
                
                if score < bestScore then
                    bestScore = score
                    bestCorner = corner
                end
            end
        end
        
        if not bestCorner then
            -- Can't find a valid corner - just try to go to goal directly
            -- The movement system will handle collision
            table.insert(path, {x = goalX, y = goalY})
            return path
        end
        
        -- Add corner as intermediate waypoint
        table.insert(path, {x = bestCorner.x, y = bestCorner.y})
        currentX, currentY = bestCorner.x, bestCorner.y
    end
    
    -- Ran out of iterations - add goal anyway
    table.insert(path, {x = goalX, y = goalY})
    return path
end

-- Get direction to next waypoint
-- Returns nil, nil if we've reached the end of the path
function Pathfinding.getDirection(unitX, unitY, path, waypointIndex)
    if not path or not waypointIndex or waypointIndex > #path then
        return nil, nil
    end
    
    local wp = path[waypointIndex]
    local dx = wp.x - unitX
    local dy = wp.y - unitY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist < 1 then
        return nil, nil
    end
    
    return dx / dist, dy / dist
end

-- Check if unit has reached current waypoint
function Pathfinding.reachedWaypoint(unitX, unitY, path, waypointIndex, threshold)
    threshold = threshold or 8
    if not path or not waypointIndex or waypointIndex > #path then
        return true
    end
    
    local wp = path[waypointIndex]
    local dx = wp.x - unitX
    local dy = wp.y - unitY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    return dist < threshold
end

-- Check if this is the final waypoint (the actual destination)
function Pathfinding.isFinalWaypoint(path, waypointIndex)
    if not path or not waypointIndex then
        return true
    end
    return waypointIndex >= #path
end

-- Check if there's clear line of sight between two points
function Pathfinding.canSee(startX, startY, goalX, goalY, buildings, map, unitRadius)
    unitRadius = unitRadius or 14
    local blocker = findBlockingBuilding(startX, startY, goalX, goalY, buildings, map, unitRadius)
    return blocker == nil
end

return Pathfinding
