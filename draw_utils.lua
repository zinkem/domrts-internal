--[[
    Draw Utilities
    Enhanced drawing helpers for units and buildings
    Provides: outlines, shadows, animation helpers, flash effects
]]

local Effects = require("effects")

local DrawUtils = {}

-- Animation timers (global, shared across all entities)
DrawUtils.globalTime = 0
DrawUtils.windOffset = 0  -- For tree sway

function DrawUtils.update(dt)
    DrawUtils.globalTime = DrawUtils.globalTime + dt
    -- Gentle wind oscillation
    DrawUtils.windOffset = math.sin(DrawUtils.globalTime * 0.8) * 0.03 + 
                           math.sin(DrawUtils.globalTime * 1.3) * 0.02
end

-- Get idle bob offset (breathing/shifting)
function DrawUtils.getIdleBob(seed, intensity)
    seed = seed or 0
    intensity = intensity or 1
    local t = DrawUtils.globalTime + seed * 0.7
    return math.sin(t * 1.5) * 1.5 * intensity
end

-- Get walk bob offset (bouncy movement)
function DrawUtils.getWalkBob(seed, speed)
    seed = seed or 0
    speed = speed or 8
    local t = DrawUtils.globalTime + seed * 0.5
    return math.abs(math.sin(t * speed)) * 2
end

-- Draw dark outline around a shape by drawing it offset in multiple directions
-- Call this BEFORE drawing the main shape
function DrawUtils.drawOutline(drawFunc, thickness, color)
    thickness = thickness or 1.5
    color = color or {0, 0, 0, 0.7}
    
    love.graphics.setColor(color)
    
    -- Draw in 8 directions
    local offsets = {
        {-thickness, 0}, {thickness, 0}, {0, -thickness}, {0, thickness},
        {-thickness, -thickness}, {thickness, -thickness}, 
        {-thickness, thickness}, {thickness, thickness}
    }
    
    for _, off in ipairs(offsets) do
        love.graphics.push()
        love.graphics.translate(off[1], off[2])
        drawFunc()
        love.graphics.pop()
    end
end

-- Draw entity with flash effect if active
function DrawUtils.applyFlash(entity, drawFunc)
    local flash = Effects.getFlash(entity)
    
    if flash then
        -- Draw normal first
        drawFunc()
        
        -- Draw flash overlay (additive-ish)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(flash)
        drawFunc()
        love.graphics.setBlendMode("alpha")
    else
        drawFunc()
    end
end

-- Enhanced shadow drawing
function DrawUtils.drawShadow(x, y, radiusX, radiusY, alpha)
    alpha = alpha or 0.35
    radiusY = radiusY or radiusX * 0.4
    
    -- Outer soft shadow
    love.graphics.setColor(0, 0, 0, alpha * 0.3)
    love.graphics.ellipse("fill", x, y, radiusX * 1.3, radiusY * 1.3)
    
    -- Inner darker shadow
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.ellipse("fill", x, y, radiusX, radiusY)
end

-- Selection circle with pulse effect
function DrawUtils.drawSelection(x, y, radius, color)
    color = color or {0, 1, 0}
    local pulse = 1 + math.sin(DrawUtils.globalTime * 4) * 0.1
    local pulseRadius = radius * pulse
    
    -- Outer glow
    love.graphics.setColor(color[1], color[2], color[3], 0.2)
    love.graphics.circle("fill", x, y, pulseRadius + 4)
    
    -- Main selection ring
    love.graphics.setColor(color[1], color[2], color[3], 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, pulseRadius + 2)
    
    -- Inner bright ring
    love.graphics.setColor(color[1], color[2], color[3], 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", x, y, pulseRadius)
end

-- Health bar with smooth gradient
function DrawUtils.drawHealthBar(x, y, width, height, percent, showAlways)
    if not showAlways and percent >= 1 then return end
    
    percent = math.max(0, math.min(1, percent))
    
    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - 1, y - 1, width + 2, height + 2, 2)
    
    -- Health gradient (green -> yellow -> red)
    local r, g, b
    if percent > 0.5 then
        -- Green to yellow
        local t = (percent - 0.5) * 2
        r = 1 - t * 0.5
        g = 0.8
        b = 0.2
    else
        -- Yellow to red
        local t = percent * 2
        r = 1
        g = t * 0.8
        b = 0.2
    end
    
    love.graphics.setColor(r, g, b, 0.9)
    love.graphics.rectangle("fill", x, y, width * percent, height, 1)
    
    -- Border
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, width, height, 1)
end

-- Torch/fire flicker effect - returns offset and scale
function DrawUtils.getTorchFlicker(seed)
    seed = seed or 0
    local t = DrawUtils.globalTime + seed * 2.3
    
    local flicker = math.sin(t * 15) * 0.15 + 
                    math.sin(t * 23) * 0.1 + 
                    math.sin(t * 7) * 0.08
    
    local scale = 1 + flicker
    local offsetX = math.sin(t * 11) * 1.5
    local offsetY = math.sin(t * 17) * 1
    
    return offsetX, offsetY, scale
end

-- Draw animated torch flame
function DrawUtils.drawTorch(x, y, size, seed)
    size = size or 5
    seed = seed or 0
    
    local offX, offY, scale = DrawUtils.getTorchFlicker(seed)
    local s = size * scale
    
    -- Outer glow
    love.graphics.setColor(1, 0.6, 0.1, 0.3)
    love.graphics.circle("fill", x + offX, y + offY, s * 2.5)
    
    -- Middle glow
    love.graphics.setColor(1, 0.7, 0.2, 0.5)
    love.graphics.circle("fill", x + offX * 0.7, y + offY * 0.7, s * 1.5)
    
    -- Core flame
    love.graphics.setColor(1, 0.9, 0.4, 0.9)
    love.graphics.circle("fill", x + offX * 0.3, y + offY * 0.3, s)
    
    -- Bright center
    love.graphics.setColor(1, 1, 0.8, 1)
    love.graphics.circle("fill", x, y, s * 0.4)
end

-- Tree sway offset based on position
function DrawUtils.getTreeSway(x, y, height)
    height = height or 1
    local posOffset = (x * 0.01 + y * 0.013) 
    local sway = math.sin(DrawUtils.globalTime * 1.2 + posOffset) * 2 +
                 math.sin(DrawUtils.globalTime * 0.7 + posOffset * 1.5) * 1.5
    return sway * height * DrawUtils.windOffset * 30
end

-- Seeded random helper (doesn't affect global state)
local function seededRandom(seed, index)
    local x = math.sin(seed * 12.9898 + index * 78.233) * 43758.5453
    return x - math.floor(x)
end

-- Draw a chunky foliage mass (larger irregular shapes, not tiny stipples)
local function drawFoliageChunk(cx, cy, size, colorVar, sway, seed, chunkIndex)
    -- Draw 3-5 overlapping irregular quads/polygons
    local numShapes = 3 + math.floor(seededRandom(seed, chunkIndex * 50) * 3)
    
    for layer = 1, 3 do
        -- Layer colors: dark -> mid -> light
        local layerBright = (layer - 1) * 0.035
        
        if layer == 1 then
            love.graphics.setColor(0.05 + colorVar, 0.25 + colorVar, 0.07, 1)
        elseif layer == 2 then
            love.graphics.setColor(0.08 + colorVar, 0.34 + colorVar, 0.1, 1)
        else
            love.graphics.setColor(0.12 + colorVar, 0.44 + colorVar, 0.14, 1)
        end
        
        for i = 1, numShapes do
            local shapeIndex = chunkIndex * 1000 + layer * 100 + i
            
            -- Position within chunk
            local ox = (seededRandom(seed, shapeIndex) - 0.5) * size * (1.2 - layer * 0.2)
            local oy = (seededRandom(seed, shapeIndex + 1) - 0.5) * size * (0.8 - layer * 0.15)
            oy = oy - layer * 2  -- Higher layers slightly higher
            
            -- Size varies
            local shapeSize = size * (0.4 + seededRandom(seed, shapeIndex + 2) * 0.4) / layer
            
            -- Sway increases with layer (top moves more)
            local shapeSway = sway * (0.3 + layer * 0.25)
            
            -- Draw irregular quad (4-point polygon with randomized corners)
            local corners = {}
            for c = 1, 4 do
                local angle = (c - 1) * math.pi * 0.5 + seededRandom(seed, shapeIndex + c * 10) * 0.5
                local dist = shapeSize * (0.7 + seededRandom(seed, shapeIndex + c * 10 + 5) * 0.5)
                table.insert(corners, cx + ox + shapeSway + math.cos(angle) * dist)
                table.insert(corners, cy + oy + math.sin(angle) * dist)
            end
            
            love.graphics.polygon("fill", corners)
        end
    end
end

-- Draw edge foliage (distinct leaf/bush shapes pointing outward)
local function drawEdgeFoliage(screenX, screenY, tileSize, edgeSides, seed, sway, colorVar)
    -- For each edge side, draw outward-pointing foliage
    local edges = {}
    if edgeSides.left then table.insert(edges, "left") end
    if edgeSides.right then table.insert(edges, "right") end
    if edgeSides.top then table.insert(edges, "top") end
    if edgeSides.bottom then table.insert(edges, "bottom") end
    
    for _, side in ipairs(edges) do
        local clusterCount = 3 + math.floor(seededRandom(seed, 900) * 3)
        
        for i = 1, clusterCount do
            local cx, cy
            local pointAngle  -- Direction foliage points
            
            if side == "left" then
                cx = screenX - 4 + seededRandom(seed, 910 + i) * 12
                cy = screenY + seededRandom(seed, 920 + i) * tileSize
                pointAngle = -math.pi * 0.5
            elseif side == "right" then
                cx = screenX + tileSize - 8 + seededRandom(seed, 911 + i) * 12
                cy = screenY + seededRandom(seed, 921 + i) * tileSize
                pointAngle = math.pi * 0.5
            elseif side == "top" then
                cx = screenX + seededRandom(seed, 912 + i) * tileSize
                cy = screenY - 4 + seededRandom(seed, 922 + i) * 12
                pointAngle = 0
            else -- bottom
                cx = screenX + seededRandom(seed, 913 + i) * tileSize
                cy = screenY + tileSize - 8 + seededRandom(seed, 923 + i) * 12
                pointAngle = math.pi
            end
            
            local clusterSize = 6 + seededRandom(seed, 940 + i) * 6
            local clusterColorVar = colorVar + (seededRandom(seed, 950 + i) - 0.5) * 0.03
            local clusterSway = sway * 0.4
            
            -- Draw chunky bush shape (multiple overlapping polygons)
            -- Back layer
            love.graphics.setColor(0.06 + clusterColorVar, 0.28 + clusterColorVar, 0.08, 1)
            local bx, by = cx + clusterSway * 0.3, cy
            love.graphics.polygon("fill",
                bx + math.cos(pointAngle) * clusterSize * 0.8, by + math.sin(pointAngle) * clusterSize * 0.8,
                bx + math.cos(pointAngle + 2.2) * clusterSize * 0.7, by + math.sin(pointAngle + 2.2) * clusterSize * 0.6,
                bx + math.cos(pointAngle - 2.2) * clusterSize * 0.7, by + math.sin(pointAngle - 2.2) * clusterSize * 0.6
            )
            
            -- Mid layer
            love.graphics.setColor(0.09 + clusterColorVar, 0.36 + clusterColorVar, 0.11, 1)
            bx, by = cx + clusterSway * 0.5, cy
            love.graphics.polygon("fill",
                bx + math.cos(pointAngle) * clusterSize * 0.9, by + math.sin(pointAngle) * clusterSize * 0.7,
                bx + math.cos(pointAngle + 1.8) * clusterSize * 0.5, by + math.sin(pointAngle + 1.8) * clusterSize * 0.5,
                bx + math.cos(pointAngle - 1.8) * clusterSize * 0.5, by + math.sin(pointAngle - 1.8) * clusterSize * 0.5
            )
            
            -- Highlight
            love.graphics.setColor(0.14 + clusterColorVar, 0.46 + clusterColorVar, 0.16, 1)
            bx, by = cx + clusterSway * 0.6, cy - 1
            love.graphics.polygon("fill",
                bx + math.cos(pointAngle) * clusterSize * 0.5, by + math.sin(pointAngle) * clusterSize * 0.4,
                bx + math.cos(pointAngle + 1.5) * clusterSize * 0.3, by + math.sin(pointAngle + 1.5) * clusterSize * 0.3,
                bx + math.cos(pointAngle - 1.5) * clusterSize * 0.3, by + math.sin(pointAngle - 1.5) * clusterSize * 0.3
            )
        end
    end
end

-- Draw just the forest floor (called in terrain pass)
function DrawUtils.drawForestFloor(screenX, screenY, tileSize, gridX, gridY)
    local seed = gridX * 7919 + gridY * 4637
    
    -- Dark forest floor
    love.graphics.setColor(0.08, 0.15, 0.06, 1)
    love.graphics.rectangle("fill", screenX, screenY, tileSize, tileSize)
    
    -- Dark undergrowth spots
    love.graphics.setColor(0.05, 0.11, 0.04, 1)
    for i = 1, 3 do
        local lx = screenX + seededRandom(seed, 600 + i) * tileSize
        local ly = screenY + seededRandom(seed, 610 + i) * tileSize
        local lw = 4 + seededRandom(seed, 620 + i) * 8
        local lh = 3 + seededRandom(seed, 630 + i) * 5
        love.graphics.ellipse("fill", lx, ly, lw, lh)
    end
end

-- Draw tree canopy only (called in foliage pass, after all terrain)
function DrawUtils.drawTreeCanopy(screenX, screenY, gridX, gridY, tileSize, isEdge, edgeSides)
    local seed = gridX * 7919 + gridY * 4637
    isEdge = isEdge or false
    edgeSides = edgeSides or {}
    
    -- Base color variation
    local tileColorVar = (seededRandom(seed, 1) - 0.5) * 0.05
    
    -- Wind sway
    local baseSway = DrawUtils.getTreeSway(screenX, screenY, 1)
    
    -- Draw 2-4 chunky foliage masses
    local chunkCount = 2 + math.floor(seededRandom(seed, 2) * 2)
    
    for i = 1, chunkCount do
        local chunkX = screenX + tileSize * (0.2 + seededRandom(seed, 50 + i) * 0.6)
        local chunkY = screenY + tileSize * (0.2 + seededRandom(seed, 60 + i) * 0.5)
        local chunkSize = 14 + seededRandom(seed, 70 + i) * 10
        local chunkSway = baseSway * (0.6 + seededRandom(seed, 80 + i) * 0.5)
        local chunkColorVar = tileColorVar + (seededRandom(seed, 90 + i) - 0.5) * 0.02
        
        drawFoliageChunk(chunkX, chunkY, chunkSize, chunkColorVar, chunkSway, seed, i)
    end
    
    -- Fill any remaining gaps with medium blobs
    love.graphics.setColor(0.07 + tileColorVar, 0.32 + tileColorVar, 0.09, 1)
    for i = 1, 4 do
        local fx = screenX + seededRandom(seed, 500 + i) * tileSize
        local fy = screenY + seededRandom(seed, 510 + i) * tileSize * 0.85
        local fr = 5 + seededRandom(seed, 520 + i) * 7
        love.graphics.circle("fill", fx + baseSway * 0.4, fy, fr)
    end
    
    -- Highlight spots
    love.graphics.setColor(0.13 + tileColorVar, 0.46 + tileColorVar, 0.15, 0.85)
    for i = 1, 3 do
        local hx = screenX + tileSize * (0.15 + seededRandom(seed, 550 + i) * 0.7)
        local hy = screenY + tileSize * (0.1 + seededRandom(seed, 560 + i) * 0.5)
        local hr = 4 + seededRandom(seed, 570 + i) * 5
        love.graphics.circle("fill", hx + baseSway * 0.7, hy, hr)
    end
    
    -- Draw edge foliage if on edge
    if isEdge then
        drawEdgeFoliage(screenX, screenY, tileSize, edgeSides, seed, baseSway, tileColorVar)
    end
end

-- Legacy single-call function (for compatibility)
function DrawUtils.drawTree(screenX, screenY, gridX, gridY, tileSize, isEdge, edgeSides)
    DrawUtils.drawForestFloor(screenX, screenY, tileSize, gridX, gridY)
    DrawUtils.drawTreeCanopy(screenX, screenY, gridX, gridY, tileSize, isEdge, edgeSides)
end

-- Draw outline for any unit (call the unit's internal draw as drawFunc)
function DrawUtils.drawUnitWithOutline(x, y, drawFunc, outlineColor)
    outlineColor = outlineColor or {0, 0, 0, 0.6}
    local thickness = 1.5
    
    -- Draw outline
    love.graphics.setColor(outlineColor)
    local offsets = {
        {-thickness, 0}, {thickness, 0}, {0, -thickness}, {0, thickness},
    }
    
    for _, off in ipairs(offsets) do
        love.graphics.push()
        love.graphics.translate(off[1], off[2])
        drawFunc()
        love.graphics.pop()
    end
    
    -- Draw main unit
    drawFunc()
end

return DrawUtils
