--[[
    Footman - Basic melee soldier
    Inherits from Unit base class
    
    ENHANCED: Now includes visual effects, outlines, and animations
]]

local Unit = require("unit")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Visual enhancement modules (optional - graceful fallback if missing)
local Effects, DrawUtils
pcall(function() Effects = require("effects") end)
pcall(function() DrawUtils = require("draw_utils") end)

local Footman = setmetatable({}, {__index = Unit})
Footman.__index = Footman

-- Class constants
Footman.RADIUS = 14
Footman.SPEED = 70

function Footman.new(params)
    local self = Unit.new(params)
    setmetatable(self, Footman)
    
    self.radius = Footman.RADIUS
    self.speed = Footman.SPEED
    self.type = "footman"
    self.name = "Footman"
    
    -- Combat stats: damage 2, hp 3, attack speed 1
    self.maxHp = 3
    self.hp = self.maxHp
    self.damage = 2
    self.attackSpeed = 1.0
    self.sightRadius = 5
    
    -- Animation properties
    self.animTimer = 0
    self.idleSeed = math.random() * 100
    self.lastWorldX = self.worldX
    self.lastWorldY = self.worldY
    self.dustTimer = 0
    
    -- Attack animation
    self.attackAnimTimer = 0  -- Timer for sword swing
    self.isSwinging = false
    
    return self
end

-- Override update to add animation timer and effects
function Footman:update(dt, buildings, allUnits, allBuildings)
    self.animTimer = (self.animTimer or 0) + dt
    self.dustTimer = math.max(0, (self.dustTimer or 0) - dt)
    
    -- Update attack animation timer
    if self.attackAnimTimer and self.attackAnimTimer > 0 then
        self.attackAnimTimer = self.attackAnimTimer - dt
        if self.attackAnimTimer <= 0 then
            self.isSwinging = false
        end
    end
    
    -- Clear lastAttackHit flag before update (it's set in Unit.updateAttacking)
    self.lastAttackHit = false
    
    -- Track movement for dust
    local moveDistSq = (self.worldX - (self.lastWorldX or self.worldX))^2 + 
                       (self.worldY - (self.lastWorldY or self.worldY))^2
    if moveDistSq > 4 and self.dustTimer <= 0 and Effects then
        Effects.footstep(self.worldX, self.worldY + 10)
        self.dustTimer = 0.12
    end
    
    self.lastWorldX = self.worldX
    self.lastWorldY = self.worldY
    
    -- Call parent Unit update for combat logic
    Unit.update(self, dt, buildings, allUnits, allBuildings)
    
    -- Check if we just hit something (lastAttackHit is set in Unit.updateAttacking)
    if self.lastAttackHit then
        self.isSwinging = true
        self.attackAnimTimer = 0.3  -- Swing duration
        
        -- Play hit sound
        local Audio
        pcall(function() Audio = require("audio") end)
        if Audio and Audio.playHit then
            Audio.playHit()
        end
    end
end

function Footman:draw()
    local x, y = self:getScreenPos()
    
    -- Draw health bar
    self:drawHealthBar()
    
    -- Animation offsets
    local idleBob = 0
    local walkBob = 0
    local breathe = 0
    
    -- Determine if moving
    local isMoving = self.state == "Moving" or self.state == "Attacking" or
                     (self.targetX and self.targetY)
    
    if isMoving then
        walkBob = math.abs(math.sin((self.animTimer or 0) * 9)) * 2.5
    else
        -- Idle sway
        if DrawUtils then
            idleBob = DrawUtils.getIdleBob(self.idleSeed or 0, 0.6)
        else
            idleBob = math.sin((self.animTimer or 0) * 1.2 + (self.idleSeed or 0)) * 1
        end
    end
    
    -- Breathing
    breathe = math.sin((self.animTimer or 0) * 1.8 + (self.idleSeed or 0)) * 0.4
    
    y = y - walkBob - idleBob
    local baseY = y + walkBob + idleBob
    
    -- Selection circle
    if self.selected then
        local playerTeam = Teams and Teams.PLAYER or 1
        local selR, selG, selB = 0, 1, 0  -- Green for player
        if self.team ~= playerTeam then
            selR, selG, selB = 1, 0, 0  -- Red for enemy
        end
        if DrawUtils then
            if self.team ~= playerTeam then
                love.graphics.setColor(selR, selG, selB, 0.4)
                love.graphics.circle("fill", x, baseY, self.radius + 4)
                love.graphics.setColor(selR, selG, selB, 0.8)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", x, baseY, self.radius + 4)
            else
                DrawUtils.drawSelection(x, baseY, self.radius + 2, {0.3, 1, 0.4})
            end
        else
            love.graphics.setColor(selR, selG, selB, 0.4)
            love.graphics.circle("fill", x, baseY, self.radius + 4)
            love.graphics.setColor(selR, selG, selB, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", x, baseY, self.radius + 4)
        end
    end
    
    -- Enhanced shadow
    if DrawUtils then
        DrawUtils.drawShadow(x, baseY + 10, 12, 4, 0.4)
    else
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.ellipse("fill", x, baseY + 10, 11, 4)
    end
    
    -- Draw function for body (used for outline and flash)
    local function drawBody()
        -- Get team colors
        local teamColors = Teams and Teams.getColors(self.team) or nil
        local shieldColor = teamColors and teamColors.primary or {0.55, 0.28, 0.12, 1}
        local bossColor = teamColors and teamColors.emblem or {0.75, 0.65, 0.2, 1}
        
        -- Arm swing when walking
        local armSwing = 0
        if isMoving then
            armSwing = math.sin((self.animTimer or 0) * 9) * 3
        end
        
        -- Feet (leather boots)
        love.graphics.setColor(0.35, 0.25, 0.15, 1)
        love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
        love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
        
        -- Legs (chainmail)
        love.graphics.setColor(0.45, 0.45, 0.5, 1)
        love.graphics.rectangle("fill", x - 6, y + 1, 5, 9, 1)
        love.graphics.rectangle("fill", x + 1, y + 1, 5, 9, 1)
        -- Chainmail texture hint
        love.graphics.setColor(0.5, 0.5, 0.55, 0.5)
        love.graphics.line(x - 5, y + 3, x - 2, y + 3)
        love.graphics.line(x + 2, y + 5, x + 5, y + 5)
        
        -- Shield on left arm (moves with arm) - TEAM COLORED
        love.graphics.setColor(shieldColor)
        love.graphics.ellipse("fill", x - 12, y - 2 + armSwing * 0.5, 6, 10)
        love.graphics.setColor(0.45, 0.45, 0.5, 1)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", x - 12, y - 2 + armSwing * 0.5, 6, 10)
        -- Shield boss - TEAM COLORED
        love.graphics.setColor(bossColor)
        love.graphics.circle("fill", x - 12, y - 2 + armSwing * 0.5, 3)
        love.graphics.setColor(0.9, 0.85, 0.6, 0.6)
        love.graphics.circle("fill", x - 13, y - 3 + armSwing * 0.5, 1.5)
        
        -- Body (chainmail) - with breathing
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.rectangle("fill", x - 7 - breathe * 0.3, y - 8, 14 + breathe * 0.6, 12, 2)
        -- Chainmail highlight
        love.graphics.setColor(0.6, 0.6, 0.65, 0.4)
        love.graphics.rectangle("fill", x - 5, y - 7, 4, 2, 1)
        
        -- Belt
        love.graphics.setColor(0.4, 0.32, 0.18, 1)
        love.graphics.rectangle("fill", x - 7, y, 14, 3)
        love.graphics.setColor(0.6, 0.5, 0.25, 1)
        love.graphics.rectangle("fill", x - 2, y, 4, 3)
        
        -- Right arm holding sword (moves opposite to left)
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.ellipse("fill", x + 9, y - 4 - armSwing * 0.5, 3, 5)
        love.graphics.setColor(0.85, 0.72, 0.58, 1)
        love.graphics.rectangle("fill", x + 7, y - 2 - armSwing * 0.3, 4, 8, 1)
        
        -- Hand
        love.graphics.setColor(0.85, 0.72, 0.58, 1)
        love.graphics.circle("fill", x + 9, y + 6 - armSwing * 0.3, 3)
        
        -- Sword with attack swing animation
        local swordAngle = math.sin((self.animTimer or 0) * 2) * 0.05
        local swingOffset = 0
        local swingAngle = 0
        local swingProgress = 0
        
        -- Attack swing animation
        if self.isSwinging and self.attackAnimTimer then
            swingProgress = 1 - (self.attackAnimTimer / 0.3)  -- 0 to 1
            -- Swing arc: start at rest, swing down and forward
            swingAngle = math.sin(swingProgress * math.pi) * 1.5  -- Big rotation
            swingOffset = math.sin(swingProgress * math.pi) * 8  -- Move forward
        end
        
        -- Motion blur trail (draw before sword)
        if self.isSwinging and swingProgress > 0.1 and swingProgress < 0.9 then
            local blurCount = 4
            for i = 1, blurCount do
                local trailProgress = swingProgress - (i * 0.08)
                if trailProgress > 0 then
                    local trailAngle = math.sin(trailProgress * math.pi) * 1.5
                    local trailOffset = math.sin(trailProgress * math.pi) * 8
                    local alpha = (1 - i / blurCount) * 0.4
                    
                    love.graphics.push()
                    love.graphics.translate(x + 9 + trailOffset, y + 4 - armSwing * 0.3)
                    love.graphics.rotate(swordAngle + trailAngle)
                    -- Ghost blade
                    love.graphics.setColor(0.9, 0.95, 1, alpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.line(0, -2, 0, -18)
                    love.graphics.pop()
                end
            end
        end
        
        love.graphics.push()
        love.graphics.translate(x + 9 + swingOffset, y + 4 - armSwing * 0.3)
        love.graphics.rotate(swordAngle + swingAngle)
        
        -- Blade glow during swing
        if self.isSwinging then
            love.graphics.setColor(1, 1, 0.9, 0.5)
            love.graphics.setLineWidth(6)
            love.graphics.line(0, -2, 0, -16)
        end
        
        -- Blade
        love.graphics.setColor(0.7, 0.7, 0.75, 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(0, 0, 0, -18)
        -- Blade highlight
        love.graphics.setColor(0.9, 0.9, 0.95, 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.line(-1, -2, -1, -16)
        -- Handle
        love.graphics.setColor(0.45, 0.35, 0.2, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(0, 0, 0, 4)
        -- Crossguard
        love.graphics.setColor(0.65, 0.55, 0.25, 1)
        love.graphics.line(-4, 0, 4, 0)
        love.graphics.pop()
        
        -- Head
        love.graphics.setColor(0.85, 0.72, 0.58, 1)
        love.graphics.ellipse("fill", x, y - 12, 6, 7)
        
        -- Helmet
        love.graphics.setColor(0.45, 0.45, 0.5, 1)
        love.graphics.arc("fill", x, y - 14, 7, math.pi, 2 * math.pi)
        -- Helmet crest
        love.graphics.setColor(0.5, 0.5, 0.55, 1)
        love.graphics.rectangle("fill", x - 1, y - 14, 2, 6)
        -- Helmet shine
        love.graphics.setColor(0.65, 0.65, 0.7, 0.5)
        love.graphics.arc("line", x - 2, y - 15, 4, math.pi * 1.1, math.pi * 1.5)
        
        -- Eyes
        love.graphics.setColor(0.15, 0.12, 0.08, 1)
        love.graphics.circle("fill", x - 3, y - 12, 1.5)
        love.graphics.circle("fill", x + 3, y - 12, 1.5)
    end
    
    -- Draw with outline
    if DrawUtils and Effects then
        -- Dark outline
        love.graphics.setColor(0.08, 0.06, 0.04, 0.7)
        local offsets = {{-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5}}
        for _, off in ipairs(offsets) do
            love.graphics.push()
            love.graphics.translate(off[1], off[2])
            drawBody()
            love.graphics.pop()
        end
        
        -- Body with flash
        DrawUtils.applyFlash(self, drawBody)
    else
        drawBody()
    end
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Footman:drawOnMinimap(mapX, mapY, scale)
    -- Use team color
    if Teams then
        Teams.setColor(self.team, "minimapUnit")
    else
        love.graphics.setColor(0.3, 0.7, 0.4, 1)
    end
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.circle("fill", mmX, mmY, math.max(2, 3))
end

return Footman
