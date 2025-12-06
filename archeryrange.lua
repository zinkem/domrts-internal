--[[
    Archery Range
    Military building that produces archers
    Size: 3x3 tiles, grid-aligned
    Requires: Barracks
]]

local Button = require("button")

local ArcheryRange = {}
ArcheryRange.__index = ArcheryRange

ArcheryRange.GRID_SIZE = 3
ArcheryRange.COST_GOLD = 500
ArcheryRange.COST_LUMBER = 150
ArcheryRange.BUILD_TIME = 18.0
ArcheryRange.ARCHER_COST_GOLD = 150
ArcheryRange.ARCHER_COST_LUMBER = 50
ArcheryRange.ARCHER_TIME = 10.0

function ArcheryRange.new(params)
    local self = setmetatable({}, ArcheryRange)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = ArcheryRange.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "archeryrange"
    self.name = "Archery Range"
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = ArcheryRange.BUILD_TIME
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

function ArcheryRange:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function ArcheryRange:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function ArcheryRange:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function ArcheryRange:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function ArcheryRange:getSpawnPos()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize + 20, wy + self.pixelSize / 2
end

function ArcheryRange:update(dt)
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return false, true  -- no archer, build complete
        end
        return false, false
    end
    
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= ArcheryRange.ARCHER_TIME then
            self.isProducing = false
            self.productionTimer = 0
            return true, false  -- archer ready
        end
    end
    return false, false
end

function ArcheryRange:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction scaffolding
        love.graphics.setColor(0.5, 0.45, 0.35, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.35, 0.8)
        -- Scaffolding poles
        love.graphics.rectangle("fill", x + 5, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + size - 9, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 2, size - 10, 4)
        
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
    else
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.ellipse("fill", x + size/2, y + size + 3, size/2 - 5, 6)
        
        -- Ground/training area (packed dirt)
        love.graphics.setColor(0.45, 0.38, 0.28, 1)
        love.graphics.rectangle("fill", x + 5, y + 35, size - 10, size - 40, 2)
        
        -- Main structure (wooden, open-air)
        love.graphics.setColor(0.5, 0.4, 0.28, 1)
        love.graphics.rectangle("fill", x + 5, y + 20, size - 10, 20, 2)
        
        -- Support pillars
        love.graphics.setColor(0.45, 0.35, 0.22, 1)
        love.graphics.rectangle("fill", x + 8, y + 15, 8, 25)
        love.graphics.rectangle("fill", x + size - 16, y + 15, 8, 25)
        love.graphics.rectangle("fill", x + size/2 - 4, y + 15, 8, 25)
        
        -- Roof (long wooden cover)
        love.graphics.setColor(0.42, 0.32, 0.2, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 5,
            x - 5, y + 22,
            x + size + 5, y + 22
        )
        -- Roof highlight
        love.graphics.setColor(0.5, 0.4, 0.28, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 5,
            x + size/2 - 35, y + 18,
            x + size/2, y + 14
        )
        
        -- Target boards (multiple)
        for i = 0, 2 do
            local tx = x + 15 + i * 30
            -- Target stand
            love.graphics.setColor(0.5, 0.4, 0.25, 1)
            love.graphics.rectangle("fill", tx + 6, y + 45, 3, 35)
            love.graphics.rectangle("fill", tx, y + 75, 15, 3)
            -- Target circle
            love.graphics.setColor(0.9, 0.85, 0.7, 1)
            love.graphics.circle("fill", tx + 7, y + 52, 10)
            love.graphics.setColor(0.8, 0.2, 0.2, 1)
            love.graphics.circle("fill", tx + 7, y + 52, 7)
            love.graphics.setColor(0.9, 0.85, 0.7, 1)
            love.graphics.circle("fill", tx + 7, y + 52, 4)
            love.graphics.setColor(0.8, 0.2, 0.2, 1)
            love.graphics.circle("fill", tx + 7, y + 52, 2)
            -- Arrow in target
            love.graphics.setColor(0.5, 0.4, 0.25, 1)
            love.graphics.line(tx + 5 + i, y + 50 + i, tx + 5 + i, y + 43)
            love.graphics.setColor(0.6, 0.6, 0.65, 1)
            love.graphics.polygon("fill", tx + 4 + i, y + 43, tx + 6 + i, y + 43, tx + 5 + i, y + 40)
        end
        
        -- Bow rack
        love.graphics.setColor(0.5, 0.38, 0.22, 1)
        love.graphics.rectangle("fill", x + 8, y + 42, 3, 40)
        -- Bows on rack
        love.graphics.setColor(0.55, 0.4, 0.2, 1)
        for i = 0, 2 do
            love.graphics.arc("line", x + 8, y + 48 + i * 12, 8, math.pi * 0.5, math.pi * 1.5, 6)
        end
        
        -- Arrow quiver
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + size - 20, y + 45, 10, 25, 2)
        -- Arrows sticking out
        love.graphics.setColor(0.6, 0.5, 0.3, 1)
        love.graphics.line(x + size - 18, y + 42, x + size - 18, y + 35)
        love.graphics.line(x + size - 15, y + 43, x + size - 15, y + 38)
        love.graphics.line(x + size - 12, y + 42, x + size - 12, y + 36)
        -- Arrowheads
        love.graphics.setColor(0.6, 0.6, 0.65, 1)
        love.graphics.polygon("fill", x + size - 19, y + 35, x + size - 17, y + 35, x + size - 18, y + 32)
        love.graphics.polygon("fill", x + size - 16, y + 38, x + size - 14, y + 38, x + size - 15, y + 35)
        love.graphics.polygon("fill", x + size - 13, y + 36, x + size - 11, y + 36, x + size - 12, y + 33)
        
        -- Banner with bow emblem
        love.graphics.setColor(0.2, 0.5, 0.25, 1)
        love.graphics.polygon("fill",
            x + size/2 - 2, y + 5,
            x + size/2 + 15, y + 8,
            x + size/2 + 12, y + 18,
            x + size/2 - 2, y + 15
        )
        -- Bow symbol on banner
        love.graphics.setColor(0.9, 0.85, 0.5, 1)
        love.graphics.arc("line", x + size/2 + 6, y + 12, 4, math.pi * 0.6, math.pi * 1.4, 5)
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
    end
    
    -- Production progress bar
    if self.completed and self.isProducing then
        local barW = size - 10
        local progress = self.productionTimer / ArcheryRange.ARCHER_TIME
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.3, 0.7, 0.4, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function ArcheryRange:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function ArcheryRange:startProduction()
    if self.completed and not self.isProducing then
        self.isProducing = true
        self.productionTimer = 0
        return true
    end
    return false
end

function ArcheryRange:canProduce()
    return self.completed and not self.isProducing
end

function ArcheryRange:getProductionProgress()
    if self.isProducing then
        return math.floor((self.productionTimer / ArcheryRange.ARCHER_TIME) * 100)
    end
    return 0
end

function ArcheryRange:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function ArcheryRange:updateUI(resources, screenW, screenH, font, currentPop, maxPop)
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
                text = "Train Archer",
                font = font,
                colors = {
                    normal = {0.3, 0.5, 0.35, 1},
                    hover = {0.4, 0.6, 0.45, 1},
                    pressed = {0.2, 0.4, 0.25, 1},
                    text = {1, 1, 1, 1},
                    border = {0.2, 0.4, 0.25, 1}
                },
                onClick = function()
                    if resources.gold >= ArcheryRange.ARCHER_COST_GOLD and
                       resources.lumber >= ArcheryRange.ARCHER_COST_LUMBER and
                       selfRef:canProduce() and 
                       selfRef.currentPop < selfRef.maxPop then
                        if selfRef:startProduction() then
                            resources.gold = resources.gold - ArcheryRange.ARCHER_COST_GOLD
                            resources.lumber = resources.lumber - ArcheryRange.ARCHER_COST_LUMBER
                        end
                    end
                end
            })
        end
        
        local costText = string.format("Archer (%dg %dL)", ArcheryRange.ARCHER_COST_GOLD, ArcheryRange.ARCHER_COST_LUMBER)
        self.actionButton:setText(costText)
        
        local canAfford = resources.gold >= ArcheryRange.ARCHER_COST_GOLD and 
                         resources.lumber >= ArcheryRange.ARCHER_COST_LUMBER
        self.actionButton:setEnabled(canAfford and currentPop < maxPop and self:canProduce())
        self.actionButton:update(0)
    else
        self.actionButton = nil
    end
end

function ArcheryRange:drawUI()
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

function ArcheryRange:mousepressed(x, y, button)
    if self.actionButton then self.actionButton:mousepressed(x, y, button) end
end

function ArcheryRange:mousereleased(x, y, button)
    if self.actionButton then self.actionButton:mousereleased(x, y, button) end
end

function ArcheryRange:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(self.completed and 0.3 or 0.25, self.completed and 0.55 or 0.4, self.completed and 0.35 or 0.28, self.completed and 1 or 0.6)
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return ArcheryRange
