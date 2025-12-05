--[[
    Flow Field Pathfinding
    Generates direction fields for navigation around obstacles
    Uses BFS from destination to compute optimal direction at each tile
]]

local FlowField = {}
FlowField.__index = FlowField

-- Direction vectors (8-directional)
FlowField.DIRECTIONS = {
    {dx = 1, dy = 0},   -- right
    {dx = -1, dy = 0},  -- left
    {dx = 0, dy = 1},   -- down
    {dx = 0, dy = -1},  -- up
    {dx = 1, dy = 1},   -- down-right
    {dx = -1, dy = 1},  -- down-left
    {dx = 1, dy = -1},  -- up-right
    {dx = -1, dy = -1}, -- up-left
}

-- Cache of flow fields by destination key
local fieldCache = {}

function FlowField.new(destGridX, destGridY, map, buildings)
    local self = setmetatable({}, FlowField)
    
    self.destX = destGridX
    self.destY = destGridY
    self.width = map.width
    self.height = map.height
    
    -- Direction to move at each tile (nil if blocked or unreachable)
    -- Format: {dx, dy} normalized direction vector
    self.directions = {}
    
    -- Cost to reach destination from each tile (for debugging/visualization)
    self.costs = {}
    
    -- Generate the field
    self:generate(map, buildings)
    
    return self
end

-- Generate flow field using BFS from destination
function FlowField:generate(map, buildings)
    -- Initialize grids
    for y = 1, self.height do
        self.directions[y] = {}
        self.costs[y] = {}
        for x = 1, self.width do
            self.directions[y][x] = nil
            self.costs[y][x] = math.huge
        end
    end
    
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
    
    -- Check if a tile is walkable
    local function isWalkable(x, y)
        if x < 1 or x > self.width or y < 1 or y > self.height then
            return false
        end
        if blocked[y .. "," .. x] then
            return false
        end
        return map:isTilePassable(x, y)
    end
    
    -- BFS from destination
    local queue = {}
    local queueStart = 1
    local queueEnd = 1
    
    -- Seed with destination (and adjacent tiles if dest is a building)
    if blocked[self.destY .. "," .. self.destX] then
        -- Destination is inside a building - seed from all adjacent walkable tiles
        for _, dir in ipairs(FlowField.DIRECTIONS) do
            -- Check building bounds
            local building = nil
            if buildings then
                for _, b in ipairs(buildings) do
                    if b.gridX and b.gridY and b.gridSize then
                        if self.destX >= b.gridX and self.destX < b.gridX + b.gridSize and
                           self.destY >= b.gridY and self.destY < b.gridY + b.gridSize then
                            building = b
                            break
                        end
                    end
                end
            end
            
            if building then
                -- Seed from all tiles adjacent to this building
                for by = building.gridY - 1, building.gridY + building.gridSize do
                    for bx = building.gridX - 1, building.gridX + building.gridSize do
                        local isEdge = (bx == building.gridX - 1 or bx == building.gridX + building.gridSize or
                                       by == building.gridY - 1 or by == building.gridY + building.gridSize)
                        if isEdge and isWalkable(bx, by) then
                            self.costs[by][bx] = 0
                            queue[queueEnd] = {x = bx, y = by}
                            queueEnd = queueEnd + 1
                        end
                    end
                end
                break
            end
        end
    else
        -- Normal case - destination is walkable
        self.costs[self.destY][self.destX] = 0
        queue[queueEnd] = {x = self.destX, y = self.destY}
        queueEnd = queueEnd + 1
    end
    
    -- BFS to compute costs
    while queueStart < queueEnd do
        local current = queue[queueStart]
        queueStart = queueStart + 1
        
        local currentCost = self.costs[current.y][current.x]
        
        for _, dir in ipairs(FlowField.DIRECTIONS) do
            local nx, ny = current.x + dir.dx, current.y + dir.dy
            
            if isWalkable(nx, ny) then
                -- Diagonal movement costs more
                local moveCost = (dir.dx ~= 0 and dir.dy ~= 0) and 1.414 or 1
                local newCost = currentCost + moveCost
                
                if newCost < self.costs[ny][nx] then
                    self.costs[ny][nx] = newCost
                    queue[queueEnd] = {x = nx, y = ny}
                    queueEnd = queueEnd + 1
                end
            end
        end
    end
    
    -- Compute direction vectors (point toward lowest cost neighbor)
    for y = 1, self.height do
        for x = 1, self.width do
            if self.costs[y][x] < math.huge then
                local bestDx, bestDy = 0, 0
                local bestCost = self.costs[y][x]
                
                for _, dir in ipairs(FlowField.DIRECTIONS) do
                    local nx, ny = x + dir.dx, y + dir.dy
                    if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                        if self.costs[ny][nx] < bestCost then
                            bestCost = self.costs[ny][nx]
                            bestDx, bestDy = dir.dx, dir.dy
                        end
                    end
                end
                
                if bestDx ~= 0 or bestDy ~= 0 then
                    -- Normalize
                    local len = math.sqrt(bestDx * bestDx + bestDy * bestDy)
                    self.directions[y][x] = {dx = bestDx / len, dy = bestDy / len}
                end
            end
        end
    end
end

-- Get direction to move from a world position
-- Returns dx, dy (normalized) or nil if unreachable
function FlowField:getDirection(worldX, worldY, map)
    local gridX = math.floor(worldX / map.tileSize) + 1
    local gridY = math.floor(worldY / map.tileSize) + 1
    
    if gridX < 1 or gridX > self.width or gridY < 1 or gridY > self.height then
        return nil, nil
    end
    
    local dir = self.directions[gridY][gridX]
    if dir then
        return dir.dx, dir.dy
    end
    return nil, nil
end

-- Get cost (distance) from a world position to destination
function FlowField:getCost(worldX, worldY, map)
    local gridX = math.floor(worldX / map.tileSize) + 1
    local gridY = math.floor(worldY / map.tileSize) + 1
    
    if gridX < 1 or gridX > self.width or gridY < 1 or gridY > self.height then
        return math.huge
    end
    
    return self.costs[gridY][gridX]
end

-- Check if a position can reach the destination
function FlowField:isReachable(worldX, worldY, map)
    return self:getCost(worldX, worldY, map) < math.huge
end

-- Static method: Get or create a cached flow field
function FlowField.getField(destGridX, destGridY, map, buildings)
    local key = destGridX .. "," .. destGridY
    
    if not fieldCache[key] then
        fieldCache[key] = FlowField.new(destGridX, destGridY, map, buildings)
    end
    
    return fieldCache[key]
end

-- Static method: Invalidate all cached flow fields (call when map changes)
function FlowField.invalidateAll()
    fieldCache = {}
end

-- Static method: Invalidate a specific flow field
function FlowField.invalidate(destGridX, destGridY)
    local key = destGridX .. "," .. destGridY
    fieldCache[key] = nil
end

-- Debug: Draw flow field arrows
function FlowField:debugDraw(map)
    love.graphics.setColor(1, 1, 0, 0.5)
    love.graphics.setLineWidth(1)
    
    for y = 1, self.height do
        for x = 1, self.width do
            local dir = self.directions[y][x]
            if dir then
                local worldX, worldY = map:gridToWorld(x, y)
                local screenX, screenY = map:worldToScreen(worldX + 16, worldY + 16)
                
                local arrowLen = 10
                local endX = screenX + dir.dx * arrowLen
                local endY = screenY + dir.dy * arrowLen
                
                love.graphics.line(screenX, screenY, endX, endY)
            end
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return FlowField
