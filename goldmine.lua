--[[
    Gold Mine
    Resource node that peons harvest gold from
    Size: 3x3 tiles, grid-aligned
    Style: Isometric rocky mountain with cave entrance and gold veins
]]

-- Building renderer for retro pixel art effect
local BuildingRenderer
pcall(function() BuildingRenderer = require("building_renderer") end)

-- Shared isometric utilities
local IsoUtils = require("iso_utils")
local isoProject = IsoUtils.project
local isoQuad = IsoUtils.quad
local isoBox = IsoUtils.box
local isoOctagonalPrism = IsoUtils.octagonalPrism
local isoOctagon = IsoUtils.octagon

local GoldMine = {}
GoldMine.__index = GoldMine

GoldMine.GRID_SIZE = 3

-- Static counter
local goldMineIdCounter = 0

function GoldMine.new(params)
    local self = setmetatable({}, GoldMine)
    
    goldMineIdCounter = goldMineIdCounter + 1
    self.uniqueId = goldMineIdCounter
    self.animTimer = 0
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = GoldMine.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.goldReserves = params.gold or 12500
    self.maxGold = self.goldReserves
    self.selected = false
    self.depleted = false
    self.type = "goldmine"
    self.name = "Gold Mine"
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function GoldMine:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function GoldMine:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function GoldMine:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function GoldMine:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function GoldMine:update(dt)
    self.animTimer = (self.animTimer or 0) + dt
    
    if self.goldReserves <= 0 then
        self.depleted = true
    end
end

function GoldMine:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Use palette shader with 2x scaling
    local drawScale = 2
    local canvasSize = 128
    local scaledSize = canvasSize * drawScale
    local offsetX = x + (size - scaledSize) / 2
    local offsetY = y + size - scaledSize

    if BuildingRenderer and BuildingRenderer.begin("large") then
        self:drawGoldMineIso(16, 24, 96)
        BuildingRenderer.finishWithSize("large", offsetX, offsetY, drawScale)
    else
        love.graphics.push()
        love.graphics.translate(offsetX, offsetY)
        love.graphics.scale(drawScale, drawScale)
        self:drawGoldMineIso(16, 24, 96)
        love.graphics.pop()
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
        
        -- Gold reserves display
        love.graphics.setColor(0, 0, 0, 0.6)
        local goldText = tostring(self.goldReserves) .. " gold"
        local font = love.graphics.getFont()
        local textW = font:getWidth(goldText)
        love.graphics.rectangle("fill", x + (size - textW) / 2 - 4, y - 22, textW + 8, 18, 3)
        love.graphics.setColor(1, 0.85, 0, 1)
        love.graphics.print(goldText, x + (size - textW) / 2, y - 20)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function GoldMine:drawGoldMineIso(x, y, size)
    local scale = 1
    local originX = x + size/2
    local originY = y + size - 10
    
    -- Colors (duller if depleted)
    local rockTop = self.depleted and {0.40, 0.38, 0.35} or {0.50, 0.46, 0.40}
    local rockLeft = self.depleted and {0.32, 0.30, 0.28} or {0.38, 0.35, 0.30}
    local rockRight = self.depleted and {0.36, 0.34, 0.32} or {0.44, 0.40, 0.35}
    local rockDark = {0.25, 0.23, 0.20}
    local goldColor = {0.95, 0.80, 0.20}
    local goldBright = {1.0, 0.90, 0.40}
    local woodColor = {0.50, 0.38, 0.25}
    local woodDark = {0.38, 0.28, 0.18}
    local caveColor = {0.08, 0.06, 0.04}
    
    -- === ROCKY MOUNTAIN BASE (using octagonal shapes) ===
    local rockWallColors = {
        {rockRight[1], rockRight[2], rockRight[3]},
        {rockTop[1]*0.9, rockTop[2]*0.9, rockTop[3]*0.9},
        {rockLeft[1], rockLeft[2], rockLeft[3]},
        {rockTop[1]*0.85, rockTop[2]*0.85, rockTop[3]*0.85},
    }

    -- Back peak (tallest) - octagonal
    local backR = 14*scale
    local backCX, backCY = 4*scale, -11*scale
    isoOctagonalPrism(backCX, backCY, 0, backR, 42*scale, originX, originY, rockTop, rockWallColors)

    -- Left outcrop - octagonal
    local leftR = 10*scale
    local leftCX, leftCY = -14*scale, 1*scale
    isoOctagonalPrism(leftCX, leftCY, 0, leftR, 28*scale, originX, originY, rockTop, rockWallColors)

    -- Right outcrop - octagonal
    local rightR = 10*scale
    local rightCX, rightCY = 18*scale, -2*scale
    isoOctagonalPrism(rightCX, rightCY, 0, rightR, 32*scale, originX, originY, rockTop, rockWallColors)

    -- Front lower rocks - wider octagonal
    local frontR = 18*scale
    local frontCX, frontCY = 0, 14*scale
    isoOctagonalPrism(frontCX, frontCY, 0, frontR, 18*scale, originX, originY, rockTop, rockWallColors)

    -- Additional rock detail left (keep as box for variety)
    isoBox(-20*scale, -2*scale, 0, 14*scale, 10*scale, 16*scale, originX, originY,
           {rockTop[1]*0.95, rockTop[2]*0.95, rockTop[3]*0.95}, rockLeft, rockRight)

    -- Additional rock detail right (keep as box for variety)
    isoBox(14*scale, 4*scale, 0, 10*scale, 14*scale, 14*scale, originX, originY,
           {rockTop[1]*0.92, rockTop[2]*0.92, rockTop[3]*0.92}, rockLeft, rockRight)
    
    -- Front face Y for details (front of front rocks)
    local frontFaceY = frontCY + frontR

    -- Rock cracks/texture
    love.graphics.setColor(rockDark[1], rockDark[2], rockDark[3], 0.5)
    love.graphics.setLineWidth(1)

    local c1x1, c1y1 = isoProject(-6*scale, frontFaceY, 6*scale, originX, originY)
    local c1x2, c1y2 = isoProject(4*scale, frontFaceY, 12*scale, originX, originY)
    love.graphics.line(c1x1, c1y1, c1x2, c1y2)

    local c2x1, c2y1 = isoProject(8*scale, frontFaceY, 4*scale, originX, originY)
    local c2x2, c2y2 = isoProject(14*scale, frontFaceY, 10*scale, originX, originY)
    love.graphics.line(c2x1, c2y1, c2x2, c2y2)

    -- === GOLD VEINS (if not depleted) ===
    if not self.depleted then
        local time = self.animTimer or 0
        local shimmer = 0.85 + math.sin(time * 3) * 0.15

        love.graphics.setColor(goldColor[1] * shimmer, goldColor[2] * shimmer, goldColor[3], 1)
        love.graphics.setLineWidth(2)

        -- Vein 1 on front
        local v1x1, v1y1 = isoProject(-10*scale, frontFaceY, 6*scale, originX, originY)
        local v1x2, v1y2 = isoProject(0*scale, frontFaceY, 10*scale, originX, originY)
        love.graphics.line(v1x1, v1y1, v1x2, v1y2)

        -- Vein 2 on front
        local v2x1, v2y1 = isoProject(6*scale, frontFaceY, 5*scale, originX, originY)
        local v2x2, v2y2 = isoProject(14*scale, frontFaceY, 9*scale, originX, originY)
        love.graphics.line(v2x1, v2y1, v2x2, v2y2)

        -- Vein on right face (on right outcrop)
        local rightFaceX = rightCX + rightR
        local v3x1, v3y1 = isoProject(rightFaceX, rightCY - 4*scale, 14*scale, originX, originY)
        local v3x2, v3y2 = isoProject(rightFaceX, rightCY + 4*scale, 18*scale, originX, originY)
        love.graphics.line(v3x1, v3y1, v3x2, v3y2)

        love.graphics.setLineWidth(1)

        -- Gold nugget highlights
        love.graphics.setColor(goldBright[1], goldBright[2], goldBright[3], shimmer)
        local n1x, n1y = isoProject(-4*scale, frontFaceY, 8*scale, originX, originY)
        love.graphics.circle("fill", n1x, n1y, 2.5)

        local n2x, n2y = isoProject(10*scale, frontFaceY, 7*scale, originX, originY)
        love.graphics.circle("fill", n2x, n2y, 2)

        local n3x, n3y = isoProject(rightFaceX, rightCY, 16*scale, originX, originY)
        love.graphics.circle("fill", n3x, n3y, 2)

        -- Sparkles
        love.graphics.setColor(1, 1, 0.8, 0.6 + math.sin(time * 5) * 0.3)
        local sp1x, sp1y = isoProject(-6*scale, frontFaceY, 9*scale, originX, originY)
        love.graphics.circle("fill", sp1x, sp1y, 1)

        local sp2x, sp2y = isoProject(12*scale, frontFaceY, 8*scale, originX, originY)
        love.graphics.circle("fill", sp2x, sp2y, 1)
    end

    -- === CAVE ENTRANCE ===
    local caveX, caveY = -10*scale, frontFaceY
    local caveW, caveH = 18*scale, 16*scale
    
    -- Cave opening (dark)
    isoQuad(
        {caveX, caveY, 0},
        {caveX + caveW, caveY, 0},
        {caveX + caveW, caveY, caveH},
        {caveX, caveY, caveH},
        originX, originY, caveColor
    )
    
    -- Cave arch
    local archCX, archCY = isoProject(caveX + caveW/2, caveY, caveH, originX, originY)
    love.graphics.setColor(caveColor[1], caveColor[2], caveColor[3], 1)
    love.graphics.arc("fill", archCX, archCY, 7, math.pi, 2 * math.pi)
    
    -- === WOODEN SUPPORT BEAMS ===
    -- Left beam
    isoBox(caveX - 2*scale, caveY - 1, 0, 3*scale, 2*scale, caveH + 2*scale, originX, originY,
           woodColor, woodDark, woodColor)
    
    -- Right beam
    isoBox(caveX + caveW - 1*scale, caveY - 1, 0, 3*scale, 2*scale, caveH + 2*scale, originX, originY,
           woodColor, woodDark, woodColor)
    
    -- Top beam
    isoBox(caveX - 3*scale, caveY - 1, caveH, caveW + 6*scale, 3*scale, 3*scale, originX, originY,
           woodColor, woodDark, woodColor)
    
    -- === MINE CART TRACKS ===
    love.graphics.setColor(0.45, 0.42, 0.40, 1)
    local t1x1, t1y1 = isoProject(caveX + 3*scale, caveY + 1, 0.5, originX, originY)
    local t1x2, t1y2 = isoProject(caveX + 3*scale, caveY + 10*scale, 0.5, originX, originY)
    love.graphics.setLineWidth(2)
    love.graphics.line(t1x1, t1y1, t1x2, t1y2)
    
    local t2x1, t2y1 = isoProject(caveX + caveW - 3*scale, caveY + 1, 0.5, originX, originY)
    local t2x2, t2y2 = isoProject(caveX + caveW - 3*scale, caveY + 10*scale, 0.5, originX, originY)
    love.graphics.line(t2x1, t2y1, t2x2, t2y2)
    love.graphics.setLineWidth(1)
    
    -- Track ties
    love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
    for i = 0, 2 do
        local tieY = caveY + 2*scale + i * 3.5*scale
        local tx1, ty1 = isoProject(caveX + 2*scale, tieY, 0, originX, originY)
        local tx2, ty2 = isoProject(caveX + caveW - 2*scale, tieY, 0, originX, originY)
        love.graphics.setLineWidth(2)
        love.graphics.line(tx1, ty1, tx2, ty2)
    end
    love.graphics.setLineWidth(1)
    
    -- === LANTERN (if not depleted) ===
    if not self.depleted then
        local time = self.animTimer or 0
        local flicker = 0.8 + math.sin(time * 10) * 0.2
        
        -- Lantern hook
        love.graphics.setColor(woodDark[1], woodDark[2], woodDark[3], 1)
        local lhx, lhy = isoProject(caveX - 5*scale, caveY, caveH - 2*scale, originX, originY)
        love.graphics.rectangle("fill", lhx - 1, lhy, 2, 7)
        
        -- Lantern glow
        love.graphics.setColor(1, 0.7, 0.2, 0.3 * flicker)
        love.graphics.circle("fill", lhx, lhy + 9, 7)
        
        -- Lantern body
        love.graphics.setColor(1, 0.75, 0.25, flicker)
        love.graphics.circle("fill", lhx, lhy + 9, 3.5)
        
        -- Lantern core
        love.graphics.setColor(1, 0.9, 0.5, 1)
        love.graphics.circle("fill", lhx, lhy + 9, 1.5)
    end
    
    -- === PICKAXE ===
    if not self.depleted then
        local pax, pay = isoProject(20*scale, 18*scale, 0, originX, originY)
        
        -- Handle
        love.graphics.setColor(woodColor[1], woodColor[2], woodColor[3], 1)
        love.graphics.push()
        love.graphics.translate(pax, pay)
        love.graphics.rotate(-0.5)
        love.graphics.rectangle("fill", -1, -16, 2.5, 18)
        love.graphics.pop()
        
        -- Head
        love.graphics.setColor(0.50, 0.50, 0.55, 1)
        love.graphics.push()
        love.graphics.translate(pax, pay - 14)
        love.graphics.rotate(-0.5)
        love.graphics.polygon("fill", -7, 0, 0, -3, 7, 2, 0, 3)
        love.graphics.pop()
    end
end

function GoldMine:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function GoldMine:extractGold(amount)
    if self.depleted then return 0 end
    local extracted = math.min(amount, self.goldReserves)
    self.goldReserves = self.goldReserves - extracted
    if self.goldReserves <= 0 then
        self.depleted = true
        if self.onDepleted then
            self.onDepleted(self)
        end
    end
    return extracted
end

function GoldMine:updateUI(resources, screenW, screenH, font) end
function GoldMine:drawUI() end
function GoldMine:mousepressed(x, y, button) end
function GoldMine:mousereleased(x, y, button) end

function GoldMine:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(self.depleted and 0.4 or 1, self.depleted and 0.4 or 0.85, self.depleted and 0.4 or 0, 1)
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return GoldMine
