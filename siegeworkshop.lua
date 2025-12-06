--[[
    Siege Workshop
    Military building that produces siege units
    Size: 3x3 tiles, grid-aligned
    Requires: Keep (Town Hall tier 3)
    Produces: Flying Scout, Ballista, Kamikaze
]]

local Button = require("button")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

local SiegeWorkshop = {}
SiegeWorkshop.__index = SiegeWorkshop

SiegeWorkshop.GRID_SIZE = 3
SiegeWorkshop.COST_GOLD = 800
SiegeWorkshop.COST_LUMBER = 400
SiegeWorkshop.BUILD_TIME = 25.0

-- Unit costs
SiegeWorkshop.FLYINGSCOUT_COST_GOLD = 200
SiegeWorkshop.FLYINGSCOUT_COST_LUMBER = 100
SiegeWorkshop.FLYINGSCOUT_TIME = 12.0

SiegeWorkshop.BALLISTA_COST_GOLD = 500
SiegeWorkshop.BALLISTA_COST_LUMBER = 200
SiegeWorkshop.BALLISTA_TIME = 18.0

SiegeWorkshop.KAMIKAZE_COST_GOLD = 300
SiegeWorkshop.KAMIKAZE_COST_LUMBER = 100
SiegeWorkshop.KAMIKAZE_TIME = 8.0

function SiegeWorkshop.new(params)
    local self = setmetatable({}, SiegeWorkshop)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = SiegeWorkshop.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "siegeworkshop"
    self.name = "Siege Workshop"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 90
    self.hp = self.maxHp
    self.sightRadius = 6
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = SiegeWorkshop.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    self.isProducing = false
    self.productionTimer = 0
    self.producingUnit = nil  -- "flyingscout", "ballista", "kamikaze"
    self.productionTime = 0
    
    -- UI buttons
    self.flyingScoutButton = nil
    self.ballistaButton = nil
    self.kamikazeButton = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function SiegeWorkshop:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function SiegeWorkshop:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function SiegeWorkshop:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function SiegeWorkshop:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function SiegeWorkshop:getSpawnPos()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize + 20, wy + self.pixelSize / 2
end

function SiegeWorkshop:update(dt)
    if self.isBuilding then
        self.buildProgress = self.buildProgress + dt
        if self.buildProgress >= self.buildTime then
            self.isBuilding = false
            self.completed = true
            return nil, true  -- build complete
        end
        return nil, false
    end
    
    if self.isProducing then
        self.productionTimer = self.productionTimer + dt
        if self.productionTimer >= self.productionTime then
            local unit = self.producingUnit
            self.isProducing = false
            self.productionTimer = 0
            self.producingUnit = nil
            self.productionTime = 0
            return unit, false  -- unit ready
        end
    end
    return nil, false
end

function SiegeWorkshop:startProduction(unitType)
    if self.completed and not self.isProducing then
        self.isProducing = true
        self.productionTimer = 0
        self.producingUnit = unitType
        
        if unitType == "flyingscout" then
            self.productionTime = SiegeWorkshop.FLYINGSCOUT_TIME
        elseif unitType == "ballista" then
            self.productionTime = SiegeWorkshop.BALLISTA_TIME
        elseif unitType == "kamikaze" then
            self.productionTime = SiegeWorkshop.KAMIKAZE_TIME
        end
        
        return true
    end
    return false
end

function SiegeWorkshop:canProduce()
    return self.completed and not self.isProducing
end

function SiegeWorkshop:getProductionProgress()
    if self.isProducing and self.productionTime > 0 then
        return math.floor((self.productionTimer / self.productionTime) * 100)
    end
    return 0
end

function SiegeWorkshop:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function SiegeWorkshop:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction scaffolding
        love.graphics.setColor(0.45, 0.4, 0.35, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.5, 0.45, 0.38, 0.8)
        -- Scaffolding and equipment
        love.graphics.rectangle("fill", x + 5, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + size - 9, y + 5, 4, size - 10)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 2, size - 10, 4)
        -- Gears/wheels in progress
        love.graphics.setColor(0.4, 0.38, 0.4, 0.8)
        love.graphics.circle("line", x + size/2, y + size/2, 15)
        
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
        
        -- Main building (stone/industrial)
        love.graphics.setColor(0.4, 0.38, 0.35, 1)
        love.graphics.rectangle("fill", x + 5, y + 25, size - 10, size - 25, 3)
        
        -- Stone texture
        love.graphics.setColor(0.35, 0.33, 0.3, 1)
        for row = 0, 4 do
            for col = 0, 3 do
                local offsetX = (row % 2) * 12
                love.graphics.rectangle("fill", x + 10 + col * 20 + offsetX, y + 30 + row * 14, 16, 10, 1)
            end
        end
        
        -- Roof (industrial, flat-ish with smokestacks)
        love.graphics.setColor(0.35, 0.32, 0.28, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 5,
            x - 3, y + 28,
            x + size + 3, y + 28
        )
        
        -- Smokestacks
        love.graphics.setColor(0.4, 0.35, 0.32, 1)
        love.graphics.rectangle("fill", x + 15, y - 10, 12, 25, 2)
        love.graphics.rectangle("fill", x + size - 27, y - 8, 12, 23, 2)
        -- Smoke
        love.graphics.setColor(0.5, 0.5, 0.5, 0.4)
        love.graphics.circle("fill", x + 21, y - 15, 6)
        love.graphics.circle("fill", x + 23, y - 24, 5)
        love.graphics.circle("fill", x + size - 21, y - 13, 5)
        love.graphics.circle("fill", x + size - 19, y - 20, 4)
        
        -- Large doors (workshop entrance)
        love.graphics.setColor(0.35, 0.28, 0.2, 1)
        love.graphics.rectangle("fill", x + size/2 - 22, y + size - 50, 44, 50)
        love.graphics.arc("fill", x + size/2, y + size - 50, 22, math.pi, 2 * math.pi)
        
        -- Door details (iron bands)
        love.graphics.setColor(0.4, 0.38, 0.42, 1)
        love.graphics.rectangle("fill", x + size/2 - 22, y + size - 45, 44, 3)
        love.graphics.rectangle("fill", x + size/2 - 22, y + size - 30, 44, 3)
        love.graphics.rectangle("fill", x + size/2 - 22, y + size - 15, 44, 3)
        -- Hinges
        love.graphics.setColor(0.45, 0.42, 0.45, 1)
        love.graphics.circle("fill", x + size/2 - 18, y + size - 40, 3)
        love.graphics.circle("fill", x + size/2 - 18, y + size - 20, 3)
        love.graphics.circle("fill", x + size/2 + 18, y + size - 40, 3)
        love.graphics.circle("fill", x + size/2 + 18, y + size - 20, 3)
        
        -- Catapult arm visible inside
        love.graphics.setColor(0.55, 0.42, 0.25, 1)
        love.graphics.polygon("fill",
            x + size/2 - 5, y + size - 25,
            x + size/2 + 5, y + size - 25,
            x + size/2 + 10, y + size - 50,
            x + size/2 - 10, y + size - 50
        )
        
        -- Gears on side
        love.graphics.setColor(0.45, 0.42, 0.45, 1)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", x + 20, y + 50, 12)
        love.graphics.circle("line", x + size - 20, y + 50, 12)
        -- Gear teeth
        love.graphics.setColor(0.5, 0.47, 0.5, 1)
        for i = 0, 5 do
            local angle = i * math.pi / 3
            love.graphics.rectangle("fill", 
                x + 20 + math.cos(angle) * 10 - 2, 
                y + 50 + math.sin(angle) * 10 - 3, 
                4, 6)
            love.graphics.rectangle("fill", 
                x + size - 20 + math.cos(angle) * 10 - 2, 
                y + 50 + math.sin(angle) * 10 - 3, 
                4, 6)
        end
        
        -- Wood pile
        love.graphics.setColor(0.55, 0.4, 0.25, 1)
        love.graphics.ellipse("fill", x + size - 15, y + size - 12, 10, 6)
        love.graphics.ellipse("fill", x + size - 18, y + size - 18, 8, 5)
        
        -- Banner/sign
        love.graphics.setColor(0.5, 0.38, 0.25, 1)
        love.graphics.rectangle("fill", x + 8, y + 28, 3, 35)
        love.graphics.setColor(0.6, 0.3, 0.15, 1)
        love.graphics.polygon("fill",
            x + 11, y + 28,
            x + 30, y + 32,
            x + 28, y + 48,
            x + 11, y + 44
        )
        -- Catapult symbol
        love.graphics.setColor(0.8, 0.7, 0.3, 1)
        love.graphics.polygon("fill", x + 17, y + 42, x + 24, y + 42, x + 20, y + 34)
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
        local progress = self.productionTimer / self.productionTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW, 8, 2)
        love.graphics.setColor(0.6, 0.4, 0.3, 1)
        love.graphics.rectangle("fill", x + 5, y + size + 5, barW * progress, 8, 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function SiegeWorkshop:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function SiegeWorkshop:updateUI(resources, screenW, screenH, font, currentPop, maxPop)
    currentPop = currentPop or 0
    maxPop = maxPop or 999
    self.currentPop = currentPop
    self.maxPop = maxPop
    
    -- Don't show UI for enemy buildings
    local playerTeam = Teams and Teams.PLAYER or 1
    if self.team ~= playerTeam then return end
    
    if self.selected and self.completed then
        -- New bottom panel positioning (matches barracks layout)
        local panelX = screenW - 288
        local panelY = screenH - 188
        local buttonY = panelY + 55
        local buttonW = 125
        local buttonH = 32
        local spacing = 36
        
        local selfRef = self
        
        -- Flying Scout button
        if not self.flyingScoutButton then
            self.flyingScoutButton = Button.new({
                x = panelX + 12, y = buttonY, width = buttonW, height = buttonH,
                text = "Scout (200/100)", font = font,
                colors = {
                    normal = {0.4, 0.5, 0.55, 1}, hover = {0.5, 0.6, 0.65, 1},
                    pressed = {0.3, 0.4, 0.45, 1}, text = {0.95, 0.92, 0.85, 1}, border = {0.4, 0.5, 0.55, 1}
                },
                onClick = function()
                    if resources.gold >= SiegeWorkshop.FLYINGSCOUT_COST_GOLD and
                       resources.lumber >= SiegeWorkshop.FLYINGSCOUT_COST_LUMBER and
                       selfRef:canProduce() and selfRef.currentPop < selfRef.maxPop then
                        resources.gold = resources.gold - SiegeWorkshop.FLYINGSCOUT_COST_GOLD
                        resources.lumber = resources.lumber - SiegeWorkshop.FLYINGSCOUT_COST_LUMBER
                        selfRef:startProduction("flyingscout")
                    end
                end
            })
        else
            self.flyingScoutButton.x = panelX + 12
            self.flyingScoutButton.y = buttonY
        end
        
        -- Ballista button (second column)
        if not self.ballistaButton then
            self.ballistaButton = Button.new({
                x = panelX + 12 + buttonW + 8, y = buttonY, width = buttonW, height = buttonH,
                text = "Ballista (500/200)", font = font,
                colors = {
                    normal = {0.55, 0.45, 0.35, 1}, hover = {0.65, 0.55, 0.45, 1},
                    pressed = {0.45, 0.35, 0.25, 1}, text = {0.95, 0.92, 0.85, 1}, border = {0.55, 0.45, 0.35, 1}
                },
                onClick = function()
                    if resources.gold >= SiegeWorkshop.BALLISTA_COST_GOLD and
                       resources.lumber >= SiegeWorkshop.BALLISTA_COST_LUMBER and
                       selfRef:canProduce() and selfRef.currentPop < selfRef.maxPop then
                        resources.gold = resources.gold - SiegeWorkshop.BALLISTA_COST_GOLD
                        resources.lumber = resources.lumber - SiegeWorkshop.BALLISTA_COST_LUMBER
                        selfRef:startProduction("ballista")
                    end
                end
            })
        else
            self.ballistaButton.x = panelX + 12 + buttonW + 8
            self.ballistaButton.y = buttonY
        end
        
        -- Kamikaze button (second row)
        if not self.kamikazeButton then
            self.kamikazeButton = Button.new({
                x = panelX + 12, y = buttonY + spacing, width = buttonW, height = buttonH,
                text = "Kamikaze (300/100)", font = font,
                colors = {
                    normal = {0.6, 0.35, 0.35, 1}, hover = {0.7, 0.45, 0.45, 1},
                    pressed = {0.5, 0.25, 0.25, 1}, text = {0.95, 0.92, 0.85, 1}, border = {0.6, 0.35, 0.35, 1}
                },
                onClick = function()
                    if resources.gold >= SiegeWorkshop.KAMIKAZE_COST_GOLD and
                       resources.lumber >= SiegeWorkshop.KAMIKAZE_COST_LUMBER and
                       selfRef:canProduce() and selfRef.currentPop < selfRef.maxPop then
                        resources.gold = resources.gold - SiegeWorkshop.KAMIKAZE_COST_GOLD
                        resources.lumber = resources.lumber - SiegeWorkshop.KAMIKAZE_COST_LUMBER
                        selfRef:startProduction("kamikaze")
                    end
                end
            })
        else
            self.kamikazeButton.x = panelX + 12
            self.kamikazeButton.y = buttonY + spacing
        end
        
        -- Update button states
        local canAffordScout = resources.gold >= SiegeWorkshop.FLYINGSCOUT_COST_GOLD and 
                              resources.lumber >= SiegeWorkshop.FLYINGSCOUT_COST_LUMBER
        local canAffordBallista = resources.gold >= SiegeWorkshop.BALLISTA_COST_GOLD and 
                                 resources.lumber >= SiegeWorkshop.BALLISTA_COST_LUMBER
        local canAffordKamikaze = resources.gold >= SiegeWorkshop.KAMIKAZE_COST_GOLD and 
                                 resources.lumber >= SiegeWorkshop.KAMIKAZE_COST_LUMBER
        
        self.flyingScoutButton:setEnabled(canAffordScout and currentPop < maxPop and self:canProduce())
        self.ballistaButton:setEnabled(canAffordBallista and currentPop < maxPop and self:canProduce())
        self.kamikazeButton:setEnabled(canAffordKamikaze and currentPop < maxPop and self:canProduce())
        
        self.flyingScoutButton:update(0)
        self.ballistaButton:update(0)
        self.kamikazeButton:update(0)
    else
        self.flyingScoutButton = nil
        self.ballistaButton = nil
        self.kamikazeButton = nil
    end
end

function SiegeWorkshop:drawUI()
    if self.selected and self.completed then
        if self.flyingScoutButton then self.flyingScoutButton:draw() end
        if self.ballistaButton then self.ballistaButton:draw() end
        if self.kamikazeButton then self.kamikazeButton:draw() end
        
        if self.currentPop >= self.maxPop then
            local screenW = love.graphics.getWidth()
            local screenH = love.graphics.getHeight()
            love.graphics.setColor(1, 0.4, 0.4, 1)
            love.graphics.setFont(Game.fonts.small)
            love.graphics.print("Need more farms!", screenW - 276, screenH - 188 + 95)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function SiegeWorkshop:mousepressed(x, y, button)
    if self.flyingScoutButton then self.flyingScoutButton:mousepressed(x, y, button) end
    if self.ballistaButton then self.ballistaButton:mousepressed(x, y, button) end
    if self.kamikazeButton then self.kamikazeButton:mousepressed(x, y, button) end
end

function SiegeWorkshop:mousereleased(x, y, button)
    if self.flyingScoutButton then self.flyingScoutButton:mousereleased(x, y, button) end
    if self.ballistaButton then self.ballistaButton:mousereleased(x, y, button) end
    if self.kamikazeButton then self.kamikazeButton:mousereleased(x, y, button) end
end

function SiegeWorkshop:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        if Teams then
            Teams.setColor(self.team, "minimapBuilding")
        else
            love.graphics.setColor(0.5, 0.4, 0.35, 1)
        end
    else
        love.graphics.setColor(0.4, 0.32, 0.28, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

-- Combat Methods --

function SiegeWorkshop:takeDamage(amount)
    self.hp = self.hp - amount
end

function SiegeWorkshop:isDead()
    return self.hp <= 0
end

function SiegeWorkshop:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = self.pixelSize - 10
    local barHeight = 4
    local barX = x + 5
    local barY = y - 8
    
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

return SiegeWorkshop
