--[[
    Effects System
    Handles particles, flashes, and visual effects for drama
]]

local Effects = {}
Effects.__index = Effects

-- Particle types
Effects.DUST = "dust"
Effects.BLOOD = "blood"
Effects.SPARK = "spark"
Effects.GOLD_SPARKLE = "gold_sparkle"
Effects.WOOD_CHIP = "wood_chip"
Effects.LEAF = "leaf"
Effects.SMOKE = "smoke"

-- Global effects instance
local particles = {}
local flashes = {}  -- Screen flashes / unit flashes

function Effects.init()
    particles = {}
    flashes = {}
end

-- Spawn a single particle
function Effects.spawn(type, x, y, params)
    params = params or {}
    
    local p = {
        type = type,
        x = x,
        y = y,
        vx = params.vx or 0,
        vy = params.vy or 0,
        life = params.life or 1.0,
        maxLife = params.life or 1.0,
        size = params.size or 3,
        sizeEnd = params.sizeEnd or params.size or 3,
        color = params.color or {1, 1, 1, 1},
        colorEnd = params.colorEnd or params.color or {1, 1, 1, 0},
        gravity = params.gravity or 0,
        friction = params.friction or 0.98,
        rotation = params.rotation or 0,
        rotationSpeed = params.rotationSpeed or 0,
    }
    
    table.insert(particles, p)
    return p
end

-- Spawn multiple particles in a burst
function Effects.burst(type, x, y, count, params)
    params = params or {}
    local spread = params.spread or 50
    local speedMin = params.speedMin or 20
    local speedMax = params.speedMax or 60
    
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = speedMin + math.random() * (speedMax - speedMin)
        
        local pParams = {
            vx = math.cos(angle) * speed + (params.vx or 0),
            vy = math.sin(angle) * speed + (params.vy or 0),
            life = params.life or (0.3 + math.random() * 0.4),
            size = params.size or (2 + math.random() * 2),
            sizeEnd = params.sizeEnd or 0,
            color = params.color,
            colorEnd = params.colorEnd,
            gravity = params.gravity or 100,
            friction = params.friction or 0.95,
            rotation = math.random() * math.pi * 2,
            rotationSpeed = (math.random() - 0.5) * 10,
        }
        
        Effects.spawn(type, x + (math.random() - 0.5) * spread * 0.3, y + (math.random() - 0.5) * spread * 0.3, pParams)
    end
end

-- Preset effect: Dust cloud (movement, landing)
function Effects.dustCloud(x, y, intensity)
    intensity = intensity or 1
    local count = math.floor(3 * intensity)
    Effects.burst(Effects.DUST, x, y, count, {
        spread = 10,
        speedMin = 10,
        speedMax = 30,
        life = 0.4 + math.random() * 0.3,
        size = 4 + math.random() * 3,
        sizeEnd = 8,
        color = {0.6, 0.55, 0.4, 0.5},
        colorEnd = {0.7, 0.65, 0.5, 0},
        gravity = -20,  -- Rise slightly
        friction = 0.92,
    })
end

-- Preset effect: Footstep dust
function Effects.footstep(x, y)
    Effects.spawn(Effects.DUST, x, y, {
        vx = (math.random() - 0.5) * 15,
        vy = -10 - math.random() * 10,
        life = 0.3,
        size = 2 + math.random() * 2,
        sizeEnd = 4,
        color = {0.55, 0.5, 0.4, 0.4},
        colorEnd = {0.6, 0.55, 0.45, 0},
        gravity = 20,
        friction = 0.9,
    })
end

-- Preset effect: Blood splatter (combat)
function Effects.blood(x, y, direction)
    direction = direction or 0
    Effects.burst(Effects.BLOOD, x, y, 5, {
        spread = 8,
        speedMin = 40,
        speedMax = 100,
        vx = math.cos(direction) * 30,
        vy = math.sin(direction) * 30 - 20,
        life = 0.5,
        size = 3,
        sizeEnd = 1,
        color = {0.7, 0.1, 0.1, 0.9},
        colorEnd = {0.5, 0.05, 0.05, 0},
        gravity = 200,
        friction = 0.96,
    })
end

-- Preset effect: Metal sparks (weapon clash)
function Effects.sparks(x, y)
    Effects.burst(Effects.SPARK, x, y, 8, {
        spread = 5,
        speedMin = 80,
        speedMax = 150,
        life = 0.2 + math.random() * 0.2,
        size = 2,
        sizeEnd = 0,
        color = {1, 0.9, 0.5, 1},
        colorEnd = {1, 0.5, 0.2, 0},
        gravity = 150,
        friction = 0.98,
    })
end

-- Preset effect: Gold sparkle (resource pickup)
function Effects.goldSparkle(x, y)
    Effects.burst(Effects.GOLD_SPARKLE, x, y, 6, {
        spread = 15,
        speedMin = 20,
        speedMax = 50,
        life = 0.5,
        size = 3,
        sizeEnd = 0,
        color = {1, 0.85, 0.2, 1},
        colorEnd = {1, 0.7, 0.1, 0},
        gravity = -30,  -- Float up
        friction = 0.95,
    })
end

-- Preset effect: Wood chips (chopping)
function Effects.woodChips(x, y)
    Effects.burst(Effects.WOOD_CHIP, x, y, 4, {
        spread = 10,
        speedMin = 50,
        speedMax = 100,
        life = 0.6,
        size = 3,
        sizeEnd = 2,
        color = {0.6, 0.45, 0.25, 1},
        colorEnd = {0.5, 0.35, 0.2, 0},
        gravity = 250,
        friction = 0.97,
        rotationSpeed = 15,
    })
end

-- Preset effect: Falling leaf
function Effects.leaf(x, y)
    local drift = (math.random() - 0.5) * 30
    Effects.spawn(Effects.LEAF, x, y, {
        vx = drift,
        vy = 5,
        life = 2.0 + math.random() * 1.0,
        size = 3 + math.random() * 2,
        sizeEnd = 3,
        color = {0.2 + math.random() * 0.2, 0.5 + math.random() * 0.2, 0.15, 0.8},
        colorEnd = {0.3, 0.4, 0.1, 0},
        gravity = 15,
        friction = 0.99,
        rotation = math.random() * math.pi * 2,
        rotationSpeed = (math.random() - 0.5) * 3,
    })
end

-- Preset effect: Smoke (buildings, fires)
function Effects.smoke(x, y, intensity)
    intensity = intensity or 1
    Effects.spawn(Effects.SMOKE, x, y, {
        vx = (math.random() - 0.5) * 10,
        vy = -20 - math.random() * 20 * intensity,
        life = 1.5 + math.random() * 0.5,
        size = 5 + math.random() * 5,
        sizeEnd = 15 + math.random() * 10,
        color = {0.3, 0.3, 0.3, 0.4 * intensity},
        colorEnd = {0.4, 0.4, 0.4, 0},
        gravity = -10,
        friction = 0.98,
    })
end

-- Add a flash effect to a unit (damage, heal, etc)
function Effects.flash(entity, color, duration)
    table.insert(flashes, {
        entity = entity,
        color = color or {1, 1, 1, 0.8},
        duration = duration or 0.15,
        timer = 0,
    })
end

-- Damage flash (white)
function Effects.damageFlash(entity)
    Effects.flash(entity, {1, 1, 1, 0.9}, 0.12)
end

-- Heal flash (green)
function Effects.healFlash(entity)
    Effects.flash(entity, {0.3, 1, 0.3, 0.7}, 0.2)
end

-- Check if entity has active flash
function Effects.getFlash(entity)
    for _, f in ipairs(flashes) do
        if f.entity == entity then
            local alpha = 1 - (f.timer / f.duration)
            return {f.color[1], f.color[2], f.color[3], f.color[4] * alpha}
        end
    end
    return nil
end

-- Update all particles and flashes
function Effects.update(dt)
    -- Update particles
    local i = 1
    while i <= #particles do
        local p = particles[i]
        
        -- Physics
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + p.gravity * dt
        p.vx = p.vx * p.friction
        p.vy = p.vy * p.friction
        p.rotation = p.rotation + p.rotationSpeed * dt
        
        -- Life
        p.life = p.life - dt
        
        if p.life <= 0 then
            table.remove(particles, i)
        else
            i = i + 1
        end
    end
    
    -- Update flashes
    local j = 1
    while j <= #flashes do
        local f = flashes[j]
        f.timer = f.timer + dt
        if f.timer >= f.duration then
            table.remove(flashes, j)
        else
            j = j + 1
        end
    end
end

-- Draw all particles (call after drawing entities)
function Effects.draw(map)
    for _, p in ipairs(particles) do
        -- Convert to screen coords if map provided
        local sx, sy = p.x, p.y
        if map then
            sx, sy = map:worldToScreen(p.x, p.y)
        end
        
        -- Interpolate color and size based on life
        local t = 1 - (p.life / p.maxLife)
        local r = p.color[1] + (p.colorEnd[1] - p.color[1]) * t
        local g = p.color[2] + (p.colorEnd[2] - p.color[2]) * t
        local b = p.color[3] + (p.colorEnd[3] - p.color[3]) * t
        local a = p.color[4] + (p.colorEnd[4] - p.color[4]) * t
        local size = p.size + (p.sizeEnd - p.size) * t
        
        love.graphics.setColor(r, g, b, a)
        
        -- Draw based on type
        if p.type == Effects.DUST or p.type == Effects.SMOKE then
            love.graphics.circle("fill", sx, sy, size)
        elseif p.type == Effects.BLOOD then
            love.graphics.circle("fill", sx, sy, size)
        elseif p.type == Effects.SPARK or p.type == Effects.GOLD_SPARKLE then
            -- Diamond shape for sparkles
            love.graphics.push()
            love.graphics.translate(sx, sy)
            love.graphics.rotate(p.rotation)
            love.graphics.polygon("fill", 0, -size, size * 0.5, 0, 0, size, -size * 0.5, 0)
            love.graphics.pop()
        elseif p.type == Effects.WOOD_CHIP then
            -- Small rectangle
            love.graphics.push()
            love.graphics.translate(sx, sy)
            love.graphics.rotate(p.rotation)
            love.graphics.rectangle("fill", -size/2, -size/4, size, size/2)
            love.graphics.pop()
        elseif p.type == Effects.LEAF then
            -- Oval leaf shape
            love.graphics.push()
            love.graphics.translate(sx, sy)
            love.graphics.rotate(p.rotation)
            love.graphics.ellipse("fill", 0, 0, size, size * 0.5)
            love.graphics.pop()
        else
            love.graphics.circle("fill", sx, sy, size)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Get particle count (for debugging)
function Effects.getCount()
    return #particles
end

-- Clear all effects
function Effects.clear()
    particles = {}
    flashes = {}
end

return Effects
