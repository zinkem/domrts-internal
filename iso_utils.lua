--[[
    Isometric Rendering Utilities
    Shared module for isometric projection and shape rendering
    Used by all buildings for consistent visual style
]]

local IsoUtils = {}

--============================================================================
-- ISOMETRIC PROJECTION
-- True 2:1 isometric projection
--============================================================================

function IsoUtils.project(x, y, z, originX, originY)
    local screenX = originX + (x - y) * 0.5
    local screenY = originY + (x + y) * 0.25 - z * 0.5
    return screenX, screenY
end

--============================================================================
-- BASIC SHAPES
--============================================================================

-- Draw a quadrilateral with 4 3D points
function IsoUtils.quad(p1, p2, p3, p4, originX, originY, color)
    local sx1, sy1 = IsoUtils.project(p1[1], p1[2], p1[3], originX, originY)
    local sx2, sy2 = IsoUtils.project(p2[1], p2[2], p2[3], originX, originY)
    local sx3, sy3 = IsoUtils.project(p3[1], p3[2], p3[3], originX, originY)
    local sx4, sy4 = IsoUtils.project(p4[1], p4[2], p4[3], originX, originY)

    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon("fill", sx1, sy1, sx2, sy2, sx3, sy3, sx4, sy4)
end

-- Draw a rectangular box (for compatibility with existing code)
function IsoUtils.box(x, y, z, w, d, h, originX, originY, topColor, leftColor, rightColor)
    -- Top face
    IsoUtils.quad(
        {x, y, z + h},
        {x + w, y, z + h},
        {x + w, y + d, z + h},
        {x, y + d, z + h},
        originX, originY, topColor
    )

    -- Left face (front in isometric view)
    IsoUtils.quad(
        {x, y + d, z},
        {x, y + d, z + h},
        {x + w, y + d, z + h},
        {x + w, y + d, z},
        originX, originY, leftColor
    )

    -- Right face
    IsoUtils.quad(
        {x + w, y, z},
        {x + w, y, z + h},
        {x + w, y + d, z + h},
        {x + w, y + d, z},
        originX, originY, rightColor
    )
end

--============================================================================
-- OCTAGONAL SHAPES (rounded corners)
--============================================================================

-- Draw an octagonal top face
-- cx, cy = center position, r = radius, z = height
function IsoUtils.octagon(cx, cy, z, r, originX, originY, color)
    -- Octagon vertices: cut corners at 45 degrees
    -- Corner cut is r * (1 - 1/sqrt(2)) ≈ r * 0.293
    local cut = r * 0.293
    local points = {
        {cx - r + cut, cy - r, z},        -- top edge left
        {cx + r - cut, cy - r, z},        -- top edge right
        {cx + r, cy - r + cut, z},        -- right edge top
        {cx + r, cy + r - cut, z},        -- right edge bottom
        {cx + r - cut, cy + r, z},        -- bottom edge right
        {cx - r + cut, cy + r, z},        -- bottom edge left
        {cx - r, cy + r - cut, z},        -- left edge bottom
        {cx - r, cy - r + cut, z},        -- left edge top
    }

    -- Project all points
    local screenPts = {}
    for i, p in ipairs(points) do
        local sx, sy = IsoUtils.project(p[1], p[2], p[3], originX, originY)
        screenPts[i] = {sx, sy}
    end

    -- Draw as polygon
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.polygon("fill",
        screenPts[1][1], screenPts[1][2],
        screenPts[2][1], screenPts[2][2],
        screenPts[3][1], screenPts[3][2],
        screenPts[4][1], screenPts[4][2],
        screenPts[5][1], screenPts[5][2],
        screenPts[6][1], screenPts[6][2],
        screenPts[7][1], screenPts[7][2],
        screenPts[8][1], screenPts[8][2]
    )
end

-- Draw octagonal prism walls (visible faces only)
function IsoUtils.octagonalPrism(cx, cy, z, r, h, originX, originY, topColor, wallColors)
    local cut = r * 0.293

    -- Define the 8 vertices at bottom and top
    local bottomPts = {
        {cx - r + cut, cy - r, z},        -- 1: top edge left
        {cx + r - cut, cy - r, z},        -- 2: top edge right
        {cx + r, cy - r + cut, z},        -- 3: right edge top
        {cx + r, cy + r - cut, z},        -- 4: right edge bottom
        {cx + r - cut, cy + r, z},        -- 5: bottom edge right
        {cx - r + cut, cy + r, z},        -- 6: bottom edge left
        {cx - r, cy + r - cut, z},        -- 7: left edge bottom
        {cx - r, cy - r + cut, z},        -- 8: left edge top
    }

    local topPts = {}
    for i, p in ipairs(bottomPts) do
        topPts[i] = {p[1], p[2], z + h}
    end

    -- Draw visible wall faces (faces 3-7 are typically visible in isometric)
    -- Face indices go clockwise, we draw faces facing "camera" (south-east-ish)
    local faces = {
        {3, 4, wallColors[1] or {0.52, 0.50, 0.46}},  -- right face (bright)
        {4, 5, wallColors[2] or {0.48, 0.46, 0.42}},  -- bottom-right corner
        {5, 6, wallColors[3] or {0.45, 0.43, 0.40}},  -- bottom face (medium)
        {6, 7, wallColors[4] or {0.42, 0.40, 0.38}},  -- bottom-left corner
    }

    for _, face in ipairs(faces) do
        local i1, i2, color = face[1], face[2], face[3]
        IsoUtils.quad(
            bottomPts[i1], bottomPts[i2], topPts[i2], topPts[i1],
            originX, originY, color
        )
    end

    -- Draw top face
    IsoUtils.octagon(cx, cy, z + h, r, originX, originY, topColor)
end

-- Convenience function: octagonal box with auto-generated wall colors from base color
function IsoUtils.octagonalBox(cx, cy, z, r, h, originX, originY, baseColor)
    local topColor = {baseColor[1] * 1.1, baseColor[2] * 1.1, baseColor[3] * 1.1}
    local wallColors = {
        {baseColor[1] * 1.05, baseColor[2] * 1.05, baseColor[3] * 1.05},  -- right (brightest)
        {baseColor[1] * 0.95, baseColor[2] * 0.95, baseColor[3] * 0.95},  -- bottom-right
        {baseColor[1] * 0.85, baseColor[2] * 0.85, baseColor[3] * 0.85},  -- bottom
        {baseColor[1] * 0.75, baseColor[2] * 0.75, baseColor[3] * 0.75},  -- bottom-left (darkest)
    }
    IsoUtils.octagonalPrism(cx, cy, z, r, h, originX, originY, topColor, wallColors)
end

--============================================================================
-- COMMON BUILDING ELEMENTS
--============================================================================

-- Draw a door on the front face
function IsoUtils.door(cx, frontY, z, doorW, doorH, originX, originY, frameColor, woodColor)
    -- Door frame
    IsoUtils.quad(
        {cx - doorW/2 - 1, frontY, z},
        {cx + doorW/2 + 1, frontY, z},
        {cx + doorW/2 + 1, frontY, z + doorH + 2},
        {cx - doorW/2 - 1, frontY, z + doorH + 2},
        originX, originY, frameColor or {0.32, 0.30, 0.28}
    )
    -- Door wood
    IsoUtils.quad(
        {cx - doorW/2, frontY + 0.5, z},
        {cx + doorW/2, frontY + 0.5, z},
        {cx + doorW/2, frontY + 0.5, z + doorH},
        {cx - doorW/2, frontY + 0.5, z + doorH},
        originX, originY, woodColor or {0.18, 0.12, 0.08}
    )
end

-- Draw a window slit
function IsoUtils.windowSlit(cx, frontY, z, w, h, originX, originY, color)
    IsoUtils.quad(
        {cx - w/2, frontY, z},
        {cx + w/2, frontY, z},
        {cx + w/2, frontY, z + h},
        {cx - w/2, frontY, z + h},
        originX, originY, color or {0.10, 0.08, 0.06}
    )
end

-- Draw a conical/pyramidal roof
function IsoUtils.pyramidRoof(cx, cy, z, r, h, originX, originY, roofColor)
    local cut = r * 0.293
    local peakX, peakY = IsoUtils.project(cx, cy, z + h, originX, originY)

    -- Get octagon points at base
    local basePoints = {
        {cx - r + cut, cy - r, z},      -- 1: back-left
        {cx + r - cut, cy - r, z},      -- 2: back-right
        {cx + r, cy - r + cut, z},      -- 3: right-back
        {cx + r, cy + r - cut, z},      -- 4: right-front
        {cx + r - cut, cy + r, z},      -- 5: front-right
        {cx - r + cut, cy + r, z},      -- 6: front-left
        {cx - r, cy + r - cut, z},      -- 7: left-front
        {cx - r, cy - r + cut, z},      -- 8: left-back
    }

    -- Draw ALL 8 roof faces, back to front for proper layering
    -- Back faces first (will be covered by front faces)
    local drawOrder = {1, 2, 8, 3, 7, 4, 6, 5}  -- back to front
    local shades = {
        [1] = 0.65, [2] = 0.70,  -- back faces (darker)
        [3] = 1.0,  [4] = 0.95,  -- right faces (brighter)
        [5] = 0.85, [6] = 0.80,  -- front faces (medium)
        [7] = 0.70, [8] = 0.65,  -- left faces (darker)
    }

    for _, faceIdx in ipairs(drawOrder) do
        local nextIdx = faceIdx % 8 + 1
        local p1 = basePoints[faceIdx]
        local p2 = basePoints[nextIdx]

        local sx1, sy1 = IsoUtils.project(p1[1], p1[2], p1[3], originX, originY)
        local sx2, sy2 = IsoUtils.project(p2[1], p2[2], p2[3], originX, originY)

        local shade = shades[faceIdx]
        love.graphics.setColor(roofColor[1] * shade, roofColor[2] * shade, roofColor[3] * shade, 1)
        love.graphics.polygon("fill", sx1, sy1, sx2, sy2, peakX, peakY)
    end
end

return IsoUtils
