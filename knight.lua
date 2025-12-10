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
        love.graphics.circle("fill", x, y, 22)
        love.graphics.setColor(holyGreenGlow[1], holyGreenGlow[2], holyGreenGlow[3], 0.08)
        love.graphics.circle("fill", x, y, 28)
    elseif isOrc and accentGlow then
        love.graphics.setColor(accentGlow[1], accentGlow[2], accentGlow[3], 0.12)
        love.graphics.circle("fill", x, y, 20)
    end

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x, y + 12, 14, 5)

    -- Mount body (horse or wolf)
    love.graphics.setColor(mountColor[1], mountColor[2], mountColor[3], 1)
    if isOrc then
        -- Wolf body (slightly different shape - more hunched)
        love.graphics.ellipse("fill", x, y + 3, 13, 7)
    else
        -- Horse body
        love.graphics.ellipse("fill", x, y + 4, 14, 8)
    end

    -- Mount legs
    love.graphics.setColor(mountColorDark[1], mountColorDark[2], mountColorDark[3], 1)
    love.graphics.rectangle("fill", x - 8, y + 6, 3, 8, 1)
    love.graphics.rectangle("fill", x - 3, y + 7, 3, 7, 1)
    love.graphics.rectangle("fill", x + 3, y + 7, 3, 7, 1)
    love.graphics.rectangle("fill", x + 8, y + 6, 3, 8, 1)

    -- Leg armor (steel for knight, silver for paladin, none for orc)
    if not isOrc then
        if self.isPaladin then
            love.graphics.setColor(silverMid[1], silverMid[2], silverMid[3], 0.8)
        else
            love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 0.8)
        end
        love.graphics.rectangle("fill", x - 8, y + 10, 3, 2)
        love.graphics.rectangle("fill", x + 8, y + 10, 3, 2)
    end

    -- Hooves/Paws
    if isOrc then
        -- Wolf paws (slightly larger, darker)
        love.graphics.setColor(0.18, 0.16, 0.14, 1)
    else
        love.graphics.setColor(0.25, 0.22, 0.2, 1)
    end
    love.graphics.ellipse("fill", x - 7, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x - 2, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x + 4, y + 14, 2, 1.5)
    love.graphics.ellipse("fill", x + 9, y + 14, 2, 1.5)

    -- Mount neck and head
    love.graphics.setColor(mountColor[1], mountColor[2], mountColor[3], 1)
    if isOrc then
        -- Wolf head (more angular, with snout)
        love.graphics.polygon("fill", x + 8, y + 1, x + 16, y - 6, x + 18, y - 4, x + 12, y + 3)
        love.graphics.ellipse("fill", x + 18, y - 6, 6, 4)  -- Wolf head
        -- Wolf ears (pointed)
        love.graphics.polygon("fill", x + 14, y - 9, x + 16, y - 14, x + 18, y - 9)
        love.graphics.polygon("fill", x + 19, y - 9, x + 21, y - 14, x + 23, y - 9)
        -- Wolf snout
        love.graphics.setColor(mountColorDark[1], mountColorDark[2], mountColorDark[3], 1)
        love.graphics.ellipse("fill", x + 24, y - 5, 3, 2)
    else
        -- Horse neck and head
        love.graphics.polygon("fill", x + 10, y + 2, x + 18, y - 8, x + 20, y - 6, x + 14, y + 4)
        love.graphics.ellipse("fill", x + 20, y - 8, 5, 4)
        -- Horse ears
        love.graphics.polygon("fill", x + 18, y - 12, x + 20, y - 16, x + 22, y - 11)
    end

    -- Mount eye
    if isOrc then
        -- Wolf eye (yellow/amber, predatory)
        love.graphics.setColor(0.9, 0.7, 0.2, 1)
        love.graphics.circle("fill", x + 19, y - 7, 1.2)
        love.graphics.setColor(0.1, 0.05, 0.0, 1)
        love.graphics.circle("fill", x + 19, y - 7, 0.6)
    else
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
        love.graphics.circle("fill", x + 21, y - 9, 1)
    end

    -- Mane/Fur and Tail
    if isOrc then
        -- Wolf has no mane, but has fur tufts
        love.graphics.setColor(mountColorDark[1], mountColorDark[2], mountColorDark[3], 1)
        -- Fur on back
        love.graphics.polygon("fill", x + 8, y - 2, x + 10, y - 5, x + 12, y - 1)
        -- Wolf tail (bushy)
        love.graphics.setColor(mountColor[1], mountColor[2], mountColor[3], 1)
        love.graphics.polygon("fill", x - 12, y + 1, x - 20, y + 4, x - 18, y + 8, x - 12, y + 5)
        love.graphics.setColor(mountColorDark[1], mountColorDark[2], mountColorDark[3], 0.6)
        love.graphics.polygon("fill", x - 14, y + 3, x - 18, y + 5, x - 16, y + 7, x - 13, y + 5)
    else
        if self.isPaladin then
            love.graphics.setColor(0.85, 0.85, 0.88, 1)  -- Silver-white mane
        else
            love.graphics.setColor(0.2, 0.15, 0.1, 1)  -- Dark brown mane
        end
        love.graphics.polygon("fill", x + 12, y - 2, x + 16, y - 10, x + 18, y - 6, x + 14, y + 2)
        -- Horse tail
        love.graphics.polygon("fill", x - 14, y + 2, x - 18, y + 8, x - 14, y + 10, x - 12, y + 6)
    end

    -- Bridle/Reins (horse) or nothing (wolf)
    if not isOrc then
        if self.isPaladin then
            love.graphics.setColor(silverLight[1], silverLight[2], silverLight[3], 1)
        else
            love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        end
        love.graphics.setLineWidth(1.5)
        love.graphics.line(x + 18, y - 6, x + 24, y - 8)
        love.graphics.circle("fill", x + 18, y - 7, 2)
    end

    -- Blanket under saddle
    if isOrc then
        -- Crude leather/fur blanket for orc
        love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 1)
        love.graphics.polygon("fill", x - 9, y - 3, x + 9, y - 3, x + 11, y + 5, x - 11, y + 5)
        -- Blood-red trim
        love.graphics.setColor(0.6, 0.2, 0.15, 0.9)
        love.graphics.rectangle("fill", x - 9, y + 3, 18, 2)
    else
        if self.isPaladin then
            love.graphics.setColor(0.92, 0.94, 0.98, 1)  -- White/silver blanket
        else
            love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 1)  -- Dark cloth blanket
        end
        love.graphics.polygon("fill", x - 10, y - 2, x + 10, y - 2, x + 12, y + 6, x - 12, y + 6)
        -- Blanket trim
        if self.isPaladin then
            love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.8)
        else
            love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        end
        love.graphics.rectangle("fill", x - 10, y + 4, 20, 2)
    end

    -- Saddle
    love.graphics.setColor(leatherDark[1], leatherDark[2], leatherDark[3], 1)
    love.graphics.ellipse("fill", x, y - 2, 8, 5)
    love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 0.5)
    love.graphics.ellipse("fill", x - 2, y - 3, 4, 2)

    -- Rider armor
    if isOrc then
        -- Orc raider: crude dark iron armor, green skin showing
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.rectangle("fill", x - 5, y - 14, 10, 12, 2)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.3)
        love.graphics.rectangle("fill", x - 4, y - 13, 8, 3, 1)
        -- Spikes on shoulders
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
        love.graphics.polygon("fill", x - 6, y - 12, x - 8, y - 17, x - 4, y - 12)
        love.graphics.polygon("fill", x + 4, y - 12, x + 6, y - 17, x + 8, y - 12)
    elseif self.isPaladin then
        -- Silver plate armor with glow
        love.graphics.setColor(silverMid[1], silverMid[2], silverMid[3], 1)
        love.graphics.rectangle("fill", x - 5, y - 14, 10, 12, 2)
        love.graphics.setColor(silverLight[1], silverLight[2], silverLight[3], 0.7)
        love.graphics.rectangle("fill", x - 4, y - 13, 8, 4, 1)
        -- Holy symbol on chest
        love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.9)
        love.graphics.circle("fill", x, y - 8, 3)
        love.graphics.setColor(holyGreenGlow[1], holyGreenGlow[2], holyGreenGlow[3], 0.5)
        love.graphics.circle("fill", x, y - 8, 4)
    else
        -- Steel plate armor
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.rectangle("fill", x - 5, y - 14, 10, 12, 2)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.5)
        love.graphics.rectangle("fill", x - 4, y - 13, 8, 4, 1)
    end
    love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
    love.graphics.line(x, y - 14, x, y - 3)

    -- Cape (no cape for orc)
    if not isOrc then
        if self.isPaladin then
            love.graphics.setColor(0.95, 0.95, 0.98, 1)  -- White cape
        else
            love.graphics.setColor(clothMid[1], clothMid[2], clothMid[3], 1)  -- Dark cape
        end
        love.graphics.polygon("fill", x - 4, y - 10, x - 12, y + 4, x - 2, y + 2)
        -- Cape highlight
        if self.isPaladin then
            love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.3)
        else
            love.graphics.setColor(0.45, 0.42, 0.48, 0.5)
        end
        love.graphics.polygon("fill", x - 4, y - 10, x - 8, y, x - 3, y - 2)
    end

    -- Head/helmet
    if isOrc then
        -- Orc head: green skin, tusks, crude helmet
        love.graphics.setColor(skin[1], skin[2], skin[3], 1)
        love.graphics.ellipse("fill", x, y - 18, 5, 6)
        -- Tusks
        love.graphics.setColor(0.9, 0.88, 0.82, 1)
        love.graphics.polygon("fill", x - 3, y - 14, x - 4, y - 10, x - 2, y - 13)
        love.graphics.polygon("fill", x + 3, y - 14, x + 4, y - 10, x + 2, y - 13)
        -- Crude helmet
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.arc("fill", x, y - 19, 5, math.pi * 1.0, math.pi * 2.0)
        -- Helmet spike
        love.graphics.setColor(steelDark[1], steelDark[2], steelDark[3], 1)
        love.graphics.polygon("fill", x - 1, y - 23, x, y - 28, x + 1, y - 23)
        -- Glowing eyes
        love.graphics.setColor(0.9, 0.3, 0.1, 1)
        love.graphics.circle("fill", x - 2, y - 18, 1.2)
        love.graphics.circle("fill", x + 2, y - 18, 1.2)
        love.graphics.setColor(1.0, 0.5, 0.2, 0.5)
        love.graphics.circle("fill", x - 2, y - 18, 2)
        love.graphics.circle("fill", x + 2, y - 18, 2)
    elseif self.isPaladin then
        love.graphics.setColor(silverMid[1], silverMid[2], silverMid[3], 1)
        love.graphics.ellipse("fill", x, y - 18, 5, 6)
        love.graphics.setColor(silverLight[1], silverLight[2], silverLight[3], 0.7)
        love.graphics.arc("fill", x, y - 19, 4, math.pi, math.pi * 1.8)
    else
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.ellipse("fill", x, y - 18, 5, 6)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.5)
        love.graphics.arc("fill", x, y - 19, 4, math.pi, math.pi * 1.8)
    end

    -- Helmet plume (not for orc - they have spike)
    if not isOrc then
        if self.isPaladin then
            love.graphics.setColor(0.95, 0.97, 1.0, 1)  -- White plume
            love.graphics.polygon("fill", x - 2, y - 24, x + 4, y - 28, x + 2, y - 18)
            -- Glowing effect on plume
            love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.4)
            love.graphics.polygon("fill", x - 1, y - 23, x + 3, y - 26, x + 1, y - 19)
        else
            love.graphics.setColor(0.5, 0.15, 0.15, 1)  -- Dark red plume
            love.graphics.polygon("fill", x - 2, y - 24, x + 4, y - 28, x + 2, y - 18)
        end
    end

    -- Weapon: Lance (human) or Axe (orc)
    if isOrc then
        -- Brutal war axe
        love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(x + 8, y - 6, x + 16, y - 24)
        -- Axe head
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.polygon("fill", x + 14, y - 22, x + 22, y - 28, x + 20, y - 20, x + 16, y - 18)
        love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 0.5)
        love.graphics.polygon("fill", x + 15, y - 22, x + 19, y - 26, x + 18, y - 21)
        -- Fel glow on axe (optional)
        if accentGlow then
            love.graphics.setColor(accentGlow[1], accentGlow[2], accentGlow[3], 0.3)
            love.graphics.circle("fill", x + 18, y - 24, 4)
        end
    else
        -- Lance
        love.graphics.setColor(leatherMid[1], leatherMid[2], leatherMid[3], 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(x + 8, y - 8, x + 20, y - 30)
        -- Lance tip
        if self.isPaladin then
            love.graphics.setColor(silverLight[1], silverLight[2], silverLight[3], 1)
            love.graphics.polygon("fill", x + 19, y - 30, x + 21, y - 30, x + 20, y - 36)
            -- Holy glow on lance tip
            love.graphics.setColor(holyGreen[1], holyGreen[2], holyGreen[3], 0.5)
            love.graphics.circle("fill", x + 20, y - 33, 3)
        else
            love.graphics.setColor(steelLight[1], steelLight[2], steelLight[3], 1)
            love.graphics.polygon("fill", x + 19, y - 30, x + 21, y - 30, x + 20, y - 36)
        end
        -- Lance bands
        love.graphics.setColor(steelMid[1], steelMid[2], steelMid[3], 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 12, y - 16, x + 14, y - 18)
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
