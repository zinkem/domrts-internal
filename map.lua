--[[
    Map
    64x64 tile grid with scrolling, terrain generation
    Tile size: 32x32 pixels
    
    ENHANCED: Trees now have variation and wind sway
]]

-- Visual enhancement modules (optional - graceful fallback if missing)
local DrawUtils
pcall(function() DrawUtils = require("draw_utils") end)

local Map = {}
Map.__index = Map

-- Tile types
Map.TILE_GRASS = 1
Map.TILE_TREE = 2
Map.TILE_STUMP = 3

-- Fog of war states
Map.FOG_UNEXPLORED = 0  -- Black, never seen
Map.FOG_EXPLORED = 1    -- Dimmed, seen before but no vision
Map.FOG_VISIBLE = 2     -- Full visibility, unit nearby

-- Constants
Map.TILE_SIZE = 32
Map.WIDTH = 64
Map.HEIGHT = 64

-- Animation time (for tree sway)
Map.animTime = 0

function Map.new()
    local self = setmetatable({}, Map)
    
    self.tileSize = Map.TILE_SIZE
    self.width = Map.WIDTH
    self.height = Map.HEIGHT
    
    -- Camera position (top-left in world pixels)
    self.cameraX = 0
    self.cameraY = 0
    self.scrollSpeed = 400
    self.edgeScrollSpeed = 350  -- Edge scroll slightly slower
    self.edgeScrollMargin = 20  -- Pixels from edge to trigger scroll
    
    -- Viewport (set by gameplay)
    self.viewportX = 0
    self.viewportY = 0
    self.viewportW = 800
    self.viewportH = 600
    
    -- Minimap dragging
    self.minimapDragging = false
    
    -- Tree health tracking (harvests remaining)
    self.treeHealth = {}
    
    -- Fog of war
    self.fogEnabled = true
    self.fog = {}
    for y = 1, self.height do
        self.fog[y] = {}
        for x = 1, self.width do
            self.fog[y][x] = Map.FOG_UNEXPLORED
        end
    end
    
    -- Perlin noise seed
    self.noiseSeed = math.random(0, 1000)
    
    -- Initialize tiles as grass
    self.tiles = {}
    for y = 1, self.height do
        self.tiles[y] = {}
        for x = 1, self.width do
            self.tiles[y][x] = Map.TILE_GRASS
        end
    end
    
    -- Generate trees using perlin noise
    self:generateTerrain()
    
    return self
end

-- Simple perlin-like noise using sine waves
function Map:noise2D(x, y)
    local seed = self.noiseSeed
    local n = math.sin(x * 0.1 + seed) * math.cos(y * 0.1 + seed * 0.7)
    n = n + math.sin(x * 0.05 + y * 0.08 + seed * 1.3) * 0.5
    n = n + math.sin(x * 0.2 - y * 0.15 + seed * 0.3) * 0.25
    return (n + 1.75) / 3.5  -- Normalize to 0-1
end

function Map:generateTerrain()
    local treeThreshold = 0.65  -- Higher = fewer trees
    
    for y = 1, self.height do
        self.treeHealth[y] = {}
        for x = 1, self.width do
            local n = self:noise2D(x, y)
            if n > treeThreshold then
                self.tiles[y][x] = Map.TILE_TREE
                self.treeHealth[y][x] = 10  -- 10 harvests per tree
            else
                self.treeHealth[y][x] = 0
            end
        end
    end
end

function Map:clearArea(gridX, gridY, gridW, gridH)
    for y = gridY, gridY + gridH - 1 do
        for x = gridX, gridX + gridW - 1 do
            if y >= 1 and y <= self.height and x >= 1 and x <= self.width then
                self.tiles[y][x] = Map.TILE_GRASS
            end
        end
    end
end

function Map:isAreaClear(gridX, gridY, gridW, gridH)
    for y = gridY, gridY + gridH - 1 do
        for x = gridX, gridX + gridW - 1 do
            if x < 1 or x > self.width or y < 1 or y > self.height then
                return false
            end
            if self.tiles[y][x] == Map.TILE_TREE then
                return false
            end
        end
    end
    return true
end

function Map:findClearArea(gridW, gridH, preferX, preferY, searchRadius)
    searchRadius = searchRadius or 20
    
    -- Try preferred position first
    if preferX and preferY then
        if self:isAreaClear(preferX, preferY, gridW, gridH) then
            return preferX, preferY
        end
        
        -- Spiral outward from preferred position
        for dist = 1, searchRadius do
            for dx = -dist, dist do
                for dy = -dist, dist do
                    if math.abs(dx) == dist or math.abs(dy) == dist then
                        local testX = preferX + dx
                        local testY = preferY + dy
                        if self:isAreaClear(testX, testY, gridW, gridH) then
                            return testX, testY
                        end
                    end
                end
            end
        end
    end
    
    -- Random search as fallback
    for attempt = 1, 100 do
        local testX = math.random(2, self.width - gridW - 1)
        local testY = math.random(2, self.height - gridH - 1)
        if self:isAreaClear(testX, testY, gridW, gridH) then
            return testX, testY
        end
    end
    
    return nil, nil
end

function Map:setViewport(x, y, w, h)
    self.viewportX = x
    self.viewportY = y
    self.viewportW = w
    self.viewportH = h
end

function Map:clampCamera()
    local maxX = self.width * self.tileSize - self.viewportW
    local maxY = self.height * self.tileSize - self.viewportH
    self.cameraX = math.max(0, math.min(self.cameraX, maxX))
    self.cameraY = math.max(0, math.min(self.cameraY, maxY))
end

function Map:scroll(dx, dy)
    self.cameraX = self.cameraX + dx
    self.cameraY = self.cameraY + dy
    self:clampCamera()
end

function Map:centerOn(worldX, worldY)
    self.cameraX = worldX - self.viewportW / 2
    self.cameraY = worldY - self.viewportH / 2
    self:clampCamera()
end

function Map:centerOnTile(gridX, gridY)
    local worldX = (gridX - 0.5) * self.tileSize
    local worldY = (gridY - 0.5) * self.tileSize
    self:centerOn(worldX, worldY)
end

-- Convert grid coords to world pixels (top-left of tile)
function Map:gridToWorld(gridX, gridY)
    return (gridX - 1) * self.tileSize, (gridY - 1) * self.tileSize
end

-- Convert world pixels to grid coords
function Map:worldToGrid(worldX, worldY)
    return math.floor(worldX / self.tileSize) + 1, math.floor(worldY / self.tileSize) + 1
end

-- Convert world pixels to screen pixels
function Map:worldToScreen(worldX, worldY)
    return worldX - self.cameraX + self.viewportX, worldY - self.cameraY + self.viewportY
end

-- Convert screen pixels to world pixels
function Map:screenToWorld(screenX, screenY)
    return screenX + self.cameraX - self.viewportX, screenY + self.cameraY - self.viewportY
end

function Map:isInViewport(screenX, screenY)
    return screenX >= self.viewportX and screenX <= self.viewportX + self.viewportW and
           screenY >= self.viewportY and screenY <= self.viewportY + self.viewportH
end

function Map:isTilePassable(gridX, gridY)
    if gridX < 1 or gridX > self.width or gridY < 1 or gridY > self.height then
        return false
    end
    return self.tiles[gridY][gridX] ~= Map.TILE_TREE
end

function Map:isTileTree(gridX, gridY)
    if gridX < 1 or gridX > self.width or gridY < 1 or gridY > self.height then
        return false
    end
    return self.tiles[gridY][gridX] == Map.TILE_TREE
end

function Map:harvestTree(gridX, gridY)
    -- Returns true if tree still has health, false if depleted
    if not self:isTileTree(gridX, gridY) then
        return false
    end
    
    -- Ensure health table exists for this row
    if not self.treeHealth[gridY] then
        self.treeHealth[gridY] = {}
    end
    
    -- Initialize health if not set
    if not self.treeHealth[gridY][gridX] then
        self.treeHealth[gridY][gridX] = 10
    end
    
    -- Decrement health
    self.treeHealth[gridY][gridX] = self.treeHealth[gridY][gridX] - 1
    
    -- Check if depleted
    if self.treeHealth[gridY][gridX] <= 0 then
        self.tiles[gridY][gridX] = Map.TILE_STUMP
        return false  -- Tree is gone
    end
    
    return true  -- Tree still has health
end

function Map:getTileWorldCenter(gridX, gridY)
    local wx, wy = self:gridToWorld(gridX, gridY)
    return wx + self.tileSize / 2, wy + self.tileSize / 2
end

function Map:isWorldPosPassable(worldX, worldY)
    local gridX, gridY = self:worldToGrid(worldX, worldY)
    return self:isTilePassable(gridX, gridY)
end

function Map:update(dt, disableEdgeScroll)
    -- Update animation time for tree sway
    Map.animTime = Map.animTime + dt
    if DrawUtils then
        DrawUtils.update(dt)
    end
    
    -- Keyboard scrolling (arrow keys only - WASD reserved for commands)
    local dx, dy = 0, 0
    if love.keyboard.isDown("left") then
        dx = -self.scrollSpeed * dt
    end
    if love.keyboard.isDown("right") then
        dx = self.scrollSpeed * dt
    end
    if love.keyboard.isDown("up") then
        dy = -self.scrollSpeed * dt
    end
    if love.keyboard.isDown("down") then
        dy = self.scrollSpeed * dt
    end
    
    -- Edge scrolling (when mouse near edge of screen or outside window)
    if not disableEdgeScroll then
        local mx, my = love.mouse.getPosition()
        local ww, wh = love.graphics.getDimensions()
        local inWindow = mx >= 0 and mx <= ww and my >= 0 and my <= wh
        
        -- Check if mouse is in viewport area (not in UI)
        local inViewport = mx >= self.viewportX and mx <= self.viewportX + self.viewportW and
                          my >= self.viewportY and my <= self.viewportY + self.viewportH
        
        if inViewport or not inWindow then
            local edgeDx, edgeDy = 0, 0
            
            -- Left edge or off left
            if mx < self.viewportX + self.edgeScrollMargin or (not inWindow and mx < 0) then
                edgeDx = -self.edgeScrollSpeed * dt
            end
            -- Right edge or off right  
            if mx > self.viewportX + self.viewportW - self.edgeScrollMargin or (not inWindow and mx > ww) then
                edgeDx = self.edgeScrollSpeed * dt
            end
            -- Top edge or off top
            if my < self.viewportY + self.edgeScrollMargin or (not inWindow and my < 0) then
                edgeDy = -self.edgeScrollSpeed * dt
            end
            -- Bottom edge or off bottom
            if my > self.viewportY + self.viewportH - self.edgeScrollMargin or (not inWindow and my > wh) then
                edgeDy = self.edgeScrollSpeed * dt
            end
            
            dx = dx + edgeDx
            dy = dy + edgeDy
        end
    end
    
    if dx ~= 0 or dy ~= 0 then
        self:scroll(dx, dy)
    end
    
    -- Handle minimap dragging
    if self.minimapDragging and love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        self:minimapNavigate(mx, my)
    elseif self.minimapDragging and not love.mouse.isDown(1) then
        self.minimapDragging = false
    end
end

-- Update fog of war based on unit positions
function Map:updateFog(units, buildings, playerTeam)
    if not self.fogEnabled then return end
    
    -- Reset all visible tiles to explored (they were seen but no longer have vision)
    for y = 1, self.height do
        for x = 1, self.width do
            if self.fog[y][x] == Map.FOG_VISIBLE then
                self.fog[y][x] = Map.FOG_EXPLORED
            end
        end
    end
    
    -- Grant vision from player units
    for _, unit in ipairs(units) do
        if unit.team == playerTeam and not (unit.isDead and unit:isDead()) then
            local sightRadius = unit.sightRadius or 4  -- Default 4 tiles
            local gridX, gridY = self:worldToGrid(unit.worldX, unit.worldY)
            self:revealArea(gridX, gridY, sightRadius)
        end
    end
    
    -- Grant vision from player buildings
    for _, building in ipairs(buildings) do
        if building.team == playerTeam and not (building.isDead and building:isDead()) then
            local sightRadius = building.sightRadius or 5  -- Buildings see a bit further
            local cx, cy = building:getWorldCenter()
            local gridX, gridY = self:worldToGrid(cx, cy)
            self:revealArea(gridX, gridY, sightRadius)
        end
    end
end

-- Reveal area around a point
function Map:revealArea(centerX, centerY, radius)
    local radiusSq = radius * radius
    for dy = -radius, radius do
        for dx = -radius, radius do
            if dx * dx + dy * dy <= radiusSq then
                local x = centerX + dx
                local y = centerY + dy
                if x >= 1 and x <= self.width and y >= 1 and y <= self.height then
                    self.fog[y][x] = Map.FOG_VISIBLE
                end
            end
        end
    end
end

-- Check fog state
function Map:getTileFog(gridX, gridY)
    if gridX < 1 or gridX > self.width or gridY < 1 or gridY > self.height then
        return Map.FOG_UNEXPLORED
    end
    return self.fog[gridY][gridX]
end

function Map:isTileVisible(gridX, gridY)
    return self:getTileFog(gridX, gridY) == Map.FOG_VISIBLE
end

function Map:isTileExplored(gridX, gridY)
    local fog = self:getTileFog(gridX, gridY)
    return fog == Map.FOG_VISIBLE or fog == Map.FOG_EXPLORED
end

function Map:draw()
    -- Calculate visible tile range
    local startX = math.floor(self.cameraX / self.tileSize) + 1
    local startY = math.floor(self.cameraY / self.tileSize) + 1
    local endX = math.ceil((self.cameraX + self.viewportW) / self.tileSize) + 1
    local endY = math.ceil((self.cameraY + self.viewportH) / self.tileSize) + 1
    
    startX = math.max(1, startX)
    startY = math.max(1, startY)
    endX = math.min(self.width, endX)
    endY = math.min(self.height, endY)
    
    love.graphics.setScissor(self.viewportX, self.viewportY, self.viewportW, self.viewportH)
    
    -- Helper to check if a tile is a tree
    local function isTree(tx, ty)
        if tx < 1 or tx > self.width or ty < 1 or ty > self.height then
            return false
        end
        return self.tiles[ty][tx] == Map.TILE_TREE
    end
    
    -- Seeded random helper for fallback
    local function sRand(s, i)
        local v = math.sin(s * 12.9898 + i * 78.233) * 43758.5453
        return v - math.floor(v)
    end
    
    --===========================================
    -- PASS 1: Draw all terrain/ground tiles
    --===========================================
    for y = startY, endY do
        for x = startX, endX do
            local worldX, worldY = self:gridToWorld(x, y)
            local screenX, screenY = self:worldToScreen(worldX, worldY)
            local tile = self.tiles[y][x]
            
            if tile == Map.TILE_GRASS then
                self:drawHoundstoothTile(screenX, screenY, x, y)
                
            elseif tile == Map.TILE_TREE then
                -- Draw dark forest floor only (canopy in pass 2)
                if DrawUtils then
                    DrawUtils.drawForestFloor(screenX, screenY, self.tileSize, x, y)
                else
                    -- Fallback forest floor
                    local seed = x * 7919 + y * 4637
                    love.graphics.setColor(0.08, 0.15, 0.06, 1)
                    love.graphics.rectangle("fill", screenX, screenY, self.tileSize, self.tileSize)
                    love.graphics.setColor(0.05, 0.11, 0.04, 1)
                    for i = 1, 3 do
                        local lx = screenX + sRand(seed, 600 + i) * self.tileSize
                        local ly = screenY + sRand(seed, 610 + i) * self.tileSize
                        love.graphics.ellipse("fill", lx, ly, 5, 3)
                    end
                end
                
            elseif tile == Map.TILE_STUMP then
                -- Brown stump tile with low contrast to grass
                love.graphics.setColor(0.28, 0.38, 0.22, 1)
                love.graphics.rectangle("fill", screenX, screenY, self.tileSize, self.tileSize)
                love.graphics.setColor(0.25, 0.35, 0.20, 1)
                love.graphics.rectangle("fill", screenX + 4, screenY + 4, 10, 8)
                love.graphics.rectangle("fill", screenX + 18, screenY + 20, 8, 6)
                love.graphics.setColor(0.35, 0.25, 0.15, 1)
                love.graphics.circle("fill", screenX + 16, screenY + 16, 5)
                love.graphics.setColor(0.30, 0.22, 0.12, 1)
                love.graphics.circle("fill", screenX + 16, screenY + 16, 3)
            end
        end
    end
    
    --===========================================
    -- PASS 2: Draw tree canopy (foliage layer)
    -- Drawn in Y order so lower trees overlap higher ones
    --===========================================
    for y = startY, endY do
        for x = startX, endX do
            local tile = self.tiles[y][x]
            
            if tile == Map.TILE_TREE then
                local worldX, worldY = self:gridToWorld(x, y)
                local screenX, screenY = self:worldToScreen(worldX, worldY)
                local seed = x * 7919 + y * 4637
                
                -- Detect edges
                local isEdge = not isTree(x-1, y) or not isTree(x+1, y) or 
                               not isTree(x, y-1) or not isTree(x, y+1)
                local edgeSides = {
                    left = not isTree(x-1, y),
                    right = not isTree(x+1, y),
                    top = not isTree(x, y-1),
                    bottom = not isTree(x, y+1)
                }
                
                if DrawUtils then
                    DrawUtils.drawTreeCanopy(screenX, screenY, x, y, self.tileSize, isEdge, edgeSides)
                else
                    -- Fallback canopy with chunky shapes
                    local sway = math.sin(Map.animTime * 1.2 + x * 0.1 + y * 0.13) * 2
                    local colorVar = (sRand(seed, 1) - 0.5) * 0.05
                    
                    -- Draw chunky foliage blobs
                    for i = 1, 3 do
                        local cx = screenX + self.tileSize * (0.2 + sRand(seed, 50 + i) * 0.6)
                        local cy = screenY + self.tileSize * (0.2 + sRand(seed, 60 + i) * 0.5)
                        local chunkSway = sway * (0.5 + sRand(seed, 80 + i) * 0.5)
                        
                        -- Back layer
                        love.graphics.setColor(0.05 + colorVar, 0.25 + colorVar, 0.07, 1)
                        love.graphics.circle("fill", cx + chunkSway * 0.3 - 4, cy + 3, 10)
                        love.graphics.circle("fill", cx + chunkSway * 0.3 + 5, cy + 2, 9)
                        
                        -- Mid layer  
                        love.graphics.setColor(0.08 + colorVar, 0.34 + colorVar, 0.1, 1)
                        love.graphics.circle("fill", cx + chunkSway * 0.5, cy, 12)
                        love.graphics.circle("fill", cx + chunkSway * 0.5 + 6, cy + 4, 8)
                        
                        -- Light layer
                        love.graphics.setColor(0.12 + colorVar, 0.44 + colorVar, 0.14, 1)
                        love.graphics.circle("fill", cx + chunkSway * 0.7 - 2, cy - 3, 8)
                    end
                    
                    -- Highlights
                    love.graphics.setColor(0.14 + colorVar, 0.48 + colorVar, 0.16, 0.85)
                    for i = 1, 2 do
                        local hx = screenX + sRand(seed, 550 + i) * self.tileSize
                        local hy = screenY + sRand(seed, 560 + i) * self.tileSize * 0.6
                        love.graphics.circle("fill", hx + sway * 0.7, hy, 5)
                    end
                    
                    -- Edge foliage
                    if isEdge then
                        for i = 1, 3 do
                            local ex, ey, angle
                            if edgeSides.left then
                                ex = screenX - 2 + sRand(seed, 900 + i) * 10
                                ey = screenY + sRand(seed, 910 + i) * self.tileSize
                                angle = -math.pi * 0.5
                            elseif edgeSides.right then
                                ex = screenX + self.tileSize - 8 + sRand(seed, 901 + i) * 10
                                ey = screenY + sRand(seed, 911 + i) * self.tileSize
                                angle = math.pi * 0.5
                            elseif edgeSides.bottom then
                                ex = screenX + sRand(seed, 902 + i) * self.tileSize
                                ey = screenY + self.tileSize - 8 + sRand(seed, 912 + i) * 10
                                angle = math.pi
                            else
                                ex = screenX + sRand(seed, 903 + i) * self.tileSize
                                ey = screenY - 2 + sRand(seed, 913 + i) * 10
                                angle = 0
                            end
                            
                            local es = 6 + sRand(seed, 940 + i) * 5
                            love.graphics.setColor(0.07 + colorVar, 0.3 + colorVar, 0.09, 1)
                            love.graphics.polygon("fill",
                                ex + math.cos(angle) * es + sway * 0.3, ey + math.sin(angle) * es,
                                ex + math.cos(angle + 2.2) * es * 0.6, ey + math.sin(angle + 2.2) * es * 0.5,
                                ex + math.cos(angle - 2.2) * es * 0.6, ey + math.sin(angle - 2.2) * es * 0.5
                            )
                            love.graphics.setColor(0.1 + colorVar, 0.38 + colorVar, 0.12, 1)
                            love.graphics.polygon("fill",
                                ex + math.cos(angle) * es * 0.7 + sway * 0.4, ey + math.sin(angle) * es * 0.6,
                                ex + math.cos(angle + 1.8) * es * 0.4, ey + math.sin(angle + 1.8) * es * 0.3,
                                ex + math.cos(angle - 1.8) * es * 0.4, ey + math.sin(angle - 1.8) * es * 0.3
                            )
                        end
                    end
                end
            end
        end
    end
    
    --===========================================
    -- PASS 3: Draw fog of war overlay
    --===========================================
    if self.fogEnabled then
        for y = startY, endY do
            for x = startX, endX do
                local fogState = self.fog[y] and self.fog[y][x] or Map.FOG_UNEXPLORED
                local worldX, worldY = self:gridToWorld(x, y)
                local screenX, screenY = self:worldToScreen(worldX, worldY)
                
                if fogState == Map.FOG_UNEXPLORED then
                    -- Completely black
                    love.graphics.setColor(0, 0, 0, 1)
                    love.graphics.rectangle("fill", screenX, screenY, self.tileSize, self.tileSize)
                elseif fogState == Map.FOG_EXPLORED then
                    -- Dimmed overlay (semi-transparent dark)
                    love.graphics.setColor(0, 0, 0, 0.6)
                    love.graphics.rectangle("fill", screenX, screenY, self.tileSize, self.tileSize)
                end
                -- FOG_VISIBLE = no overlay, full visibility
            end
        end
    end
    
    love.graphics.setScissor()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw houndstooth pattern tile with very low contrast
function Map:drawHoundstoothTile(screenX, screenY, gridX, gridY)
    local size = self.tileSize
    local half = size / 2
    
    -- Base grass color
    local baseR, baseG, baseB = 0.22, 0.45, 0.22
    -- Very subtle variation for houndstooth
    local altR, altG, altB = 0.24, 0.47, 0.24
    
    -- Determine which pattern cell (2x2 repeat)
    local px = (gridX - 1) % 2
    local py = (gridY - 1) % 2
    
    -- Fill base
    love.graphics.setColor(baseR, baseG, baseB, 1)
    love.graphics.rectangle("fill", screenX, screenY, size, size)
    
    -- Houndstooth pattern: alternating notched squares
    love.graphics.setColor(altR, altG, altB, 1)
    
    if (px + py) % 2 == 0 then
        -- Top-left quadrant with notch
        love.graphics.rectangle("fill", screenX, screenY, half, half)
        -- Bottom-right notch extension
        love.graphics.rectangle("fill", screenX + half, screenY + half, half / 2, half / 2)
        love.graphics.rectangle("fill", screenX + half / 2, screenY + half, half / 2, half / 2)
        love.graphics.rectangle("fill", screenX + half, screenY + half / 2, half / 2, half / 2)
    else
        -- Bottom-right quadrant with notch
        love.graphics.rectangle("fill", screenX + half, screenY + half, half, half)
        -- Top-left notch extension  
        love.graphics.rectangle("fill", screenX, screenY, half / 2, half / 2)
        love.graphics.rectangle("fill", screenX + half / 2, screenY, half / 2, half / 2)
        love.graphics.rectangle("fill", screenX, screenY + half / 2, half / 2, half / 2)
    end
end

function Map:drawMinimap(x, y, size)
    -- Store minimap bounds for click detection
    self.minimapX = x
    self.minimapY = y
    self.minimapSize = size
    
    local scale = size / self.width
    
    -- Background (unexplored - black)
    love.graphics.setColor(0.02, 0.02, 0.02, 1)
    love.graphics.rectangle("fill", x, y, size, size, 4)
    
    -- Draw terrain based on fog state
    for ty = 1, self.height do
        for tx = 1, self.width do
            local fogState = self.fog[ty] and self.fog[ty][tx] or Map.FOG_UNEXPLORED
            
            if fogState ~= Map.FOG_UNEXPLORED then
                local px = x + (tx-1) * scale
                local py = y + (ty-1) * scale
                
                -- Dim explored tiles, full brightness for visible
                local brightness = fogState == Map.FOG_VISIBLE and 1 or 0.5
                
                if self.tiles[ty][tx] == Map.TILE_TREE then
                    love.graphics.setColor(0.1 * brightness, 0.3 * brightness, 0.1 * brightness, 1)
                else
                    love.graphics.setColor(0.1 * brightness, 0.2 * brightness, 0.1 * brightness, 1)
                end
                love.graphics.rectangle("fill", px, py, scale + 0.5, scale + 0.5)
            end
        end
    end
    
    -- Camera view rectangle
    local camX = x + (self.cameraX / self.tileSize) * scale
    local camY = y + (self.cameraY / self.tileSize) * scale
    local camW = (self.viewportW / self.tileSize) * scale
    local camH = (self.viewportH / self.tileSize) * scale
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", camX, camY, camW, camH)
    
    love.graphics.setColor(0.3, 0.4, 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, size, size, 4)
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Check if a point is within minimap bounds
function Map:isInMinimap(screenX, screenY)
    if not self.minimapX then return false end
    return screenX >= self.minimapX and screenX <= self.minimapX + self.minimapSize and
           screenY >= self.minimapY and screenY <= self.minimapY + self.minimapSize
end

-- Navigate camera based on minimap position
function Map:minimapNavigate(screenX, screenY)
    if not self.minimapX then return end
    
    -- Clamp to minimap bounds
    local clampedX = math.max(self.minimapX, math.min(screenX, self.minimapX + self.minimapSize))
    local clampedY = math.max(self.minimapY, math.min(screenY, self.minimapY + self.minimapSize))
    
    -- Convert minimap position to grid position
    local relX = clampedX - self.minimapX
    local relY = clampedY - self.minimapY
    
    local gridX = (relX / self.minimapSize) * self.width
    local gridY = (relY / self.minimapSize) * self.height
    
    -- Center camera on position
    self:centerOnTile(gridX, gridY)
end

function Map:minimapClick(screenX, screenY)
    -- Check if click is within minimap bounds
    if self:isInMinimap(screenX, screenY) then
        -- Start dragging and navigate immediately
        self.minimapDragging = true
        self:minimapNavigate(screenX, screenY)
        return true
    end
    
    return false
end

-- Call this on mouse release to stop dragging
function Map:minimapRelease()
    self.minimapDragging = false
end

-- Check if currently dragging on minimap
function Map:isMinimapDragging()
    return self.minimapDragging
end

return Map
