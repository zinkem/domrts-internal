--[[
    Town Hall
    Main building that can produce peons
]]

local TownHall = {}
TownHall.__index = TownHall

function TownHall.new(params)
    local self = setmetatable({}, TownHall)
    
    self.x = params.x or 0
    self.y = params.y or 0
    self.width = 96
    self.height = 96
    self.selected = false
    self.type = "townhall"
    self.name = "Town Hall"
    
    -- Production
    self.isProducing = false
    self.productionTime = 5.0
    self.productionTimer = 0
    self.productionCost = 400
    
    return self
end

function TownHall:update(dt)
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= self.productionTime then
            self.isProducing = false
            self.productionTimer = 0
            return true -- Signal that peon is ready
        end
    end
    return false
end

function TownHall:draw()
    -- Draw building base
    love.graphics.setColor(0.55, 0.35, 0.2, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 6)
    
    -- Draw roof
    love.graphics.setColor(0.35, 0.2, 0.1, 1)
    love.graphics.polygon("fill", 
        self.x + self.width / 2, self.y - 20,
        self.x - 5, self.y + 20,
        self.x + self.width + 5, self.y + 20
    )
    
    -- Draw door
    love.graphics.setColor(0.25, 0.15, 0.08, 1)
    love.graphics.rectangle("fill", self.x + 35, self.y + 55, 26, 41)
    
    -- Draw windows
    love.graphics.setColor(0.6, 0.8, 1, 0.8)
    love.graphics.rectangle("fill", self.x + 15, self.y + 30, 18, 18)
    love.graphics.rectangle("fill", self.x + 63, self.y + 30, 18, 18)
    
    -- Draw border
    love.graphics.setColor(0.25, 0.15, 0.08, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 6)
    
    -- Draw selection highlight
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x - 3, self.y - 3, self.width + 6, self.height + 6, 8)
    end
    
    -- Draw production progress bar
    if self.isProducing then
        local barWidth = self.width - 10
        local barHeight = 8
        local barX = self.x + 5
        local barY = self.y + self.height + 5
        local progress = self.productionTimer / self.productionTime
        
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 2)
        
        love.graphics.setColor(0.2, 0.8, 0.2, 1)
        love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight, 2)
        
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function TownHall:containsPoint(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
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

function TownHall:getCenterX()
    return self.x + self.width / 2
end

function TownHall:getCenterY()
    return self.y + self.height / 2
end

function TownHall:getSpawnPoint()
    return self.x + self.width + 10, self.y + self.height / 2
end

return TownHall
