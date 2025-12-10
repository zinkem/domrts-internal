--[[
    A* Grid-Based Pathfinding
    
    Uses a navigation grid at half-tile resolution (16px cells).
    Properly routes around obstacles using A* algorithm.
    
    NavGrid is cached and rebuilt only when terrain changes:
    - Building placed or destroyed
    - Tree chopped
    - Gold mine depleted
]]

local Pathfinding = {}

-- Navigation grid (cached)
local navGrid = nil      -- navGrid[y][x] = true (walkable) or false (blocked)
local navWidth = 0
local navHeight = 0
local NAV_CELL_SIZE = 16 -- Half-tile resolution (fine grid)

-- Coarse navigation grid for long-distance pathfinding
local coarseGrid = nil   -- coarseGrid[y][x] = true (walkable) or false (blocked)
local coarseWidth = 0
local coarseHeight = 0
local COARSE_CELL_SIZE = 64  -- 4x coarser (one full tile)
local COARSE_THRESHOLD = 40  -- Use coarse grid if manhattan distance > this many fine cells
local COARSE_MIN_MAP_SIZE = 48  -- Only use coarse grid on maps >= 48 tiles wide/tall

-- Path cache: pathCache[startNavY..","..startNavX.."->"..goalNavY..","..goalNavX] = path
local pathCache = {}
local PATH_CACHE_MAX = 200  -- Max cached paths before cleanup

-- Direction vectors for 8-way movement
local DIRECTIONS = {
    {dx = 1, dy = 0, cost = 1.0},      -- East
    {dx = -1, dy = 0, cost = 1.0},     -- West
    {dx = 0, dy = 1, cost = 1.0},      -- South
    {dx = 0, dy = -1, cost = 1.0},     -- North
    {dx = 1, dy = 1, cost = 1.414},    -- SE
    {dx = -1, dy = 1, cost = 1.414},   -- SW
    {dx = 1, dy = -1, cost = 1.414},   -- NE
    {dx = -1, dy = -1, cost = 1.414},  -- NW
}

-- Priority queue implementation (min-heap)
local function createPriorityQueue()
    local pq = {data = {}}
    
    function pq:push(item, priority)
        table.insert(self.data, {item = item, priority = priority})
        self:bubbleUp(#self.data)
    end
    
    function pq:pop()
        if #self.data == 0 then return nil end
        local top = self.data[1].item
        self.data[1] = self.data[#self.data]
        table.remove(self.data)
        if #self.data > 0 then
            self:bubbleDown(1)
        end
        return top
    end
    
    function pq:isEmpty()
        return #self.data == 0
    end
    
    function pq:bubbleUp(idx)
        while idx > 1 do
            local parent = math.floor(idx / 2)
            if self.data[idx].priority < self.data[parent].priority then
                self.data[idx], self.data[parent] = self.data[parent], self.data[idx]
                idx = parent
            else
                break
            end
        end
    end
    
    function pq:bubbleDown(idx)
        local size = #self.data
        while true do
            local smallest = idx
            local left = idx * 2
            local right = idx * 2 + 1
            
            if left <= size and self.data[left].priority < self.data[smallest].priority then
                smallest = left
            end
            if right <= size and self.data[right].priority < self.data[smallest].priority then
                smallest = right
            end
            
            if smallest ~= idx then
                self.data[idx], self.data[smallest] = self.data[smallest], self.data[idx]
                idx = smallest
            else
                break
            end
        end
    end
    
    return pq
end

-- Octile distance heuristic (for 8-way movement)
local function heuristic(x1, y1, x2, y2)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    return math.max(dx, dy) + 0.414 * math.min(dx, dy)
end

-- Convert world coordinates to nav grid coordinates
function Pathfinding.worldToNav(worldX, worldY)
    local navX = math.floor(worldX / NAV_CELL_SIZE) + 1
    local navY = math.floor(worldY / NAV_CELL_SIZE) + 1
    return navX, navY
end

-- Convert nav grid coordinates to world coordinates (center of cell)
function Pathfinding.navToWorld(navX, navY)
    local worldX = (navX - 1) * NAV_CELL_SIZE + NAV_CELL_SIZE / 2
    local worldY = (navY - 1) * NAV_CELL_SIZE + NAV_CELL_SIZE / 2
    return worldX, worldY
end

-- Check if a nav cell is walkable
local function isWalkable(navX, navY)
    if navX < 1 or navX > navWidth or navY < 1 or navY > navHeight then
        return false
    end
    return navGrid[navY] and navGrid[navY][navX] == true
end

-- Check if a coarse cell is walkable
local function isCoarseWalkable(cx, cy)
    if cx < 1 or cx > coarseWidth or cy < 1 or cy > coarseHeight then
        return false
    end
    return coarseGrid and coarseGrid[cy] and coarseGrid[cy][cx] == true
end

-- Build coarse grid from fine grid (call after fine grid is complete)
local function rebuildCoarseGrid()
    if not navGrid then return end

    -- Skip coarse grid on small maps - fine A* is fast enough
    local mapTilesW = navWidth / 2  -- Convert nav cells back to tiles
    local mapTilesH = navHeight / 2
    if mapTilesW < COARSE_MIN_MAP_SIZE and mapTilesH < COARSE_MIN_MAP_SIZE then
        coarseGrid = nil
        coarseWidth = 0
        coarseHeight = 0
        return
    end

    -- Coarse grid is 1/4 resolution (64px cells vs 16px)
    local ratio = COARSE_CELL_SIZE / NAV_CELL_SIZE  -- 4
    coarseWidth = math.ceil(navWidth / ratio)
    coarseHeight = math.ceil(navHeight / ratio)

    coarseGrid = {}
    for cy = 1, coarseHeight do
        coarseGrid[cy] = {}
        for cx = 1, coarseWidth do
            -- A coarse cell is walkable if ANY of its fine cells are walkable
            -- (we just need a path through, not full coverage)
            local hasWalkable = false
            local fineX1 = (cx - 1) * ratio + 1
            local fineY1 = (cy - 1) * ratio + 1
            local fineX2 = math.min(fineX1 + ratio - 1, navWidth)
            local fineY2 = math.min(fineY1 + ratio - 1, navHeight)

            for fy = fineY1, fineY2 do
                for fx = fineX1, fineX2 do
                    if isWalkable(fx, fy) then
                        hasWalkable = true
                        break
                    end
                end
                if hasWalkable then break end
            end

            coarseGrid[cy][cx] = hasWalkable
        end
    end
end

-- Clear the path cache (call when nav grid changes)
local function clearPathCache()
    pathCache = {}
end

-- Rebuild the entire navigation grid from map and buildings
function Pathfinding.rebuildNavGrid(map, buildings)
    if not map then return end

    -- Clear path cache since terrain changed
    clearPathCache()

    -- Calculate nav grid dimensions (half-tile resolution)
    navWidth = map.width * 2
    navHeight = map.height * 2

    -- Initialize all cells as walkable
    navGrid = {}
    for y = 1, navHeight do
        navGrid[y] = {}
        for x = 1, navWidth do
            navGrid[y][x] = true
        end
    end
    
    -- Mark impassable tiles (trees, water) as blocked
    -- TILE_TREE = 2, TILE_WATER = 4
    for tileY = 1, map.height do
        for tileX = 1, map.width do
            local tile = map.tiles[tileY] and map.tiles[tileY][tileX]
            if tile == 2 or tile == 4 then  -- Tree or Water
                -- Each tile maps to 2x2 nav cells
                local baseNavX = (tileX - 1) * 2 + 1
                local baseNavY = (tileY - 1) * 2 + 1
                for dy = 0, 1 do
                    for dx = 0, 1 do
                        local nx = baseNavX + dx
                        local ny = baseNavY + dy
                        if nx >= 1 and nx <= navWidth and ny >= 1 and ny <= navHeight then
                            navGrid[ny][nx] = false
                        end
                    end
                end
            end
        end
    end
    
    -- Mark buildings as blocked (with inflation for unit radius)
    if buildings then
        for _, building in ipairs(buildings) do
            Pathfinding.markBuilding(building, false)
        end
    end

    -- Build coarse grid for long-distance pathfinding
    rebuildCoarseGrid()
end

-- Mark/unmark a building in the nav grid
-- walkable = false to block, true to unblock
function Pathfinding.markBuilding(building, walkable)
    if not navGrid or not building then return end

    -- Clear path cache since terrain changed
    clearPathCache()
    
    local bx1, by1, bx2, by2
    if building.getWorldBounds then
        bx1, by1, bx2, by2 = building:getWorldBounds()
    elseif building.gridX and building.gridY and building.gridSize then
        bx1 = (building.gridX - 1) * 32
        by1 = (building.gridY - 1) * 32
        bx2 = bx1 + building.gridSize * 32
        by2 = by1 + building.gridSize * 32
    else
        return
    end
    
    -- Add inflation for unit radius (default ~14px = 1 nav cell)
    -- BUT: Don't inflate gold mines - peons need to walk right up to them
    local inflation = 1  -- 1 nav cell = 16px
    if building.goldReserves ~= nil then
        -- This is a gold mine - no inflation so peons can reach it
        inflation = 0
    end
    
    if inflation > 0 then
        bx1 = bx1 - inflation * NAV_CELL_SIZE
        by1 = by1 - inflation * NAV_CELL_SIZE
        bx2 = bx2 + inflation * NAV_CELL_SIZE
        by2 = by2 + inflation * NAV_CELL_SIZE
    end
    
    -- Convert to nav coordinates
    local navX1 = math.floor(bx1 / NAV_CELL_SIZE) + 1
    local navY1 = math.floor(by1 / NAV_CELL_SIZE) + 1
    local navX2 = math.floor(bx2 / NAV_CELL_SIZE) + 1
    local navY2 = math.floor(by2 / NAV_CELL_SIZE) + 1
    
    -- Mark cells
    for ny = navY1, navY2 do
        for nx = navX1, navX2 do
            if nx >= 1 and nx <= navWidth and ny >= 1 and ny <= navHeight then
                navGrid[ny][nx] = walkable
            end
        end
    end

    -- Rebuild coarse grid
    rebuildCoarseGrid()
end

-- Mark a tile area (for tree removal, etc)
function Pathfinding.markTile(tileX, tileY, walkable)
    if not navGrid then return end

    -- Clear path cache since terrain changed
    clearPathCache()

    -- Each tile maps to 2x2 nav cells
    local baseNavX = (tileX - 1) * 2 + 1
    local baseNavY = (tileY - 1) * 2 + 1
    
    for dy = 0, 1 do
        for dx = 0, 1 do
            local nx = baseNavX + dx
            local ny = baseNavY + dy
            if nx >= 1 and nx <= navWidth and ny >= 1 and ny <= navHeight then
                navGrid[ny][nx] = walkable
            end
        end
    end

    -- Rebuild coarse grid
    rebuildCoarseGrid()
end

-- Find nearest walkable cell to a given position
local function findNearestWalkable(navX, navY)
    if isWalkable(navX, navY) then
        return navX, navY
    end
    
    -- Spiral outward to find nearest walkable cell
    for radius = 1, 20 do
        for dy = -radius, radius do
            for dx = -radius, radius do
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local nx, ny = navX + dx, navY + dy
                    if isWalkable(nx, ny) then
                        return nx, ny
                    end
                end
            end
        end
    end
    
    return nil, nil
end

-- Find nearest walkable coarse cell
local function findNearestCoarseWalkable(cx, cy)
    if isCoarseWalkable(cx, cy) then
        return cx, cy
    end

    for radius = 1, 10 do
        for dy = -radius, radius do
            for dx = -radius, radius do
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local nx, ny = cx + dx, cy + dy
                    if isCoarseWalkable(nx, ny) then
                        return nx, ny
                    end
                end
            end
        end
    end

    return nil, nil
end

-- Coarse A* pathfinding (returns list of coarse cell centers as waypoints)
local function findCoarsePath(startCX, startCY, goalCX, goalCY)
    if not coarseGrid then return nil end

    -- Find nearest walkable coarse cells
    startCX, startCY = findNearestCoarseWalkable(startCX, startCY)
    goalCX, goalCY = findNearestCoarseWalkable(goalCX, goalCY)
    if not startCX or not goalCX then return nil end

    if startCX == goalCX and startCY == goalCY then
        return {}  -- Already there at coarse level
    end

    local openSet = createPriorityQueue()
    local cameFrom = {}
    local gScore = {}
    local closedSet = {}

    gScore[startCY] = {}
    gScore[startCY][startCX] = 0
    cameFrom[startCY] = {}

    local function heuristic(x1, y1, x2, y2)
        local dx = math.abs(x2 - x1)
        local dy = math.abs(y2 - y1)
        return math.max(dx, dy) + 0.414 * math.min(dx, dy)
    end

    local startF = heuristic(startCX, startCY, goalCX, goalCY)
    openSet:push({x = startCX, y = startCY}, startF)

    local iterations = 0
    local maxIterations = 2000

    while not openSet:isEmpty() and iterations < maxIterations do
        iterations = iterations + 1

        local current = openSet:pop()
        local cx, cy = current.x, current.y

        if closedSet[cy] and closedSet[cy][cx] then
            goto continue
        end

        if cx == goalCX and cy == goalCY then
            -- Reconstruct path (coarse waypoints)
            local path = {}
            local px, py = cx, cy

            while cameFrom[py] and cameFrom[py][px] do
                -- Convert coarse cell to world center
                local worldX = (px - 0.5) * COARSE_CELL_SIZE
                local worldY = (py - 0.5) * COARSE_CELL_SIZE
                table.insert(path, 1, {x = worldX, y = worldY})
                local prev = cameFrom[py][px]
                px, py = prev.x, prev.y
            end

            return path
        end

        if not closedSet[cy] then closedSet[cy] = {} end
        closedSet[cy][cx] = true

        for _, dir in ipairs(DIRECTIONS) do
            local nx = cx + dir.dx
            local ny = cy + dir.dy

            if nx >= 1 and nx <= coarseWidth and ny >= 1 and ny <= coarseHeight then
                if not (closedSet[ny] and closedSet[ny][nx]) then
                    if isCoarseWalkable(nx, ny) then
                        -- For diagonal, check adjacent cells
                        local canMove = true
                        if dir.dx ~= 0 and dir.dy ~= 0 then
                            if not isCoarseWalkable(cx + dir.dx, cy) or not isCoarseWalkable(cx, cy + dir.dy) then
                                canMove = false
                            end
                        end

                        if canMove then
                            if not gScore[ny] then gScore[ny] = {} end
                            local tentativeG = gScore[cy][cx] + dir.cost

                            if not gScore[ny][nx] or tentativeG < gScore[ny][nx] then
                                if not cameFrom[ny] then cameFrom[ny] = {} end
                                cameFrom[ny][nx] = {x = cx, y = cy}
                                gScore[ny][nx] = tentativeG

                                local f = tentativeG + heuristic(nx, ny, goalCX, goalCY)
                                openSet:push({x = nx, y = ny}, f)
                            end
                        end
                    end
                end
            end
        end

        ::continue::
    end

    return nil  -- No coarse path found
end

-- A* pathfinding algorithm
-- Returns list of {x, y} world coordinates, or nil if no path
function Pathfinding.findPath(startX, startY, goalX, goalY, unitRadius)
    if not navGrid then return nil end

    unitRadius = unitRadius or 14

    -- Convert to nav coordinates
    local startNavX, startNavY = Pathfinding.worldToNav(startX, startY)
    local goalNavX, goalNavY = Pathfinding.worldToNav(goalX, goalY)

    -- Clamp to grid bounds
    startNavX = math.max(1, math.min(navWidth, startNavX))
    startNavY = math.max(1, math.min(navHeight, startNavY))
    goalNavX = math.max(1, math.min(navWidth, goalNavX))
    goalNavY = math.max(1, math.min(navHeight, goalNavY))

    -- If start is blocked, find nearest walkable cell
    if not isWalkable(startNavX, startNavY) then
        startNavX, startNavY = findNearestWalkable(startNavX, startNavY)
        if not startNavX then return nil end
    end

    -- For goal, we allow blocked cells if that's where the user clicked
    -- (they might be clicking on a building to attack it)
    local goalBlocked = not isWalkable(goalNavX, goalNavY)

    -- If goal is blocked, find nearest walkable cell to it
    local actualGoalNavX, actualGoalNavY = goalNavX, goalNavY
    if goalBlocked then
        actualGoalNavX, actualGoalNavY = findNearestWalkable(goalNavX, goalNavY)
        if not actualGoalNavX then return nil end
    end

    -- Quick check: if start == goal, return trivial path
    if startNavX == actualGoalNavX and startNavY == actualGoalNavY then
        local wx, wy = Pathfinding.navToWorld(startNavX, startNavY)
        return {{x = wx, y = wy}}
    end

    -- Check path cache
    local cacheKey = startNavY .. "," .. startNavX .. "->" .. actualGoalNavY .. "," .. actualGoalNavX
    if pathCache[cacheKey] then
        -- Return a copy so caller can't modify cached path
        local cached = pathCache[cacheKey]
        local copy = {}
        for i, wp in ipairs(cached) do
            copy[i] = {x = wp.x, y = wp.y}
        end
        return copy
    end

    -- Check if this is a long-distance path - use hierarchical approach
    local manhattanDist = math.abs(actualGoalNavX - startNavX) + math.abs(actualGoalNavY - startNavY)
    if manhattanDist > COARSE_THRESHOLD and coarseGrid then
        -- Convert to coarse coordinates
        local ratio = COARSE_CELL_SIZE / NAV_CELL_SIZE
        local startCX = math.ceil(startNavX / ratio)
        local startCY = math.ceil(startNavY / ratio)
        local goalCX = math.ceil(actualGoalNavX / ratio)
        local goalCY = math.ceil(actualGoalNavY / ratio)

        -- Get coarse path
        local coarsePath = findCoarsePath(startCX, startCY, goalCX, goalCY)
        if coarsePath and #coarsePath > 0 then
            -- Build path: start -> coarse waypoints -> goal
            local path = {}

            -- Add coarse waypoints (these are already world coordinates)
            for _, wp in ipairs(coarsePath) do
                table.insert(path, {x = wp.x, y = wp.y})
            end

            -- Add final goal
            table.insert(path, {x = goalX, y = goalY})

            -- Simplify and cache
            path = Pathfinding.simplifyPath(path)

            local pathCopy = {}
            for i, wp in ipairs(path) do
                pathCopy[i] = {x = wp.x, y = wp.y}
            end
            pathCache[cacheKey] = pathCopy

            -- Cache size limit
            local cacheSize = 0
            for _ in pairs(pathCache) do cacheSize = cacheSize + 1 end
            if cacheSize > PATH_CACHE_MAX then
                clearPathCache()
                pathCache[cacheKey] = pathCopy
            end

            return path
        end
        -- Fall through to fine A* if coarse path failed
    end

    -- Fine A* algorithm (for short distances or when coarse fails)
    local openSet = createPriorityQueue()
    local cameFrom = {}  -- cameFrom[y][x] = {fromX, fromY}
    local gScore = {}    -- gScore[y][x] = cost from start
    local closedSet = {} -- closedSet[y][x] = true if visited
    
    -- Initialize
    gScore[startNavY] = {}
    gScore[startNavY][startNavX] = 0
    cameFrom[startNavY] = {}
    
    local startF = heuristic(startNavX, startNavY, actualGoalNavX, actualGoalNavY)
    openSet:push({x = startNavX, y = startNavY}, startF)
    
    local iterations = 0
    local maxIterations = 10000  -- Prevent infinite loops on large maps
    
    while not openSet:isEmpty() and iterations < maxIterations do
        iterations = iterations + 1
        
        local current = openSet:pop()
        local cx, cy = current.x, current.y
        
        -- Skip if already visited (can happen due to duplicate entries in open set)
        if closedSet[cy] and closedSet[cy][cx] then
            goto continue
        end
        
        -- Check if reached goal
        if cx == actualGoalNavX and cy == actualGoalNavY then
            -- Reconstruct path
            local path = {}
            local px, py = cx, cy
            
            while cameFrom[py] and cameFrom[py][px] do
                local worldX, worldY = Pathfinding.navToWorld(px, py)
                table.insert(path, 1, {x = worldX, y = worldY})
                local prev = cameFrom[py][px]
                px, py = prev.x, prev.y
            end
            
            -- Add final goal position (use actual clicked position if goal was walkable)
            if not goalBlocked then
                -- Replace last waypoint with exact goal position
                if #path > 0 then
                    path[#path] = {x = goalX, y = goalY}
                else
                    table.insert(path, {x = goalX, y = goalY})
                end
            end
            
            -- Simplify path (remove unnecessary waypoints)
            path = Pathfinding.simplifyPath(path)

            -- Cache the path (store a copy)
            local pathCopy = {}
            for i, wp in ipairs(path) do
                pathCopy[i] = {x = wp.x, y = wp.y}
            end
            pathCache[cacheKey] = pathCopy

            -- Simple cache size limit - clear if too large
            local cacheSize = 0
            for _ in pairs(pathCache) do cacheSize = cacheSize + 1 end
            if cacheSize > PATH_CACHE_MAX then
                clearPathCache()
                pathCache[cacheKey] = pathCopy  -- Re-add current path
            end

            return path
        end
        
        -- Mark as visited
        if not closedSet[cy] then closedSet[cy] = {} end
        closedSet[cy][cx] = true
        
        -- Explore neighbors
        for _, dir in ipairs(DIRECTIONS) do
            local nx = cx + dir.dx
            local ny = cy + dir.dy
            
            -- Skip if out of bounds or already visited
            if nx >= 1 and nx <= navWidth and ny >= 1 and ny <= navHeight then
                if not (closedSet[ny] and closedSet[ny][nx]) then
                    -- Check if walkable
                    if isWalkable(nx, ny) then
                        -- For diagonal movement, also check the two adjacent cells
                        local canMove = true
                        if dir.dx ~= 0 and dir.dy ~= 0 then
                            -- Diagonal - check both adjacent cells to prevent corner cutting
                            if not isWalkable(cx + dir.dx, cy) or not isWalkable(cx, cy + dir.dy) then
                                canMove = false
                            end
                        end
                        
                        if canMove then
                            if not gScore[ny] then gScore[ny] = {} end
                            local tentativeG = gScore[cy][cx] + dir.cost
                            
                            if not gScore[ny][nx] or tentativeG < gScore[ny][nx] then
                                -- Better path found
                                if not cameFrom[ny] then cameFrom[ny] = {} end
                                cameFrom[ny][nx] = {x = cx, y = cy}
                                gScore[ny][nx] = tentativeG
                                
                                local f = tentativeG + heuristic(nx, ny, actualGoalNavX, actualGoalNavY)
                                openSet:push({x = nx, y = ny}, f)
                            end
                        end
                    end
                end
            end
        end
        
        ::continue::
    end
    
    -- No path found
    return nil
end

-- Simplify path by removing collinear waypoints
function Pathfinding.simplifyPath(path)
    if not path or #path < 3 then return path end
    
    local simplified = {path[1]}
    
    for i = 2, #path - 1 do
        local prev = simplified[#simplified]
        local curr = path[i]
        local next = path[i + 1]
        
        -- Check if curr is collinear with prev and next
        local dx1 = curr.x - prev.x
        local dy1 = curr.y - prev.y
        local dx2 = next.x - curr.x
        local dy2 = next.y - curr.y
        
        -- Normalize
        local len1 = math.sqrt(dx1*dx1 + dy1*dy1)
        local len2 = math.sqrt(dx2*dx2 + dy2*dy2)
        
        if len1 > 0 and len2 > 0 then
            dx1, dy1 = dx1/len1, dy1/len1
            dx2, dy2 = dx2/len2, dy2/len2
            
            -- Check if directions are similar (dot product close to 1)
            local dot = dx1*dx2 + dy1*dy2
            if dot < 0.99 then
                -- Direction changed significantly, keep this waypoint
                table.insert(simplified, curr)
            end
        end
    end
    
    -- Always include the last waypoint
    table.insert(simplified, path[#path])
    
    return simplified
end

-- Helper functions for path following

-- Get direction to next waypoint
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

-- Check if this is the final waypoint
function Pathfinding.isFinalWaypoint(path, waypointIndex)
    if not path or not waypointIndex then
        return true
    end
    return waypointIndex >= #path
end

-- Check if nav grid is initialized
function Pathfinding.isInitialized()
    return navGrid ~= nil
end

-- Get nav grid dimensions (for debugging)
function Pathfinding.getGridSize()
    return navWidth, navHeight
end

-- Debug: check if a world position is walkable
function Pathfinding.isWorldPosWalkable(worldX, worldY)
    local navX, navY = Pathfinding.worldToNav(worldX, worldY)
    return isWalkable(navX, navY)
end

-- For backwards compatibility with old code that passes buildings
-- This version ignores the buildings parameter since navGrid is pre-built
function Pathfinding.canSee(startX, startY, goalX, goalY, buildings, map, unitRadius)
    -- Simple line-of-sight check through nav grid
    local startNavX, startNavY = Pathfinding.worldToNav(startX, startY)
    local goalNavX, goalNavY = Pathfinding.worldToNav(goalX, goalY)
    
    -- Bresenham's line algorithm to check all cells along the line
    local dx = math.abs(goalNavX - startNavX)
    local dy = math.abs(goalNavY - startNavY)
    local sx = startNavX < goalNavX and 1 or -1
    local sy = startNavY < goalNavY and 1 or -1
    local err = dx - dy
    
    local x, y = startNavX, startNavY
    
    while true do
        if not isWalkable(x, y) then
            return false
        end
        
        if x == goalNavX and y == goalNavY then
            break
        end
        
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end
    end
    
    return true
end

return Pathfinding
