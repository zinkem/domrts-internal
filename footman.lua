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
        love.graphics.circle("fill", x, y, 18)
    end

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x, y + 10, 12, 4)

    -- Feet (leather boots)
    love.graphics.setColor(leatherDark[1], leatherDark[2], leatherDark[3], 1)
    love.graphics.ellipse("fill", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("fill", x + 5, y + 8, 4, 3)
    love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
    love.graphics.ellipse("line", x - 5, y + 8, 4, 3)
    love.graphics.ellipse("line", x + 5, y + 8, 4, 3)

    -- Legs (dark cloth pants)
    love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 1)
    love.graphics.rectangle("fill", x - 6, y + 1, 5, 9, 1)
    love.graphics.rectangle("fill", x + 1, y + 1, 5, 9, 1)
    -- Fabric highlight
    love.graphics.setColor(clothLight[1], clothLight[2], clothLight[3], 0.5)
    love.graphics.rectangle("fill", x - 5, y + 2, 2, 7, 1)

    -- Shield on left arm (steel kite shield)
    love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    love.graphics.ellipse("fill", x - 12, y - 2, 7, 11)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", x - 12, y - 2, 7, 11)
    -- Shield design (cross)
    love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
    love.graphics.rectangle("fill", x - 13, y - 6, 2, 10)
    love.graphics.rectangle("fill", x - 16, y - 3, 8, 2)
    love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 1)
    love.graphics.circle("fill", x - 12, y - 2, 2)
    -- Shield highlight
    love.graphics.setColor(0.8, 0.82, 0.85, 0.3)
    love.graphics.arc("fill", x - 13, y - 4, 5, math.pi * 1.2, math.pi * 1.7)

    -- Body (steel chainmail over cloth)
    love.graphics.setColor(clothDark[1], clothDark[2], clothDark[3], 1)
    love.graphics.rectangle("fill", x - 8, y - 8, 16, 12, 2)
    -- Steel chainmail
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.rectangle("fill", x - 6, y - 7, 12, 8, 2)
    -- Armor detail (chainmail texture)
    love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.4)
    love.graphics.rectangle("fill", x - 5, y - 6, 10, 2, 1)
    love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    love.graphics.line(x, y - 7, x, y + 1)

    -- Belt (leather with iron buckle)
    love.graphics.setColor(leatherDark[1], leatherDark[2], leatherDark[3], 1)
    love.graphics.rectangle("fill", x - 7, y, 14, 3)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.rectangle("fill", x - 2, y, 4, 3)  -- Buckle
    love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    love.graphics.rectangle("fill", x - 1, y + 0.5, 2, 2)  -- Buckle center

    -- Shoulder pauldron (steel)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.ellipse("fill", x - 8, y - 6, 4, 3)
    love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.5)
    love.graphics.arc("fill", x - 8, y - 7, 3, math.pi, math.pi * 1.5)

    -- Right arm holding sword
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.ellipse("fill", x + 8, y - 5, 4, 3)  -- Shoulder
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.rectangle("fill", x + 6, y - 2, 5, 8, 1)  -- Arm
    -- Leather bracer
    love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
    love.graphics.rectangle("fill", x + 6, y + 2, 5, 3, 1)

    -- Hand
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.circle("fill", x + 9, y + 6, 3)

    -- Sword (straight longsword)
    love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 1)
    love.graphics.setLineWidth(3)
    love.graphics.line(x + 9, y + 4, x + 9, y - 16)
    love.graphics.setColor(0.85, 0.87, 0.9, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 8, y + 2, x + 8, y - 14)
    -- Steel hilt
    love.graphics.setColor(leatherDark[1], leatherDark[2], leatherDark[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(x + 9, y + 4, x + 9, y + 7)
    love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
    love.graphics.line(x + 5, y + 4, x + 13, y + 4)  -- Crossguard

    -- Head
    love.graphics.setColor(skin[1], skin[2], skin[3], 1)
    love.graphics.ellipse("fill", x, y - 12, 6, 7)

    if isOrc then
        -- Orc features: no hair showing, just helmet and tusks
        -- Darker green shadow on face
        love.graphics.setColor(skinShadow[1], skinShadow[2], skinShadow[3], 0.5)
        love.graphics.ellipse("fill", x + 2, y - 10, 3, 4)

        -- Tusks (iconic orc feature)
        love.graphics.setColor(0.9, 0.88, 0.82, 1)  -- Ivory color
        love.graphics.polygon("fill", x - 4, y - 8, x - 5, y - 4, x - 3, y - 7)
        love.graphics.polygon("fill", x + 4, y - 8, x + 5, y - 4, x + 3, y - 7)

        -- Crude iron helmet (more brutal looking)
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.arc("fill", x, y - 14, 7, math.pi * 1.0, math.pi * 2.0)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.4)
        love.graphics.arc("fill", x - 2, y - 15, 4, math.pi * 1.2, math.pi * 1.6)
        -- Helmet spikes
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
        love.graphics.polygon("fill", x - 5, y - 18, x - 4, y - 22, x - 3, y - 18)
        love.graphics.polygon("fill", x + 3, y - 18, x + 4, y - 22, x + 5, y - 18)
        -- Face guard
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    else
        -- Human features: hair and steel helmet
        -- Dark brown hair
        love.graphics.setColor(0.25, 0.18, 0.12, 1)
        love.graphics.ellipse("fill", x, y - 15, 7, 5)
        -- Hair detail
        love.graphics.setColor(0.32, 0.24, 0.18, 1)
        love.graphics.ellipse("fill", x + 4, y - 14, 4, 3)
        love.graphics.ellipse("fill", x - 3, y - 16, 3, 2)

        -- Steel helmet (open face)
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.arc("fill", x, y - 14, 7, math.pi * 1.1, math.pi * 1.9)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.6)
        love.graphics.arc("fill", x - 2, y - 15, 5, math.pi * 1.2, math.pi * 1.6)
        -- Nose guard
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
        love.graphics.rectangle("fill", x - 1, y - 15, 2, 5)
    end

    -- Eyes
    if isOrc and accentGlow then
        -- Glowing red/orange eyes for orcs
        love.graphics.setColor(0.9, 0.3, 0.1, 1)
        love.graphics.circle("fill", x - 2, y - 12, 1.5)
        love.graphics.circle("fill", x + 2, y - 12, 1.5)
        -- Eye glow
        love.graphics.setColor(1.0, 0.5, 0.2, 0.4)
        love.graphics.circle("fill", x - 2, y - 12, 2.5)
        love.graphics.circle("fill", x + 2, y - 12, 2.5)
    else
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
        love.graphics.circle("fill", x - 2, y - 12, 1.5)
        love.graphics.circle("fill", x + 2, y - 12, 1.5)
    end

    -- Cloth tabard from belt
    love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 0.9)
    love.graphics.polygon("fill", x - 2, y + 3, x + 2, y + 3, x + 3, y + 10, x - 3, y + 10)

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
