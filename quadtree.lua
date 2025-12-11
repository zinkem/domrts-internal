--[[
    Quadtree - Spatial partitioning for efficient neighbor queries

    Usage:
        local qt = Quadtree.new(0, 0, worldWidth, worldHeight)
        qt:insert(unit)  -- unit must have a method to get coordinates
        local nearby = qt:query(x, y, radius)
        qt:clear()  -- reset for next frame
]]

local Quadtree = {}
Quadtree.__index = Quadtree

-- Configuration (can be overridden per-tree)
-- Benchmarked: cap=16 significantly outperforms cap=4 for 500-1000 units
local DEFAULT_MAX_OBJECTS = 16  -- Max objects before subdivision
local DEFAULT_MAX_DEPTH = 8     -- Maximum tree depth

-- Create a new quadtree node
-- x, y = top-left corner, w, h = dimensions
-- Optional config: {maxObjects = N, maxDepth = N}
function Quadtree.new(x, y, w, h, depth, config)
    local self = setmetatable({}, Quadtree)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.depth = depth or 0
    self.objects = {}
    self.divided = false
    -- Configuration (inherited from root or use defaults)
    self.maxObjects = config and config.maxObjects or DEFAULT_MAX_OBJECTS
    self.maxDepth = config and config.maxDepth or DEFAULT_MAX_DEPTH
    self.config = config  -- Pass to children
    -- Children: nw, ne, sw, se (created on subdivision)
    self.nw = nil
    self.ne = nil
    self.sw = nil
    self.se = nil
    return self
end

-- Check if a point is within this node's bounds
function Quadtree:contains(px, py)
    return px >= self.x and px < self.x + self.w and
           py >= self.y and py < self.y + self.h
end

-- Check if a circular region intersects this node's bounds
function Quadtree:intersects(cx, cy, radius)
    -- Find closest point on rectangle to circle center
    local closestX = math.max(self.x, math.min(cx, self.x + self.w))
    local closestY = math.max(self.y, math.min(cy, self.y + self.h))
    local dx = cx - closestX
    local dy = cy - closestY
    return (dx * dx + dy * dy) <= (radius * radius)
end

-- Subdivide this node into 4 children
function Quadtree:subdivide()
    local halfW = self.w / 2
    local halfH = self.h / 2
    local nextDepth = self.depth + 1

    self.nw = Quadtree.new(self.x, self.y, halfW, halfH, nextDepth, self.config)
    self.ne = Quadtree.new(self.x + halfW, self.y, halfW, halfH, nextDepth, self.config)
    self.sw = Quadtree.new(self.x, self.y + halfH, halfW, halfH, nextDepth, self.config)
    self.se = Quadtree.new(self.x + halfW, self.y + halfH, halfW, halfH, nextDepth, self.config)

    self.divided = true
end

-- Insert an object into the quadtree
-- Object must have a way to get coordinates (configured via getPosition function)
function Quadtree:insert(obj, getX, getY)
    local px = getX(obj)
    local py = getY(obj)

    -- Ignore if outside bounds
    if not self:contains(px, py) then
        return false
    end

    -- If we have room and haven't subdivided, add here
    if #self.objects < self.maxObjects and not self.divided then
        table.insert(self.objects, obj)
        return true
    end

    -- Subdivide if we haven't yet (and not at max depth)
    if not self.divided then
        if self.depth >= self.maxDepth then
            -- At max depth, just add to this node
            table.insert(self.objects, obj)
            return true
        end
        self:subdivide()

        -- Re-insert existing objects into children
        local oldObjects = self.objects
        self.objects = {}
        for _, oldObj in ipairs(oldObjects) do
            self:insert(oldObj, getX, getY)
        end
    end

    -- Insert into appropriate child
    if self.nw:insert(obj, getX, getY) then return true end
    if self.ne:insert(obj, getX, getY) then return true end
    if self.sw:insert(obj, getX, getY) then return true end
    if self.se:insert(obj, getX, getY) then return true end

    return false
end

-- Query all objects within a circular region
function Quadtree:query(cx, cy, radius, found, getX, getY)
    found = found or {}

    -- Skip if this node doesn't intersect the query region
    if not self:intersects(cx, cy, radius) then
        return found
    end

    -- Check objects in this node
    local radiusSq = radius * radius
    for _, obj in ipairs(self.objects) do
        local px = getX(obj)
        local py = getY(obj)
        local dx = px - cx
        local dy = py - cy
        if (dx * dx + dy * dy) <= radiusSq then
            table.insert(found, obj)
        end
    end

    -- Recurse into children
    if self.divided then
        self.nw:query(cx, cy, radius, found, getX, getY)
        self.ne:query(cx, cy, radius, found, getX, getY)
        self.sw:query(cx, cy, radius, found, getX, getY)
        self.se:query(cx, cy, radius, found, getX, getY)
    end

    return found
end

-- Remove an object from the quadtree
-- Returns true if found and removed
function Quadtree:remove(obj, getX, getY)
    local px = getX(obj)
    local py = getY(obj)

    -- Check if in bounds
    if not self:contains(px, py) then
        return false
    end

    -- Check this node's objects
    for i, o in ipairs(self.objects) do
        if o == obj then
            table.remove(self.objects, i)
            return true
        end
    end

    -- Check children
    if self.divided then
        if self.nw:remove(obj, getX, getY) then return true end
        if self.ne:remove(obj, getX, getY) then return true end
        if self.sw:remove(obj, getX, getY) then return true end
        if self.se:remove(obj, getX, getY) then return true end
    end

    return false
end

-- Update an object's position in the quadtree
-- Removes from old position and re-inserts at new position
-- oldX, oldY = previous position (before the object moved)
function Quadtree:update(obj, oldX, oldY, getX, getY)
    -- Create temporary accessor for old position
    local function getOldX() return oldX end
    local function getOldY() return oldY end

    -- Remove from old position
    self:remove(obj, getOldX, getOldY)

    -- Insert at new position
    self:insert(obj, getX, getY)
end

-- Clear all objects (reuse structure for next frame)
function Quadtree:clear()
    self.objects = {}
    if self.divided then
        self.nw:clear()
        self.ne:clear()
        self.sw:clear()
        self.se:clear()
    end
    -- Optionally collapse subdivisions:
    -- self.divided = false
    -- self.nw, self.ne, self.sw, self.se = nil, nil, nil, nil
end

-- Check if a rectangle intersects this node's bounds
function Quadtree:intersectsRect(rx, ry, rw, rh)
    return not (rx > self.x + self.w or rx + rw < self.x or
                ry > self.y + self.h or ry + rh < self.y)
end

-- Query all objects within a rectangle
function Quadtree:queryRect(rx, ry, rw, rh, found, getX, getY)
    found = found or {}

    if not self:intersectsRect(rx, ry, rw, rh) then
        return found
    end

    -- Check objects in this node
    for _, obj in ipairs(self.objects) do
        local px = getX(obj)
        local py = getY(obj)
        if px >= rx and px < rx + rw and py >= ry and py < ry + rh then
            table.insert(found, obj)
        end
    end

    -- Recurse into children
    if self.divided then
        self.nw:queryRect(rx, ry, rw, rh, found, getX, getY)
        self.ne:queryRect(rx, ry, rw, rh, found, getX, getY)
        self.sw:queryRect(rx, ry, rw, rh, found, getX, getY)
        self.se:queryRect(rx, ry, rw, rh, found, getX, getY)
    end

    return found
end

-- Find the closest object within a radius that passes a filter
-- Returns (object, distance) or (nil, nil) if none found
function Quadtree:findClosest(cx, cy, radius, getX, getY, filterFn)
    local candidates = self:query(cx, cy, radius, nil, getX, getY)

    local closest = nil
    local closestDist = math.huge

    for _, obj in ipairs(candidates) do
        if not filterFn or filterFn(obj) then
            local px = getX(obj)
            local py = getY(obj)
            local dx = px - cx
            local dy = py - cy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < closestDist then
                closest = obj
                closestDist = dist
            end
        end
    end

    if closest then
        return closest, closestDist
    end
    return nil, nil
end

-- Find ANY object within a radius that passes a filter (early exit, faster than findClosest)
-- Returns object or nil if none found
function Quadtree:findAny(cx, cy, radius, getX, getY, filterFn)
    -- Check if this node intersects the query region
    if not self:intersects(cx, cy, radius) then
        return nil
    end

    -- Check objects in this node first
    local radiusSq = radius * radius
    for _, obj in ipairs(self.objects) do
        local px = getX(obj)
        local py = getY(obj)
        local dx = px - cx
        local dy = py - cy
        if (dx * dx + dy * dy) <= radiusSq then
            if not filterFn or filterFn(obj) then
                return obj  -- Early exit on first match
            end
        end
    end

    -- Recurse into children
    if self.divided then
        local found = self.nw:findAny(cx, cy, radius, getX, getY, filterFn)
        if found then return found end
        found = self.ne:findAny(cx, cy, radius, getX, getY, filterFn)
        if found then return found end
        found = self.sw:findAny(cx, cy, radius, getX, getY, filterFn)
        if found then return found end
        found = self.se:findAny(cx, cy, radius, getX, getY, filterFn)
        if found then return found end
    end

    return nil
end

return Quadtree
