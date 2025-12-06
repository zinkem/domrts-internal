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

-- Draw a dense canopy blob (multiple overlapping circles)
local function drawCanopyBlob(cx, cy, size, colorVar, sway, seed, blobIndex)
    -- Multiple overlapping circles for organic shape
    local numCircles = 4 + math.floor(seededRandom(seed, blobIndex * 100) * 3)
    
    -- Back layer (darker)
    love.graphics.setColor(0.05 + colorVar, 0.24 + colorVar, 0.07, 1)
    for i = 1, numCircles do
        local ox = (seededRandom(seed, blobIndex * 100 + i * 10) - 0.5) * size * 0.8
        local oy = (seededRandom(seed, blobIndex * 100 + i * 10 + 1) - 0.5) * size * 0.6
        local r = size * (0.5 + seededRandom(seed, blobIndex * 100 + i * 10 + 2) * 0.5)
        love.graphics.circle("fill", cx + ox + sway * 0.4, cy + oy + 3, r)
    end
    
    -- Mid layer
    love.graphics.setColor(0.07 + colorVar, 0.32 + colorVar, 0.09, 1)
    for i = 1, numCircles do
        local ox = (seededRandom(seed, blobIndex * 200 + i * 10) - 0.5) * size * 0.7
        local oy = (seededRandom(seed, blobIndex * 200 + i * 10 + 1) - 0.5) * size * 0.5
        local r = size * (0.4 + seededRandom(seed, blobIndex * 200 + i * 10 + 2) * 0.5)
        love.graphics.circle("fill", cx + ox + sway * 0.6, cy + oy, r)
    end
    
    -- Front layer (lighter)
    love.graphics.setColor(0.1 + colorVar, 0.4 + colorVar, 0.12, 1)
    for i = 1, numCircles - 1 do
        local ox = (seededRandom(seed, blobIndex * 300 + i * 10) - 0.5) * size * 0.6
        local oy = (seededRandom(seed, blobIndex * 300 + i * 10 + 1) - 0.5) * size * 0.4 - 2
        local r = size * (0.3 + seededRandom(seed, blobIndex * 300 + i * 10 + 2) * 0.4)
        love.graphics.circle("fill", cx + ox + sway * 0.8, cy + oy, r)
    end
    
    -- Highlight spots
    love.graphics.setColor(0.15 + colorVar, 0.5 + colorVar, 0.18, 0.8)
    for i = 1, 2 do
        local ox = (seededRandom(seed, blobIndex * 400 + i * 10) - 0.5) * size * 0.5
        local oy = (seededRandom(seed, blobIndex * 400 + i * 10 + 1) - 0.5) * size * 0.3 - 4
        local r = size * (0.15 + seededRandom(seed, blobIndex * 400 + i * 10 + 2) * 0.2)
        love.graphics.circle("fill", cx + ox + sway, cy + oy, r)
    end
end

-- Draw edge vegetation (bushes, undergrowth visible at forest edge)
local function drawEdgeVegetation(screenX, screenY, tileSize, edgeSides, seed, sway)
    local bushCount = 1 + math.floor(seededRandom(seed, 700) * 2)
    
    for i = 1, bushCount do
        local bx, by
        local bscale = 0.7 + seededRandom(seed, 710 + i) * 0.5
        local bColorVar = (seededRandom(seed, 720 + i) - 0.5) * 0.05
        
        -- Position toward edge
        if edgeSides.left and seededRandom(seed, 730 + i) < 0.6 then
            bx = screenX - 2 + seededRandom(seed, 740 + i) * 8
            by = screenY + tileSize * (0.4 + seededRandom(seed, 750 + i) * 0.5)
        elseif edgeSides.right and seededRandom(seed, 731 + i) < 0.6 then
            bx = screenX + tileSize - 6 + seededRandom(seed, 741 + i) * 8
            by = screenY + tileSize * (0.4 + seededRandom(seed, 751 + i) * 0.5)
        elseif edgeSides.bottom and seededRandom(seed, 732 + i) < 0.6 then
            bx = screenX + tileSize * (0.2 + seededRandom(seed, 742 + i) * 0.6)
            by = screenY + tileSize - 2 + seededRandom(seed, 752 + i) * 6
        elseif edgeSides.top and seededRandom(seed, 733 + i) < 0.6 then
            bx = screenX + tileSize * (0.2 + seededRandom(seed, 743 + i) * 0.6)
            by = screenY + 2 + seededRandom(seed, 753 + i) * 8
        else
            bx = screenX + seededRandom(seed, 740 + i) * tileSize
            by = screenY + tileSize * (0.6 + seededRandom(seed, 750 + i) * 0.35)
        end
        
        local bSway = sway * 0.3
        
        -- Bush shadow
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.ellipse("fill", bx + 1, by + 2, 5 * bscale, 2 * bscale)
        
        -- Bush layers
        love.graphics.setColor(0.06 + bColorVar, 0.28 + bColorVar, 0.08, 1)
        love.graphics.ellipse("fill", bx + bSway * 0.3 - 3 * bscale, by, 6 * bscale, 4 * bscale)
        love.graphics.ellipse("fill", bx + bSway * 0.3 + 3 * bscale, by + 1, 5 * bscale, 3.5 * bscale)
        
        love.graphics.setColor(0.09 + bColorVar, 0.36 + bColorVar, 0.11, 1)
        love.graphics.ellipse("fill", bx + bSway * 0.5, by - 2 * bscale, 7 * bscale, 5 * bscale)
        
        love.graphics.setColor(0.13 + bColorVar, 0.44 + bColorVar, 0.15, 1)
        love.graphics.ellipse("fill", bx + bSway * 0.6 - 1, by - 4 * bscale, 5 * bscale, 3.5 * bscale)
        
        -- Highlight
        love.graphics.setColor(0.18 + bColorVar, 0.52 + bColorVar, 0.2, 0.7)
        love.graphics.circle("fill", bx + bSway - 2, by - 5 * bscale, 2 * bscale)
    end
end

-- Enhanced tree drawing - dense overlapping canopy
function DrawUtils.drawTree(screenX, screenY, gridX, gridY, tileSize, isEdge, edgeSides)
    local seed = gridX * 7919 + gridY * 4637
    isEdge = isEdge or false
    edgeSides = edgeSides or {}
    
    -- Base color variation
    local tileColorVar = (seededRandom(seed, 1) - 0.5) * 0.06
    
    -- Wind sway
    local baseSway = DrawUtils.getTreeSway(screenX, screenY, 1)
    
    -- Number of canopy blobs (more = denser)
    local blobCount = 3 + math.floor(seededRandom(seed, 2) * 2)
    
    -- Draw edge bushes first (behind canopy) if on edge
    if isEdge then
        drawEdgeVegetation(screenX, screenY, tileSize, edgeSides, seed, baseSway)
    end
    
    -- Draw canopy blobs - overlapping for density
    for i = 1, blobCount do
        -- Position blobs to cover tile and overlap into neighbors
        local blobX = screenX + tileSize * (0.1 + seededRandom(seed, 50 + i) * 0.8)
        local blobY = screenY + tileSize * (0.2 + seededRandom(seed, 60 + i) * 0.6)
        
        -- Vary size - larger blobs overlap more
        local blobSize = 12 + seededRandom(seed, 70 + i) * 10
        
        -- Vary sway per blob
        local blobSway = baseSway * (0.7 + seededRandom(seed, 80 + i) * 0.6)
        
        -- Color variation per blob
        local blobColorVar = tileColorVar + (seededRandom(seed, 90 + i) - 0.5) * 0.03
        
        drawCanopyBlob(blobX, blobY, blobSize, blobColorVar, blobSway, seed, i)
    end
    
    -- Add extra coverage circles to fill gaps
    love.graphics.setColor(0.07 + tileColorVar, 0.3 + tileColorVar, 0.09, 1)
    for i = 1, 5 do
        local fx = screenX + seededRandom(seed, 500 + i) * tileSize
        local fy = screenY + seededRandom(seed, 510 + i) * tileSize * 0.8
        local fr = 6 + seededRandom(seed, 520 + i) * 8
        love.graphics.circle("fill", fx + baseSway * 0.5, fy, fr)
    end
    
    -- Top highlight layer for depth
    love.graphics.setColor(0.12 + tileColorVar, 0.42 + tileColorVar, 0.14, 0.7)
    for i = 1, 3 do
        local hx = screenX + tileSize * (0.2 + seededRandom(seed, 550 + i) * 0.6)
        local hy = screenY + tileSize * (0.1 + seededRandom(seed, 560 + i) * 0.4)
        local hr = 5 + seededRandom(seed, 570 + i) * 6
        love.graphics.circle("fill", hx + baseSway, hy, hr)
    end
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
