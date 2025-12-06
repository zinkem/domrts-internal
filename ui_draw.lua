--[[
    UI Drawing Module - Professional Medieval Theme
    Drop-in replacement for gameplay.lua UI functions
    Features: Beveled borders, gradients, drop shadows, 3D rivets, ornamental details
]]

local UIDraw = {}

-- Enhanced color palette - DARKER/AGED for worn medieval look
local UI = {
    -- Stone colors (very dark, high contrast)
    stoneLight = {0.32, 0.30, 0.26, 1},
    stoneMid = {0.20, 0.18, 0.16, 1},
    stoneDark = {0.10, 0.09, 0.08, 1},
    stoneAccent = {0.38, 0.35, 0.30, 1},
    stoneHighlight = {0.48, 0.44, 0.38, 1},  -- For lit edges (good contrast)
    stoneShadow = {0.05, 0.04, 0.03, 1},     -- For shadowed edges (very dark)
    
    -- Metal colors (aged bronze/gold)
    metalGold = {0.72, 0.58, 0.26, 1},
    metalGoldLight = {0.88, 0.72, 0.42, 1},
    metalGoldDark = {0.45, 0.35, 0.14, 1},
    metalBronze = {0.50, 0.38, 0.20, 1},
    metalBronzeLight = {0.65, 0.50, 0.30, 1},
    metalBronzeDark = {0.30, 0.22, 0.10, 1},
    metalShine = {1.0, 0.90, 0.65, 1},
    
    -- Shadow colors (deeper)
    dropShadow = {0, 0, 0, 0.5},
    innerShadow = {0, 0, 0, 0.35},
    
    -- Text colors
    textLight = {0.92, 0.88, 0.80, 1},
    textDark = {0.15, 0.12, 0.10, 1},
    textGold = {1, 0.82, 0.25, 1},
    
    -- Dimensions
    topBarHeight = 42,
    minimapSize = 160,
    bottomPanelHeight = 180,
    bottomPanelWidth = 280,
}

UIDraw.UI = UI  -- Export for access

-- Shared hash function for consistent randomness (Lua 5.1 compatible)
local function hash(a, b)
    local h = (a * 374761393 + b * 668265263) % 2147483647
    h = ((h * 1274126177) % 2147483647)
    return (h % 1000) / 1000
end

-- Spray noise texture - like Asperite spray tool
local function drawSprayNoise(x, y, w, h, density, lightColor, darkColor, seed)
    seed = seed or 0
    local numDots = math.floor(w * h * density / 100)
    
    for i = 1, numDots do
        local px = x + hash(i + seed, seed) * w
        local py = y + hash(seed, i + seed) * h
        local isLight = hash(i * 3 + seed, i * 7) > 0.5
        local alpha = 0.08 + hash(i * 11, seed) * 0.12
        
        if isLight then
            love.graphics.setColor(lightColor[1], lightColor[2], lightColor[3], alpha)
        else
            love.graphics.setColor(darkColor[1], darkColor[2], darkColor[3], alpha + 0.05)
        end
        
        -- Vary dot size slightly
        local size = 0.5 + hash(i, i + seed) * 1.0
        love.graphics.rectangle("fill", px, py, size, size)
    end
end

-- Worn edge highlight - lighter pixels along edges
local function drawWornEdges(x, y, w, h, intensity)
    intensity = intensity or 0.15
    
    -- Top edge wear (catches light)
    for i = 0, w - 1 do
        if hash(i, 1) > 0.7 then
            local alpha = hash(i, 2) * intensity
            love.graphics.setColor(1, 0.95, 0.85, alpha)
            local py = y + hash(i, 3) * 3
            love.graphics.rectangle("fill", x + i, py, 1, 1)
        end
    end
    
    -- Left edge wear
    for i = 0, h - 1 do
        if hash(1, i) > 0.75 then
            local alpha = hash(2, i) * intensity * 0.8
            love.graphics.setColor(1, 0.95, 0.85, alpha)
            local px = x + hash(3, i) * 2
            love.graphics.rectangle("fill", px, y + i, 1, 1)
        end
    end
    
    -- Bottom edge darkening (shadow/grime)
    for i = 0, w - 1 do
        if hash(i, 100) > 0.6 then
            local alpha = hash(i, 101) * intensity * 1.2
            love.graphics.setColor(0, 0, 0, alpha)
            local py = y + h - 1 - hash(i, 102) * 2
            love.graphics.rectangle("fill", x + i, py, 1, 1)
        end
    end
end

-- Helper: Draw a vertical gradient rectangle using stacked lines
local function drawGradientV(x, y, w, h, colorTop, colorBottom)
    for i = 0, h - 1 do
        local t = i / h
        love.graphics.setColor(
            colorTop[1] + (colorBottom[1] - colorTop[1]) * t,
            colorTop[2] + (colorBottom[2] - colorTop[2]) * t,
            colorTop[3] + (colorBottom[3] - colorTop[3]) * t,
            colorTop[4] + (colorBottom[4] - colorTop[4]) * t
        )
        love.graphics.rectangle("fill", x, y + i, w, 1)
    end
end

-- Helper: Draw a horizontal gradient rectangle
local function drawGradientH(x, y, w, h, colorLeft, colorRight)
    for i = 0, w - 1 do
        local t = i / w
        love.graphics.setColor(
            colorLeft[1] + (colorRight[1] - colorLeft[1]) * t,
            colorLeft[2] + (colorRight[2] - colorLeft[2]) * t,
            colorLeft[3] + (colorRight[3] - colorLeft[3]) * t,
            colorLeft[4] + (colorRight[4] - colorLeft[4]) * t
        )
        love.graphics.rectangle("fill", x + i, y, 1, h)
    end
end

-- Helper: Draw a 3D rivet with highlight and shadow
local function drawRivet3D(cx, cy, radius)
    -- Main rivet body
    love.graphics.setColor(UI.metalGold)
    love.graphics.circle("fill", cx, cy, radius, 16)
    
    -- Inner darker ring (gives depth)
    love.graphics.setColor(UI.metalGoldDark[1], UI.metalGoldDark[2], UI.metalGoldDark[3], 0.6)
    love.graphics.circle("fill", cx + 0.5, cy + 0.5, radius * 0.75, 12)
    
    -- Bright center
    love.graphics.setColor(UI.metalGold)
    love.graphics.circle("fill", cx, cy, radius * 0.6, 12)
    
    -- Highlight (upper-left)
    love.graphics.setColor(UI.metalShine[1], UI.metalShine[2], UI.metalShine[3], 0.9)
    love.graphics.circle("fill", cx - radius * 0.3, cy - radius * 0.3, radius * 0.35, 8)
    
    -- Shadow arc (bottom-right) - draw as small dark crescent
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.arc("fill", cx, cy, radius * 0.9, math.pi * 0.25, math.pi * 0.75, 8)
end

-- Helper: Draw ornamental corner bracket
local function drawCornerOrnament(x, y, size, flipH, flipV)
    local sx = flipH and -1 or 1
    local sy = flipV and -1 or 1
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(sx, sy)
    
    -- L-shaped bracket
    love.graphics.setColor(UI.metalBronzeDark)
    love.graphics.setLineWidth(3)
    love.graphics.line(0, size * 0.7, 0, 0, size * 0.7, 0)
    
    love.graphics.setColor(UI.metalBronze)
    love.graphics.setLineWidth(2)
    love.graphics.line(1, size * 0.7 - 1, 1, 1, size * 0.7 - 1, 1)
    
    -- Highlight on top edge
    love.graphics.setColor(UI.metalBronzeLight[1], UI.metalBronzeLight[2], UI.metalBronzeLight[3], 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.line(2, 2, size * 0.65, 2)
    
    -- Small decorative diamond at corner
    love.graphics.setColor(UI.metalGold)
    local d = 4
    love.graphics.polygon("fill", 0, d, d, 0, d*2, d, d, d*2)
    love.graphics.setColor(UI.metalShine[1], UI.metalShine[2], UI.metalShine[3], 0.6)
    love.graphics.polygon("fill", d, 1, d + 2, d, d, d + 2, d - 2, d)
    
    love.graphics.pop()
end

-- Helper: Draw beveled border (light on top/left, dark on bottom/right)
local function drawBeveledBorder(x, y, w, h, thickness, cornerRadius)
    thickness = thickness or 2
    cornerRadius = cornerRadius or 4
    
    -- Outer dark edge (shadow on bottom-right)
    love.graphics.setColor(UI.stoneShadow[1], UI.stoneShadow[2], UI.stoneShadow[3], 0.8)
    love.graphics.setLineWidth(thickness + 1)
    -- Bottom edge
    love.graphics.line(x + cornerRadius, y + h, x + w - cornerRadius, y + h)
    -- Right edge  
    love.graphics.line(x + w, y + cornerRadius, x + w, y + h - cornerRadius)
    
    -- Outer light edge (highlight on top-left)
    love.graphics.setColor(UI.stoneHighlight[1], UI.stoneHighlight[2], UI.stoneHighlight[3], 0.6)
    love.graphics.setLineWidth(thickness)
    -- Top edge
    love.graphics.line(x + cornerRadius, y, x + w - cornerRadius, y)
    -- Left edge
    love.graphics.line(x, y + cornerRadius, x, y + h - cornerRadius)
end

-- Main panel drawing function with all enhancements
-- subtle: if true, use minimal texture (for info panels where text needs to be readable)
function UIDraw.drawStonePanel(x, y, w, h, cornerRadius, subtle)
    cornerRadius = cornerRadius or 6
    subtle = subtle or false
    
    -- 1. DROP SHADOW (offset behind panel)
    local shadowOffset = 4
    love.graphics.setColor(UI.dropShadow)
    love.graphics.rectangle("fill", x + shadowOffset, y + shadowOffset, w, h, cornerRadius)
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", x + shadowOffset + 2, y + shadowOffset + 2, w, h, cornerRadius + 2)
    
    -- 2. GRADIENT FILL (darker overall)
    local gradientTop = {UI.stoneMid[1] + 0.04, UI.stoneMid[2] + 0.04, UI.stoneMid[3] + 0.03, 0.98}
    local gradientBottom = {UI.stoneDark[1] - 0.02, UI.stoneDark[2] - 0.02, UI.stoneDark[3] - 0.02, 0.98}
    
    local steps = math.ceil(h / 4)
    for i = 0, steps - 1 do
        local t = i / steps
        local segY = y + i * 4
        local segH = math.min(4, h - i * 4)
        love.graphics.setColor(
            gradientTop[1] + (gradientBottom[1] - gradientTop[1]) * t,
            gradientTop[2] + (gradientBottom[2] - gradientTop[2]) * t,
            gradientTop[3] + (gradientBottom[3] - gradientTop[3]) * t,
            gradientTop[4]
        )
        love.graphics.rectangle("fill", x, segY, w, segH, i == 0 and cornerRadius or 0, i == 0 and cornerRadius or 0)
    end
    
    -- 3. STONE TEXTURE
    if subtle then
        -- SUBTLE MODE: Very minimal texture for info panels
        local numNoise = math.floor(w * h * 0.004)
        for i = 1, numNoise do
            local px = x + 4 + hash(i, y) * (w - 8)
            local py = y + 4 + hash(x, i) * (h - 8)
            local isLight = hash(i * 3, i * 7) > 0.5
            if isLight then
                love.graphics.setColor(1, 0.95, 0.85, 0.05)
            else
                love.graphics.setColor(0, 0, 0, 0.07)
            end
            love.graphics.rectangle("fill", px, py, 1, 1)
        end
    else
        -- FULL MODE: Organic weathered stone with cracks and damage
        local margin = 4
        local innerX, innerY = x + margin, y + margin
        local innerW, innerH = w - margin * 2, h - margin * 2
        
        -- A) ORGANIC COLOR BLOTCHES (natural stone variation)
        local numBlotches = math.floor((w * h) / 800)
        for i = 1, numBlotches do
            local bx = innerX + hash(i, 1) * innerW
            local by = innerY + hash(1, i) * innerH
            local bsize = 8 + hash(i, i) * 25
            local colorVar = (hash(i * 3, i * 5) - 0.5) * 0.1
            local isDark = hash(i * 7, i * 11) > 0.6
            
            local br = UI.stoneMid[1] + colorVar
            local bg = UI.stoneMid[2] + colorVar * 0.8
            local bb = UI.stoneMid[3] + colorVar * 0.5
            
            if isDark then
                br, bg, bb = br - 0.06, bg - 0.05, bb - 0.04
            end
            
            -- Draw soft blotch (multiple overlapping circles)
            for j = 1, 3 do
                local ox = (hash(i, j * 2) - 0.5) * bsize * 0.5
                local oy = (hash(j * 2, i) - 0.5) * bsize * 0.5
                local r = bsize * (0.3 + hash(i + j, j) * 0.4)
                love.graphics.setColor(br, bg, bb, 0.15)
                love.graphics.circle("fill", bx + ox, by + oy, r)
            end
        end
        
        -- B) CRACK NETWORK (branching cracks across surface)
        local numCracks = 3 + math.floor(hash(x, y) * 4)
        for c = 1, numCracks do
            -- Start point
            local cx = innerX + hash(c, 100) * innerW
            local cy = innerY + hash(100, c) * innerH
            
            -- Crack direction and length
            local angle = hash(c, 101) * math.pi * 2
            local length = 15 + hash(c, 102) * 40
            local segments = math.floor(length / 4)
            
            love.graphics.setColor(0, 0, 0, 0.35)
            love.graphics.setLineWidth(1)
            
            local prevX, prevY = cx, cy
            for s = 1, segments do
                -- Wander the crack direction
                angle = angle + (hash(c * s, s * c) - 0.5) * 0.8
                local stepLen = 3 + hash(s, c) * 3
                local nextX = prevX + math.cos(angle) * stepLen
                local nextY = prevY + math.sin(angle) * stepLen
                
                -- Keep in bounds
                if nextX > innerX + 2 and nextX < innerX + innerW - 2 and
                   nextY > innerY + 2 and nextY < innerY + innerH - 2 then
                    love.graphics.line(prevX, prevY, nextX, nextY)
                    
                    -- Crack highlight (light catching edge)
                    love.graphics.setColor(1, 0.95, 0.85, 0.15)
                    love.graphics.line(prevX + 1, prevY, nextX + 1, nextY)
                    love.graphics.setColor(0, 0, 0, 0.35)
                    
                    -- Branch chance
                    if hash(c + s, s) > 0.85 then
                        local branchAngle = angle + (hash(s, c + 50) - 0.5) * 1.5
                        local branchLen = 5 + hash(s, c + 51) * 10
                        local bx2 = nextX + math.cos(branchAngle) * branchLen
                        local by2 = nextY + math.sin(branchAngle) * branchLen
                        love.graphics.setColor(0, 0, 0, 0.25)
                        love.graphics.line(nextX, nextY, bx2, by2)
                    end
                    
                    prevX, prevY = nextX, nextY
                else
                    break
                end
            end
        end
        
        -- C) PITTING / EROSION (small dark spots)
        local numPits = math.floor((w * h) / 300)
        for i = 1, numPits do
            local px = innerX + hash(i, 200) * innerW
            local py = innerY + hash(200, i) * innerH
            local psize = 1 + hash(i, 201) * 2.5
            
            -- Dark pit
            love.graphics.setColor(0, 0, 0, 0.2 + hash(i, 202) * 0.15)
            love.graphics.circle("fill", px, py, psize)
            
            -- Light edge on top-left of pit
            if psize > 1.5 then
                love.graphics.setColor(1, 0.95, 0.85, 0.12)
                love.graphics.arc("line", "open", px, py, psize - 0.5, math.pi * 0.8, math.pi * 1.3, 4)
            end
        end
        
        -- D) CHIPS AND DAMAGE along edges
        local numChips = math.floor((w + h) / 25)
        for i = 1, numChips do
            local edge = math.floor(hash(i, 300) * 4)  -- 0=top, 1=right, 2=bottom, 3=left
            local chipX, chipY
            local chipW = 3 + hash(i, 301) * 8
            local chipH = 2 + hash(i, 302) * 5
            
            if edge == 0 then  -- Top
                chipX = innerX + hash(i, 303) * (innerW - chipW)
                chipY = innerY
            elseif edge == 1 then  -- Right
                chipX = innerX + innerW - chipH
                chipY = innerY + hash(i, 304) * (innerH - chipW)
                chipW, chipH = chipH, chipW
            elseif edge == 2 then  -- Bottom
                chipX = innerX + hash(i, 305) * (innerW - chipW)
                chipY = innerY + innerH - chipH
            else  -- Left
                chipX = innerX
                chipY = innerY + hash(i, 306) * (innerH - chipW)
                chipW, chipH = chipH, chipW
            end
            
            -- Dark chip/gouge
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", chipX, chipY, chipW, chipH)
            
            -- Highlight on inner edge
            love.graphics.setColor(1, 0.95, 0.85, 0.1)
            if edge == 0 then
                love.graphics.line(chipX, chipY + chipH, chipX + chipW, chipY + chipH)
            elseif edge == 2 then
                love.graphics.line(chipX, chipY, chipX + chipW, chipY)
            elseif edge == 3 then
                love.graphics.line(chipX + chipW, chipY, chipX + chipW, chipY + chipH)
            else
                love.graphics.line(chipX, chipY, chipX, chipY + chipH)
            end
        end
        
        -- E) SURFACE NOISE (fine grain texture)
        local numNoise = math.floor((w * h) / 80)
        for i = 1, numNoise do
            local px = innerX + hash(i, 400) * innerW
            local py = innerY + hash(400, i) * innerH
            local isLight = hash(i * 3, 401) > 0.45
            
            if isLight then
                love.graphics.setColor(1, 0.95, 0.85, 0.08 + hash(i, 402) * 0.06)
            else
                love.graphics.setColor(0, 0, 0, 0.1 + hash(i, 403) * 0.08)
            end
            love.graphics.rectangle("fill", px, py, 1, 1)
        end
        
        -- F) STAINS / WATER DAMAGE (subtle darker areas)
        local numStains = 1 + math.floor(hash(x + y, 500) * 2)
        for i = 1, numStains do
            local sx = innerX + hash(i, 501) * innerW * 0.7 + innerW * 0.15
            local sy = innerY + hash(501, i) * innerH * 0.7 + innerH * 0.15
            local sizeX = 15 + hash(i, 502) * 30
            local sizeY = 10 + hash(i, 503) * 20
            
            love.graphics.setColor(0, 0, 0, 0.06)
            love.graphics.ellipse("fill", sx, sy, sizeX, sizeY)
            love.graphics.setColor(0, 0, 0, 0.04)
            love.graphics.ellipse("fill", sx + 3, sy + 2, sizeX * 0.7, sizeY * 0.7)
        end
        
        -- G) WORN HIGHLIGHT EDGES
        drawWornEdges(innerX, innerY, innerW, innerH, 0.12)
    end
    
    -- 4. INNER SHADOW (darkens edges inside panel)
    -- Top inner shadow (very subtle, stone is lit from above)
    love.graphics.setColor(UI.stoneHighlight[1], UI.stoneHighlight[2], UI.stoneHighlight[3], 0.15)
    love.graphics.rectangle("fill", x + 3, y + 3, w - 6, 3, 2)
    
    -- Bottom inner shadow
    love.graphics.setColor(UI.innerShadow)
    love.graphics.rectangle("fill", x + 3, y + h - 6, w - 6, 4, 2)
    -- Left inner shadow
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.rectangle("fill", x + w - 6, y + 3, 4, h - 6, 2)
    
    -- 5. BEVELED METAL BORDER (with gradient and wear)
    local borderWidth = 3
    
    -- Draw border segments with gradient effect
    -- Top border (lighter, catches light)
    for i = 0, w - cornerRadius * 2 do
        local t = i / (w - cornerRadius * 2)
        local shimmer = math.sin(t * math.pi) * 0.1  -- Subtle curve highlight
        love.graphics.setColor(
            UI.metalBronze[1] + 0.1 + shimmer,
            UI.metalBronze[2] + 0.08 + shimmer,
            UI.metalBronze[3] + 0.05 + shimmer,
            1
        )
        love.graphics.rectangle("fill", x + cornerRadius + i, y, 1, borderWidth)
    end
    
    -- Bottom border (darker, in shadow)
    for i = 0, w - cornerRadius * 2 do
        local t = i / (w - cornerRadius * 2)
        local variation = math.sin(t * math.pi * 3) * 0.03  -- Subtle variation
        love.graphics.setColor(
            UI.metalBronzeDark[1] + variation,
            UI.metalBronzeDark[2] + variation,
            UI.metalBronzeDark[3] + variation,
            1
        )
        love.graphics.rectangle("fill", x + cornerRadius + i, y + h - borderWidth, 1, borderWidth)
    end
    
    -- Left border (lighter)
    for i = 0, h - cornerRadius * 2 do
        local t = i / (h - cornerRadius * 2)
        local shimmer = math.sin(t * math.pi) * 0.08
        love.graphics.setColor(
            UI.metalBronze[1] + 0.05 + shimmer,
            UI.metalBronze[2] + 0.04 + shimmer,
            UI.metalBronze[3] + 0.02 + shimmer,
            1
        )
        love.graphics.rectangle("fill", x, y + cornerRadius + i, borderWidth, 1)
    end
    
    -- Right border (darker)
    for i = 0, h - cornerRadius * 2 do
        local t = i / (h - cornerRadius * 2)
        local variation = math.sin(t * math.pi * 2) * 0.02
        love.graphics.setColor(
            UI.metalBronzeDark[1] + 0.05 + variation,
            UI.metalBronzeDark[2] + 0.04 + variation,
            UI.metalBronzeDark[3] + 0.02 + variation,
            1
        )
        love.graphics.rectangle("fill", x + w - borderWidth, y + cornerRadius + i, borderWidth, 1)
    end
    
    -- Corner arcs (simplified)
    love.graphics.setColor(UI.metalBronze)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.arc("line", "open", x + cornerRadius, y + cornerRadius, cornerRadius, math.pi, math.pi * 1.5, 8)
    love.graphics.arc("line", "open", x + w - cornerRadius, y + cornerRadius, cornerRadius, math.pi * 1.5, math.pi * 2, 8)
    love.graphics.setColor(UI.metalBronzeDark)
    love.graphics.arc("line", "open", x + cornerRadius, y + h - cornerRadius, cornerRadius, math.pi * 0.5, math.pi, 8)
    love.graphics.arc("line", "open", x + w - cornerRadius, y + h - cornerRadius, cornerRadius, 0, math.pi * 0.5, 8)
    
    -- Wear marks / scratches on border (subtle)
    love.graphics.setColor(UI.metalBronzeLight[1], UI.metalBronzeLight[2], UI.metalBronzeLight[3], 0.15)
    -- A few horizontal scratches on top
    if w > 60 then
        love.graphics.line(x + 20, y + 1.5, x + 35, y + 1.5)
        love.graphics.line(x + w - 50, y + 1.5, x + w - 30, y + 1.5)
    end
    -- Darker wear marks
    love.graphics.setColor(0, 0, 0, 0.12)
    if w > 80 then
        love.graphics.line(x + 45, y + h - 1.5, x + 60, y + h - 1.5)
    end
    
    -- Highlight on top and left inner edges
    love.graphics.setColor(UI.metalShine[1], UI.metalShine[2], UI.metalShine[3], 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + cornerRadius, y + borderWidth, x + w - cornerRadius, y + borderWidth)
    love.graphics.line(x + borderWidth, y + cornerRadius, x + borderWidth, y + h - cornerRadius)
    
    -- 6. 3D RIVETS at corners
    local rivetInset = 10
    local rivetSize = 4.5
    drawRivet3D(x + rivetInset, y + rivetInset, rivetSize)
    drawRivet3D(x + w - rivetInset, y + rivetInset, rivetSize)
    drawRivet3D(x + rivetInset, y + h - rivetInset, rivetSize)
    drawRivet3D(x + w - rivetInset, y + h - rivetInset, rivetSize)
    
    -- 7. ORNAMENTAL CORNER DETAILS (small brackets)
    if w > 80 and h > 60 then
        local ornamentSize = 12
        drawCornerOrnament(x + 2, y + 2, ornamentSize, false, false)
        drawCornerOrnament(x + w - 2, y + 2, ornamentSize, true, false)
        drawCornerOrnament(x + 2, y + h - 2, ornamentSize, false, true)
        drawCornerOrnament(x + w - 2, y + h - 2, ornamentSize, true, true)
    end
end

-- Enhanced resource group with better icons
function UIDraw.drawResourceGroup(x, y, iconType, value, label, fonts)
    local groupW, groupH = 90, 32
    
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", x + 2, y + 2, groupW, groupH, 4)
    
    -- Gradient background (lighter top)
    local bgTop = {UI.stoneMid[1] + 0.05, UI.stoneMid[2] + 0.05, UI.stoneMid[3] + 0.04, 0.9}
    local bgBottom = {UI.stoneDark[1] + 0.05, UI.stoneDark[2] + 0.05, UI.stoneDark[3] + 0.04, 0.9}
    
    for i = 0, groupH - 1, 2 do
        local t = i / groupH
        love.graphics.setColor(
            bgTop[1] + (bgBottom[1] - bgTop[1]) * t,
            bgTop[2] + (bgBottom[2] - bgTop[2]) * t,
            bgTop[3] + (bgBottom[3] - bgTop[3]) * t,
            bgTop[4]
        )
        love.graphics.rectangle("fill", x, y + i, groupW, 2, i == 0 and 4 or 0)
    end
    
    -- Beveled border
    love.graphics.setColor(UI.metalBronzeDark)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, groupW, groupH, 4)
    
    love.graphics.setColor(UI.metalBronzeLight[1], UI.metalBronzeLight[2], UI.metalBronzeLight[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 4, y + 1, x + groupW - 4, y + 1)  -- Top highlight
    
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.line(x + 4, y + groupH - 1, x + groupW - 4, y + groupH - 1)  -- Bottom shadow
    
    -- ICONS
    local iconCX, iconCY = x + 16, y + 16
    
    if iconType == "gold" then
        -- Gold coin with rim, shine, and embossed look
        -- Outer rim (dark)
        love.graphics.setColor(0.6, 0.45, 0.1, 1)
        love.graphics.circle("fill", iconCX, iconCY, 11, 20)
        
        -- Main coin body
        love.graphics.setColor(1, 0.82, 0.25, 1)
        love.graphics.circle("fill", iconCX, iconCY, 10, 20)
        
        -- Inner gradient simulation (darker bottom)
        love.graphics.setColor(0.85, 0.65, 0.15, 1)
        love.graphics.arc("fill", iconCX, iconCY, 9, math.pi * 0.2, math.pi * 0.8, 12)
        
        -- Inner rim
        love.graphics.setColor(0.9, 0.7, 0.2, 1)
        love.graphics.circle("line", iconCX, iconCY, 7, 16)
        
        -- Embossed "G" or symbol
        love.graphics.setColor(0.7, 0.5, 0.1, 1)
        if fonts and fonts.small then
            love.graphics.setFont(fonts.small)
        end
        local gW = love.graphics.getFont():getWidth("$")
        love.graphics.print("$", iconCX - gW/2 + 1, iconCY - 6)
        love.graphics.setColor(1, 0.9, 0.4, 1)
        love.graphics.print("$", iconCX - gW/2, iconCY - 7)
        
        -- Shine highlight (upper left)
        love.graphics.setColor(1, 1, 0.85, 0.8)
        love.graphics.ellipse("fill", iconCX - 4, iconCY - 4, 3, 2)
        
        -- Small secondary shine
        love.graphics.setColor(1, 1, 0.9, 0.5)
        love.graphics.circle("fill", iconCX + 3, iconCY - 5, 1.5)
        
    elseif iconType == "lumber" then
        -- Wood log with grain detail
        local logX, logY = x + 6, y + 8
        local logW, logH = 18, 16
        
        -- Log shadow
        love.graphics.setColor(0.25, 0.15, 0.05, 0.5)
        love.graphics.rectangle("fill", logX + 2, logY + 2, logW, logH, 3)
        
        -- Main log body (darker wood)
        love.graphics.setColor(0.5, 0.32, 0.12, 1)
        love.graphics.rectangle("fill", logX, logY, logW, logH, 3)
        
        -- Wood grain lines
        love.graphics.setColor(0.38, 0.22, 0.08, 0.7)
        for i = 0, 3 do
            local ly = logY + 3 + i * 4
            love.graphics.line(logX + 2, ly, logX + logW - 2, ly + 1)
        end
        
        -- Top highlight
        love.graphics.setColor(0.65, 0.45, 0.2, 1)
        love.graphics.rectangle("fill", logX, logY, logW, 3, 2)
        
        -- Cut end (ellipse)
        local endX = logX + logW - 1
        local endY = logY + logH / 2
        
        -- End shadow
        love.graphics.setColor(0.35, 0.2, 0.08, 1)
        love.graphics.ellipse("fill", endX, endY, 5, 8)
        
        -- End face
        love.graphics.setColor(0.75, 0.55, 0.3, 1)
        love.graphics.ellipse("fill", endX - 1, endY, 4, 7)
        
        -- Growth rings
        love.graphics.setColor(0.6, 0.4, 0.2, 0.8)
        love.graphics.ellipse("line", endX - 1, endY, 3, 5)
        love.graphics.ellipse("line", endX - 1, endY, 1.5, 2.5)
        
        -- Center dot
        love.graphics.setColor(0.45, 0.28, 0.12, 1)
        love.graphics.circle("fill", endX - 1, endY, 1)
        
    elseif iconType == "pop" then
        -- House with more detail
        local hx, hy = x + 16, y + 6
        
        -- House shadow
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.polygon("fill", hx + 2, hy + 12, hx - 8, hy + 12, hx + 12, hy + 12)
        love.graphics.rectangle("fill", hx - 5, hy + 12, 14, 14)
        
        -- Roof
        love.graphics.setColor(0.55, 0.35, 0.2, 1)
        love.graphics.polygon("fill", hx, hy, hx - 12, hy + 14, hx + 12, hy + 14)
        -- Roof highlight
        love.graphics.setColor(0.7, 0.5, 0.3, 1)
        love.graphics.polygon("fill", hx, hy, hx - 2, hy + 4, hx + 2, hy + 4)
        -- Roof shadow
        love.graphics.setColor(0.4, 0.25, 0.12, 1)
        love.graphics.polygon("fill", hx, hy + 10, hx + 10, hy + 14, hx - 10, hy + 14)
        
        -- House body
        love.graphics.setColor(0.58, 0.5, 0.38, 1)
        love.graphics.rectangle("fill", hx - 8, hy + 14, 16, 12)
        
        -- Body shading (right side darker)
        love.graphics.setColor(0.45, 0.38, 0.28, 1)
        love.graphics.rectangle("fill", hx + 2, hy + 14, 6, 12)
        
        -- Door
        love.graphics.setColor(0.35, 0.22, 0.1, 1)
        love.graphics.rectangle("fill", hx - 3, hy + 18, 6, 8)
        -- Door highlight
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", hx - 3, hy + 18, 2, 8)
        
        -- Window
        love.graphics.setColor(0.6, 0.75, 0.9, 1)
        love.graphics.rectangle("fill", hx + 4, hy + 16, 3, 3)
        love.graphics.setColor(0.3, 0.2, 0.1, 1)
        love.graphics.rectangle("line", hx + 4, hy + 16, 3, 3)
    end
    
    -- Value text with shadow
    if fonts and fonts.medium then
        love.graphics.setFont(fonts.medium)
    end
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(tostring(value), x + 33, y + 9)
    love.graphics.setColor(UI.textLight)
    love.graphics.print(tostring(value), x + 32, y + 8)
end

-- Enhanced top bar with proper styling
function UIDraw.drawTopBar(screenW, resources, currentPop, maxPop, elapsedTime, townHallTier, gameSpeed, fonts)
    local barHeight = UI.topBarHeight
    
    -- Drop shadow under bar
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, barHeight, screenW, 6)
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", 0, barHeight + 6, screenW, 4)
    
    -- Gradient background
    local bgTop = {UI.stoneMid[1] + 0.05, UI.stoneMid[2] + 0.05, UI.stoneMid[3] + 0.04, 0.95}
    local bgBottom = {UI.stoneDark[1] - 0.02, UI.stoneDark[2] - 0.02, UI.stoneDark[3] - 0.02, 0.95}
    
    for i = 0, barHeight - 4, 2 do
        local t = i / barHeight
        love.graphics.setColor(
            bgTop[1] + (bgBottom[1] - bgTop[1]) * t,
            bgTop[2] + (bgBottom[2] - bgTop[2]) * t,
            bgTop[3] + (bgBottom[3] - bgTop[3]) * t,
            bgTop[4]
        )
        love.graphics.rectangle("fill", 0, i, screenW, 2)
    end
    
    -- Stone texture overlay (weathered, organic)
    -- Color blotches
    local numBlotches = math.floor(screenW / 40)
    for i = 1, numBlotches do
        local bx = hash(i, 1) * screenW
        local by = 4 + hash(1, i) * (barHeight - 12)
        local bsize = 10 + hash(i, i) * 20
        local colorVar = (hash(i * 3, i * 5) - 0.5) * 0.08
        local isDark = hash(i * 7, i * 11) > 0.55
        
        local br = UI.stoneMid[1] + colorVar
        local bg = UI.stoneMid[2] + colorVar * 0.8
        local bb = UI.stoneMid[3] + colorVar * 0.5
        if isDark then br, bg, bb = br - 0.04, bg - 0.04, bb - 0.03 end
        
        love.graphics.setColor(br, bg, bb, 0.2)
        love.graphics.ellipse("fill", bx, by, bsize, bsize * 0.6)
    end
    
    -- Sparse cracks
    local numCracks = 2 + math.floor(hash(screenW, 1) * 3)
    for c = 1, numCracks do
        local cx = hash(c, 100) * screenW
        local cy = 5 + hash(100, c) * (barHeight - 14)
        local angle = hash(c, 101) * math.pi * 2
        local length = 8 + hash(c, 102) * 15
        
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.setLineWidth(1)
        local px, py = cx, cy
        for s = 1, math.floor(length / 3) do
            angle = angle + (hash(c * s, s) - 0.5) * 0.6
            local nx = px + math.cos(angle) * 3
            local ny = py + math.sin(angle) * 2
            if ny > 2 and ny < barHeight - 6 then
                love.graphics.line(px, py, nx, ny)
                px, py = nx, ny
            end
        end
    end
    
    -- Surface noise
    local numNoise = math.floor(screenW * barHeight / 60)
    for i = 1, numNoise do
        local px = hash(i, 400) * screenW
        local py = 3 + hash(400, i) * (barHeight - 10)
        if hash(i * 3, 401) > 0.45 then
            love.graphics.setColor(1, 0.95, 0.85, 0.07)
        else
            love.graphics.setColor(0, 0, 0, 0.09)
        end
        love.graphics.rectangle("fill", px, py, 1, 1)
    end
    
    -- Top highlight edge (worn/uneven)
    for i = 0, screenW - 1 do
        if hash(i, 999) > 0.4 then
            local alpha = 0.12 + hash(i, 1000) * 0.15
            love.graphics.setColor(UI.stoneHighlight[1], UI.stoneHighlight[2], UI.stoneHighlight[3], alpha)
            love.graphics.rectangle("fill", i, 0, 1, 1 + math.floor(hash(i, 1001) * 1.5))
        end
    end
    
    -- Bottom metal trim with gradient and wear
    local trimHeight = 4
    for i = 0, screenW - 1 do
        local t = i / screenW
        local shimmer = math.sin(t * math.pi * 8) * 0.02  -- Subtle wavering
        love.graphics.setColor(
            UI.metalBronze[1] + shimmer,
            UI.metalBronze[2] + shimmer * 0.8,
            UI.metalBronze[3] + shimmer * 0.5,
            1
        )
        love.graphics.rectangle("fill", i, barHeight - trimHeight, 1, trimHeight)
    end
    -- Top highlight of trim
    love.graphics.setColor(UI.metalBronzeLight[1], UI.metalBronzeLight[2], UI.metalBronzeLight[3], 0.6)
    love.graphics.rectangle("fill", 0, barHeight - trimHeight, screenW, 1)
    -- Bottom shadow of trim  
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 0, barHeight - 1, screenW, 1)
    
    -- Decorative rivets along bottom
    for i = 1, math.floor(screenW / 80) do
        drawRivet3D(i * 80, barHeight - 2, 3)
    end
    
    -- LEFT: Resource groups
    local rx = 10
    UIDraw.drawResourceGroup(rx, 5, "gold", resources.gold, "Gold", fonts)
    rx = rx + 100
    UIDraw.drawResourceGroup(rx, 5, "lumber", resources.lumber, "Lumber", fonts)
    rx = rx + 100
    
    -- Population display (with warning state)
    local atCap = currentPop >= maxPop
    UIDraw.drawResourceGroup(rx, 5, "pop", currentPop .. "/" .. maxPop, "Pop", fonts)
    if atCap then
        -- Red warning overlay
        love.graphics.setColor(1, 0.2, 0.2, 0.3)
        love.graphics.rectangle("fill", rx, 5, 90, 32, 4)
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx, 5, 90, 32, 4)
    end
    
    -- CENTER: Time display
    local centerX = screenW / 2
    if fonts and fonts.medium then love.graphics.setFont(fonts.medium) end
    local timeStr = string.format("%02d:%02d", math.floor(elapsedTime/60), math.floor(elapsedTime%60))
    local timeW = love.graphics.getFont():getWidth(timeStr)
    
    -- Time backdrop
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", centerX - timeW/2 - 8, 8, timeW + 16, 24, 4)
    
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.print(timeStr, centerX - timeW/2 + 1, 13)
    love.graphics.setColor(UI.textLight)
    love.graphics.print(timeStr, centerX - timeW/2, 12)
    
    -- Speed indicator
    local speedText = "1x"
    local speedColor = UI.textLight
    if gameSpeed == 0.5 then
        speedText = "0.5x"
        speedColor = {0.5, 0.7, 1, 1}
    elseif gameSpeed == 2.0 then
        speedText = "2x"
        speedColor = {1, 0.7, 0.4, 1}
    end
    if fonts and fonts.small then love.graphics.setFont(fonts.small) end
    love.graphics.setColor(speedColor)
    love.graphics.print(speedText, centerX + timeW/2 + 14, 14)
    
    -- RIGHT: HQ tier indicator
    local tierName = townHallTier == 3 and "KEEP" or (townHallTier == 2 and "HOLD" or "HALL")
    local tierColor = townHallTier == 3 and UI.metalGold or (townHallTier == 2 and UI.metalBronze or UI.textLight)
    
    love.graphics.setColor(tierColor)
    if fonts and fonts.medium then love.graphics.setFont(fonts.medium) end
    local tierW = love.graphics.getFont():getWidth(tierName)
    
    -- Tier backdrop
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", screenW - UI.minimapSize - tierW - 30, 8, tierW + 16, 24, 4)
    
    love.graphics.setColor(tierColor)
    love.graphics.print(tierName, screenW - UI.minimapSize - tierW - 22, 12)
end

-- Enhanced minimap frame
function UIDraw.drawMinimapFrame(screenW)
    local mmSize = UI.minimapSize
    local mmX = screenW - mmSize - 8
    local mmY = UI.topBarHeight + 8
    local frameInset = 8
    
    -- Draw ornate frame
    UIDraw.drawStonePanel(mmX - frameInset, mmY - frameInset, mmSize + frameInset * 2, mmSize + frameInset * 2, 4)
    
    return mmX, mmY, mmSize
end

-- Enhanced bottom panel
function UIDraw.drawBottomPanelFrame(screenW, screenH)
    local panelW = UI.bottomPanelWidth
    local panelH = UI.bottomPanelHeight
    local panelX = screenW - panelW - 8
    local panelY = screenH - panelH - 8
    
    -- Draw main panel with SUBTLE mode (less texture for readability)
    UIDraw.drawStonePanel(panelX, panelY, panelW, panelH, 6, true)
    
    -- Header bar with gradient
    local headerH = 24
    local hTop = {UI.metalBronze[1], UI.metalBronze[2], UI.metalBronze[3], 0.4}
    local hBottom = {UI.metalBronzeDark[1], UI.metalBronzeDark[2], UI.metalBronzeDark[3], 0.4}
    
    for i = 0, headerH - 1, 2 do
        local t = i / headerH
        love.graphics.setColor(
            hTop[1] + (hBottom[1] - hTop[1]) * t,
            hTop[2] + (hBottom[2] - hTop[2]) * t,
            hTop[3] + (hBottom[3] - hTop[3]) * t,
            hTop[4]
        )
        love.graphics.rectangle("fill", panelX + 6, panelY + 6 + i, panelW - 12, 2, i == 0 and 3 or 0)
    end
    
    -- Header border
    love.graphics.setColor(UI.metalBronzeDark)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX + 6, panelY + 6, panelW - 12, headerH, 3)
    
    -- Divider line under header
    love.graphics.setColor(UI.metalBronze[1], UI.metalBronze[2], UI.metalBronze[3], 0.3)
    love.graphics.line(panelX + 12, panelY + 32, panelX + panelW - 12, panelY + 32)
    
    return panelX, panelY, panelW, panelH
end

-- New horizontal command bar at bottom of screen
function UIDraw.drawCommandBar(screenW, screenH)
    local barH = 80
    local barY = screenH - barH
    local barX = 0
    local barW = screenW
    
    -- Draw bar background
    UIDraw.drawStonePanel(barX, barY, barW, barH, 4, true)
    
    -- Divider line at top
    love.graphics.setColor(UI.metalBronze[1], UI.metalBronze[2], UI.metalBronze[3], 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(barX + 4, barY + 2, barX + barW - 4, barY + 2)
    
    return barX, barY, barW, barH
end

-- Draw a command button with hotkey indicator
function UIDraw.drawCommandButton(x, y, w, h, text, hotkey, enabled, hovered, pressed, iconType)
    local bgColor, borderColor, textColor
    
    if not enabled then
        bgColor = {0.15, 0.13, 0.11, 0.8}
        borderColor = {0.3, 0.25, 0.2, 0.5}
        textColor = {0.5, 0.45, 0.4, 0.6}
    elseif pressed then
        bgColor = {0.25, 0.20, 0.15, 1}
        borderColor = {0.6, 0.5, 0.3, 1}
        textColor = {1, 0.9, 0.7, 1}
    elseif hovered then
        bgColor = {0.35, 0.28, 0.18, 1}
        borderColor = {0.75, 0.6, 0.35, 1}
        textColor = {1, 0.95, 0.85, 1}
    else
        bgColor = {0.22, 0.18, 0.14, 1}
        borderColor = {0.5, 0.4, 0.25, 1}
        textColor = {0.92, 0.88, 0.78, 1}
    end
    
    -- Button background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 4)
    
    -- Button border
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 4)
    
    -- Draw icon/portrait in center-top area
    local iconSize = 28
    local iconX = x + (w - iconSize) / 2
    local iconY = y + 5
    
    -- Icon background (darker inset)
    love.graphics.setColor(0.08, 0.06, 0.05, 0.9)
    love.graphics.rectangle("fill", iconX - 1, iconY - 1, iconSize + 2, iconSize + 2, 3)
    
    -- Draw appropriate icon based on type
    local iconAlpha = enabled and 1 or 0.5
    if iconType == "peon" then
        -- Peon face icon
        love.graphics.setColor(0.85, 0.7, 0.55, iconAlpha)  -- Skin
        love.graphics.circle("fill", iconX + iconSize/2, iconY + iconSize/2, 10)
        love.graphics.setColor(0.4, 0.25, 0.15, iconAlpha)  -- Hair
        love.graphics.arc("fill", iconX + iconSize/2, iconY + iconSize/2 - 3, 10, math.pi, 0)
        love.graphics.setColor(0.2, 0.15, 0.1, iconAlpha)  -- Eyes
        love.graphics.circle("fill", iconX + iconSize/2 - 3, iconY + iconSize/2 + 1, 2)
        love.graphics.circle("fill", iconX + iconSize/2 + 3, iconY + iconSize/2 + 1, 2)
    elseif iconType == "footman" then
        -- Footman helmet icon
        love.graphics.setColor(0.6, 0.6, 0.65, iconAlpha)  -- Steel helmet
        love.graphics.rectangle("fill", iconX + 5, iconY + 3, iconSize - 10, iconSize - 8, 3)
        love.graphics.setColor(0.4, 0.4, 0.45, iconAlpha)  -- Visor
        love.graphics.rectangle("fill", iconX + 7, iconY + 12, iconSize - 14, 6)
        love.graphics.setColor(0.8, 0.7, 0.3, iconAlpha)  -- Plume/crest
        love.graphics.polygon("fill", iconX + iconSize/2, iconY + 2, iconX + iconSize/2 - 4, iconY + 8, iconX + iconSize/2 + 4, iconY + 8)
    elseif iconType == "farm" then
        -- Farm icon (barn shape)
        love.graphics.setColor(0.6, 0.35, 0.2, iconAlpha)  -- Brown wood
        love.graphics.rectangle("fill", iconX + 4, iconY + 10, iconSize - 8, iconSize - 12)
        love.graphics.setColor(0.7, 0.3, 0.2, iconAlpha)  -- Red roof
        love.graphics.polygon("fill", iconX + 2, iconY + 10, iconX + iconSize/2, iconY + 2, iconX + iconSize - 2, iconY + 10)
        love.graphics.setColor(0.4, 0.25, 0.1, iconAlpha)  -- Door
        love.graphics.rectangle("fill", iconX + iconSize/2 - 3, iconY + 16, 6, 10)
    elseif iconType == "barracks" then
        -- Barracks icon (fortress shape)
        love.graphics.setColor(0.5, 0.45, 0.4, iconAlpha)  -- Stone gray
        love.graphics.rectangle("fill", iconX + 3, iconY + 8, iconSize - 6, iconSize - 10)
        -- Battlements
        love.graphics.rectangle("fill", iconX + 3, iconY + 4, 5, 6)
        love.graphics.rectangle("fill", iconX + iconSize/2 - 2.5, iconY + 4, 5, 6)
        love.graphics.rectangle("fill", iconX + iconSize - 8, iconY + 4, 5, 6)
        love.graphics.setColor(0.25, 0.2, 0.15, iconAlpha)  -- Gate
        love.graphics.rectangle("fill", iconX + iconSize/2 - 4, iconY + 14, 8, 12)
    elseif iconType == "tower" then
        -- Tower icon
        love.graphics.setColor(0.5, 0.45, 0.4, iconAlpha)  -- Stone
        love.graphics.rectangle("fill", iconX + 8, iconY + 6, iconSize - 16, iconSize - 8)
        -- Pointed roof
        love.graphics.setColor(0.4, 0.3, 0.25, iconAlpha)
        love.graphics.polygon("fill", iconX + iconSize/2, iconY + 2, iconX + 6, iconY + 8, iconX + iconSize - 6, iconY + 8)
        -- Window
        love.graphics.setColor(0.2, 0.3, 0.4, iconAlpha)
        love.graphics.rectangle("fill", iconX + iconSize/2 - 2, iconY + 14, 4, 6)
    elseif iconType == "attack" then
        -- Attack icon (sword)
        love.graphics.setColor(0.7, 0.7, 0.75, iconAlpha)  -- Blade
        love.graphics.polygon("fill", iconX + 6, iconY + iconSize - 4, iconX + iconSize - 6, iconY + 4, iconX + iconSize - 4, iconY + 6, iconX + 8, iconY + iconSize - 2)
        love.graphics.setColor(0.5, 0.35, 0.2, iconAlpha)  -- Handle
        love.graphics.rectangle("fill", iconX + 4, iconY + iconSize - 8, 6, 8)
        love.graphics.setColor(0.8, 0.7, 0.3, iconAlpha)  -- Guard
        love.graphics.rectangle("fill", iconX + 2, iconY + iconSize - 10, 10, 3)
    elseif iconType == "stop" then
        -- Stop icon (hand)
        love.graphics.setColor(0.9, 0.3, 0.2, iconAlpha)
        love.graphics.circle("fill", iconX + iconSize/2, iconY + iconSize/2, 11)
        love.graphics.setColor(0.95, 0.85, 0.7, iconAlpha)  -- Palm
        love.graphics.rectangle("fill", iconX + 8, iconY + 10, 12, 14, 2)
        -- Fingers
        for i = 0, 3 do
            love.graphics.rectangle("fill", iconX + 8 + i * 3, iconY + 5, 3, 8, 1)
        end
    else
        -- Generic icon (question mark or simple shape)
        love.graphics.setColor(0.6, 0.55, 0.5, iconAlpha)
        love.graphics.circle("fill", iconX + iconSize/2, iconY + iconSize/2, 10)
        love.graphics.setColor(0.3, 0.25, 0.2, iconAlpha)
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.print("?", iconX + iconSize/2 - 4, iconY + iconSize/2 - 8)
    end
    
    -- Hotkey in top-left corner (no box, just the letter)
    if hotkey then
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.setFont(Game.fonts.small)
        love.graphics.print(hotkey, x + 5, y + 3)
        -- Letter
        love.graphics.setColor(enabled and {1, 0.9, 0.5, 1} or {0.6, 0.5, 0.3, 0.6})
        love.graphics.print(hotkey, x + 4, y + 2)
    end
    
    -- Button text at bottom
    love.graphics.setColor(textColor)
    love.graphics.setFont(Game.fonts.small)
    local textW = Game.fonts.small:getWidth(text)
    local textX = x + (w - textW) / 2
    local textY = y + h - 16
    love.graphics.print(text, textX, textY)
    
    return x, y, w, h
end

return UIDraw
