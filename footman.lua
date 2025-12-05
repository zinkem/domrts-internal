--[[
    Footman
    Military unit that can move around the map
    Cannot enter mines, buildings, or traverse trees
    Size: 1x1 tile, circular collision
]]

local FlowField = require("flowfield")

local Footman = {}
Footman.__index = Footman

Footman.STATE_IDLE = "Idle"
Footman.STATE_MOVING = "Moving"
Footman.RADIUS = 14

function Footman.new(params)
    local self = setmetatable({}, Footman)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Footman.RADIUS
    self.speed = 100
    self.selected = false
    self.type = "footman"
    self.name = "Footman"
    self.state = Footman.STATE_IDLE
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil  -- Flow field for pathfinding
    
    return self
end

function Footman:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Footman:wouldCollideWithBuilding(x, y, building)
    if not building.getWorldBounds then return false end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    return (distX * distX + distY * distY) < (self.radius * self.radius)
end

function Footman:getBuildingPenetration(x, y, building)
    if not building.getWorldBounds then return 0 end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    local dist = math.sqrt(distX * distX + distY * distY)
    if dist < self.radius then
        return self.radius - dist
    end
    return 0
end

function Footman:canMoveTo(newX, newY, buildings)
    -- Check tree collision
    if self.map and not self.map:isWorldPosPassable(newX, newY) then
        return false
    end
    
    if not buildings then return true end
    
    for _, b in ipairs(buildings) do
        local currentPen = self:getBuildingPenetration(self.worldX, self.worldY, b)
        local newPen = self:getBuildingPenetration(newX, newY, b)
        
        if newPen > 0 then
            if currentPen > 0 then
                -- Already inside - only allow if reducing penetration
                if newPen >= currentPen then
                    return false
                end
            else
                return false
            end
        end
    end
    
    return true
end

function Footman:update(dt, buildings)
    if self.state == Footman.STATE_MOVING then
        self:updateMoving(dt, buildings)
    end
end

function Footman:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Footman.STATE_IDLE
        return
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 8 then
        self.state = Footman.STATE_IDLE
        self.targetX = nil
        self.targetY = nil
        self.flowField = nil
        return
    end
    
    -- Get movement direction from flow field or direct path
    local moveDirX, moveDirY
    
    if self.flowField then
        moveDirX, moveDirY = self.flowField:getDirection(self.worldX, self.worldY, self.map)
    end
    
    -- Fall back to direct path if no flow field direction
    if not moveDirX or not moveDirY then
        if dist > 0.1 then
            moveDirX = dx / dist
            moveDirY = dy / dist
        else
            return
        end
    end
    
    -- Movement
    local moveSpeed = self.speed * dt
    local moveX = moveDirX * moveSpeed
    local moveY = moveDirY * moveSpeed
    local newX = self.worldX + moveX
    local newY = self.worldY + moveY
    
    if self:canMoveTo(newX, newY, buildings) then
        self.worldX = newX
        self.worldY = newY
    else
        -- Try sliding
        if self:canMoveTo(newX, self.worldY, buildings) then
            self.worldX = newX
        elseif self:canMoveTo(self.worldX, newY, buildings) then
            self.worldY = newY
        end
    end
end

function Footman:draw()
    local x, y = self:getScreenPos()
    
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.circle("fill", x, y, self.radius + 4)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end
    
    love.graphics.setColor(0.6, 0.25, 0.25, 1)
    love.graphics.circle("fill", x, y, self.radius)
    
    love.graphics.setColor(0.7, 0.35, 0.35, 1)
    love.graphics.arc("fill", x, y, self.radius - 2, -math.pi/2 - 0.5, -math.pi/2 + 0.5)
    
    love.graphics.setColor(0.7, 0.7, 0.75, 1)
    love.graphics.circle("fill", x, y - 2, 8)
    
    love.graphics.setColor(0.3, 0.3, 0.35, 1)
    love.graphics.rectangle("fill", x - 5, y - 4, 10, 4, 1)
    
    love.graphics.setColor(0.6, 0.6, 0.65, 1)
    love.graphics.rectangle("fill", x + 6, y - 10, 3, 16, 1)
    love.graphics.setColor(0.5, 0.4, 0.3, 1)
    love.graphics.rectangle("fill", x + 4, y - 2, 7, 4, 1)
    
    love.graphics.setColor(0.5, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", x - 12, y - 6, 6, 14, 2)
    love.graphics.setColor(0.7, 0.5, 0.2, 1)
    love.graphics.rectangle("fill", x - 11, y - 2, 4, 6, 1)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Footman:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Footman:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Footman:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.flowField = flowField
    self.state = Footman.STATE_MOVING
end

function Footman:getStateText()
    return self.state
end

function Footman:updateUI(resources, screenW, screenH, font) end
function Footman:drawUI() end
function Footman:mousepressed(x, y, button) end
function Footman:mousereleased(x, y, button) end

function Footman:drawOnMinimap(mapX, mapY, scale)
    love.graphics.setColor(0.8, 0.3, 0.3, 1)
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.5))
end

return Footman
