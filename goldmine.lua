--[[
    Gold Mine
    Resource node that peons can harvest gold from
]]

local GoldMine = {}
GoldMine.__index = GoldMine

function GoldMine.new(params)
    local self = setmetatable({}, GoldMine)
    
    self.x = params.x or 0
    self.y = params.y or 0
    self.width = 64
    self.height = 64
    self.goldReserves = params.gold or 100000
    self.maxGold = self.goldReserves
    self.selected = false
    self.depleted = false
    self.type = "goldmine"
    self.name = "Gold Mine"
    
    return self
end

function GoldMine:update(dt)
    if self.goldReserves <= 0 then
        self.depleted = true
    end
end

function GoldMine:draw()
    -- Draw mine base
    if self.depleted then
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
    else
        love.graphics.setColor(0.45, 0.35, 0.25, 1)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 4)
    
    -- Draw gold veins
    if not self.depleted then
        love.graphics.setColor(0.9, 0.75, 0.1, 1)
        love.graphics.rectangle("fill", self.x + 8, self.y + 8, 18, 12, 2)
        love.graphics.rectangle("fill", self.x + 38, self.y + 20, 16, 10, 2)
        love.graphics.rectangle("fill", self.x + 12, self.y + 38, 20, 14, 2)
        love.graphics.rectangle("fill", self.x + 40, self.y + 42, 14, 12, 2)
    end
    
    -- Draw cave entrance
    love.graphics.setColor(0.1, 0.08, 0.05, 1)
    love.graphics.rectangle("fill", self.x + 20, self.y + 35, 24, 29, 3)
    
    -- Draw border
    love.graphics.setColor(0.25, 0.2, 0.1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 4)
    
    -- Draw selection highlight
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", self.x - 2, self.y - 2, self.width + 4, self.height + 4, 6)
    end
    
    -- Draw gold amount above mine
    love.graphics.setColor(1, 0.85, 0, 1)
    local goldText = tostring(self.goldReserves)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(goldText)
    love.graphics.print(goldText, self.x + (self.width - textWidth) / 2, self.y - 18)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function GoldMine:containsPoint(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
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

function GoldMine:getCenterX()
    return self.x + self.width / 2
end

function GoldMine:getCenterY()
    return self.y + self.height / 2
end

return GoldMine
