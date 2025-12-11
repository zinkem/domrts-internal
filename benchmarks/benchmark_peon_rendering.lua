--[[
    Benchmark: Peon Rendering - Canvas Caching vs Live Drawing

    Compares the performance of:
    - OLD: Drawing ~35 primitives per peon, 5x for outline (175 draw calls per peon)
    - NEW: Drawing 5 canvas blits per peon (4 outline + 1 main)

    Run with: love . --benchmark-peon-rendering
]]

local Benchmark = {}

-- Mock DrawUtils for fallback path
local MockDrawUtils = {
    getIdleBob = function(seed, scale) return math.sin(seed) * scale end,
    drawShadow = function() end,
    drawSelection = function() end,
    applyFlash = function(entity, drawFn) drawFn() end,
}

-- Mock peon states
local STATE_IDLE = "Idle"
local STATE_MOVING = "Moving"
local STATE_CHOPPING = "Chopping"
local STATE_HARVESTING = "Harvesting"
local STATE_RETURNING = "Returning"

-- Animation frame counts
local ANIM_FRAMES = {
    idle = 4,
    walk = 6,
    chop = 8,
    harvest = 6,
}

-- Create mock peons with various states
local function createMockPeons(count)
    local peons = {}
    local states = {STATE_IDLE, STATE_MOVING, STATE_CHOPPING, STATE_HARVESTING, STATE_RETURNING}
    local carries = {"none", "gold", "lumber"}

    for i = 1, count do
        local state = states[(i % #states) + 1]
        local carry = carries[(i % #carries) + 1]
        -- Override carry for work states
        if state == STATE_CHOPPING or state == STATE_HARVESTING then
            carry = "none"
        end

        table.insert(peons, {
            x = 100 + (i % 20) * 50,
            y = 100 + math.floor(i / 20) * 50,
            state = state,
            carryingGold = carry == "gold" and 10 or 0,
            carryingLumber = carry == "lumber" and 10 or 0,
            animTimer = math.random() * 10,
            idleSeed = math.random() * 100,
            flashTimer = 0,
            selected = i % 10 == 0,
            radius = 14,
        })
    end
    return peons
end

-- Draw peon body at position (OLD method - live primitives)
local function drawPeonBodyLive(x, y, peon)
    local breathe = math.sin(peon.animTimer * 2 + peon.idleSeed) * 0.5

    -- Feet
    love.graphics.setColor(0.4, 0.3, 0.2, 1)
    love.graphics.ellipse("fill", x - 5, y + 7, 5, 3)
    love.graphics.ellipse("fill", x + 5, y + 7, 5, 3)

    -- Legs
    love.graphics.setColor(0.5, 0.35, 0.25, 1)
    love.graphics.rectangle("fill", x - 6, y + 2, 5, 7, 1)
    love.graphics.rectangle("fill", x + 1, y + 2, 5, 7, 1)

    -- Body
    love.graphics.setColor(0.55, 0.45, 0.35, 1)
    love.graphics.rectangle("fill", x - 8 - breathe * 0.5, y - 6, 16 + breathe, 12, 2)

    -- Belt
    love.graphics.setColor(0.35, 0.25, 0.15, 1)
    love.graphics.rectangle("fill", x - 8, y + 1, 16, 3)
    love.graphics.setColor(0.6, 0.5, 0.2, 1)
    love.graphics.rectangle("fill", x - 2, y + 1, 4, 3)

    -- Arms
    local armSwing = 0
    if peon.state == STATE_MOVING or peon.state == STATE_RETURNING then
        armSwing = math.sin(peon.animTimer * 10) * 2
    end
    love.graphics.setColor(0.55, 0.45, 0.35, 1)
    love.graphics.rectangle("fill", x - 11, y - 4 + armSwing, 5, 10, 1)
    love.graphics.rectangle("fill", x + 6, y - 4 - armSwing, 5, 10, 1)

    -- Hands
    love.graphics.setColor(0.85, 0.7, 0.55, 1)
    love.graphics.circle("fill", x - 9, y + 4 + armSwing, 3)
    love.graphics.circle("fill", x + 9, y + 4 - armSwing, 3)

    -- Head
    love.graphics.setColor(0.85, 0.7, 0.55, 1)
    love.graphics.ellipse("fill", x, y - 10, 6, 7)

    -- Hood/cap
    love.graphics.setColor(0.5, 0.4, 0.3, 1)
    love.graphics.arc("fill", x, y - 10, 7, math.pi, 2 * math.pi)
    love.graphics.rectangle("fill", x - 7, y - 12, 14, 4, 1)

    -- Face
    love.graphics.setColor(0.15, 0.1, 0.05, 1)
    love.graphics.circle("fill", x - 2, y - 11, 1.5)
    love.graphics.circle("fill", x + 2, y - 11, 1.5)
    love.graphics.setColor(0.7, 0.5, 0.4, 1)
    love.graphics.ellipse("fill", x, y - 8, 2, 1.5)

    -- Tool
    if peon.state == STATE_CHOPPING or peon.carryingLumber > 0 then
        local axeAngle = 0
        if peon.state == STATE_CHOPPING then
            axeAngle = math.sin(peon.animTimer * 12) * 0.4
        end
        love.graphics.push()
        love.graphics.translate(x + 12, y)
        love.graphics.rotate(axeAngle)
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", -2, -8, 2, 14, 1)
        love.graphics.setColor(0.65, 0.65, 0.7, 1)
        love.graphics.polygon("fill", -3, -8, 4, -6, 4, -2, -3, -4)
        love.graphics.setColor(0.85, 0.85, 0.9, 0.6)
        love.graphics.line(-1, -7, 2, -5)
        love.graphics.pop()
    elseif peon.state == STATE_HARVESTING or peon.carryingGold > 0 then
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
        love.graphics.rectangle("fill", x + 10, y - 6, 2, 12, 1)
        love.graphics.setColor(0.55, 0.55, 0.6, 1)
        love.graphics.polygon("fill", x + 8, y - 8, x + 18, y - 6, x + 14, y - 2)
        love.graphics.setColor(0.75, 0.75, 0.8, 0.5)
        love.graphics.line(x + 10, y - 7, x + 15, y - 5)
    end

    -- Carried resources
    if peon.carryingGold > 0 then
        love.graphics.setColor(0.65, 0.5, 0.12, 1)
        love.graphics.ellipse("fill", x, y - 2, 7, 6)
        love.graphics.setColor(0.9, 0.75, 0.15, 1)
        love.graphics.circle("fill", x - 2, y - 3, 3)
        love.graphics.circle("fill", x + 2, y - 1, 2.5)
        love.graphics.setColor(1, 0.95, 0.5, 0.7)
        love.graphics.circle("fill", x - 3, y - 4, 1.5)
    elseif peon.carryingLumber > 0 then
        love.graphics.setColor(0.5, 0.35, 0.18, 1)
        love.graphics.rectangle("fill", x - 4, y - 14, 3, 12, 1)
        love.graphics.setColor(0.55, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", x - 1, y - 16, 3, 14, 1)
        love.graphics.setColor(0.5, 0.36, 0.19, 1)
        love.graphics.rectangle("fill", x + 2, y - 13, 3, 11, 1)
        love.graphics.setColor(0.65, 0.5, 0.3, 0.5)
        love.graphics.line(x - 3, y - 13, x - 3, y - 5)
        love.graphics.line(x, y - 15, x, y - 4)
    end
end

-- Draw peon with outline (OLD method)
local function drawPeonOld(peon)
    local x, y = peon.x, peon.y

    -- Calculate y offset
    local yOffset = 0
    if peon.state == STATE_CHOPPING then
        yOffset = math.abs(math.sin(peon.animTimer * 12)) * 6
    elseif peon.state == STATE_MOVING or peon.state == STATE_RETURNING then
        yOffset = math.abs(math.sin(peon.animTimer * 10)) * 2
    elseif peon.state == STATE_IDLE then
        yOffset = math.sin(peon.animTimer * 1.5 + peon.idleSeed) * 1.2
    end
    y = y - yOffset

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x, peon.y + 10, 11, 4)

    -- Outline (4 offset draws)
    love.graphics.setColor(0.1, 0.08, 0.05, 0.7)
    local offsets = {{-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5}}
    for _, off in ipairs(offsets) do
        love.graphics.push()
        love.graphics.translate(off[1], off[2])
        drawPeonBodyLive(x, y, peon)
        love.graphics.pop()
    end

    -- Main body
    drawPeonBodyLive(x, y, peon)
end

-- Create sprite cache (NEW method setup)
local function createSpriteCache()
    local SpriteCache = require("sprite_cache")
    local cache = SpriteCache.new(64, 64, {originX = 32, originY = 54})

    local carryStates = {"none", "gold", "lumber"}

    -- Helper to draw body at origin for caching
    local function drawBodyAtOrigin(params)
        local x, y = 0, 0
        local breathe = params.breathe or 0
        local armSwing = params.armSwing or 0
        local carry = params.carry or "none"
        local axeAngle = params.axeAngle or 0
        local showAxe = params.showAxe
        local showPickaxe = params.showPickaxe

        -- Feet
        love.graphics.setColor(0.4, 0.3, 0.2, 1)
        love.graphics.ellipse("fill", x - 5, y + 7, 5, 3)
        love.graphics.ellipse("fill", x + 5, y + 7, 5, 3)

        -- Legs
        love.graphics.setColor(0.5, 0.35, 0.25, 1)
        love.graphics.rectangle("fill", x - 6, y + 2, 5, 7, 1)
        love.graphics.rectangle("fill", x + 1, y + 2, 5, 7, 1)

        -- Body
        love.graphics.setColor(0.55, 0.45, 0.35, 1)
        love.graphics.rectangle("fill", x - 8 - breathe * 0.5, y - 6, 16 + breathe, 12, 2)

        -- Belt
        love.graphics.setColor(0.35, 0.25, 0.15, 1)
        love.graphics.rectangle("fill", x - 8, y + 1, 16, 3)
        love.graphics.setColor(0.6, 0.5, 0.2, 1)
        love.graphics.rectangle("fill", x - 2, y + 1, 4, 3)

        -- Arms
        love.graphics.setColor(0.55, 0.45, 0.35, 1)
        love.graphics.rectangle("fill", x - 11, y - 4 + armSwing, 5, 10, 1)
        love.graphics.rectangle("fill", x + 6, y - 4 - armSwing, 5, 10, 1)

        -- Hands
        love.graphics.setColor(0.85, 0.7, 0.55, 1)
        love.graphics.circle("fill", x - 9, y + 4 + armSwing, 3)
        love.graphics.circle("fill", x + 9, y + 4 - armSwing, 3)

        -- Head
        love.graphics.setColor(0.85, 0.7, 0.55, 1)
        love.graphics.ellipse("fill", x, y - 10, 6, 7)

        -- Hood/cap
        love.graphics.setColor(0.5, 0.4, 0.3, 1)
        love.graphics.arc("fill", x, y - 10, 7, math.pi, 2 * math.pi)
        love.graphics.rectangle("fill", x - 7, y - 12, 14, 4, 1)

        -- Face
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
        love.graphics.circle("fill", x - 2, y - 11, 1.5)
        love.graphics.circle("fill", x + 2, y - 11, 1.5)
        love.graphics.setColor(0.7, 0.5, 0.4, 1)
        love.graphics.ellipse("fill", x, y - 8, 2, 1.5)

        -- Tool
        if showAxe or carry == "lumber" then
            love.graphics.push()
            love.graphics.translate(x + 12, y)
            love.graphics.rotate(axeAngle)
            love.graphics.setColor(0.5, 0.35, 0.2, 1)
            love.graphics.rectangle("fill", -2, -8, 2, 14, 1)
            love.graphics.setColor(0.65, 0.65, 0.7, 1)
            love.graphics.polygon("fill", -3, -8, 4, -6, 4, -2, -3, -4)
            love.graphics.setColor(0.85, 0.85, 0.9, 0.6)
            love.graphics.line(-1, -7, 2, -5)
            love.graphics.pop()
        elseif showPickaxe or carry == "gold" then
            love.graphics.setColor(0.5, 0.35, 0.2, 1)
            love.graphics.rectangle("fill", x + 10, y - 6, 2, 12, 1)
            love.graphics.setColor(0.55, 0.55, 0.6, 1)
            love.graphics.polygon("fill", x + 8, y - 8, x + 18, y - 6, x + 14, y - 2)
            love.graphics.setColor(0.75, 0.75, 0.8, 0.5)
            love.graphics.line(x + 10, y - 7, x + 15, y - 5)
        end

        -- Carried resources
        if carry == "gold" then
            love.graphics.setColor(0.65, 0.5, 0.12, 1)
            love.graphics.ellipse("fill", x, y - 2, 7, 6)
            love.graphics.setColor(0.9, 0.75, 0.15, 1)
            love.graphics.circle("fill", x - 2, y - 3, 3)
            love.graphics.circle("fill", x + 2, y - 1, 2.5)
            love.graphics.setColor(1, 0.95, 0.5, 0.7)
            love.graphics.circle("fill", x - 3, y - 4, 1.5)
        elseif carry == "lumber" then
            love.graphics.setColor(0.5, 0.35, 0.18, 1)
            love.graphics.rectangle("fill", x - 4, y - 14, 3, 12, 1)
            love.graphics.setColor(0.55, 0.4, 0.2, 1)
            love.graphics.rectangle("fill", x - 1, y - 16, 3, 14, 1)
            love.graphics.setColor(0.5, 0.36, 0.19, 1)
            love.graphics.rectangle("fill", x + 2, y - 13, 3, 11, 1)
            love.graphics.setColor(0.65, 0.5, 0.3, 0.5)
            love.graphics.line(x - 3, y - 13, x - 3, y - 5)
            love.graphics.line(x, y - 15, x, y - 4)
        end
    end

    -- Prerender idle
    local idleFrames = {}
    for i = 0, ANIM_FRAMES.idle - 1 do table.insert(idleFrames, i) end
    cache:prerender("idle", function(params)
        local phase = params.frame / ANIM_FRAMES.idle * math.pi * 2
        drawBodyAtOrigin({carry = params.carry, breathe = math.sin(phase) * 0.5})
    end, {carry = carryStates, frame = idleFrames})

    -- Prerender walk
    local walkFrames = {}
    for i = 0, ANIM_FRAMES.walk - 1 do table.insert(walkFrames, i) end
    cache:prerender("walk", function(params)
        local phase = params.frame / ANIM_FRAMES.walk * math.pi * 2
        drawBodyAtOrigin({carry = params.carry, armSwing = math.sin(phase) * 2})
    end, {carry = carryStates, frame = walkFrames})

    -- Prerender chop
    local chopFrames = {}
    for i = 0, ANIM_FRAMES.chop - 1 do table.insert(chopFrames, i) end
    cache:prerender("chop", function(params)
        local phase = params.frame / ANIM_FRAMES.chop * math.pi * 2
        drawBodyAtOrigin({carry = "none", showAxe = true, axeAngle = math.sin(phase) * 0.4})
    end, {carry = {"none"}, frame = chopFrames})

    -- Prerender harvest
    local harvestFrames = {}
    for i = 0, ANIM_FRAMES.harvest - 1 do table.insert(harvestFrames, i) end
    cache:prerender("harvest", function(params)
        local phase = params.frame / ANIM_FRAMES.harvest * math.pi * 2
        drawBodyAtOrigin({carry = "none", showPickaxe = true, armSwing = math.sin(phase) * 1.5})
    end, {carry = {"none"}, frame = harvestFrames})

    return cache
end

-- Get visual state for cache lookup
local function getVisualState(peon)
    local state, frameCount, animSpeed

    if peon.state == STATE_CHOPPING then
        state = "chop"
        frameCount = ANIM_FRAMES.chop
        animSpeed = 12
    elseif peon.state == STATE_HARVESTING then
        state = "harvest"
        frameCount = ANIM_FRAMES.harvest
        animSpeed = 8
    elseif peon.state == STATE_MOVING or peon.state == STATE_RETURNING then
        state = "walk"
        frameCount = ANIM_FRAMES.walk
        animSpeed = 10
    else
        state = "idle"
        frameCount = ANIM_FRAMES.idle
        animSpeed = 1.5
    end

    local carry
    if peon.carryingGold > 0 then
        carry = "gold"
    elseif peon.carryingLumber > 0 then
        carry = "lumber"
    else
        carry = "none"
    end

    if state == "chop" or state == "harvest" then
        carry = "none"
    end

    local frame = math.floor((peon.animTimer * animSpeed) % frameCount)

    local yOffset = 0
    if state == "chop" then
        yOffset = math.abs(math.sin(peon.animTimer * 12)) * 6
    elseif state == "walk" then
        yOffset = math.abs(math.sin(peon.animTimer * 10)) * 2
    elseif state == "idle" then
        yOffset = math.sin(peon.animTimer * 1.5 + peon.idleSeed) * 1.2
    end

    return state, carry, frame, yOffset
end

-- Draw peon using cached canvas (NEW method)
local function drawPeonNew(peon, cache)
    local x, y = peon.x, peon.y
    local state, carry, frame, yOffset = getVisualState(peon)
    y = y - yOffset

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", x, peon.y + 10, 11, 4)

    -- Get cached canvas
    local canvas = cache:get(state, carry, frame)
    if canvas then
        local drawX = x - 32
        local drawY = y - 54

        -- Outline (4 canvas blits)
        love.graphics.setColor(0.1, 0.08, 0.05, 0.7)
        local offsets = {{-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5}}
        for _, off in ipairs(offsets) do
            love.graphics.draw(canvas, drawX + off[1], drawY + off[2])
        end

        -- Main sprite
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, drawX, drawY)
    end
end

function Benchmark.run()
    print("\n" .. string.rep("=", 60))
    print("BENCHMARK: Peon Rendering - Canvas Caching vs Live Drawing")
    print(string.rep("=", 60))

    local scenarios = {
        {peons = 10, name = "Small army (10 peons)"},
        {peons = 30, name = "Medium army (30 peons)"},
        {peons = 60, name = "Large army (60 peons)"},
        {peons = 100, name = "Stress test (100 peons)"},
    }

    local iterations = 100

    -- Create sprite cache once
    print("\nCreating sprite cache...")
    local cache = createSpriteCache()
    local stats = cache:getStats()
    print(string.format("  Cached %d canvases (%.2f MB VRAM)\n", stats.canvasCount, stats.memoryMB))

    for _, scenario in ipairs(scenarios) do
        print(string.format("--- %s ---", scenario.name))

        local peons = createMockPeons(scenario.peons)

        -- ===== OLD METHOD (live primitives) =====
        local startOld = love.timer.getTime()
        local oldDrawCalls = 0
        for i = 1, iterations do
            for _, peon in ipairs(peons) do
                drawPeonOld(peon)
                -- ~35 primitives * 5 (4 outline + 1 main) = 175 per peon
                oldDrawCalls = oldDrawCalls + 175
                peon.animTimer = peon.animTimer + 0.016
            end
        end
        local timeOld = love.timer.getTime() - startOld

        -- Reset anim timers
        for _, peon in ipairs(peons) do
            peon.animTimer = math.random() * 10
        end

        -- ===== NEW METHOD (cached canvases) =====
        local startNew = love.timer.getTime()
        local newDrawCalls = 0
        for i = 1, iterations do
            for _, peon in ipairs(peons) do
                drawPeonNew(peon, cache)
                -- 1 shadow + 5 canvas blits = 6 per peon
                newDrawCalls = newDrawCalls + 6
                peon.animTimer = peon.animTimer + 0.016
            end
        end
        local timeNew = love.timer.getTime() - startNew

        local speedup = timeOld / timeNew
        local drawCallReduction = oldDrawCalls / newDrawCalls

        print(string.format("  OLD (live):   %.4fs (%d draw calls)", timeOld, oldDrawCalls))
        print(string.format("  NEW (cached): %.4fs (%d draw calls)", timeNew, newDrawCalls))
        print(string.format("  Speedup: %.2fx faster", speedup))
        print(string.format("  Draw calls reduced: %.1fx fewer", drawCallReduction))
        print()
    end

    print(string.rep("=", 60))
    print("Benchmark complete!")
    print(string.rep("=", 60) .. "\n")

    love.event.quit()
end

return Benchmark
