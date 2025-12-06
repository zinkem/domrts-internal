--[[
    Barracks
    Military building that produces footmen and knights
    Size: 3x3 tiles, grid-aligned
]]

local Button = require("button")
local Requirements = require("requirements")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

local Barracks = {}
Barracks.__index = Barracks

Barracks.GRID_SIZE = 3
Barracks.COST_GOLD = 400
Barracks.COST_LUMBER = 100
Barracks.BUILD_TIME = 15.0
Barracks.FOOTMAN_COST = 135
Barracks.FOOTMAN_TIME = 8.0
Barracks.KNIGHT_COST_GOLD = 300
Barracks.KNIGHT_COST_LUMBER = 100
Barracks.KNIGHT_TIME = 12.0

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
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 400
    self.hp = self.maxHp
    self.sightRadius = 2
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = Barracks.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    self.isProducing = false
    self.productionTimer = 0
    self.producingUnit = nil  -- "footman" or "knight"
    self.actionButton = nil
    self.knightButton = nil
    
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
            return nil, true -- no unit, build complete
        end
        return nil, false
    end
    
    if self.isProducing then
        local productionTime = self.producingUnit == "knight" and Barracks.KNIGHT_TIME or Barracks.FOOTMAN_TIME
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= productionTime then
            local unitType = self.producingUnit
            self.isProducing = false
            self.productionTimer = 0
            self.producingUnit = nil
            return unitType, false -- unit type ready
        end
    end
    return nil, false
end

function Barracks:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction scaffolding
        love.graphics.setColor(0.5, 0.4, 0.3, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.6, 0.5, 0.3, 0.8)
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
        
        -- Main building base (dark stone)
        love.graphics.setColor(0.38, 0.32, 0.28, 1)
        love.graphics.rectangle("fill", x + 5, y + 25, size - 10, size - 25, 3)
        
        -- Stone texture
        love.graphics.setColor(0.35, 0.3, 0.26, 1)
        for row = 0, 3 do
            for col = 0, 3 do
                local offsetX = (row % 2) * 10
                love.graphics.rectangle("fill", x + 10 + col * 18 + offsetX, y + 30 + row * 14, 14, 10, 1)
            end
        end
        
        -- Roof (dark red/maroon military style)
        love.graphics.setColor(0.45, 0.18, 0.15, 1)
        love.graphics.polygon("fill", 
            x + size/2, y - 5,
            x - 3, y + 30,
            x + size + 3, y + 30
        )
        -- Roof highlight
        love.graphics.setColor(0.55, 0.22, 0.18, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 5,
            x + size/2 - 30, y + 25,
            x + size/2, y + 20
        )
        
        -- Entrance
        love.graphics.setColor(0.12, 0.1, 0.08, 1)
        love.graphics.rectangle("fill", x + size/2 - 15, y + size - 42, 30, 42)
        love.graphics.arc("fill", x + size/2, y + size - 42, 15, math.pi, 2 * math.pi)
        
        -- Wooden door with iron bars
        love.graphics.setColor(0.35, 0.25, 0.15, 1)
        love.graphics.rectangle("fill", x + size/2 - 13, y + size - 38, 26, 38)
        -- Iron bars
        love.graphics.setColor(0.3, 0.3, 0.32, 1)
        love.graphics.rectangle("fill", x + size/2 - 8, y + size - 35, 2, 32)
        love.graphics.rectangle("fill", x + size/2 + 6, y + size - 35, 2, 32)
        love.graphics.rectangle("fill", x + size/2 - 12, y + size - 25, 24, 2)
        
        -- Crossed swords emblem above door
        love.graphics.setColor(0.7, 0.65, 0.55, 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(x + size/2 - 18, y + 38, x + size/2 + 18, y + 58)
        love.graphics.line(x + size/2 + 18, y + 38, x + size/2 - 18, y + 58)
        -- Sword handles
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.circle("fill", x + size/2 - 18, y + 38, 4)
        love.graphics.circle("fill", x + size/2 + 18, y + 38, 4)
        
        -- Shield emblem
        love.graphics.setColor(0.6, 0.15, 0.15, 1)
        love.graphics.ellipse("fill", x + size/2, y + 48, 10, 12)
        love.graphics.setColor(0.8, 0.7, 0.2, 1)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", x + size/2, y + 48, 10, 12)
        
        -- Training dummy on left side
        love.graphics.setColor(0.6, 0.5, 0.35, 1)
        love.graphics.rectangle("fill", x + 12, y + 60, 4, 30)  -- Post
        love.graphics.setColor(0.7, 0.6, 0.4, 1)
        love.graphics.ellipse("fill", x + 14, y + 55, 8, 10)  -- Head
        love.graphics.rectangle("fill", x + 6, y + 65, 16, 4)  -- Arms
        
        -- Weapon rack on right side
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + size - 25, y + 55, 20, 4)
        love.graphics.rectangle("fill", x + size - 25, y + 55, 3, 35)
        love.graphics.rectangle("fill", x + size - 8, y + 55, 3, 35)
        -- Swords on rack
        love.graphics.setColor(0.6, 0.6, 0.65, 1)
        love.graphics.rectangle("fill", x + size - 20, y + 45, 2, 20)
        love.graphics.rectangle("fill", x + size - 14, y + 47, 2, 18)
        
        -- Torches
        love.graphics.setColor(1, 0.6, 0.2, 0.9)
        love.graphics.circle("fill", x + 25, y + 45, 4)
        love.graphics.circle("fill", x + size - 25, y + 45, 4)
        love.graphics.setColor(1, 0.8, 0.4, 0.4)
        love.graphics.circle("fill", x + 25, y + 45, 7)
        love.graphics.circle("fill", x + size - 25, y + 45, 7)
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 4)
    end
    
    -- Production progress bar
    if self.completed and self.isProducing then
        local productionTime = self.producingUnit == "knight" and Barracks.KNIGHT_TIME or Barracks.FOOTMAN_TIME
        local barW = size - 10
        local progress = self.productionTimer / productionTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        -- Different color for knight vs footman
        if self.producingUnit == "knight" then
            love.graphics.setColor(0.6, 0.5, 0.2, 1)
        else
            love.graphics.setColor(0.8, 0.3, 0.3, 1)
        end
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    -- Health bar
    self:drawHealthBar()
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Barracks:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function Barracks:startProduction(unitType)
    unitType = unitType or "footman"
    if self.completed and not self.isProducing then
        self.isProducing = true
        self.productionTimer = 0
        self.producingUnit = unitType
        return true
    end
    return false
end

function Barracks:canProduce()
    return self.completed and not self.isProducing
end

function Barracks:getProductionProgress()
    if self.isProducing then
        local productionTime = self.producingUnit == "knight" and Barracks.KNIGHT_TIME or Barracks.FOOTMAN_TIME
        return math.floor((self.productionTimer / productionTime) * 100)
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
        -- New bottom panel positioning
        local panelX = screenW - 288
        local panelY = screenH - 188
        local buttonY = panelY + 55
        local buttonW = 125
        local buttonH = 36
        
        -- Train Footman button
        if not self.actionButton then
            local selfRef = self
            self.actionButton = Button.new({
                x = panelX + 12,
                y = buttonY,
                width = buttonW,
                height = buttonH,
                text = "Footman (135/0)",
                font = font,
                colors = {
                    normal = {0.5, 0.35, 0.35, 1},
                    hover = {0.6, 0.45, 0.45, 1},
                    pressed = {0.4, 0.25, 0.25, 1},
                    text = {0.95, 0.92, 0.85, 1},
                    border = {0.6, 0.35, 0.35, 1}
                },
                onClick = function()
                    if resources.gold >= Barracks.FOOTMAN_COST and 
                       selfRef:canProduce() and 
                       selfRef.currentPop < selfRef.maxPop then
                        if selfRef:startProduction("footman") then
                            resources.gold = resources.gold - Barracks.FOOTMAN_COST
                        end
                    end
                end
            })
        else
            self.actionButton.x = panelX + 12
            self.actionButton.y = buttonY
        end
        
        self.actionButton:setEnabled(resources.gold >= Barracks.FOOTMAN_COST and currentPop < maxPop and self:canProduce())
        
        -- Set disabled reason for hover tooltip
        local reason = nil
        if self.isProducing then
            reason = "Already training"
        elseif resources.gold < Barracks.FOOTMAN_COST then
            reason = "Need more gold"
        elseif currentPop >= maxPop then
            reason = "Need more farms"
        end
        self.actionButton:setDisabledReason(reason)
        
        self.actionButton:update(0)
        
        -- Train Knight button (only if Stable exists)
        if Requirements.canProduceKnight() then
            if not self.knightButton then
                local selfRef = self
                self.knightButton = Button.new({
                    x = panelX + 12 + buttonW + 8,
                    y = buttonY,
                    width = buttonW,
                    height = buttonH,
                    text = "Knight (300/100)",
                    font = font,
                    colors = {
                        normal = {0.55, 0.45, 0.25, 1},
                        hover = {0.65, 0.55, 0.35, 1},
                        pressed = {0.45, 0.35, 0.15, 1},
                        text = {0.95, 0.92, 0.85, 1},
                        border = {0.7, 0.55, 0.25, 1}
                    },
                    onClick = function()
                        if resources.gold >= Barracks.KNIGHT_COST_GOLD and 
                           resources.lumber >= Barracks.KNIGHT_COST_LUMBER and
                           selfRef:canProduce() and 
                           selfRef.currentPop < selfRef.maxPop then
                            if selfRef:startProduction("knight") then
                                resources.gold = resources.gold - Barracks.KNIGHT_COST_GOLD
                                resources.lumber = resources.lumber - Barracks.KNIGHT_COST_LUMBER
                            end
                        end
                    end
                })
            else
                self.knightButton.x = panelX + 12 + buttonW + 8
                self.knightButton.y = buttonY
            end
            
            local canAffordKnight = resources.gold >= Barracks.KNIGHT_COST_GOLD and resources.lumber >= Barracks.KNIGHT_COST_LUMBER
            self.knightButton:setEnabled(canAffordKnight and currentPop < maxPop and self:canProduce())
            
            -- Set disabled reason for hover tooltip
            local knightReason = nil
            if self.isProducing then
                knightReason = "Already training"
            elseif not canAffordKnight then
                if resources.gold < Barracks.KNIGHT_COST_GOLD and resources.lumber < Barracks.KNIGHT_COST_LUMBER then
                    knightReason = "Need gold & lumber"
                elseif resources.gold < Barracks.KNIGHT_COST_GOLD then
                    knightReason = "Need more gold"
                else
                    knightReason = "Need more lumber"
                end
            elseif currentPop >= maxPop then
                knightReason = "Need more farms"
            end
            self.knightButton:setDisabledReason(knightReason)
            
            self.knightButton:update(0)
        else
            self.knightButton = nil
        end
    else
        self.actionButton = nil
        self.knightButton = nil
    end
end

function Barracks:drawUI()
    if self.selected and self.completed then
        if self.actionButton then
            self.actionButton:draw()
        end
        
        if self.knightButton then
            self.knightButton:draw()
        end
    end
end

function Barracks:mousepressed(x, y, button)
    if self.actionButton then self.actionButton:mousepressed(x, y, button) end
    if self.knightButton then self.knightButton:mousepressed(x, y, button) end
end

function Barracks:mousereleased(x, y, button)
    if self.actionButton then self.actionButton:mousereleased(x, y, button) end
    if self.knightButton then self.knightButton:mousereleased(x, y, button) end
end

-- Combat Methods --

function Barracks:takeDamage(amount)
    self.hp = self.hp - amount
end

function Barracks:isDead()
    return self.hp <= 0
end

function Barracks:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 10
    local barHeight = 5
    local barX = x + 5
    local barY = y - 10
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
    
    -- Health bar
    local healthPct = self.hp / self.maxHp
    love.graphics.setColor(1 - healthPct, healthPct, 0.2, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPct, barHeight)
    
    -- Border
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
end

function Barracks:drawOnMinimap(mapX, mapY, scale)
    -- Use team color
    if self.completed then
        if Teams then
            Teams.setColor(self.team, "minimapBuilding")
        else
            love.graphics.setColor(0.6, 0.3, 0.3, 1)
        end
    else
        love.graphics.setColor(0.4, 0.3, 0.3, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

return Barracks
