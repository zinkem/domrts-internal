--[[
    Farm
    Provides unit capacity (+4 units per farm)
    Size: 2x2 tiles, grid-aligned
]]

local Farm = {}
Farm.__index = Farm

Farm.GRID_SIZE = 2
Farm.COST_GOLD = 250
Farm.COST_LUMBER = 50
Farm.BUILD_TIME = 10.0
Farm.CAPACITY_BONUS = 4

function Farm.new(params)
    local self = setmetatable({}, Farm)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = Farm.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "farm"
    self.name = "Farm"
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = Farm.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function Farm:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function Farm:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function Farm:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function Farm:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function Farm:update(dt)
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return true
        end
    end
    return false
end

function Farm:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        love.graphics.setColor(0.4, 0.3, 0.2, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
    else
        love.graphics.setColor(0.45, 0.55, 0.25, 1)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        
        love.graphics.setColor(0.6, 0.7, 0.3, 1)
        for row = 0, 3 do
            love.graphics.rectangle("fill", x + 4, y + 8 + row * 14, size - 8, 8, 2)
        end
        
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x, y, 4, size)
        love.graphics.rectangle("fill", x + size - 4, y, 4, size)
        love.graphics.rectangle("fill", x, y, size, 4)
        love.graphics.rectangle("fill", x, y + size - 4, size, 4)
    end
    
    love.graphics.setColor(0.3, 0.25, 0.15, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, size, size, 4)
    
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 6)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Farm:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function Farm:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function Farm:updateUI(resources, screenW, screenH, font) end
function Farm:drawUI() end
function Farm:mousepressed(x, y, button) end
function Farm:mousereleased(x, y, button) end

function Farm:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        love.graphics.setColor(0.5, 0.6, 0.3, 1)
    else
        love.graphics.setColor(0.4, 0.4, 0.3, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return Farm
