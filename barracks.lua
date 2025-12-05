--[[
    Barracks
    Military building that produces footmen
    Size: 3x3 tiles, grid-aligned
]]

local Button = require("button")

local Barracks = {}
Barracks.__index = Barracks

Barracks.GRID_SIZE = 3
Barracks.COST_GOLD = 400
Barracks.COST_LUMBER = 100
Barracks.BUILD_TIME = 15.0
Barracks.FOOTMAN_COST = 135
Barracks.FOOTMAN_TIME = 8.0

function Barracks.new(params)
    local self = setmetatable({}, Barracks)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = Barracks.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "barracks"
    self.name = "Barracks"
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = Barracks.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    self.isProducing = false
    self.productionTimer = 0
    self.actionButton = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function Barracks:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function Barracks:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function Barracks:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function Barracks:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function Barracks:getSpawnPos()
    local wx, wy = self:getWorldPos()
    -- Spawn far enough from building edge (pixelSize + radius + buffer)
    return wx + self.pixelSize + 20, wy + self.pixelSize / 2
end

function Barracks:update(dt)
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return false, true -- no footman, build complete
        end
        return false, false
    end
    
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= Barracks.FOOTMAN_TIME then
            self.isProducing = false
            self.productionTimer = 0
            return true, false -- footman ready
        end
    end
    return false, false
end

function Barracks:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        love.graphics.setColor(0.4, 0.3, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
    else
        love.graphics.setColor(0.5, 0.4, 0.35, 1)
        love.graphics.rectangle("fill", x, y, size, size, 6)
        
        love.graphics.setColor(0.35, 0.25, 0.2, 1)
        love.graphics.polygon("fill", x + size/2, y - 15, x - 3, y + 25, x + size + 3, y + 25)
        
        love.graphics.setColor(0.25, 0.18, 0.12, 1)
        love.graphics.rectangle("fill", x + size/2 - 18, y + size - 50, 36, 50)
        
        love.graphics.setColor(0.7, 0.7, 0.75, 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(x + size/2 - 15, y + 35, x + size/2 + 15, y + 55)
        love.graphics.line(x + size/2 + 15, y + 35, x + size/2 - 15, y + 55)
        
        love.graphics.setColor(0.6, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", x + size/2 - 8, y + 38, 16, 20, 3)
    end
    
    love.graphics.setColor(0.25, 0.18, 0.12, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, size, size, 6)
    
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 8)
    end
    
    if self.completed and self.isProducing then
        local barW = size - 10
        local progress = self.productionTimer / Barracks.FOOTMAN_TIME
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.8, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Barracks:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function Barracks:startProduction()
    if self.completed and not self.isProducing then
        self.isProducing = true
        self.productionTimer = 0
        return true
    end
    return false
end

function Barracks:canProduce()
    return self.completed and not self.isProducing
end

function Barracks:getProductionProgress()
    if self.isProducing then
        return math.floor((self.productionTimer / Barracks.FOOTMAN_TIME) * 100)
    end
    return 0
end

function Barracks:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function Barracks:updateUI(resources, screenW, screenH, font, currentPop, maxPop)
    currentPop = currentPop or 0
    maxPop = maxPop or 999
    self.currentPop = currentPop
    self.maxPop = maxPop
    
    if self.selected and self.completed then
        local panelX = screenW - 180
        local buttonY = 70 + 145
        
        if not self.actionButton then
            local selfRef = self
            self.actionButton = Button.new({
                x = panelX + 10,
                y = buttonY,
                width = 150,
                height = 40,
                text = "Train Footman (135g)",
                font = font,
                colors = {
                    normal = {0.5, 0.3, 0.3, 1},
                    hover = {0.6, 0.4, 0.4, 1},
                    pressed = {0.4, 0.2, 0.2, 1},
                    text = {1, 1, 1, 1},
                    border = {0.4, 0.2, 0.2, 1}
                },
                onClick = function()
                    if resources.gold >= Barracks.FOOTMAN_COST and 
                       selfRef:canProduce() and 
                       selfRef.currentPop < selfRef.maxPop then
                        if selfRef:startProduction() then
                            resources.gold = resources.gold - Barracks.FOOTMAN_COST
                        end
                    end
                end
            })
        end
        
        self.actionButton:setEnabled(resources.gold >= Barracks.FOOTMAN_COST and currentPop < maxPop and self:canProduce())
        self.actionButton:update(0)
    else
        self.actionButton = nil
    end
end

function Barracks:drawUI()
    if self.selected and self.completed and self.actionButton then
        self.actionButton:draw()
        
        if self.currentPop >= self.maxPop then
            local screenW = love.graphics.getWidth()
            love.graphics.setColor(1, 0.4, 0.4, 1)
            love.graphics.setFont(Game.fonts.small)
            love.graphics.print("Need more farms!", screenW - 170, 70 + 190)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function Barracks:mousepressed(x, y, button)
    if self.actionButton then self.actionButton:mousepressed(x, y, button) end
end

function Barracks:mousereleased(x, y, button)
    if self.actionButton then self.actionButton:mousereleased(x, y, button) end
end

function Barracks:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(self.completed and 0.6 or 0.4, 0.3, 0.3, self.completed and 1 or 0.6)
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return Barracks
