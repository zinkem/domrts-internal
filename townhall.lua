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
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = TownHall.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "townhall"
    self.name = "Town Hall"
    
    self.isProducing = false
    self.productionTime = 5.0
    self.productionTimer = 0
    self.productionCost = 400
    self.actionButton = nil
    
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

function TownHall:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function TownHall:update(dt)
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= self.productionTime then
            self.isProducing = false
            self.productionTimer = 0
            return true
        end
    end
    return false
end

function TownHall:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x + size/2, y + size + 5, size/2 - 5, 8)
    
    -- Main castle base (stone walls)
    love.graphics.setColor(0.45, 0.42, 0.38, 1)
    love.graphics.rectangle("fill", x + 8, y + 20, size - 16, size - 20, 2)
    
    -- Stone texture pattern
    love.graphics.setColor(0.4, 0.37, 0.33, 1)
    for row = 0, 4 do
        for col = 0, 3 do
            local offsetX = (row % 2) * 12
            love.graphics.rectangle("fill", x + 12 + col * 20 + offsetX, y + 25 + row * 14, 16, 10, 1)
        end
    end
    
    -- Left tower
    love.graphics.setColor(0.5, 0.47, 0.42, 1)
    love.graphics.rectangle("fill", x, y + 10, 24, size - 10, 2)
    -- Tower battlements
    love.graphics.setColor(0.45, 0.42, 0.38, 1)
    for i = 0, 2 do
        love.graphics.rectangle("fill", x + i * 9, y + 2, 6, 12)
    end
    -- Tower window
    love.graphics.setColor(0.2, 0.25, 0.35, 1)
    love.graphics.rectangle("fill", x + 8, y + 30, 8, 12, 1)
    love.graphics.setColor(0.6, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", x + 11, y + 30, 2, 12)
    
    -- Right tower  
    love.graphics.setColor(0.5, 0.47, 0.42, 1)
    love.graphics.rectangle("fill", x + size - 24, y + 10, 24, size - 10, 2)
    -- Tower battlements
    love.graphics.setColor(0.45, 0.42, 0.38, 1)
    for i = 0, 2 do
        love.graphics.rectangle("fill", x + size - 24 + i * 9, y + 2, 6, 12)
    end
    -- Tower window
    love.graphics.setColor(0.2, 0.25, 0.35, 1)
    love.graphics.rectangle("fill", x + size - 16, y + 30, 8, 12, 1)
    love.graphics.setColor(0.6, 0.5, 0.3, 1)
    love.graphics.rectangle("fill", x + size - 13, y + 30, 2, 12)
    
    -- Center battlements
    love.graphics.setColor(0.48, 0.45, 0.4, 1)
    for i = 0, 4 do
        love.graphics.rectangle("fill", x + 28 + i * 9, y + 12, 6, 10)
    end
    
    -- Main entrance arch
    love.graphics.setColor(0.15, 0.12, 0.08, 1)
    love.graphics.rectangle("fill", x + size/2 - 14, y + size - 45, 28, 45)
    love.graphics.arc("fill", x + size/2, y + size - 45, 14, math.pi, 2 * math.pi)
    
    -- Wooden door
    love.graphics.setColor(0.4, 0.28, 0.15, 1)
    love.graphics.rectangle("fill", x + size/2 - 12, y + size - 40, 24, 40)
    -- Door details
    love.graphics.setColor(0.3, 0.2, 0.1, 1)
    love.graphics.rectangle("fill", x + size/2 - 1, y + size - 40, 2, 40)
    -- Door hinges/studs
    love.graphics.setColor(0.35, 0.3, 0.25, 1)
    love.graphics.circle("fill", x + size/2 - 8, y + size - 30, 2)
    love.graphics.circle("fill", x + size/2 + 8, y + size - 30, 2)
    love.graphics.circle("fill", x + size/2 - 8, y + size - 15, 2)
    love.graphics.circle("fill", x + size/2 + 8, y + size - 15, 2)
    
    -- Banner/flag on center
    love.graphics.setColor(0.5, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", x + size/2 - 1, y - 15, 2, 25)
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.polygon("fill", 
        x + size/2 + 1, y - 15,
        x + size/2 + 16, y - 8,
        x + size/2 + 1, y
    )
    love.graphics.setColor(0.9, 0.8, 0.2, 1)
    love.graphics.circle("fill", x + size/2 + 8, y - 8, 3)
    
    -- Torch lights
    love.graphics.setColor(1, 0.7, 0.3, 0.8)
    love.graphics.circle("fill", x + 12, y + 55, 4)
    love.graphics.circle("fill", x + size - 12, y + 55, 4)
    love.graphics.setColor(1, 0.9, 0.5, 0.4)
    love.graphics.circle("fill", x + 12, y + 55, 7)
    love.graphics.circle("fill", x + size - 12, y + 55, 7)
    
    -- Selection highlight
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
    end
    
    -- Production progress bar
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

function TownHall:getSpawnPos()
    local wx, wy = self:getWorldPos()
    -- Spawn far enough from building edge (pixelSize + radius + buffer)
    return wx + self.pixelSize + 20, wy + self.pixelSize / 2
end

function TownHall:updateUI(resources, screenW, screenH, font, currentPop, maxPop)
    currentPop = currentPop or 0
    maxPop = maxPop or 999
    self.currentPop = currentPop
    self.maxPop = maxPop
    
    if self.selected then
        local panelX = screenW - 180
        local buttonY = 70 + 145
        
        if not self.actionButton then
            local selfRef = self
            self.actionButton = Button.new({
                x = panelX + 10,
                y = buttonY,
                width = 150,
                height = 40,
                text = "Train Peon (400g)",
                font = font,
                onClick = function()
                    if resources.gold >= selfRef.productionCost and 
                       selfRef:canProduce() and 
                       selfRef.currentPop < selfRef.maxPop then
                        if selfRef:startProduction() then
                            resources.gold = resources.gold - selfRef.productionCost
                        end
                    end
                end
            })
        end
        
        local canAfford = resources.gold >= self.productionCost
        local hasCapacity = currentPop < maxPop
        self.actionButton:setEnabled(canAfford and hasCapacity and self:canProduce())
        self.actionButton:update(0)
    else
        self.actionButton = nil
    end
end

function TownHall:drawUI()
    if self.selected and self.actionButton then
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

function TownHall:mousepressed(x, y, button)
    if self.actionButton then self.actionButton:mousepressed(x, y, button) end
end

function TownHall:mousereleased(x, y, button)
    if self.actionButton then self.actionButton:mousereleased(x, y, button) end
end

function TownHall:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.6, 0.4, 0.2, 1)
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return TownHall
