--[[
    Map
    64x64 tile grid with scrolling, terrain generation
    Tile size: 32x32 pixels
]]

local Map = {}
Map.__index = Map

-- Tile types
Map.TILE_GRASS = 1
Map.TILE_TREE = 2

-- Constants
Map.TILE_SIZE = 32
Map.WIDTH = 64
Map.HEIGHT = 64

function Map.new()
    local self = setmetatable({}, Map)
    
    self.tileSize = Map.TILE_SIZE
    self.width = Map.WIDTH
    self.height = Map.HEIGHT
    
    -- Camera position (top-left in world pixels)
    self.cameraX = 0
    self.cameraY = 0
    self.scrollSpeed = 400
    
    -- Viewport (set by gameplay)
    self.viewportX = 0
    self.viewportY = 0
    self.viewportW = 800
    self.viewportH = 600
    
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
        for x = 1, self.width do
            local n = self:noise2D(x, y)
            if n > treeThreshold then
                self.tiles[y][x] = Map.TILE_TREE
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

function Map:getTileWorldCenter(gridX, gridY)
    local wx, wy = self:gridToWorld(gridX, gridY)
    return wx + self.tileSize / 2, wy + self.tileSize / 2
end

function Map:isWorldPosPassable(worldX, worldY)
    local gridX, gridY = self:worldToGrid(worldX, worldY)
    return self:isTilePassable(gridX, gridY)
end

function Map:update(dt)
    -- Keyboard scrolling
    local dx, dy = 0, 0
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        dx = -self.scrollSpeed * dt
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        dx = self.scrollSpeed * dt
    end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        dy = -self.scrollSpeed * dt
    end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        dy = self.scrollSpeed * dt
    end
    
    if dx ~= 0 or dy ~= 0 then
        self:scroll(dx, dy)
    end
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
    
    for y = startY, endY do
        for x = startX, endX do
            local worldX, worldY = self:gridToWorld(x, y)
            local screenX, screenY = self:worldToScreen(worldX, worldY)
            local tile = self.tiles[y][x]
            
            if tile == Map.TILE_GRASS then
                self:drawHoundstoothTile(screenX, screenY, x, y)
            elseif tile == Map.TILE_TREE then
                -- Grass under tree (use houndstooth too)
                self:drawHoundstoothTile(screenX, screenY, x, y)
                -- Trunk
                love.graphics.setColor(0.4, 0.25, 0.1, 1)
                love.graphics.rectangle("fill", screenX + 12, screenY + 18, 8, 14)
                -- Foliage
                love.graphics.setColor(0.1, 0.35, 0.12, 1)
                love.graphics.circle("fill", screenX + 16, screenY + 12, 11)
                love.graphics.setColor(0.15, 0.45, 0.18, 1)
                love.graphics.circle("fill", screenX + 14, screenY + 10, 7)
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
    
    love.graphics.setColor(0.1, 0.2, 0.1, 1)
    love.graphics.rectangle("fill", x, y, size, size, 4)
    
    -- Draw trees only (grass is background)
    for ty = 1, self.height do
        for tx = 1, self.width do
            if self.tiles[ty][tx] == Map.TILE_TREE then
                love.graphics.setColor(0.1, 0.3, 0.1, 1)
                love.graphics.rectangle("fill", x + (tx-1) * scale, y + (ty-1) * scale, scale, scale)
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

function Map:minimapClick(screenX, screenY)
    -- Check if click is within minimap bounds
    if not self.minimapX then return false end
    
    if screenX >= self.minimapX and screenX <= self.minimapX + self.minimapSize and
       screenY >= self.minimapY and screenY <= self.minimapY + self.minimapSize then
        
        -- Convert minimap click to grid position
        local relX = screenX - self.minimapX
        local relY = screenY - self.minimapY
        
        local gridX = (relX / self.minimapSize) * self.width
        local gridY = (relY / self.minimapSize) * self.height
        
        -- Center camera on clicked position
        self:centerOnTile(gridX, gridY)
        return true
    end
    
    return false
end

return Map
