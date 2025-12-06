--[[
    A* Pathfinding
    Used as fallback when flow field has no direction for current tile
    Returns a path (list of grid positions) from start to goal
]]

local AStar = {}

-- Priority queue implementation using binary heap
local function createPriorityQueue()
    local pq = {heap = {}, map = {}}
    
    function pq:push(item, priority)
        local node = {item = item, priority = priority}
        table.insert(self.heap, node)
        self.map[item] = #self.heap
        self:bubbleUp(#self.heap)
    end
    
    function pq:pop()
        if #self.heap == 0 then return nil end
        local top = self.heap[1]
        self.map[top.item] = nil
        if #self.heap > 1 then
            self.heap[1] = self.heap[#self.heap]
            self.map[self.heap[1].item] = 1
        end
        table.remove(self.heap)
        if #self.heap > 0 then
            self:bubbleDown(1)
        end
        return top.item
    end
    
    function pq:update(item, priority)
        local idx = self.map[item]
        if idx then
            local oldPriority = self.heap[idx].priority
            self.heap[idx].priority = priority
            if priority < oldPriority then
                self:bubbleUp(idx)
            else
                self:bubbleDown(idx)
            end
        end
    end
    
    function pq:contains(item)
        return self.map[item] ~= nil
    end
    
    function pq:isEmpty()
        return #self.heap == 0
    end
    
    function pq:bubbleUp(idx)
        while idx > 1 do
            local parent = math.floor(idx / 2)
            if self.heap[idx].priority < self.heap[parent].priority then
                self.heap[idx], self.heap[parent] = self.heap[parent], self.heap[idx]
                self.map[self.heap[idx].item] = idx
                self.map[self.heap[parent].item] = parent
                idx = parent
            else
                break
            end
        end
    end
    
    function pq:bubbleDown(idx)
        while true do
            local smallest = idx
            local left = idx * 2
            local right = idx * 2 + 1
            
            if left <= #self.heap and self.heap[left].priority < self.heap[smallest].priority then
                smallest = left
            end
            if right <= #self.heap and self.heap[right].priority < self.heap[smallest].priority then
                smallest = right
            end
            
            if smallest ~= idx then
                self.heap[idx], self.heap[smallest] = self.heap[smallest], self.heap[idx]
                self.map[self.heap[idx].item] = idx
                self.map[self.heap[smallest].item] = smallest
                idx = smallest
            else
                break
            end
        end
    end
    
    return pq
end

-- Direction vectors for 8-directional movement
local DIRECTIONS = {
    {dx = 1, dy = 0, cost = 1},      -- right
    {dx = -1, dy = 0, cost = 1},     -- left
    {dx = 0, dy = 1, cost = 1},      -- down
    {dx = 0, dy = -1, cost = 1},     -- up
    {dx = 1, dy = 1, cost = 1.414},  -- down-right
    {dx = -1, dy = 1, cost = 1.414}, -- down-left
    {dx = 1, dy = -1, cost = 1.414}, -- up-right
    {dx = -1, dy = -1, cost = 1.414}, -- up-left
}

-- Heuristic: octile distance (accounts for diagonal movement)
local function heuristic(x1, y1, x2, y2)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    return math.max(dx, dy) + 0.414 * math.min(dx, dy)
end

-- Find path from start to goal
-- Returns list of {gridX, gridY} positions, or nil if no path
function AStar.findPath(startGridX, startGridY, goalGridX, goalGridY, map, buildings)
    local width = map.width
    local height = map.height
    
    -- Build blocked tile set from buildings
    local blocked = {}
    if buildings then
        for _, b in ipairs(buildings) do
            if b.gridX and b.gridY and b.gridSize then
                for by = b.gridY, b.gridY + b.gridSize - 1 do
                    for bx = b.gridX, b.gridX + b.gridSize - 1 do
                        blocked[by .. "," .. bx] = true
                    end
                end
            end
        end
    end
    
    -- Check if goal is inside a building - find adjacent tile instead
    local actualGoalX, actualGoalY = goalGridX, goalGridY
    if blocked[goalGridY .. "," .. goalGridX] then
        -- Find nearest walkable tile adjacent to the building, closest to the CLICKED position
        local building = nil
        if buildings then
            for _, b in ipairs(buildings) do
                if b.gridX and b.gridY and b.gridSize then
                    if goalGridX >= b.gridX and goalGridX < b.gridX + b.gridSize and
                       goalGridY >= b.gridY and goalGridY < b.gridY + b.gridSize then
                        building = b
                        break
                    end
                end
            end
        end
        
        if building then
            local bestDist = math.huge
            for by = building.gridY - 1, building.gridY + building.gridSize do
                for bx = building.gridX - 1, building.gridX + building.gridSize do
                    local isEdge = (bx == building.gridX - 1 or bx == building.gridX + building.gridSize or
                                   by == building.gridY - 1 or by == building.gridY + building.gridSize)
                    if isEdge then
                        local key = by .. "," .. bx
                        if not blocked[key] and bx >= 1 and bx <= width and by >= 1 and by <= height and map:isTilePassable(bx, by) then
                            -- Distance from CLICKED position, not start position
                            local dist = heuristic(goalGridX, goalGridY, bx, by)
                            if dist < bestDist then
                                bestDist = dist
                                actualGoalX, actualGoalY = bx, by
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Check walkability
    local function isWalkable(x, y)
        if x < 1 or x > width or y < 1 or y > height then
            return false
        end
        if blocked[y .. "," .. x] then
            return false
        end
        return map:isTilePassable(x, y)
    end
    
    -- Check if start is valid
    if not isWalkable(startGridX, startGridY) then
        -- Try to find nearest walkable tile to start
        for _, dir in ipairs(DIRECTIONS) do
            local nx, ny = startGridX + dir.dx, startGridY + dir.dy
            if isWalkable(nx, ny) then
                startGridX, startGridY = nx, ny
                break
            end
        end
    end
    
    -- A* search
    local openSet = createPriorityQueue()
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    
    local startKey = startGridY .. "," .. startGridX
    local goalKey = actualGoalY .. "," .. actualGoalX
    
    gScore[startKey] = 0
    fScore[startKey] = heuristic(startGridX, startGridY, actualGoalX, actualGoalY)
    openSet:push(startKey, fScore[startKey])
    
    local iterations = 0
    local maxIterations = 2000  -- Prevent infinite loops on large searches
    
    while not openSet:isEmpty() and iterations < maxIterations do
        iterations = iterations + 1
        
        local currentKey = openSet:pop()
        
        if currentKey == goalKey then
            -- Reconstruct path
            local path = {}
            local key = currentKey
            while key do
                local y, x = key:match("(%d+),(%d+)")
                table.insert(path, 1, {gridX = tonumber(x), gridY = tonumber(y)})
                key = cameFrom[key]
            end
            return path
        end
        
        local cy, cx = currentKey:match("(%d+),(%d+)")
        cx, cy = tonumber(cx), tonumber(cy)
        
        for _, dir in ipairs(DIRECTIONS) do
            local nx, ny = cx + dir.dx, cy + dir.dy
            
            if isWalkable(nx, ny) then
                local neighborKey = ny .. "," .. nx
                local tentativeG = (gScore[currentKey] or math.huge) + dir.cost
                
                if tentativeG < (gScore[neighborKey] or math.huge) then
                    cameFrom[neighborKey] = currentKey
                    gScore[neighborKey] = tentativeG
                    fScore[neighborKey] = tentativeG + heuristic(nx, ny, actualGoalX, actualGoalY)
                    
                    if not openSet:contains(neighborKey) then
                        openSet:push(neighborKey, fScore[neighborKey])
                    else
                        openSet:update(neighborKey, fScore[neighborKey])
                    end
                end
            end
        end
    end
    
    -- No path found
    return nil
end

-- Get direction to next waypoint from a path
-- Returns normalized dx, dy to move toward next grid cell
function AStar.getDirectionFromPath(path, worldX, worldY, map)
    if not path or #path < 2 then
        return nil, nil
    end
    
    local currentGridX = math.floor(worldX / map.tileSize) + 1
    local currentGridY = math.floor(worldY / map.tileSize) + 1
    
    -- Find current position in path
    local currentIndex = 1
    for i, node in ipairs(path) do
        if node.gridX == currentGridX and node.gridY == currentGridY then
            currentIndex = i
            break
        end
    end
    
    -- Get next waypoint
    local nextIndex = currentIndex + 1
    if nextIndex > #path then
        return nil, nil
    end
    
    local nextNode = path[nextIndex]
    local targetWorldX = (nextNode.gridX - 1) * map.tileSize + map.tileSize / 2
    local targetWorldY = (nextNode.gridY - 1) * map.tileSize + map.tileSize / 2
    
    local dx = targetWorldX - worldX
    local dy = targetWorldY - worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > 0.1 then
        return dx / dist, dy / dist
    end
    
    return nil, nil
end

return AStar
