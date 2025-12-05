--[[
    Main Entry Point
    Handles scene management and global state
]]

-- Global game state
Game = {
    settings = {
        musicEnabled = true,
        soundEnabled = true
    },
    currentScene = nil,
    scenes = {}
}

-- Scene manager
local SceneManager = {}

function SceneManager.switch(sceneName)
    if Game.scenes[sceneName] then
        Game.currentScene = Game.scenes[sceneName]
        if Game.currentScene.load then
            Game.currentScene.load()
        end
    else
        error("Scene not found: " .. sceneName)
    end
end

function SceneManager.register(name, scene)
    Game.scenes[name] = scene
end

-- Make scene manager globally accessible
Game.SceneManager = SceneManager

-- Love2D callbacks
function love.load()
    love.window.setTitle("Love2D Game")
    love.window.setMode(1280, 720, {
        resizable = false,
        vsync = true
    })
    
    Game.fonts = {
        small = love.graphics.newFont(14),
        medium = love.graphics.newFont(20),
        large = love.graphics.newFont(32),
        title = love.graphics.newFont(64)
    }
    
    -- Load and register scenes
    Game.SceneManager.register("title", require("title"))
    Game.SceneManager.register("gameplay", require("gameplay"))
    Game.SceneManager.register("victory", require("victory"))
    
    -- Start with title screen
    Game.SceneManager.switch("title")
end

function love.update(dt)
    if Game.currentScene and Game.currentScene.update then
        Game.currentScene.update(dt)
    end
end

function love.draw()
    if Game.currentScene and Game.currentScene.draw then
        Game.currentScene.draw()
    end
end

function love.keypressed(key)
    if Game.currentScene and Game.currentScene.keypressed then
        Game.currentScene.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if Game.currentScene and Game.currentScene.mousepressed then
        Game.currentScene.mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if Game.currentScene and Game.currentScene.mousereleased then
        Game.currentScene.mousereleased(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if Game.currentScene and Game.currentScene.mousemoved then
        Game.currentScene.mousemoved(x, y, dx, dy)
    end
end
