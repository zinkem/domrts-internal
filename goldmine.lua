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
    
    -- Grid position (top-left tile)
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = GoldMine.GRID_SIZE
    
    -- Map reference
    self.map = params.map
    
    -- Pixel dimensions
    self.pixelSize = self.gridSize * 32
    
    self.goldReserves = params.gold or 100000
    self.maxGold = self.goldReserves
    self.selected = false
    self.depleted = false
    self.type = "goldmine"
    self.name = "Gold Mine"
    
    -- Clear trees at location
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

function GoldMine:update(dt)
    if self.goldReserves <= 0 then
        self.depleted = true
    end
end

function GoldMine:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Mine base
    if self.depleted then
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
    else
        love.graphics.setColor(0.45, 0.35, 0.25, 1)
    end
    love.graphics.rectangle("fill", x, y, size, size, 4)
    
    -- Gold veins
    if not self.depleted then
        love.graphics.setColor(0.9, 0.75, 0.1, 1)
        love.graphics.rectangle("fill", x + 8, y + 8, 24, 18, 2)
        love.graphics.rectangle("fill", x + size - 34, y + 22, 22, 16, 2)
        love.graphics.rectangle("fill", x + 12, y + size - 34, 28, 20, 2)
        love.graphics.rectangle("fill", x + size - 32, y + size - 30, 20, 18, 2)
    end
    
    -- Cave entrance
    love.graphics.setColor(0.1, 0.08, 0.05, 1)
    love.graphics.rectangle("fill", x + size/2 - 18, y + size/2 - 5, 36, size/2 + 5, 3)
    
    -- Border
    love.graphics.setColor(0.25, 0.2, 0.1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, size, size, 4)
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 6)
    end
    
    -- Gold amount
    love.graphics.setColor(1, 0.85, 0, 1)
    local goldText = tostring(self.goldReserves)
    local font = love.graphics.getFont()
    local textW = font:getWidth(goldText)
    love.graphics.print(goldText, x + (size - textW) / 2, y - 18)
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Square collision check (screen coordinates)
function GoldMine:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function GoldMine:extractGold(amount)
    if self.depleted then
        return 0
    end
    local extracted = math.min(amount, self.goldReserves)
    self.goldReserves = self.goldReserves - extracted
    if self.goldReserves <= 0 then
        self.depleted = true
    end
    return extracted
end

-- UI Methods (no actions for gold mine)
function GoldMine:updateUI(resources, screenW, screenH, font)
end

function GoldMine:drawUI()
end

function GoldMine:mousepressed(x, y, button)
end

function GoldMine:mousereleased(x, y, button)
end

-- Minimap drawing
function GoldMine:drawOnMinimap(mapX, mapY, scale)
    if self.depleted then
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
    else
        love.graphics.setColor(1, 0.85, 0, 1)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return GoldMine
