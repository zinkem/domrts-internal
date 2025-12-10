--[[
    Footman - Basic melee soldier
    Inherits from Unit base class
    Enemy variant: Orc Grunt
]]

local Unit = require("unit")

-- Teams module for faction check
local Teams
pcall(function() Teams = require("teams") end)

local Footman = setmetatable({}, {__index = Unit})
Footman.__index = Footman

-- Class constants
Footman.RADIUS = 14
Footman.SPEED = 70

function Footman.new(params)
    local self = Unit.new(params)
    setmetatable(self, Footman)

    self.radius = Footman.RADIUS
    self.clickRadius = Footman.RADIUS * 1.414  -- Match visual scale for easier selection
    self.speed = Footman.SPEED
    self.type = "footman"

    -- Set name based on team
    if Teams and self.team == Teams.ENEMY then
        self.name = "Grunt"
    else
        self.name = "Footman"
    end

    return self
end

function Footman:draw()
    local x, y = self:getScreenPos()

    -- Visual scale factor (sqrt(2) ≈ 1.414 for 2x surface area)
    local scale = 1.414

    -- Attack animation: sword swing angle (0 to ~1.2 radians during attack)
    local swingAngle = 0
    if self.attackAnimTimer and self.attackAnimTimer > 0 then
        -- Swing from raised (0.8 rad) to down (-0.4 rad) over 0.3 seconds
        local swingProgress = 1 - (self.attackAnimTimer / 0.3)  -- 0 to 1
        swingAngle = 0.8 - swingProgress * 1.2  -- 0.8 to -0.4
    end

    -- Check if this is an enemy (orc) unit
    local isOrc = Teams and self.team == Teams.ENEMY

    -- Palette selection based on faction
    local steelDark, steelMid, steelLight
    local leatherDark, leatherMid, leatherLight
    local skin, skinShadow
    local clothDark, clothMid, clothLight
    local accentGlow

    if isOrc then
        -- Orc Grunt palette (inspired by orcs.png pixel art)
        -- Dark iron, crude leather, green skin, glowing green accents
        steelDark = {0.25, 0.22, 0.20}      -- Rusty dark iron
        steelMid = {0.40, 0.35, 0.30}       -- Worn iron
        steelLight = {0.55, 0.50, 0.42}     -- Dull iron highlight
        leatherDark = {0.32, 0.25, 0.18}    -- Dark crude leather
        leatherMid = {0.48, 0.38, 0.25}     -- Brown leather
        leatherLight = {0.58, 0.48, 0.32}   -- Tan leather
        skin = {0.45, 0.55, 0.35}           -- Olive green orc skin
        skinShadow = {0.32, 0.42, 0.25}     -- Darker green shadow
        clothDark = {0.28, 0.18, 0.12}      -- Dark reddish-brown
        clothMid = {0.45, 0.28, 0.18}       -- Rust/blood red cloth
        clothLight = {0.58, 0.38, 0.25}     -- Sunset orange highlight
        accentGlow = {0.4, 0.85, 0.35}      -- Fel green magic glow
    else
        -- Human Footman palette (inspired by weary_warrior pixel art)
        -- Muted browns, steel grays, warm firelight accents
        steelDark = {0.35, 0.38, 0.42}
        steelMid = {0.55, 0.58, 0.62}
        steelLight = {0.72, 0.74, 0.78}
        leatherDark = {0.28, 0.22, 0.18}
        leatherMid = {0.45, 0.36, 0.28}
        leatherLight = {0.58, 0.48, 0.38}
        skin = {0.78, 0.62, 0.52}
        skinShadow = {0.58, 0.45, 0.38}
        clothDark = {0.22, 0.20, 0.25}
        clothMid = {0.35, 0.32, 0.38}
        clothLight = {0.48, 0.45, 0.52}
        accentGlow = nil
    end
    
    -- Selection circle
    if self.selected then
        if Teams and self.team == Teams.PLAYER then
            -- Green selection for player's own units
            love.graphics.setColor(0.2, 0.7, 0.3, 0.4)
            love.graphics.circle("fill", x, y, self.radius + 4)
            love.graphics.setColor(0.3, 0.9, 0.4, 0.8)
        else
            -- Red selection for enemy units
            love.graphics.setColor(0.7, 0.2, 0.2, 0.4)
            love.graphics.circle("fill", x, y, self.radius + 4)
            love.graphics.setColor(0.9, 0.3, 0.3, 0.8)
        end
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end

    -- Fel glow for orcs
    if isOrc and accentGlow then
        love.graphics.setColor(accentGlow[1], accentGlow[2], accentGlow[3], 0.1)
        love.graphics.circle("fill", x, y, 18 * scale)
    end

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x, y + 10 * scale, 12 * scale, 4 * scale)

    -- Feet (leather boots)
    love.graphics.setColor(leatherDark[1], leatherDark[2], leatherDark[3], 1)
    love.graphics.ellipse("fill", x - 5 * scale, y + 8 * scale, 4 * scale, 3 * scale)
    love.graphics.ellipse("fill", x + 5 * scale, y + 8 * scale, 4 * scale, 3 * scale)
    love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
    love.graphics.ellipse("line", x - 5 * scale, y + 8 * scale, 4 * scale, 3 * scale)
    love.graphics.ellipse("line", x + 5 * scale, y + 8 * scale, 4 * scale, 3 * scale)

    -- Legs (dark cloth pants)
    love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 1)
    love.graphics.rectangle("fill", x - 6 * scale, y + 1 * scale, 5 * scale, 9 * scale, 1 * scale)
    love.graphics.rectangle("fill", x + 1 * scale, y + 1 * scale, 5 * scale, 9 * scale, 1 * scale)
    -- Fabric highlight
    love.graphics.setColor(clothLight[1], clothLight[2], clothLight[3], 0.5)
    love.graphics.rectangle("fill", x - 5 * scale, y + 2 * scale, 2 * scale, 7 * scale, 1 * scale)

    -- Shield on left arm (steel kite shield)
    love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    love.graphics.ellipse("fill", x - 12 * scale, y - 2 * scale, 7 * scale, 11 * scale)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.setLineWidth(2 * scale)
    love.graphics.ellipse("line", x - 12 * scale, y - 2 * scale, 7 * scale, 11 * scale)
    -- Shield design (cross)
    love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
    love.graphics.rectangle("fill", x - 13 * scale, y - 6 * scale, 2 * scale, 10 * scale)
    love.graphics.rectangle("fill", x - 16 * scale, y - 3 * scale, 8 * scale, 2 * scale)
    love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 1)
    love.graphics.circle("fill", x - 12 * scale, y - 2 * scale, 2 * scale)
    -- Shield highlight
    love.graphics.setColor(0.8, 0.82, 0.85, 0.3)
    love.graphics.arc("fill", x - 13 * scale, y - 4 * scale, 5 * scale, math.pi * 1.2, math.pi * 1.7)

    -- Body (steel chainmail over cloth)
    love.graphics.setColor(clothDark[1], clothDark[2], clothDark[3], 1)
    love.graphics.rectangle("fill", x - 8 * scale, y - 8 * scale, 16 * scale, 12 * scale, 2 * scale)
    -- Steel chainmail
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.rectangle("fill", x - 6 * scale, y - 7 * scale, 12 * scale, 8 * scale, 2 * scale)
    -- Armor detail (chainmail texture)
    love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.4)
    love.graphics.rectangle("fill", x - 5 * scale, y - 6 * scale, 10 * scale, 2 * scale, 1 * scale)
    love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    love.graphics.line(x, y - 7 * scale, x, y + 1 * scale)

    -- Belt (leather with iron buckle)
    love.graphics.setColor(leatherDark[1], leatherDark[2], leatherDark[3], 1)
    love.graphics.rectangle("fill", x - 7 * scale, y, 14 * scale, 3 * scale)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.rectangle("fill", x - 2 * scale, y, 4 * scale, 3 * scale)  -- Buckle
    love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    love.graphics.rectangle("fill", x - 1 * scale, y + 0.5 * scale, 2 * scale, 2 * scale)  -- Buckle center

    -- Shoulder pauldron (steel)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.ellipse("fill", x - 8 * scale, y - 6 * scale, 4 * scale, 3 * scale)
    love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.5)
    love.graphics.arc("fill", x - 8 * scale, y - 7 * scale, 3 * scale, math.pi, math.pi * 1.5)

    -- Right arm holding sword (with swing animation)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.ellipse("fill", x + 8 * scale, y - 5 * scale, 4 * scale, 3 * scale)  -- Shoulder

    -- Arm pivot point for swing
    local armPivotX = x + 8 * scale
    local armPivotY = y - 2 * scale

    -- Calculate arm and sword positions based on swing
    local armEndX = armPivotX + math.sin(swingAngle) * 8 * scale
    local armEndY = armPivotY + math.cos(swingAngle) * 8 * scale

    -- Arm
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.setLineWidth(5 * scale)
    love.graphics.line(armPivotX, armPivotY, armEndX, armEndY)

    -- Leather bracer on arm
    local bracerX = armPivotX + math.sin(swingAngle) * 4 * scale
    local bracerY = armPivotY + math.cos(swingAngle) * 4 * scale
    love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
    love.graphics.setLineWidth(6 * scale)
    love.graphics.line(bracerX - math.sin(swingAngle) * 1.5 * scale,
                       bracerY - math.cos(swingAngle) * 1.5 * scale,
                       bracerX + math.sin(swingAngle) * 1.5 * scale,
                       bracerY + math.cos(swingAngle) * 1.5 * scale)

    -- Hand at end of arm
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.circle("fill", armEndX, armEndY, 3 * scale)

    -- Sword extends from hand (with swing rotation)
    local swordLength = 20 * scale
    local swordEndX = armEndX + math.sin(swingAngle) * swordLength
    local swordEndY = armEndY + math.cos(swingAngle) * swordLength

    -- Sword blade
    love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 1)
    love.graphics.setLineWidth(3 * scale)
    love.graphics.line(armEndX, armEndY, swordEndX, swordEndY)
    -- Sword highlight
    love.graphics.setColor(0.85, 0.87, 0.9, 0.6)
    love.graphics.setLineWidth(1 * scale)
    local highlightOffsetX = math.cos(swingAngle) * 1 * scale
    local highlightOffsetY = -math.sin(swingAngle) * 1 * scale
    love.graphics.line(armEndX + highlightOffsetX, armEndY + highlightOffsetY,
                       swordEndX + highlightOffsetX, swordEndY + highlightOffsetY)

    -- Sword hilt
    love.graphics.setColor(leatherDark[1], leatherDark[2], leatherDark[3], 1)
    love.graphics.setLineWidth(2 * scale)
    local hiltStartX = armEndX - math.sin(swingAngle) * 3 * scale
    local hiltStartY = armEndY - math.cos(swingAngle) * 3 * scale
    love.graphics.line(armEndX, armEndY, hiltStartX, hiltStartY)

    -- Crossguard (perpendicular to sword)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    local crossX = math.cos(swingAngle) * 4 * scale
    local crossY = -math.sin(swingAngle) * 4 * scale
    love.graphics.line(armEndX - crossX, armEndY - crossY, armEndX + crossX, armEndY + crossY)

    -- Head
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.ellipse("fill", x, y - 12 * scale, 6 * scale, 7 * scale)

    if isOrc then
        -- Orc features: no hair showing, just helmet and tusks
        -- Darker green shadow on face
        love.graphics.setColor(skinShadow[1], skinShadow[2], skinShadow[3], 0.5)
        love.graphics.ellipse("fill", x + 2 * scale, y - 10 * scale, 3 * scale, 4 * scale)

        -- Tusks (iconic orc feature)
        love.graphics.setColor(0.9, 0.88, 0.82, 1)  -- Ivory color
        love.graphics.polygon("fill", x - 4 * scale, y - 8 * scale, x - 5 * scale, y - 4 * scale, x - 3 * scale, y - 7 * scale)
        love.graphics.polygon("fill", x + 4 * scale, y - 8 * scale, x + 5 * scale, y - 4 * scale, x + 3 * scale, y - 7 * scale)

        -- Crude iron helmet (more brutal looking)
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.arc("fill", x, y - 14 * scale, 7 * scale, math.pi * 1.0, math.pi * 2.0)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.4)
        love.graphics.arc("fill", x - 2 * scale, y - 15 * scale, 4 * scale, math.pi * 1.2, math.pi * 1.6)
        -- Helmet spikes
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
        love.graphics.polygon("fill", x - 5 * scale, y - 18 * scale, x - 4 * scale, y - 22 * scale, x - 3 * scale, y - 18 * scale)
        love.graphics.polygon("fill", x + 3 * scale, y - 18 * scale, x + 4 * scale, y - 22 * scale, x + 5 * scale, y - 18 * scale)
        -- Face guard
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    else
        -- Human features: hair and steel helmet
        -- Dark brown hair
        love.graphics.setColor(0.25, 0.18, 0.12, 1)
        love.graphics.ellipse("fill", x, y - 15 * scale, 7 * scale, 5 * scale)
        -- Hair detail
        love.graphics.setColor(0.32, 0.24, 0.18, 1)
        love.graphics.ellipse("fill", x + 4 * scale, y - 14 * scale, 4 * scale, 3 * scale)
        love.graphics.ellipse("fill", x - 3 * scale, y - 16 * scale, 3 * scale, 2 * scale)

        -- Steel helmet (open face)
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.arc("fill", x, y - 14 * scale, 7 * scale, math.pi * 1.1, math.pi * 1.9)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.6)
        love.graphics.arc("fill", x - 2 * scale, y - 15 * scale, 5 * scale, math.pi * 1.2, math.pi * 1.6)
        -- Nose guard
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
        love.graphics.rectangle("fill", x - 1 * scale, y - 15 * scale, 2 * scale, 5 * scale)
    end

    -- Eyes
    if isOrc and accentGlow then
        -- Glowing red/orange eyes for orcs
        love.graphics.setColor(0.9, 0.3, 0.1, 1)
        love.graphics.circle("fill", x - 2 * scale, y - 12 * scale, 1.5 * scale)
        love.graphics.circle("fill", x + 2 * scale, y - 12 * scale, 1.5 * scale)
        -- Eye glow
        love.graphics.setColor(1.0, 0.5, 0.2, 0.4)
        love.graphics.circle("fill", x - 2 * scale, y - 12 * scale, 2.5 * scale)
        love.graphics.circle("fill", x + 2 * scale, y - 12 * scale, 2.5 * scale)
    else
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
        love.graphics.circle("fill", x - 2 * scale, y - 12 * scale, 1.5 * scale)
        love.graphics.circle("fill", x + 2 * scale, y - 12 * scale, 1.5 * scale)
    end

    -- Cloth tabard from belt
    love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 0.9)
    love.graphics.polygon("fill", x - 2 * scale, y + 3 * scale, x + 2 * scale, y + 3 * scale, x + 3 * scale, y + 10 * scale, x - 3 * scale, y + 10 * scale)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Footman:drawOnMinimap(mapX, mapY, scale)
    -- Use team-appropriate color
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
