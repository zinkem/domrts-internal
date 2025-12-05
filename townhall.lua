--[[
    Town Hall
    Main building that produces peons
    Size: 3x3 tiles, grid-aligned, square collision
]]

local Button = require("button")

local TownHall = {}
TownHall.__index = TownHall

TownHall.GRID_SIZE = 3

function TownHall.new(params)
    local self = setmetatable({}, TownHall)
    
    -- Grid position (top-left tile)
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = TownHall.GRID_SIZE
    
    -- Map reference
    self.map = params.map
    
    -- Pixel dimensions
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "townhall"
    self.name = "Town Hall"
    
    -- Production
    self.isProducing = false
    self.productionTime = 5.0
    self.productionTimer = 0
    self.productionCost = 400
    
    -- Action button
    self.actionButton = nil
    
    -- Clear trees at location
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function TownHall:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function TownHall:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function TownHall:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function TownHall:update(dt)
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= self.productionTime then
            self.isProducing = false
            self.productionTimer = 0
            return true -- Peon ready
        end
    end
    return false
end

function TownHall:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Building base
    love.graphics.setColor(0.55, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", x, y, size, size, 6)
    
    -- Roof
    love.graphics.setColor(0.35, 0.2, 0.1, 1)
    love.graphics.polygon("fill", 
        x + size / 2, y - 20,
        x - 5, y + 20,
        x + size + 5, y + 20
    )
    
    -- Door
    love.graphics.setColor(0.25, 0.15, 0.08, 1)
    love.graphics.rectangle("fill", x + size/2 - 13, y + size - 41, 26, 41)
    
    -- Windows
    love.graphics.setColor(0.6, 0.8, 1, 0.8)
    love.graphics.rectangle("fill", x + 15, y + 30, 20, 20)
    love.graphics.rectangle("fill", x + size - 35, y + 30, 20, 20)
    
    -- Border
    love.graphics.setColor(0.25, 0.15, 0.08, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, size, size, 6)
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 8)
    end
    
    -- Production bar
    if self.isProducing then
        local barW = size - 10
        local progress = self.productionTimer / self.productionTime
        
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.2, 0.8, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Square collision check (screen coordinates)
function TownHall:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function TownHall:startProduction()
    if not self.isProducing then
        self.isProducing = true
        self.productionTimer = 0
        return true
    end
    return false
end

function TownHall:canProduce()
    return not self.isProducing
end

function TownHall:getProductionProgress()
    if self.isProducing then
        return math.floor((self.productionTimer / self.productionTime) * 100)
    end
    return 0
end

-- Returns spawn position in world pixels
function TownHall:getSpawnPos()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize + 16, wy + self.pixelSize / 2
end

-- UI Methods
function TownHall:updateUI(resources, screenW, screenH, font)
    if self.selected then
        local panelX = screenW - 180
        
        if not self.actionButton then
            self.actionButton = Button.new({
                x = panelX + 10,
                y = screenH - 80,
                width = 150,
                height = 40,
                text = "Train Peon (400g)",
                font = font,
                onClick = function()
                    if resources.gold >= self.productionCost and self:canProduce() then
                        if self:startProduction() then
                            resources.gold = resources.gold - self.productionCost
                        end
                    end
                end
            })
        end
        
        self.actionButton:setEnabled(resources.gold >= self.productionCost and self:canProduce())
        self.actionButton:update(0)
    else
        self.actionButton = nil
    end
end

function TownHall:drawUI()
    if self.selected and self.actionButton then
        self.actionButton:draw()
    end
end

function TownHall:mousepressed(x, y, button)
    if self.actionButton then
        self.actionButton:mousepressed(x, y, button)
    end
end

function TownHall:mousereleased(x, y, button)
    if self.actionButton then
        self.actionButton:mousereleased(x, y, button)
    end
end

-- Minimap drawing
function TownHall:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.6, 0.4, 0.2, 1)
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return TownHall
