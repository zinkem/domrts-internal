--[[
    Replay Logger - Universal game event logging system

    Logs events from AI, player actions, units, buildings, etc.
    Saves to replays directory with timestamped files.
]]

local ReplayLogger = {}
ReplayLogger.__index = ReplayLogger

local instance = nil

function ReplayLogger.new()
    local self = setmetatable({}, ReplayLogger)

    self.log = {}
    self.gameTime = 0
    self.filename = nil
    self.lastSaveTime = 0
    self.saveInterval = 30  -- Save every 30 seconds

    self:initFile()

    return self
end

-- Get or create singleton instance
function ReplayLogger.getInstance()
    if not instance then
        instance = ReplayLogger.new()
    end
    return instance
end

-- Reset for new game
function ReplayLogger.reset()
    instance = ReplayLogger.new()
    return instance
end

-- Initialize replay file
function ReplayLogger:initFile()
    -- Create replays directory if it doesn't exist
    local lfs = love.filesystem
    if not lfs.getInfo("replays") then
        lfs.createDirectory("replays")
    end

    -- Generate filename with timestamp
    local timestamp = os.date("%Y%m%d_%H%M%S")
    self.filename = "replays/replay_" .. timestamp .. ".txt"

    -- Create empty file - let caller log CONFIG first before "game started"
    self:save()
end

-- Format timestamp
function ReplayLogger:formatTime()
    return string.format("[%02d:%02d]",
        math.floor(self.gameTime / 60),
        math.floor(self.gameTime % 60))
end

-- Log an event with category
function ReplayLogger:logEvent(category, message)
    local entry = self:formatTime() .. " [" .. category .. "] " .. message
    table.insert(self.log, entry)
end

-- Update game time and handle periodic saves
function ReplayLogger:update(dt)
    self.gameTime = self.gameTime + dt

    -- Periodic save
    if self.gameTime - self.lastSaveTime >= self.saveInterval then
        self.lastSaveTime = self.gameTime
        self:save()
    end
end

-- Save replay to file
function ReplayLogger:save()
    if not self.filename or #self.log == 0 then return end

    local content = table.concat(self.log, "\n")
    love.filesystem.write(self.filename, content)
end

-- Force save (call on game end)
function ReplayLogger:flush()
    self:logEvent("SYSTEM", "Replay ended")
    self:save()
end

-- Get the save directory path for display
function ReplayLogger:getSaveDirectory()
    return love.filesystem.getSaveDirectory() .. "/replays"
end

-- ============================================
-- Module-level convenience functions
-- Call these directly: ReplayLogger.log("AI", "message")
-- ============================================

function ReplayLogger.log(category, message)
    ReplayLogger.getInstance():logEvent(category, message)
end

function ReplayLogger.tick(dt)
    ReplayLogger.getInstance():update(dt)
end

function ReplayLogger.finish()
    ReplayLogger.getInstance():flush()
end

return ReplayLogger
