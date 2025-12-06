--[[
    Teams Module
    Defines team colors and identifiers for faction differentiation
    
    Each team has:
    - primary: Main color (tunics, shields, banners)
    - secondary: Lighter accent (highlights, trim)
    - dark: Darker shade (shadows, outlines)
    - banner: Banner/flag background
    - emblem: Emblem/symbol color on banners
]]

local Teams = {}

-- Team IDs
Teams.PLAYER = 1
Teams.ENEMY = 2
Teams.NEUTRAL = 0

-- Color palettes for each team
Teams.colors = {
    [Teams.PLAYER] = {
        name = "Blue",
        primary = {0.25, 0.45, 0.75, 1},      -- Blue tunic/shirt
        secondary = {0.35, 0.55, 0.85, 1},    -- Lighter blue highlights
        dark = {0.15, 0.25, 0.45, 1},         -- Dark blue shadows
        banner = {0.2, 0.4, 0.8, 1},          -- Blue banner
        emblem = {0.9, 0.8, 0.3, 1},          -- Gold emblem
        minimapUnit = {0.3, 0.6, 1, 1},       -- Bright blue for minimap
        minimapBuilding = {0.2, 0.45, 0.8, 1},
    },
    [Teams.ENEMY] = {
        name = "Red",
        primary = {0.7, 0.25, 0.2, 1},        -- Red tunic/shirt
        secondary = {0.85, 0.35, 0.3, 1},     -- Lighter red highlights
        dark = {0.4, 0.12, 0.1, 1},           -- Dark red shadows
        banner = {0.75, 0.15, 0.15, 1},       -- Red banner
        emblem = {0.15, 0.15, 0.15, 1},       -- Black emblem
        minimapUnit = {1, 0.3, 0.3, 1},       -- Bright red for minimap
        minimapBuilding = {0.8, 0.2, 0.2, 1},
    },
    [Teams.NEUTRAL] = {
        name = "Neutral",
        primary = {0.5, 0.5, 0.45, 1},        -- Gray
        secondary = {0.6, 0.6, 0.55, 1},
        dark = {0.35, 0.35, 0.3, 1},
        banner = {0.5, 0.5, 0.45, 1},
        emblem = {0.7, 0.65, 0.5, 1},
        minimapUnit = {0.6, 0.6, 0.55, 1},
        minimapBuilding = {0.5, 0.5, 0.45, 1},
    },
}

-- Get team colors, with fallback to neutral
function Teams.getColors(teamId)
    return Teams.colors[teamId] or Teams.colors[Teams.NEUTRAL]
end

-- Get a specific color component for a team
function Teams.getColor(teamId, colorName)
    local teamColors = Teams.getColors(teamId)
    return teamColors[colorName] or teamColors.primary
end

-- Check if two entities are on the same team
function Teams.isSameTeam(entity1, entity2)
    local team1 = entity1.team or Teams.NEUTRAL
    local team2 = entity2.team or Teams.NEUTRAL
    return team1 == team2
end

-- Check if two entities are enemies
function Teams.isEnemy(entity1, entity2)
    local team1 = entity1.team or Teams.NEUTRAL
    local team2 = entity2.team or Teams.NEUTRAL
    -- Neutral is not enemy to anyone
    if team1 == Teams.NEUTRAL or team2 == Teams.NEUTRAL then
        return false
    end
    return team1 ~= team2
end

-- Check if entity belongs to the human player
function Teams.isPlayerOwned(entity)
    return entity.team == Teams.PLAYER
end

-- Helper to apply team color with optional alpha
function Teams.setColor(teamId, colorName, alpha)
    local color = Teams.getColor(teamId, colorName)
    love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

return Teams
