--[[
    Gold Mine
    Resource node that peons harvest gold from
    Size: 3x3 tiles, grid-aligned, square collision
]]

local GoldMine = {}
GoldMine.__index = GoldMine

GoldMine.GRID_SIZE = 3

function GoldMine.new(params)
    local self = setmetatable({}, GoldMine)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = GoldMine.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.goldReserves = params.gold or 12500  -- About 1,250 harvests at 10 gold each
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
    if self.goldReserves <= 0 then
        self.depleted = true
    end
end

function GoldMine:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x + size/2, y + size + 3, size/2 - 5, 6)
    
    -- Rocky mountain/hill base
    if self.depleted then
        love.graphics.setColor(0.35, 0.33, 0.3, 1)
    else
        love.graphics.setColor(0.45, 0.4, 0.32, 1)
    end
    
    -- Main rocky formation
    love.graphics.polygon("fill",
        x + 5, y + size,
        x, y + size - 20,
        x + 10, y + 15,
        x + 25, y + 5,
        x + size/2, y,
        x + size - 25, y + 5,
        x + size - 10, y + 15,
        x + size, y + size - 20,
        x + size - 5, y + size
    )
    
    -- Rock texture/layers
    love.graphics.setColor(0.4, 0.36, 0.28, 1)
    love.graphics.polygon("fill", x + 15, y + 20, x + 35, y + 12, x + 50, y + 18, x + 40, y + 30, x + 20, y + 28)
    love.graphics.polygon("fill", x + size - 45, y + 25, x + size - 25, y + 15, x + size - 10, y + 25, x + size - 20, y + 35)
    love.graphics.polygon("fill", x + 10, y + 50, x + 30, y + 45, x + 25, y + 60, x + 8, y + 58)
    love.graphics.polygon("fill", x + size - 35, y + 55, x + size - 15, y + 48, x + size - 12, y + 62, x + size - 30, y + 65)
    
    -- Gold veins (if not depleted)
    if not self.depleted then
        love.graphics.setColor(0.9, 0.75, 0.15, 1)
        -- Gold vein streaks
        love.graphics.setLineWidth(3)
        love.graphics.line(x + 18, y + 22, x + 28, y + 18)
        love.graphics.line(x + 22, y + 26, x + 30, y + 28)
        love.graphics.line(x + size - 30, y + 20, x + size - 18, y + 25)
        love.graphics.line(x + 12, y + 55, x + 22, y + 52)
        love.graphics.line(x + size - 28, y + 58, x + size - 18, y + 55)
        
        -- Gold nugget highlights
        love.graphics.setColor(1, 0.85, 0.2, 1)
        love.graphics.circle("fill", x + 25, y + 20, 3)
        love.graphics.circle("fill", x + size - 22, y + 22, 2)
        love.graphics.circle("fill", x + 18, y + 53, 2)
        love.graphics.circle("fill", x + size - 22, y + 56, 3)
    end
    
    -- Mine entrance (dark cave opening)
    love.graphics.setColor(0.08, 0.06, 0.04, 1)
    love.graphics.rectangle("fill", x + size/2 - 20, y + size/2, 40, size/2)
    love.graphics.arc("fill", x + size/2, y + size/2, 20, math.pi, 2 * math.pi)
    
    -- Wooden support beams
    love.graphics.setColor(0.5, 0.35, 0.2, 1)
    -- Left beam
    love.graphics.polygon("fill", x + size/2 - 22, y + size/2 - 5, x + size/2 - 18, y + size/2 - 5, 
                                   x + size/2 - 18, y + size, x + size/2 - 24, y + size)
    -- Right beam
    love.graphics.polygon("fill", x + size/2 + 18, y + size/2 - 5, x + size/2 + 22, y + size/2 - 5,
                                   x + size/2 + 24, y + size, x + size/2 + 18, y + size)
    -- Top beam
    love.graphics.rectangle("fill", x + size/2 - 24, y + size/2 - 10, 48, 8, 2)
    
    -- Beam details
    love.graphics.setColor(0.4, 0.28, 0.15, 1)
    love.graphics.line(x + size/2 - 20, y + size/2 + 10, x + size/2 - 20, y + size - 5)
    love.graphics.line(x + size/2 + 20, y + size/2 + 10, x + size/2 + 20, y + size - 5)
    
    -- Mine cart track rails
    love.graphics.setColor(0.4, 0.38, 0.35, 1)
    love.graphics.rectangle("fill", x + size/2 - 15, y + size - 8, 30, 3)
    love.graphics.setColor(0.5, 0.45, 0.4, 1)
    love.graphics.rectangle("fill", x + size/2 - 12, y + size - 6, 4, 6)
    love.graphics.rectangle("fill", x + size/2 + 8, y + size - 6, 4, 6)
    
    -- Lantern/torch by entrance
    if not self.depleted then
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + size/2 - 28, y + size/2 + 5, 3, 15)
        love.graphics.setColor(1, 0.7, 0.2, 0.9)
        love.graphics.circle("fill", x + size/2 - 27, y + size/2 + 3, 5)
        love.graphics.setColor(1, 0.85, 0.4, 0.4)
        love.graphics.circle("fill", x + size/2 - 27, y + size/2 + 3, 8)
    end
    
    -- Pick axe leaning against entrance (if not depleted)
    if not self.depleted then
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + size/2 + 25, y + size/2 + 15, 3, 25, 1)
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.polygon("fill", x + size/2 + 22, y + size/2 + 12, x + size/2 + 34, y + size/2 + 8,
                                       x + size/2 + 30, y + size/2 + 18)
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
        
        -- Gold reserves display (only when selected)
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
        -- Notify callback if set (used by gameplay to update navGrid)
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
