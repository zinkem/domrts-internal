--[[
    Blacksmith
    Upgrade building for combat stats (placeholders for now)
    Size: 2x2 tiles, grid-aligned
    Requires: Barracks
]]

local Button = require("button")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

local Blacksmith = {}
Blacksmith.__index = Blacksmith

Blacksmith.GRID_SIZE = 2
Blacksmith.COST_GOLD = 300
Blacksmith.COST_LUMBER = 100
Blacksmith.BUILD_TIME = 15.0

-- Upgrade costs per level (levels 1, 2, 3)
Blacksmith.UPGRADE_COSTS = {100, 500, 1000}

function Blacksmith.new(params)
    local self = setmetatable({}, Blacksmith)
    
    self.gridX = params.gridX or 1
    self.gridY = params.gridY or 1
    self.gridSize = Blacksmith.GRID_SIZE
    self.map = params.map
    self.pixelSize = self.gridSize * 32
    
    self.selected = false
    self.type = "blacksmith"
    self.name = "Blacksmith"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    
    -- Combat stats
    self.maxHp = 60
    self.hp = self.maxHp
    self.sightRadius = 5
    
    self.isBuilding = params.isBuilding or false
    self.buildProgress = params.buildProgress or 0
    self.buildTime = Blacksmith.BUILD_TIME
    self.completed = not self.isBuilding
    self.builderPeon = nil
    
    -- Upgrade levels (0 = not researched, max 3)
    self.meleeDamageLevel = 0
    self.meleeArmorLevel = 0
    self.rangedDamageLevel = 0
    self.rangedArmorLevel = 0
    
    -- UI buttons
    self.meleeDamageButton = nil
    self.meleeArmorButton = nil
    self.rangedDamageButton = nil
    self.rangedArmorButton = nil
    
    if self.map then
        self.map:clearArea(self.gridX, self.gridY, self.gridSize, self.gridSize)
    end
    
    return self
end

function Blacksmith:getWorldPos()
    if self.map then
        return self.map:gridToWorld(self.gridX, self.gridY)
    end
    return 0, 0
end

function Blacksmith:getScreenPos()
    local wx, wy = self:getWorldPos()
    if self.map then
        return self.map:worldToScreen(wx, wy)
    end
    return wx, wy
end

function Blacksmith:getWorldCenter()
    local wx, wy = self:getWorldPos()
    return wx + self.pixelSize / 2, wy + self.pixelSize / 2
end

function Blacksmith:getWorldBounds()
    local wx, wy = self:getWorldPos()
    return wx, wy, wx + self.pixelSize, wy + self.pixelSize
end

function Blacksmith:update(dt)
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

function Blacksmith:draw()
    local x, y = self:getScreenPos()
    local size = self.pixelSize
    
    if self.isBuilding then
        -- Construction site
        love.graphics.setColor(0.45, 0.35, 0.35, 0.6)
        love.graphics.rectangle("fill", x, y, size, size, 4)
        love.graphics.setColor(0.5, 0.5, 0.55, 0.8)
        -- Metal scraps
        love.graphics.rectangle("fill", x + 8, y + 15, 15, 6)
        love.graphics.rectangle("fill", x + size - 25, y + 20, 18, 5)
        
        local barW = size - 10
        local progress = self.buildProgress / self.buildTime
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW, 8, 2)
        love.graphics.setColor(0.2, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x + 5, y + size/2 - 4, barW * progress, 8, 2)
    else
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.ellipse("fill", x + size/2, y + size + 2, size/2 - 3, 5)
        
        -- Main building (stone/brick)
        love.graphics.setColor(0.4, 0.35, 0.32, 1)
        love.graphics.rectangle("fill", x + 3, y + 15, size - 6, size - 15, 2)
        
        -- Stone texture
        love.graphics.setColor(0.35, 0.3, 0.28, 1)
        for row = 0, 2 do
            for col = 0, 2 do
                local offsetX = (row % 2) * 10
                love.graphics.rectangle("fill", x + 6 + col * 18 + offsetX, y + 20 + row * 14, 14, 10, 1)
            end
        end
        
        -- Roof
        love.graphics.setColor(0.35, 0.3, 0.28, 1)
        love.graphics.polygon("fill",
            x + size/2, y - 5,
            x - 2, y + 18,
            x + size + 2, y + 18
        )
        
        -- Chimney with smoke
        love.graphics.setColor(0.4, 0.35, 0.3, 1)
        love.graphics.rectangle("fill", x + size - 18, y - 8, 12, 20)
        -- Smoke
        love.graphics.setColor(0.5, 0.5, 0.5, 0.4)
        love.graphics.circle("fill", x + size - 12, y - 12, 5)
        love.graphics.circle("fill", x + size - 10, y - 20, 4)
        love.graphics.circle("fill", x + size - 8, y - 26, 3)
        
        -- Forge glow (orange from door)
        love.graphics.setColor(1, 0.5, 0.1, 0.6)
        love.graphics.rectangle("fill", x + 10, y + size - 32, 22, 32, 2)
        love.graphics.setColor(1, 0.7, 0.2, 0.4)
        love.graphics.circle("fill", x + 21, y + size - 16, 15)
        
        -- Door frame
        love.graphics.setColor(0.3, 0.22, 0.12, 1)
        love.graphics.rectangle("fill", x + 8, y + size - 34, 26, 34)
        love.graphics.arc("fill", x + 21, y + size - 34, 13, math.pi, 2 * math.pi)
        
        -- Anvil outside
        love.graphics.setColor(0.35, 0.35, 0.4, 1)
        love.graphics.rectangle("fill", x + size - 22, y + size - 14, 16, 6, 1)
        love.graphics.rectangle("fill", x + size - 18, y + size - 20, 8, 8)
        love.graphics.polygon("fill", 
            x + size - 22, y + size - 14,
            x + size - 26, y + size - 8,
            x + size - 22, y + size - 8
        )
        
        -- Hammer on anvil
        love.graphics.setColor(0.5, 0.4, 0.25, 1)
        love.graphics.rectangle("fill", x + size - 16, y + size - 28, 3, 12, 1)
        love.graphics.setColor(0.4, 0.4, 0.45, 1)
        love.graphics.rectangle("fill", x + size - 20, y + size - 30, 10, 5, 1)
        
        -- Weapon rack on wall
        love.graphics.setColor(0.45, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + 40, y + 22, 18, 3)
        love.graphics.rectangle("fill", x + 42, y + 22, 2, 15)
        love.graphics.rectangle("fill", x + 54, y + 22, 2, 15)
        -- Swords
        love.graphics.setColor(0.6, 0.6, 0.65, 1)
        love.graphics.rectangle("fill", x + 45, y + 18, 2, 15)
        love.graphics.rectangle("fill", x + 50, y + 20, 2, 13)
    end
    
    -- Selection
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Blacksmith:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    return screenX >= x and screenX <= x + self.pixelSize and
           screenY >= y and screenY <= y + self.pixelSize
end

function Blacksmith:getBuildProgress()
    if self.isBuilding then
        return math.floor((self.buildProgress / self.buildTime) * 100)
    end
    return 100
end

function Blacksmith:getUpgradeCost(level)
    if level >= 1 and level <= 3 then
        return Blacksmith.UPGRADE_COSTS[level]
    end
    return 0
end

function Blacksmith:updateUI(resources, screenW, screenH, font)
    -- Don't show UI for enemy buildings
    local playerTeam = Teams and Teams.PLAYER or 1
    if self.team ~= playerTeam then return end
    
    if self.selected and self.completed then
        -- New bottom panel positioning (2x2 grid)
        local panelX = screenW - 288
        local panelY = screenH - 188
        local buttonY = panelY + 55
        local buttonH = 32
        local buttonW = 125
        local spacing = 36
        
        local selfRef = self
        
        -- Melee Damage button (top left)
        if not self.meleeDamageButton then
            self.meleeDamageButton = Button.new({
                x = panelX + 12, y = buttonY, width = buttonW, height = buttonH,
                text = "Melee Dmg", font = font,
                colors = {
                    normal = {0.5, 0.35, 0.3, 1}, hover = {0.6, 0.45, 0.4, 1},
                    pressed = {0.4, 0.25, 0.2, 1}, text = {0.95, 0.92, 0.85, 1}, border = {0.5, 0.35, 0.3, 1}
                },
                onClick = function()
                    if selfRef.meleeDamageLevel < 3 then
                        local cost = selfRef:getUpgradeCost(selfRef.meleeDamageLevel + 1)
                        if resources.gold >= cost then
                            resources.gold = resources.gold - cost
                            selfRef.meleeDamageLevel = selfRef.meleeDamageLevel + 1
                        end
                    end
                end
            })
        else
            self.meleeDamageButton.x = panelX + 12
            self.meleeDamageButton.y = buttonY
        end
        
        -- Melee Armor button (top right)
        if not self.meleeArmorButton then
            self.meleeArmorButton = Button.new({
                x = panelX + 12 + buttonW + 8, y = buttonY, width = buttonW, height = buttonH,
                text = "Melee Armor", font = font,
                colors = {
                    normal = {0.35, 0.4, 0.5, 1}, hover = {0.45, 0.5, 0.6, 1},
                    pressed = {0.25, 0.3, 0.4, 1}, text = {0.95, 0.92, 0.85, 1}, border = {0.35, 0.4, 0.5, 1}
                },
                onClick = function()
                    if selfRef.meleeArmorLevel < 3 then
                        local cost = selfRef:getUpgradeCost(selfRef.meleeArmorLevel + 1)
                        if resources.gold >= cost then
                            resources.gold = resources.gold - cost
                            selfRef.meleeArmorLevel = selfRef.meleeArmorLevel + 1
                        end
                    end
                end
            })
        else
            self.meleeArmorButton.x = panelX + 12 + buttonW + 8
            self.meleeArmorButton.y = buttonY
        end
        
        -- Ranged Damage button
        -- Ranged Damage button (bottom left)
        if not self.rangedDamageButton then
            self.rangedDamageButton = Button.new({
                x = panelX + 12, y = buttonY + spacing, width = buttonW, height = buttonH,
                text = "Ranged Dmg", font = font,
                colors = {
                    normal = {0.4, 0.5, 0.35, 1}, hover = {0.5, 0.6, 0.45, 1},
                    pressed = {0.3, 0.4, 0.25, 1}, text = {0.95, 0.92, 0.85, 1}, border = {0.4, 0.5, 0.35, 1}
                },
                onClick = function()
                    if selfRef.rangedDamageLevel < 3 then
                        local cost = selfRef:getUpgradeCost(selfRef.rangedDamageLevel + 1)
                        if resources.gold >= cost then
                            resources.gold = resources.gold - cost
                            selfRef.rangedDamageLevel = selfRef.rangedDamageLevel + 1
                        end
                    end
                end
            })
        else
            self.rangedDamageButton.x = panelX + 12
            self.rangedDamageButton.y = buttonY + spacing
        end
        
        -- Ranged Armor button (bottom right)
        if not self.rangedArmorButton then
            self.rangedArmorButton = Button.new({
                x = panelX + 12 + buttonW + 8, y = buttonY + spacing, width = buttonW, height = buttonH,
                text = "Ranged Armor", font = font,
                colors = {
                    normal = {0.45, 0.4, 0.5, 1}, hover = {0.55, 0.5, 0.6, 1},
                    pressed = {0.35, 0.3, 0.4, 1}, text = {0.95, 0.92, 0.85, 1}, border = {0.45, 0.4, 0.5, 1}
                },
                onClick = function()
                    if selfRef.rangedArmorLevel < 3 then
                        local cost = selfRef:getUpgradeCost(selfRef.rangedArmorLevel + 1)
                        if resources.gold >= cost then
                            resources.gold = resources.gold - cost
                            selfRef.rangedArmorLevel = selfRef.rangedArmorLevel + 1
                        end
                    end
                end
            })
        else
            self.rangedArmorButton.x = panelX + 12 + buttonW + 8
            self.rangedArmorButton.y = buttonY + spacing
        end
        
        -- Update button text and enabled state
        local function updateButton(btn, level, name)
            if level >= 3 then
                btn:setText(name .. " MAX")
                btn:setEnabled(false)
            else
                local cost = selfRef:getUpgradeCost(level + 1)
                btn:setText(name .. " " .. (level + 1) .. " (" .. cost .. ")")
                btn:setEnabled(resources.gold >= cost)
            end
            btn:update(0)
        end
        
        updateButton(self.meleeDamageButton, self.meleeDamageLevel, "Melee+")
        updateButton(self.meleeArmorButton, self.meleeArmorLevel, "Armor+")
        updateButton(self.rangedDamageButton, self.rangedDamageLevel, "Range+")
        updateButton(self.rangedArmorButton, self.rangedArmorLevel, "R.Armor")
    else
        self.meleeDamageButton = nil
        self.meleeArmorButton = nil
        self.rangedDamageButton = nil
        self.rangedArmorButton = nil
    end
end

function Blacksmith:drawUI()
    if self.selected and self.completed then
        if self.meleeDamageButton then self.meleeDamageButton:draw() end
        if self.meleeArmorButton then self.meleeArmorButton:draw() end
        if self.rangedDamageButton then self.rangedDamageButton:draw() end
        if self.rangedArmorButton then self.rangedArmorButton:draw() end
        
        -- Label
        local screenW = love.graphics.getWidth()
        love.graphics.setColor(0.7, 0.7, 0.75, 1)
        love.graphics.setFont(Game.fonts.small)
        love.graphics.print("Upgrades (placeholder)", screenW - 170, 70 + 115)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Blacksmith:mousepressed(x, y, button)
    if self.meleeDamageButton then self.meleeDamageButton:mousepressed(x, y, button) end
    if self.meleeArmorButton then self.meleeArmorButton:mousepressed(x, y, button) end
    if self.rangedDamageButton then self.rangedDamageButton:mousepressed(x, y, button) end
    if self.rangedArmorButton then self.rangedArmorButton:mousepressed(x, y, button) end
end

function Blacksmith:mousereleased(x, y, button)
    if self.meleeDamageButton then self.meleeDamageButton:mousereleased(x, y, button) end
    if self.meleeArmorButton then self.meleeArmorButton:mousereleased(x, y, button) end
    if self.rangedDamageButton then self.rangedDamageButton:mousereleased(x, y, button) end
    if self.rangedArmorButton then self.rangedArmorButton:mousereleased(x, y, button) end
end

function Blacksmith:drawOnMinimap(mapX, mapY, scale)
    if self.completed then
        if Teams then
            Teams.setColor(self.team, "minimapBuilding")
        else
            love.graphics.setColor(0.45, 0.4, 0.5, 1)
        end
    else
        love.graphics.setColor(0.35, 0.32, 0.4, 0.6)
    end
    local x = mapX + (self.gridX - 1) * scale
    local y = mapY + (self.gridY - 1) * scale
    love.graphics.rectangle("fill", x, y, self.gridSize * scale, self.gridSize * scale)
end

-- Combat Methods --

function Blacksmith:takeDamage(amount)
    self.hp = self.hp - amount
end

function Blacksmith:isDead()
    return self.hp <= 0
end

function Blacksmith:drawHealthBar()
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

return Blacksmith
