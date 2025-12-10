--[[
    Knight - Mounted cavalry unit
    Inherits from Unit base class
    Can be upgraded to Paladin (visual change)
    Enemy variant: Orc Wolf Raider
]]

local Unit = require("unit")

-- Teams module for faction check
local Teams
pcall(function() Teams = require("teams") end)

local Knight = setmetatable({}, {__index = Unit})
Knight.__index = Knight

Knight.RADIUS = 16  -- Larger due to horse/wolf
Knight.SPEED = 120

function Knight.new(params)
    local self = Unit.new(params)
    setmetatable(self, Knight)

    self.radius = Knight.RADIUS
    self.speed = Knight.SPEED
    self.type = "knight"
    self.isPaladin = params.isPaladin or false

    -- Set name based on team and upgrade status
    if Teams and self.team == Teams.ENEMY then
        self.name = "Raider"  -- Orc wolf raider
    elseif self.isPaladin then
        self.name = "Paladin"
    else
        self.name = "Knight"
    end

    return self
end

function Knight:draw()
    local x, y = self:getScreenPos()

    -- Visual scale factor (2x size for better visibility)
    local scale = 2

    -- Attack animation: lance thrust / axe swing
    local attackAnim = 0
    if self.attackAnimTimer and self.attackAnimTimer > 0 then
        -- Thrust forward (0 to 1 and back) over 0.3 seconds
        local progress = 1 - (self.attackAnimTimer / 0.3)
        attackAnim = math.sin(progress * math.pi)  -- 0 -> 1 -> 0
    end

    -- Check if this is an enemy (orc) unit
    local isOrc = Teams and self.team == Teams.ENEMY

    -- Palette selection based on faction
    local steelDark, steelMid, steelLight
    local leatherDark, leatherMid
    local skin, clothDark, clothMid
    local silverDark, silverMid, silverLight
    local holyGreen, holyGreenGlow
    local mountColor, mountColorDark
    local accentGlow

    if isOrc then
        -- Orc Raider palette (dark iron, crude leather, wolf mount)
        steelDark = {0.25, 0.22, 0.20}
        steelMid = {0.40, 0.35, 0.30}
        steelLight = {0.55, 0.50, 0.42}
        leatherDark = {0.32, 0.25, 0.18}
        leatherMid = {0.48, 0.38, 0.25}
        skin = {0.45, 0.55, 0.35}           -- Orc green skin
        clothDark = {0.28, 0.18, 0.12}
        clothMid = {0.45, 0.28, 0.18}
        -- Wolf mount colors (dark gray/black)
        mountColor = {0.35, 0.32, 0.30}
        mountColorDark = {0.22, 0.20, 0.18}
        accentGlow = {0.4, 0.85, 0.35}      -- Fel green
        -- No paladin equivalents for orcs
        silverDark = steelDark
        silverMid = steelMid
        silverLight = steelLight
        holyGreen = accentGlow
        holyGreenGlow = {0.5, 0.95, 0.45}
    else
        -- Human palette
        steelDark = {0.35, 0.38, 0.42}
        steelMid = {0.55, 0.58, 0.62}
        steelLight = {0.72, 0.74, 0.78}
        leatherDark = {0.28, 0.22, 0.18}
        leatherMid = {0.45, 0.36, 0.28}
        skin = {0.78, 0.62, 0.52}
        clothDark = {0.22, 0.20, 0.25}
        clothMid = {0.35, 0.32, 0.38}
        -- Paladin palette (silver/white with holy green glow)
        silverDark = {0.60, 0.62, 0.68}
        silverMid = {0.78, 0.80, 0.85}
        silverLight = {0.92, 0.94, 0.98}
        holyGreen = {0.45, 0.85, 0.42}
        holyGreenGlow = {0.55, 0.95, 0.52}
        -- Horse colors
        mountColor = {0.55, 0.42, 0.32}
        mountColorDark = {0.38, 0.28, 0.22}
        accentGlow = nil
    end

    -- Adjust mount color for paladin (white horse)
    if self.isPaladin and not isOrc then
        mountColor = {0.95, 0.95, 0.98}
        mountColorDark = {0.88, 0.88, 0.92}
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

    -- Glow effect (holy for paladin, fel for orc)
    if self.isPaladin and not isOrc then
        love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.15)
        love.graphics.circle("fill", x, y, 22 * scale)
        love.graphics.setColor(holyGreenGlow[1], holyGreenGlow[2], holyGreenGlow[3], 0.08)
        love.graphics.circle("fill", x, y, 28 * scale)
    elseif isOrc and accentGlow then
        love.graphics.setColor(accentGlow[1], accentGlow[2], accentGlow[3], 0.12)
        love.graphics.circle("fill", x, y, 20 * scale)
    end

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x, y + 12 * scale, 14 * scale, 5 * scale)

    -- Mount body (horse or wolf)
    love.graphics.setColor(mountColor[1], mountColor[2], mountColor[3], 1)
    if isOrc then
        -- Wolf body (slightly different shape - more hunched)
        love.graphics.ellipse("fill", x, y + 3 * scale, 13 * scale, 7 * scale)
    else
        -- Horse body
        love.graphics.ellipse("fill", x, y + 4 * scale, 14 * scale, 8 * scale)
    end

    -- Mount legs
    love.graphics.setColor(mountColorDark[1], mountColorDark[2], mountColorDark[3], 1)
    love.graphics.rectangle("fill", x - 8 * scale, y + 6 * scale, 3 * scale, 8 * scale, 1 * scale)
    love.graphics.rectangle("fill", x - 3 * scale, y + 7 * scale, 3 * scale, 7 * scale, 1 * scale)
    love.graphics.rectangle("fill", x + 3 * scale, y + 7 * scale, 3 * scale, 7 * scale, 1 * scale)
    love.graphics.rectangle("fill", x + 8 * scale, y + 6 * scale, 3 * scale, 8 * scale, 1 * scale)

    -- Leg armor (steel for knight, silver for paladin, none for orc)
    if not isOrc then
        if self.isPaladin then
            love.graphics.setColor(silverMid[1], silverMid[2], silverMid[3], 0.8)
        else
            love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 0.8)
        end
        love.graphics.rectangle("fill", x - 8 * scale, y + 10 * scale, 3 * scale, 2 * scale)
        love.graphics.rectangle("fill", x + 8 * scale, y + 10 * scale, 3 * scale, 2 * scale)
    end

    -- Hooves/Paws
    if isOrc then
        -- Wolf paws (slightly larger, darker)
        love.graphics.setColor(0.18, 0.16, 0.14, 1)
    else
        love.graphics.setColor(0.25, 0.22, 0.2, 1)
    end
    love.graphics.ellipse("fill", x - 7 * scale, y + 14 * scale, 2 * scale, 1.5 * scale)
    love.graphics.ellipse("fill", x - 2 * scale, y + 14 * scale, 2 * scale, 1.5 * scale)
    love.graphics.ellipse("fill", x + 4 * scale, y + 14 * scale, 2 * scale, 1.5 * scale)
    love.graphics.ellipse("fill", x + 9 * scale, y + 14 * scale, 2 * scale, 1.5 * scale)

    -- Mount neck and head
    love.graphics.setColor(mountColor[1], mountColor[2], mountColor[3], 1)
    if isOrc then
        -- Wolf head (more angular, with snout)
        love.graphics.polygon("fill", x + 8 * scale, y + 1 * scale, x + 16 * scale, y - 6 * scale, x + 18 * scale, y - 4 * scale, x + 12 * scale, y + 3 * scale)
        love.graphics.ellipse("fill", x + 18 * scale, y - 6 * scale, 6 * scale, 4 * scale)  -- Wolf head
        -- Wolf ears (pointed)
        love.graphics.polygon("fill", x + 14 * scale, y - 9 * scale, x + 16 * scale, y - 14 * scale, x + 18 * scale, y - 9 * scale)
        love.graphics.polygon("fill", x + 19 * scale, y - 9 * scale, x + 21 * scale, y - 14 * scale, x + 23 * scale, y - 9 * scale)
        -- Wolf snout
        love.graphics.setColor(mountColorDark[1], mountColorDark[2], mountColorDark[3], 1)
        love.graphics.ellipse("fill", x + 24 * scale, y - 5 * scale, 3 * scale, 2 * scale)
    else
        -- Horse neck and head
        love.graphics.polygon("fill", x + 10 * scale, y + 2 * scale, x + 18 * scale, y - 8 * scale, x + 20 * scale, y - 6 * scale, x + 14 * scale, y + 4 * scale)
        love.graphics.ellipse("fill", x + 20 * scale, y - 8 * scale, 5 * scale, 4 * scale)
        -- Horse ears
        love.graphics.polygon("fill", x + 18 * scale, y - 12 * scale, x + 20 * scale, y - 16 * scale, x + 22 * scale, y - 11 * scale)
    end

    -- Mount eye
    if isOrc then
        -- Wolf eye (yellow/amber, predatory)
        love.graphics.setColor(0.9, 0.7, 0.2, 1)
        love.graphics.circle("fill", x + 19 * scale, y - 7 * scale, 1.2 * scale)
        love.graphics.setColor(0.1, 0.05, 0.0, 1)
        love.graphics.circle("fill", x + 19 * scale, y - 7 * scale, 0.6 * scale)
    else
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
        love.graphics.circle("fill", x + 21 * scale, y - 9 * scale, 1 * scale)
    end

    -- Mane/Fur and Tail
    if isOrc then
        -- Wolf has no mane, but has fur tufts
        love.graphics.setColor(mountColorDark[1], mountColorDark[2], mountColorDark[3], 1)
        -- Fur on back
        love.graphics.polygon("fill", x + 8 * scale, y - 2 * scale, x + 10 * scale, y - 5 * scale, x + 12 * scale, y - 1 * scale)
        -- Wolf tail (bushy)
        love.graphics.setColor(mountColor[1], mountColor[2], mountColor[3], 1)
        love.graphics.polygon("fill", x - 12 * scale, y + 1 * scale, x - 20 * scale, y + 4 * scale, x - 18 * scale, y + 8 * scale, x - 12 * scale, y + 5 * scale)
        love.graphics.setColor(mountColorDark[1], mountColorDark[2], mountColorDark[3], 0.6)
        love.graphics.polygon("fill", x - 14 * scale, y + 3 * scale, x - 18 * scale, y + 5 * scale, x - 16 * scale, y + 7 * scale, x - 13 * scale, y + 5 * scale)
    else
        if self.isPaladin then
            love.graphics.setColor(0.85, 0.85, 0.88, 1)  -- Silver-white mane
        else
            love.graphics.setColor(0.2, 0.15, 0.1, 1)  -- Dark brown mane
        end
        love.graphics.polygon("fill", x + 12 * scale, y - 2 * scale, x + 16 * scale, y - 10 * scale, x + 18 * scale, y - 6 * scale, x + 14 * scale, y + 2 * scale)
        -- Horse tail
        love.graphics.polygon("fill", x - 14 * scale, y + 2 * scale, x - 18 * scale, y + 8 * scale, x - 14 * scale, y + 10 * scale, x - 12 * scale, y + 6 * scale)
    end

    -- Bridle/Reins (horse) or nothing (wolf)
    if not isOrc then
        if self.isPaladin then
            love.graphics.setColor(silverLight[1], silverLight[2], silverLight[3], 1)
        else
            love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        end
        love.graphics.setLineWidth(1.5 * scale)
        love.graphics.line(x + 18 * scale, y - 6 * scale, x + 24 * scale, y - 8 * scale)
        love.graphics.circle("fill", x + 18 * scale, y - 7 * scale, 2 * scale)
    end

    -- Blanket under saddle
    if isOrc then
        -- Crude leather/fur blanket for orc
        love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 1)
        love.graphics.polygon("fill", x - 9 * scale, y - 3 * scale, x + 9 * scale, y - 3 * scale, x + 11 * scale, y + 5 * scale, x - 11 * scale, y + 5 * scale)
        -- Blood-red trim
        love.graphics.setColor(0.6, 0.2, 0.15, 0.9)
        love.graphics.rectangle("fill", x - 9 * scale, y + 3 * scale, 18 * scale, 2 * scale)
    else
        if self.isPaladin then
            love.graphics.setColor(0.92, 0.94, 0.98, 1)  -- White/silver blanket
        else
            love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 1)  -- Dark cloth blanket
        end
        love.graphics.polygon("fill", x - 10 * scale, y - 2 * scale, x + 10 * scale, y - 2 * scale, x + 12 * scale, y + 6 * scale, x - 12 * scale, y + 6 * scale)
        -- Blanket trim
        if self.isPaladin then
            love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.8)
        else
            love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        end
        love.graphics.rectangle("fill", x - 10 * scale, y + 4 * scale, 20 * scale, 2 * scale)
    end

    -- Saddle
    love.graphics.setColor(leatherDark[1], leatherDark[2], leatherDark[3], 1)
    love.graphics.ellipse("fill", x, y - 2 * scale, 8 * scale, 5 * scale)
    love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 0.5)
    love.graphics.ellipse("fill", x - 2 * scale, y - 3 * scale, 4 * scale, 2 * scale)

    -- Rider armor
    if isOrc then
        -- Orc raider: crude dark iron armor, green skin showing
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.rectangle("fill", x - 5 * scale, y - 14 * scale, 10 * scale, 12 * scale, 2 * scale)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.3)
        love.graphics.rectangle("fill", x - 4 * scale, y - 13 * scale, 8 * scale, 3 * scale, 1 * scale)
        -- Spikes on shoulders
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
        love.graphics.polygon("fill", x - 6 * scale, y - 12 * scale, x - 8 * scale, y - 17 * scale, x - 4 * scale, y - 12 * scale)
        love.graphics.polygon("fill", x + 4 * scale, y - 12 * scale, x + 6 * scale, y - 17 * scale, x + 8 * scale, y - 12 * scale)
    elseif self.isPaladin then
        -- Silver plate armor with glow
        love.graphics.setColor(silverMid[1], silverMid[2], silverMid[3], 1)
        love.graphics.rectangle("fill", x - 5 * scale, y - 14 * scale, 10 * scale, 12 * scale, 2 * scale)
        love.graphics.setColor(silverLight[1], silverLight[2], silverLight[3], 0.7)
        love.graphics.rectangle("fill", x - 4 * scale, y - 13 * scale, 8 * scale, 4 * scale, 1 * scale)
        -- Holy symbol on chest
        love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.9)
        love.graphics.circle("fill", x, y - 8 * scale, 3 * scale)
        love.graphics.setColor(holyGreenGlow[1], holyGreenGlow[2], holyGreenGlow[3], 0.5)
        love.graphics.circle("fill", x, y - 8 * scale, 4 * scale)
    else
        -- Steel plate armor
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.rectangle("fill", x - 5 * scale, y - 14 * scale, 10 * scale, 12 * scale, 2 * scale)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.5)
        love.graphics.rectangle("fill", x - 4 * scale, y - 13 * scale, 8 * scale, 4 * scale, 1 * scale)
    end
    love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    love.graphics.line(x, y - 14 * scale, x, y - 3 * scale)

    -- Cape (no cape for orc)
    if not isOrc then
        if self.isPaladin then
            love.graphics.setColor(0.95, 0.95, 0.98, 1)  -- White cape
        else
            love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 1)  -- Dark cape
        end
        love.graphics.polygon("fill", x - 4 * scale, y - 10 * scale, x - 12 * scale, y + 4 * scale, x - 2 * scale, y + 2 * scale)
        -- Cape highlight
        if self.isPaladin then
            love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.3)
        else
            love.graphics.setColor(0.45, 0.42, 0.48, 0.5)
        end
        love.graphics.polygon("fill", x - 4 * scale, y - 10 * scale, x - 8 * scale, y, x - 3 * scale, y - 2 * scale)
    end

    -- Head/helmet
    if isOrc then
        -- Orc head: green skin, tusks, crude helmet
        love.graphics.setColor(skin[1], skin[2], skin[3], 1)
        love.graphics.ellipse("fill", x, y - 18 * scale, 5 * scale, 6 * scale)
        -- Tusks
        love.graphics.setColor(0.9, 0.88, 0.82, 1)
        love.graphics.polygon("fill", x - 3 * scale, y - 14 * scale, x - 4 * scale, y - 10 * scale, x - 2 * scale, y - 13 * scale)
        love.graphics.polygon("fill", x + 3 * scale, y - 14 * scale, x + 4 * scale, y - 10 * scale, x + 2 * scale, y - 13 * scale)
        -- Crude helmet
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.arc("fill", x, y - 19 * scale, 5 * scale, math.pi * 1.0, math.pi * 2.0)
        -- Helmet spike
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
        love.graphics.polygon("fill", x - 1 * scale, y - 23 * scale, x, y - 28 * scale, x + 1 * scale, y - 23 * scale)
        -- Glowing eyes
        love.graphics.setColor(0.9, 0.3, 0.1, 1)
        love.graphics.circle("fill", x - 2 * scale, y - 18 * scale, 1.2 * scale)
        love.graphics.circle("fill", x + 2 * scale, y - 18 * scale, 1.2 * scale)
        love.graphics.setColor(1.0, 0.5, 0.2, 0.5)
        love.graphics.circle("fill", x - 2 * scale, y - 18 * scale, 2 * scale)
        love.graphics.circle("fill", x + 2 * scale, y - 18 * scale, 2 * scale)
    elseif self.isPaladin then
        love.graphics.setColor(silverMid[1], silverMid[2], silverMid[3], 1)
        love.graphics.ellipse("fill", x, y - 18 * scale, 5 * scale, 6 * scale)
        love.graphics.setColor(silverLight[1], silverLight[2], silverLight[3], 0.7)
        love.graphics.arc("fill", x, y - 19 * scale, 4 * scale, math.pi, math.pi * 1.8)
    else
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.ellipse("fill", x, y - 18 * scale, 5 * scale, 6 * scale)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.5)
        love.graphics.arc("fill", x, y - 19 * scale, 4 * scale, math.pi, math.pi * 1.8)
    end

    -- Helmet plume (not for orc - they have spike)
    if not isOrc then
        if self.isPaladin then
            love.graphics.setColor(0.95, 0.97, 1.0, 1)  -- White plume
            love.graphics.polygon("fill", x - 2 * scale, y - 24 * scale, x + 4 * scale, y - 28 * scale, x + 2 * scale, y - 18 * scale)
            -- Glowing effect on plume
            love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.4)
            love.graphics.polygon("fill", x - 1 * scale, y - 23 * scale, x + 3 * scale, y - 26 * scale, x + 1 * scale, y - 19 * scale)
        else
            love.graphics.setColor(0.5, 0.15, 0.15, 1)  -- Dark red plume
            love.graphics.polygon("fill", x - 2 * scale, y - 24 * scale, x + 4 * scale, y - 28 * scale, x + 2 * scale, y - 18 * scale)
        end
    end

    -- Weapon: Lance (human) or Axe (orc) with attack animation
    -- Attack thrust/swing offset
    local weaponOffsetX = attackAnim * 8 * scale  -- Thrust forward during attack
    local weaponOffsetY = -attackAnim * 4 * scale  -- Slightly up during attack

    if isOrc then
        -- Brutal war axe (swings down during attack)
        local axeSwing = attackAnim * 0.5  -- Rotation during attack
        love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
        love.graphics.setLineWidth(3 * scale)
        -- Axe handle
        local handleStartX = x + 8 * scale
        local handleStartY = y - 6 * scale
        local handleEndX = x + 16 * scale + weaponOffsetX
        local handleEndY = y - 24 * scale + weaponOffsetY + axeSwing * 10 * scale
        love.graphics.line(handleStartX, handleStartY, handleEndX, handleEndY)
        -- Axe head
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.polygon("fill",
            handleEndX - 2 * scale, handleEndY + 2 * scale,
            handleEndX + 6 * scale, handleEndY - 6 * scale,
            handleEndX + 4 * scale, handleEndY + 2 * scale,
            handleEndX, handleEndY + 4 * scale)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.5)
        love.graphics.polygon("fill",
            handleEndX - 1 * scale, handleEndY,
            handleEndX + 3 * scale, handleEndY - 4 * scale,
            handleEndX + 2 * scale, handleEndY + 1 * scale)
        -- Fel glow on axe (optional)
        if accentGlow then
            love.graphics.setColor(accentGlow[1], accentGlow[2], accentGlow[3], 0.3 + attackAnim * 0.3)
            love.graphics.circle("fill", handleEndX + 2 * scale, handleEndY - 2 * scale, 4 * scale)
        end
    else
        -- Lance (thrusts forward during attack)
        love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
        love.graphics.setLineWidth(3 * scale)
        local lanceStartX = x + 8 * scale
        local lanceStartY = y - 8 * scale
        local lanceEndX = x + 20 * scale + weaponOffsetX
        local lanceEndY = y - 30 * scale + weaponOffsetY
        love.graphics.line(lanceStartX, lanceStartY, lanceEndX, lanceEndY)
        -- Lance tip
        if self.isPaladin then
            love.graphics.setColor(silverLight[1], silverLight[2], silverLight[3], 1)
            love.graphics.polygon("fill",
                lanceEndX - 1 * scale, lanceEndY,
                lanceEndX + 1 * scale, lanceEndY,
                lanceEndX, lanceEndY - 6 * scale)
            -- Holy glow on lance tip (brighter during attack)
            love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.5 + attackAnim * 0.4)
            love.graphics.circle("fill", lanceEndX, lanceEndY - 3 * scale, (3 + attackAnim * 2) * scale)
        else
            love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 1)
            love.graphics.polygon("fill",
                lanceEndX - 1 * scale, lanceEndY,
                lanceEndX + 1 * scale, lanceEndY,
                lanceEndX, lanceEndY - 6 * scale)
        end
        -- Lance bands
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.setLineWidth(2 * scale)
        local bandX = lanceStartX + (lanceEndX - lanceStartX) * 0.4
        local bandY = lanceStartY + (lanceEndY - lanceStartY) * 0.4
        love.graphics.line(bandX - 1 * scale, bandY + 1 * scale, bandX + 1 * scale, bandY - 1 * scale)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function Knight:drawOnMinimap(mapX, mapY, scale)
    -- Use team-appropriate color
    if Teams then
        Teams.setColor(self.team, "minimapUnit")
    elseif self.isPaladin then
        love.graphics.setColor(0.9, 0.85, 0.3, 1)
    else
        love.graphics.setColor(0.4, 0.4, 0.7, 1)
    end
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.circle("fill", mmX, mmY, math.max(2, 3))
end

return Knight
