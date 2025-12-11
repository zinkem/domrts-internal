--[[
    Benchmark: Fog of war - Dirty-flag caching vs inline calculation

    Compares the performance of:
    - OLD: Calculate 8-neighbor alpha during draw for each visible cell
    - NEW: Dirty-flag based caching, only update changed cells

    Run with: love . --benchmark-fog-caching
]]

local Benchmark = {}

-- Fog states (matching Map constants)
local FOG_UNEXPLORED = 0
local FOG_EXPLORED = 1
local FOG_VISIBLE = 2
local FOG_SCALE = 4

-- Create a mock fog grid
local function createMockFog(mapSize)
    local fogWidth = mapSize * FOG_SCALE
    local fogHeight = mapSize * FOG_SCALE
    local fog = {}
    local fogEdgeAlpha = {}

    for y = 1, fogHeight do
        fog[y] = {}
        fogEdgeAlpha[y] = {}
        for x = 1, fogWidth do
            fog[y][x] = FOG_UNEXPLORED
            fogEdgeAlpha[y][x] = 1
        end
    end

    return fog, fogEdgeAlpha, fogWidth, fogHeight
end

-- Simulate revealing areas (like units moving)
local function revealCircle(fog, fogWidth, fogHeight, centerX, centerY, radius)
    local changed = {}
    local radiusSq = radius * radius

    for dy = -radius, radius do
        for dx = -radius, radius do
            local distSq = dx * dx + dy * dy
            if distSq <= radiusSq then
                local fx = math.floor(centerX + dx)
                local fy = math.floor(centerY + dy)
                if fx >= 1 and fx <= fogWidth and fy >= 1 and fy <= fogHeight then
                    local oldState = fog[fy][fx]
                    if oldState ~= FOG_VISIBLE then
                        fog[fy][fx] = FOG_VISIBLE
                        table.insert(changed, {fx, fy})
                    end
                end
            end
        end
    end

    return changed
end

-- OLD METHOD: Calculate alpha inline during draw (simulated)
local function getNeighborVisibilityOld(fog, fogWidth, fogHeight, fx, fy)
    if fx < 1 or fy < 1 or fx > fogWidth or fy > fogHeight then
        return FOG_UNEXPLORED
    end
    if not fog[fy] then return FOG_UNEXPLORED end
    return fog[fy][fx] or FOG_UNEXPLORED
end

local function calculateAlphaOld(fog, fogWidth, fogHeight, fx, fy)
    local fogState = fog[fy][fx]

    if fogState == FOG_UNEXPLORED then
        local brighterCount = 0
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    if getNeighborVisibilityOld(fog, fogWidth, fogHeight, fx + dx, fy + dy) > fogState then
                        brighterCount = brighterCount + 1
                    end
                end
            end
        end
        if brighterCount > 0 then
            return math.max(0.5, 1 - (brighterCount * 0.08))
        else
            return 1
        end

    elseif fogState == FOG_EXPLORED then
        local brighterCount = 0
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    if getNeighborVisibilityOld(fog, fogWidth, fogHeight, fx + dx, fy + dy) > fogState then
                        brighterCount = brighterCount + 1
                    end
                end
            end
        end
        if brighterCount > 0 then
            return math.max(0.35, 0.6 - (brighterCount * 0.04))
        else
            return 0.6
        end

    else  -- FOG_VISIBLE
        local darkerCount = 0
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    if getNeighborVisibilityOld(fog, fogWidth, fogHeight, fx + dx, fy + dy) < FOG_VISIBLE then
                        darkerCount = darkerCount + 1
                    end
                end
            end
        end
        if darkerCount > 0 then
            return math.min(0.2, darkerCount * 0.03)
        else
            return 0
        end
    end
end

-- NEW METHOD: Dirty-flag based caching
local function markFogDirty(fogDirty, fogWidth, fogHeight, fx, fy)
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = fx + dx, fy + dy
            if nx >= 1 and nx <= fogWidth and ny >= 1 and ny <= fogHeight then
                local key = ny * 100000 + nx
                fogDirty[key] = {nx, ny}
            end
        end
    end
end

local function updateFogCellAlpha(fog, fogEdgeAlpha, fogWidth, fogHeight, fx, fy)
    local fogState = fog[fy][fx]
    local alpha

    if fogState == FOG_UNEXPLORED then
        local brighterCount = 0
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    if getNeighborVisibilityOld(fog, fogWidth, fogHeight, fx + dx, fy + dy) > fogState then
                        brighterCount = brighterCount + 1
                    end
                end
            end
        end
        if brighterCount > 0 then
            alpha = math.max(0.5, 1 - (brighterCount * 0.08))
        else
            alpha = 1
        end

    elseif fogState == FOG_EXPLORED then
        local brighterCount = 0
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    if getNeighborVisibilityOld(fog, fogWidth, fogHeight, fx + dx, fy + dy) > fogState then
                        brighterCount = brighterCount + 1
                    end
                end
            end
        end
        if brighterCount > 0 then
            alpha = math.max(0.35, 0.6 - (brighterCount * 0.04))
        else
            alpha = 0.6
        end

    else  -- FOG_VISIBLE
        local darkerCount = 0
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    if getNeighborVisibilityOld(fog, fogWidth, fogHeight, fx + dx, fy + dy) < FOG_VISIBLE then
                        darkerCount = darkerCount + 1
                    end
                end
            end
        end
        if darkerCount > 0 then
            alpha = math.min(0.2, darkerCount * 0.03)
        else
            alpha = 0
        end
    end

    fogEdgeAlpha[fy][fx] = alpha
end

local function updateDirtyFogAlphas(fog, fogEdgeAlpha, fogWidth, fogHeight, fogDirty)
    for _, coords in pairs(fogDirty) do
        local fx, fy = coords[1], coords[2]
        updateFogCellAlpha(fog, fogEdgeAlpha, fogWidth, fogHeight, fx, fy)
    end
end

-- Simulate a frame with OLD method (inline calculation during draw)
local function simulateFrameOld(fog, fogWidth, fogHeight, visibleStartX, visibleStartY, visibleEndX, visibleEndY)
    local neighborChecks = 0

    for fy = visibleStartY, visibleEndY do
        for fx = visibleStartX, visibleEndX do
            local alpha = calculateAlphaOld(fog, fogWidth, fogHeight, fx, fy)
            neighborChecks = neighborChecks + 8  -- Always check 8 neighbors
            -- Simulate using the alpha (would be love.graphics.setColor in real code)
            local _ = alpha
        end
    end

    return neighborChecks
end

-- Simulate a frame with NEW method (dirty-flag caching)
local function simulateFrameNew(fog, fogEdgeAlpha, fogWidth, fogHeight, fogDirty, visibleStartX, visibleStartY, visibleEndX, visibleEndY)
    -- Update dirty cells
    local dirtyCount = 0
    for _, coords in pairs(fogDirty) do
        local fx, fy = coords[1], coords[2]
        updateFogCellAlpha(fog, fogEdgeAlpha, fogWidth, fogHeight, fx, fy)
        dirtyCount = dirtyCount + 1
    end

    -- Draw using cached values (no neighbor checks)
    for fy = visibleStartY, visibleEndY do
        local alphaRow = fogEdgeAlpha[fy]
        for fx = visibleStartX, visibleEndX do
            local alpha = alphaRow[fx]
            -- Simulate using the alpha
            local _ = alpha
        end
    end

    return dirtyCount * 8  -- 8 neighbor checks per dirty cell
end

-- Create units with positions for realistic movement simulation
local function createUnits(count, fogWidth, fogHeight, sightRadius)
    local units = {}
    for i = 1, count do
        table.insert(units, {
            x = math.random(sightRadius, fogWidth - sightRadius),
            y = math.random(sightRadius, fogHeight - sightRadius),
            dx = (math.random() - 0.5) * 4,  -- Movement direction
            dy = (math.random() - 0.5) * 4,
        })
    end
    return units
end

-- Move units realistically (small incremental moves)
local function moveUnits(units, fogWidth, fogHeight, sightRadius)
    for _, unit in ipairs(units) do
        unit.x = unit.x + unit.dx
        unit.y = unit.y + unit.dy

        -- Bounce off edges
        if unit.x < sightRadius or unit.x > fogWidth - sightRadius then
            unit.dx = -unit.dx
            unit.x = math.max(sightRadius, math.min(fogWidth - sightRadius, unit.x))
        end
        if unit.y < sightRadius or unit.y > fogHeight - sightRadius then
            unit.dy = -unit.dy
            unit.y = math.max(sightRadius, math.min(fogHeight - sightRadius, unit.y))
        end

        -- Occasionally change direction
        if math.random() < 0.05 then
            unit.dx = (math.random() - 0.5) * 4
            unit.dy = (math.random() - 0.5) * 4
        end
    end
end

function Benchmark.run()
    print("\n" .. string.rep("=", 60))
    print("BENCHMARK: Fog of War - Dirty-Flag Caching vs Inline")
    print(string.rep("=", 60))
    print("(Simulates realistic unit movement, not random teleportation)")

    local scenarios = {
        {mapSize = 64, units = 7, name = "Small map (64x64, 7 units)"},
        {mapSize = 128, units = 15, name = "Medium map (128x128, 15 units)"},
        {mapSize = 256, units = 30, name = "Large map (256x256, 30 units)"},
        {mapSize = 256, units = 60, name = "Stress test (256x256, 60 units)"},
    }

    -- Visible area (simulating typical viewport)
    local viewportTiles = 20
    local viewportFogCells = viewportTiles * FOG_SCALE  -- ~80 cells per axis

    for _, scenario in ipairs(scenarios) do
        print(string.format("\n--- %s ---", scenario.name))

        local fogWidth = scenario.mapSize * FOG_SCALE
        local fogHeight = scenario.mapSize * FOG_SCALE
        local visibleCells = viewportFogCells * viewportFogCells

        -- Set up visible range (centered on map)
        local centerX = fogWidth / 2
        local centerY = fogHeight / 2
        local visibleStartX = math.max(1, math.floor(centerX - viewportFogCells / 2))
        local visibleStartY = math.max(1, math.floor(centerY - viewportFogCells / 2))
        local visibleEndX = math.min(fogWidth, visibleStartX + viewportFogCells - 1)
        local visibleEndY = math.min(fogHeight, visibleStartY + viewportFogCells - 1)

        local iterations = 100
        local sightRadius = 4 * FOG_SCALE  -- 4 tiles in fog cells

        -- ===== OLD METHOD =====
        local fog, fogEdgeAlpha = createMockFog(scenario.mapSize)
        local unitsOld = createUnits(scenario.units, fogWidth, fogHeight, sightRadius)

        -- Pre-reveal initial unit positions
        for _, unit in ipairs(unitsOld) do
            revealCircle(fog, fogWidth, fogHeight, math.floor(unit.x), math.floor(unit.y), sightRadius)
        end

        local startOld = love.timer.getTime()
        local oldChecks = 0
        for i = 1, iterations do
            -- Move units realistically (small increments)
            moveUnits(unitsOld, fogWidth, fogHeight, sightRadius)
            for _, unit in ipairs(unitsOld) do
                revealCircle(fog, fogWidth, fogHeight, math.floor(unit.x), math.floor(unit.y), sightRadius)
            end
            oldChecks = oldChecks + simulateFrameOld(fog, fogWidth, fogHeight, visibleStartX, visibleStartY, visibleEndX, visibleEndY)
        end
        local timeOld = love.timer.getTime() - startOld

        -- ===== NEW METHOD =====
        fog, fogEdgeAlpha = createMockFog(scenario.mapSize)
        local fogDirty = {}
        local unitsNew = createUnits(scenario.units, fogWidth, fogHeight, sightRadius)

        -- Pre-reveal and build initial cache
        for _, unit in ipairs(unitsNew) do
            local changed = revealCircle(fog, fogWidth, fogHeight, math.floor(unit.x), math.floor(unit.y), sightRadius)
            for _, cell in ipairs(changed) do
                markFogDirty(fogDirty, fogWidth, fogHeight, cell[1], cell[2])
            end
        end
        updateDirtyFogAlphas(fog, fogEdgeAlpha, fogWidth, fogHeight, fogDirty)

        local startNew = love.timer.getTime()
        local newChecks = 0
        for i = 1, iterations do
            fogDirty = {}
            -- Move units realistically (small increments)
            moveUnits(unitsNew, fogWidth, fogHeight, sightRadius)
            for _, unit in ipairs(unitsNew) do
                local changed = revealCircle(fog, fogWidth, fogHeight, math.floor(unit.x), math.floor(unit.y), sightRadius)
                for _, cell in ipairs(changed) do
                    markFogDirty(fogDirty, fogWidth, fogHeight, cell[1], cell[2])
                end
            end
            newChecks = newChecks + simulateFrameNew(fog, fogEdgeAlpha, fogWidth, fogHeight, fogDirty, visibleStartX, visibleStartY, visibleEndX, visibleEndY)
        end
        local timeNew = love.timer.getTime() - startNew

        local speedup = timeOld / timeNew
        local checksReduction = oldChecks / math.max(1, newChecks)

        print(string.format("  Visible fog cells: %d (%dx%d viewport)", visibleCells, viewportFogCells, viewportFogCells))
        print(string.format("  Total fog cells: %d (%dx%d)", fogWidth * fogHeight, fogWidth, fogHeight))
        print(string.format("  OLD (inline):     %.4fs (%d neighbor checks)", timeOld, oldChecks))
        print(string.format("  NEW (dirty-flag): %.4fs (%d neighbor checks)", timeNew, newChecks))
        print(string.format("  Speedup: %.2fx faster", speedup))
        if newChecks > 0 then
            print(string.format("  Checks reduced: %.1fx fewer", checksReduction))
        end
    end

    print("\n" .. string.rep("=", 60))
    print("Benchmark complete!")
    print(string.rep("=", 60) .. "\n")

    love.event.quit()
end

return Benchmark
