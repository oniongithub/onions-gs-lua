local vector, http, images = require("vector"), require("gamesense/http"), require("gamesense/images")
local init, localPlayer, mousePos, dpi, alias, version, unixTime = true, entity.get_local_player(), nil, nil, "", "5gOdIIjNF2sP9igB", nil
local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))
local screenSize, menuPos, menuSize = vector(client.screen_size()), vector(ui.menu_position()), vector(ui.menu_size())

--[[
    Hot Enumerators
--]]

local moveType = {
    none = 0, isometric = 1, walk = 2,
    step = 3, fly = 4, flygravity = 5, 
    vphysics = 6, push = 7, noclip = 8,
    ladder = 9, observer = 10, custom = 11
}

local flags = {
    onground = 1, ducking = 2, waterjump = 3,
    ontrain = 4, inrain = 5, frozen = 6,
    atcontrols = 7, client = 8, fakeclient = 9, inwater = 10
}

local hitgroups = {
    "Generic", "Head", "Chest", "Stomach",
    "Left Arm", "Right Arm", "Left Leg",
    "Right Leg", "Neck", "Unknown", "Gear"
}

--[[
    Required Functions
--]]

local dpiControl = ui.reference("Misc", "Settings", "DPI scale")
local function getDPI() -- since the dpi control returns a string with a % sign do some magical wizardry to remove it
    local dpi = ui.get(dpiControl):gsub('[%c%p%s]', '')

    if (pcall(function() tonumber(dpi) end)) then
        return tonumber(dpi) / 100
    else
        return 1
    end
end

local function inMoveType(ent, movetype)
    return entity.get_prop(ent, "m_movetype") == movetype
end

local function hasFlag(ent, flag)
    return bit.band(flag, entity.get_prop(ent, "m_fFlags")) ~= 0
end

local function degToRad(deg)
    return deg * math.pi / 180
end

local function fromAng(vec)
    return vector(math.cos(degToRad(vec.x)) * math.cos(degToRad(vec.y)), math.cos(degToRad(vec.x)) * math.sin(degToRad(vec.y)), -1 * math.sin(degToRad(vec.x)))
end

local function trace(entSkip, vector1, vector2) -- replacement function to the regular trace that returns the ending vector aswell
    local percent, hitEnt = client.trace_line(entity.get_local_player(), vector1.x, vector1.y, vector1.z, vector2.x, vector2.y, vector2.z)
    local endVector = vector(vector1.x + (vector2.x - vector1.x * percent), vector1.y + (vector2.y - vector1.y * percent), vector1.z + (vector2.z - vector1.z * percent))

    return percent, hitEnt, endVector
end

local function traceCrosshair() -- trace to the end of your crosshair using eye angles
    local traceDist = 10000 -- Suck my nutts

    local eye = vector(client.camera_position())
    local camX, camY, camZ = client.camera_angles()
    local cam = fromAng(vector(camX, camY, camZ))
    local crosshairLocation = vector(eye.x + cam.x * traceDist, eye.y + cam.y * traceDist, eye.z + cam.z * traceDist)
    local percent, hitEnt = client.trace_line(entity.get_local_player(), eye.x, eye.y, eye.z, crosshairLocation.x, crosshairLocation.y, crosshairLocation.z)
    crosshairLocation = vector(eye.x + cam.x * (traceDist * percent), eye.y + cam.y * (traceDist * percent), eye.z + cam.z * (traceDist * percent))

    return percent, hitEnt, crosshairLocation
end

local function contains(table, key)
    for index, value in pairs(table) do
        if value == key then return true, index end
    end
    return false, nil
end

local function numberToNumber(num1, num2, percent)
    return math.clamp(num1 + (num2 - num1) * percent, 0, 255)
end

function math.clamp(number, min, max)
    if (number >= max) then
        return max
    elseif (number <= min) then
        return min
    else
        return number
    end
end

function math.in_bounds(x, y, w, h, pos_x, pos_y)
    if (pos_x >= x and pos_x <= x + w) then
        if (pos_y >= y and pos_y <= y + h) then
            return true
        end
    end

    return false
end

function client.UnixTime()
    local s = client.unix_time() local a, b, c, d = client.system_time()
    return s * 1000 + d
end unixTime = client.UnixTime()

function client.valve_server()
    local gameRules = entity.get_game_rules();

    if (gameRules) then
        local value = entity.get_prop(gameRules, "m_bIsValveDS")

        if (type(value) == "number" and value == 1) then
            return value == 1
        end
    end

    return false
end

function client.is_competitive()
    local gamemode = cvar.game_mode:get_int()
    local gametype = cvar.game_type:get_int()
    
    if (type(gamemode) == "number" and type(gametype) == "number") then
        return gamemode == 1 and gametype == 0
    end
end

function ui.multiReference(tab, groupbox, name)
    local ref1, ref2, ref3 = ui.reference(tab, groupbox, name)
    return { ref1, ref2, ref3 }
end

--[[
    Rendering Functions
--]]

local objects = {
    circle = 1, cone = 2, cylinder = 3
}

local function draw3D(origin, radius, color, outline, type, height)
    local localPlayer = entity.get_local_player()
    radius = radius * dpi
    if (not type) then type = 1 end
    if (type == 1) then height = 0 end

    if (localPlayer) then
        local prevScreenPosX, prevScreenPosY, prevScreenPosX2, prevScreenPosY2 = 0, 0, 0, 0
        local step = math.pi * 2 / 72
        local addedRotation = (math.pi * 2 * radius) / 360

        local screenPosX, screenPosY = 0, 0
        local screenPosX2, screenPosY2 = 0, 0

        local screenX, screenY = renderer.world_to_screen(origin.x, origin.y, origin.z)
        local screenX2, screenY2 = renderer.world_to_screen(origin.x, origin.y, origin.z + height)

        for rotation = 0, math.pi * 2, step do
            local posX, posY, posZ = radius * math.cos(rotation + 1) + origin.x, radius * math.sin(rotation + 1) + origin.y, origin.z
            screenPosX, screenPosY = renderer.world_to_screen(posX, posY, posZ)

            if (type == 1 or type == 2) then
                if (prevScreenPosX ~= 0 and prevScreenPosY ~= 0) then
                    renderer.triangle(screenPosX, screenPosY, screenX2, screenY2, prevScreenPosX, prevScreenPosY, color.r, color.g, color.b, color.a)
                    if (outline) then renderer.line(screenPosX, screenPosY, prevScreenPosX, prevScreenPosY, color.r, color.g, color.b, 255) end
                end
            elseif (type == 3) then
                screenPosX2, screenPosY2 = renderer.world_to_screen(posX, posY, posZ + height)

                if (prevScreenPosX ~= 0 and prevScreenPosY ~= 0) then
                    -- Sides
                    renderer.triangle(screenPosX, screenPosY, prevScreenPosX, prevScreenPosY, screenPosX2, screenPosY2, color.r, color.g, color.b, color.a)
                    renderer.triangle(prevScreenPosX2, prevScreenPosY2, prevScreenPosX, prevScreenPosY, screenPosX2, screenPosY2, color.r, color.g, color.b, color.a)

                    -- Top / Bottom
                    renderer.triangle(screenPosX, screenPosY, screenX, screenY, prevScreenPosX, prevScreenPosY, color.r, color.g, color.b, color.a)
                    renderer.triangle(screenPosX2, screenPosY2, screenX2, screenY2, prevScreenPosX2, prevScreenPosY2, color.r, color.g, color.b, color.a)

                    if (outline) then renderer.line(screenPosX, screenPosY, prevScreenPosX, prevScreenPosY, color.r, color.g, color.b, 255) end
                    if (outline) then renderer.line(screenPosX2, screenPosY2, prevScreenPosX2, prevScreenPosY2, color.r, color.g, color.b, 255) end
                end

                prevScreenPosX2, prevScreenPosY2 = screenPosX2, screenPosY2
            end

            prevScreenPosX, prevScreenPosY = screenPosX, screenPosY
        end
    end
end

local function drawBox(x, y, w, h, outline, color)
    local newCol = {}

    if (type(color) == "table") then newCol = color else
        local r, g, b, a = ui.get(color)
        newCol = { r = r, g = g, b = b, a = a }
    end

    function rect(x, y, w, h, col) -- Why the fuck does renderer.line have some autistic alpha value that you can't change?
        renderer.rectangle(x, y, w, 1, col.r, col.g, col.b, col.a) -- Left to Right
        renderer.rectangle(x + w - 1, y, 1, h, col.r, col.g, col.b, col.a) -- Right side Top to Bottom
        renderer.rectangle(x, y, 1, h, col.r, col.g, col.b, col.a) -- Left side Top to Bottom
        renderer.rectangle(x, y + h - 1, w, 1, col.r, col.g, col.b, col.a) -- Bottom Left to Right
    end

    if (outline) then
        rect(x, y, w, h, {r = 0, g = 0, b = 0, a = 255})

        if (w >= 6 and h >= 6) then
            rect(x + 1, y + 1, w - 2, h - 2, newCol)
            rect(x + 2, y + 2, w - 4, h - 4, {r = 0, g = 0, b = 0, a = 255})
        else
            --[[
                Wierd ass bug here with directX rendering, bars are 1 pixel off when 2 pixels wide, 
                adding 1 pixel long side will make it 3 wide but adding 1 pixel on the 2 pixel side will make it the given length even tho it should be length + 1 :shrug:
                I will not do that tho because I have dignity and self respect )
            ]]
            if (w >= 6) then
                renderer.rectangle(x + 1, y + 1, w - 2, h - 2, newCol.r, newCol.g, newCol.b, newCol.a)
            else
                renderer.rectangle(x + 1, y + 1, w - 2, h - 2, newCol.r, newCol.g, newCol.b, newCol.a)
            end
        end
    else
        rect(x, y, w, h, newCol)
    end
end

function renderer.filled_circle(x, y, r, g, b, a, radius, segments)
    local per_angle, last_pos_x, last_pos_y, cur_pos_x, cur_pos_y, current_angle, cos, sin = 360 / segments

    for i = 0, segments do
        if (i * per_angle <= 360) then
            current_angle, cos, sin = math.rad(i * per_angle)
            cos, sin = radius * math.cos(current_angle), radius * math.sin(current_angle)

            if (not last_pos_x or not last_pos_y) then
                last_pos_x, last_pos_y = cos + x, sin + y
            else
                cur_pos_x, cur_pos_y = cos + x, sin + y;          
                renderer.triangle(last_pos_x, last_pos_y, cur_pos_x, cur_pos_y, x, y, r, g, b, a)
                last_pos_x, last_pos_y = cur_pos_x, cur_pos_y
            end
        end
    end
end

--[[
    Input Library
--]]

local keySystem = {}
keySystem.__index = keySystem

keys = {}

local function newKey(key)
    if (type(key) ~= "number") then key = 0x01 end

    return setmetatable({ key = key, down = false, pressed = { pressed = false, x = 0, y = 0 }, released = { released = false, x = 0, y = 0 } }, keySystem)
end

function keySystem.addKey(key)
    local contains = false
    for i = 1, #keys do
        if (keys[i].key == key.key) then
            contains = true
        end
    end

    if (not contains) then
        table.insert(keys, key)
    end
end

function keySystem.removeKey(key)
    if (#keys > 0) then
        for i = 1, #keys do
            if (keys[i].key == key) then
                table.remove(keys, i)
                return
            end
        end
    end
end

function keySystem.getKey(key)
    if (#keys > 0) then
        for i = 1, #keys do
            if (keys[i].key == key) then
                return keys[i]
            end
        end
    end
end

function keySystem.run()
    if (#keys > 0) then
        for i = 1, #keys do
            if (client.key_state(keys[i].key)) then
                if (keys[i].down == false) then
                    keys[i].down = true
                    keys[i].pressed = { pressed = true, x = mousePos.x, y = mousePos.y }
                else
                    keys[i].pressed.pressed = false
                end
            else
                if (keys[i].down == true) then
                    keys[i].down, keys[i].pressed.pressed, keys[i].released = false, false, { released = true, x = mousePos.x, y = mousePos.y }
                else
                    keys[i].released.released = false
                end
            end
        end
    end
end

--[[
    Window Library
--]]

local windows = {}
windows.__index = windows
windows.styles = { default = 1, skeet = 2 }

local hudWindows = {}

local function window(x, y, w, h, text, color, styling, disableInput, visible)
    if (type(text) ~= "string") then text = "" end
    if (type(styling) ~= "number") then styling = windows.styles.default end
    if (type(x) ~= "number") then x = 0 end if (type(y) ~= "number") then y = 0 end
    if (type(w) ~= "number") then w = 0 end if (type(h) ~= "number") then h = 0 end
    if (type(disableInput) ~= "boolean") then disableInput = false end
    if (type(visible) ~= "boolean") then visible = true end
    
    if (#color > 0) then
        for i = 1, #color do
            if (type(color[i]) ~= "number") then
                color[i] = 255
            else
                if (color[i] > 255) then color[i] = 255 end
                if (color[i] < 0) then color[i] = 0 end
            end
        end
    end

    return setmetatable({ x = x, y = y, w = w, h = h, text = text, color = color, styling = styling, mouse = { x = 0, y = 0, isSelected = false }, disableInput = disableInput, visible = visible }, windows)
end

function windows:pointInside(x, y)
    if (x >= self.x and x <= self.x + self.w) then
        if (y >= self.y and y <= self.y + self.h) then
            return true
        end
    end

    return false
end

function windows.add(identifier, windowObject)
    local contains = false
    for i = 1, #hudWindows do
        if (hudWindows[i].id == identifier) then
            contains = true
        end
    end

    if (not contains) then
        table.insert(hudWindows, { id = identifier, window = windowObject })
    end
end

function windows.remove(identifier)
    if (#hudWindows > 0) then
        for i = 1, #hudWindows do
            if (hudWindows[i].id == identifier) then
                table.remove(hudWindows, i)
                return
            end
        end
    end
end

function windows.get(identifier)
    if (#hudWindows > 0) then
        for i = 1, #hudWindows do
            if (hudWindows[i].id == identifier) then
                return hudWindows[i].window
            end
        end
    end
end

keySystem.addKey(newKey(0x01))

function windows.runMovement()
    local mouseKey = keySystem.getKey(0x01)

    if (mouseKey ~= nil) then
        if (mouseKey.pressed.pressed) then
            if (#hudWindows > 0) then
                for i = 1, #hudWindows do
                    if (hudWindows[i].window:pointInside(mouseKey.pressed.x, mouseKey.pressed.y) and not hudWindows[i].window.disableInput and hudWindows[i].window.visible) then
                        hudWindows[i].window.mouse.isSelected = true
                        hudWindows[i].window.mouse.x, hudWindows[i].window.mouse.y = mouseKey.pressed.x - hudWindows[i].window.x, mouseKey.pressed.y - hudWindows[i].window.y
                        return
                    end
                end
            end
        end

        if (#hudWindows > 0) then
            for i = 1, #hudWindows do
                if (hudWindows[i].window ~= nil) then
                    if (mouseKey.down) then
                        if (hudWindows[i].window.mouse.isSelected == true and not hudWindows[i].window.disableInput and hudWindows[i].window.visible) then
                            hudWindows[i].window.x, hudWindows[i].window.y = mousePos.x - hudWindows[i].window.mouse.x, mousePos.y - hudWindows[i].window.mouse.y
                        end
                    else
                        hudWindows[i].window.mouse.isSelected = false
                    end
                end
            end
        end
    end
end

function windows.runPaint()
    if (#hudWindows > 0) then
        for i = 1, #hudWindows do
            if (hudWindows[i].window ~= nil and hudWindows[i].window.visible) then
                if (hudWindows[i].window.styling == 1) then
                    renderer.rectangle(hudWindows[i].window.x, hudWindows[i].window.y, hudWindows[i].window.w * dpi, 2 * dpi, hudWindows[i].window.color[1], hudWindows[i].window.color[2], hudWindows[i].window.color[3], 255)
                    renderer.rectangle(hudWindows[i].window.x, hudWindows[i].window.y + (2 * dpi), hudWindows[i].window.w * dpi, (hudWindows[i].window.h * dpi) - (2 * dpi), 35, 35, 35, 180)
                    renderer.blur(hudWindows[i].window.x, hudWindows[i].window.y + (2 * dpi), hudWindows[i].window.w * dpi, (hudWindows[i].window.h * dpi) - (2 * dpi), 255, 255, 255, 255)
                else
                    -- unused
                end
            end
        end
    end
end

--[[
    Notification Library
--]]

local note = {}
note.__index = note
note.easing = { linear = 1, easeIn = 2, easeOut = 3, easeInOut = 4 }
note.anchor = { topLeft = 1, topRight = 2, bottomLeft = 3, bottomRight = 4 }

local notifications = {}

local function notification(text, ms, color, easing, anchor)
    if (type(text) ~= "string") then text = "" end
    if (type(ms) ~= "number") then ms = 1000 end
    if (type(easing) ~= "number") then easing = note.easing.linear end
    if (type(anchor) ~= "number") then anchor = note.anchor.topLeft end
    
    if (#color > 0) then
        for i = 1, #color do
            if (type(color[i]) ~= "number") then
                color[i] = 255
            else
                if (color[i] > 255) then color[i] = 255 end
                if (color[i] < 0) then color[i] = 0 end
            end
        end
    end

    return setmetatable({ text = text, ms = { time = ms, startTime = globals.realtime() }, color = color, easing = easing, anchor = anchor }, note)
end

function note:run()
    table.insert(notifications, { text = self.text, ms = { time = self.ms.time, startTime = globals.realtime() }, color = self.color, easing = self.easing, anchor = self.anchor })
end

function note.remove(index)
    if (type(index) == "number") then
        table.remove(notifications, index)
    end
end

local function easingWidth(easing, width, percent) -- https://easings.net/
    if (easing == 2) then
        percent = percent^4
    elseif (easing == 3) then
        percent = 1 - (1 - percent)^4
    elseif (easing == 4) then
        if (percent < 0.5) then 
            percent = 8 * percent^4 
        else 
            percent = 1 - (-2 * percent + 2)^4 / 2 
        end 
    end

    return width - (width * percent)
end

local onionNotifications = ui.new_checkbox("Misc", "Settings", "Disable notifications")

local function notificationPaint()
    if (#notifications > 0 and not ui.get(onionNotifications)) then
        local usedY = { tl = 0, tr = 0, bl = 0, br = 0 }

        for i = #notifications, 1, -1 do
            if (globals.realtime() - notifications[i].ms.startTime >= (notifications[i].ms.time / 1000)) then
                note.remove(i)
            else               
                local textW, textH = renderer.measure_text("d", notifications[i].text)
                local padding = 8
                local render = { x = 0, y = 0, w = (textW + padding * 2) * dpi, h = 22 * dpi }
                local percent = 0
                
                if (globals.realtime() - notifications[i].ms.startTime > (notifications[i].ms.time / 2) / 1000) then
                    percent = ((globals.realtime() - notifications[i].ms.startTime) - ((notifications[i].ms.time / 2) / 1000)) / ((notifications[i].ms.time / 2) / 1000)
                end

                local sub = easingWidth(notifications[i].easing, render.w + 10, percent)

                if (notifications[i].anchor == 1) then
                    render.x, render.y = sub - ((textW + padding * 2) * dpi), 10 + usedY.tl usedY.tl = usedY.tl + 30
                elseif (notifications[i].anchor == 2) then      
                    render.x, render.y = screenSize.x - sub, 10 + usedY.tr usedY.tr = usedY.tr + 30
                elseif (notifications[i].anchor == 3) then
                    render.x, render.y = sub - ((textW + padding * 2) * dpi), screenSize.y - render.h - 10 - usedY.bl usedY.bl = usedY.bl + 30
                else
                    render.x, render.y = screenSize.x - sub, screenSize.y - render.h - 10 - usedY.br usedY.br = usedY.br + 30
                end

                renderer.rectangle(render.x, render.y, render.w, render.h, 20, 20, 20, 255)
                renderer.rectangle(render.x, render.y, render.w, 2 * dpi, 65, 65, 65, 255)
                renderer.rectangle(render.x, render.y, easingWidth(1, render.w, (globals.realtime() - notifications[i].ms.startTime) / (notifications[i].ms.time/ 1000)), 2 * dpi, notifications[i].color[1], notifications[i].color[2], notifications[i].color[3], 255)
                renderer.text(render.x + ((8 + (textW / 2)) * dpi), render.y + (render.h / 2), 255, 255, 255, 255, "cd", 0, notifications[i].text)
            end
        end
    end
end

--[[
    Party API
--]]

local party = {} party.__index = {}

function party.getCount()
    local value = panorama.loadstring([[
        return PartyListAPI.GetCount();
    ]])()

    if (value) then
        return value;
    end
end

function party.inParty()
    local value = party.getCount();
    if (value and type(value) == "number") then
        return value > 1
    end
end

--[[
    UI Initialization bs
--]]

local guiReferences = {
    dtFakelag = ui.reference("Rage", "Other", "Double tap fake lag limit"),
    damageLog = ui.reference("Misc", "Miscellaneous", "Log damage dealt"),
    blockbot = ui.reference("Misc", "Movement", "Blockbot"),
    stealName = ui.reference("Misc", "Miscellaneous", "Steal player name"),
    doubletap = ui.multiReference("Rage", "Other", "Double tap"),
    hideshots = ui.multiReference("AA", "Other", "On shot anti-aim"),
    yaw = ui.multiReference("AA", "Anti-aimbot angles", "Yaw"),
    bodyYaw = ui.multiReference("AA", "Anti-aimbot angles", "Body yaw"),
    fakelagLimit = ui.reference("AA", "Fake lag", "Limit"),
    espBounding = ui.multiReference("Visuals", "Player ESP", "Bounding box"),
    espHealth = ui.reference("Visuals", "Player ESP", "Health bar"),
    espName = ui.multiReference("Visuals", "Player ESP", "Name"),
    espWeapon = ui.reference("Visuals", "Player ESP", "Weapon text"),
    espAmmo = ui.multiReference("Visuals", "Player ESP", "Ammo"),
    espDistance = ui.reference("Visuals", "Player ESP", "Distance"),
    espMoney = ui.reference("Visuals", "Player ESP", "Money"),
    minimumDamage = ui.reference("Rage", "Aimbot", "Minimum damage"),
    playerList = ui.reference("Players", "Players", "Player List"),
    ragebot = ui.multiReference("Rage", "Aimbot", "Enabled"),
    quickpeek = ui.multiReference("Rage", "Other", "Quick peek assist"),
}

local disabledReferences = {
    { name = "Damage Logging", reference = guiReferences.damageLog, disabled = true, canGet = true },
    { name = "Blockbot", reference = guiReferences.blockbot, disabled = false, canGet = true },
    { name = "Username Stealer", reference = guiReferences.stealName, disabled = false, canGet = false },
}

if (disabledReferences ~= nil and #disabledReferences > 0) then -- Sets all the references above to be invisible due to being remade
    client.exec("clear")
    for i = 1, #disabledReferences do
        if (disabledReferences[i].canGet and type(ui.get(disabledReferences[i].reference)) == "boolean") then
            ui.set(disabledReferences[i].reference, false)
        end
        
        ui.set_visible(disabledReferences[i].reference, false)

        if (disabledReferences[i].disabled) then
            print("Option: " .. disabledReferences[i].name .. " has been disabled.")
        else
            print("Option: " .. disabledReferences[i].name .. " has been replaced.")
        end
    end

    notification("UI has been initialized.", 2500, {menuR, menuG, menuB, menuA}, 4, 1):run()
end

client.set_event_callback("shutdown", function()
    if (disabledReferences ~= nil and #disabledReferences > 0) then -- Makes removed controls visible again after unloading.
        for i = 1, #disabledReferences do          
            ui.set_visible(disabledReferences[i].reference, true)
        end
    end
end);

local output = http.get("https://raw.githubusercontent.com/oniongithub/onions-gs-lua/main/version", function(status, response)
    if (status and response and response.status == 200 and type(response.body) == "string") then
        local body = response.body:gsub("\n", "")
        if (not string.find(body, version)) then
            local text = "There is a new update available at https://github.com/oniongithub/onions-gs-lua"
            notification(text, 6000, {menuR, menuG, menuB, menuA}, 4, 1):run() print(text)
        end
    end
end)

--[[
    Holiday Mode
--]]

local onionHolidays = {
    control = ui.new_combobox("Misc", "Settings", "Holiday mode", "None", "Christmas", "Halloween", "Hanukkah"),
    time = client.UnixTime(), switch = false, globalColor = {255, 255, 255, 255},
    colors = { {255, 255, 255, 255}, {255, 255, 255, 255} }
}

ui.set_callback(onionHolidays.control, function()
    local value = ui.get(onionHolidays.control);
    if (value ~= "None") then
        if (value == "Christmas") then
            onionHolidays.colors = { {49, 235, 55, 255}, {245, 64, 82, 255} };
        elseif (value == "Halloween") then
            onionHolidays.colors = { {245, 135, 66, 255}, {0, 0, 0, 255} };
        elseif (value == "Hanukkah") then
            onionHolidays.colors = { {66, 149, 245, 255}, {255, 255, 255, 255} };
        end
    end
end)

local function runRainbow()
    if (ui.get(onionHolidays.control) ~= "None") then
        local holidayPercent = (unixTime - onionHolidays.time) / 2500
        local newPercent = easingWidth(3, 1, holidayPercent)

        if (onionHolidays.switch) then
            onionHolidays.globalColor = {numberToNumber(onionHolidays.colors[1][1], onionHolidays.colors[2][1], newPercent), numberToNumber(onionHolidays.colors[1][2], onionHolidays.colors[2][2], newPercent), numberToNumber(onionHolidays.colors[1][3], onionHolidays.colors[2][3], newPercent), 255}
        else
            onionHolidays.globalColor = {numberToNumber(onionHolidays.colors[2][1], onionHolidays.colors[1][1], newPercent), numberToNumber(onionHolidays.colors[2][2], onionHolidays.colors[1][2], newPercent), numberToNumber(onionHolidays.colors[2][3], onionHolidays.colors[1][3], newPercent), 255}
        end

        if (holidayPercent > 1) then
            onionHolidays.switch = not onionHolidays.switch
            onionHolidays.time = unixTime
        end
    end
end

--[[
    Blockbot Function
--]]

local onionBlockbot = {
    control = ui.new_hotkey("Misc", "Movement", "Blockbot", false),
    table = { currentEntity, isOn = false }
}

local function map(n, start, stop, new_start, new_stop)
    local value = (n - start) / (stop - start) * (new_stop - new_start) + new_start
    return new_start < new_stop and math.max(math.min(value, new_stop), new_start) or math.max(math.min(value, new_start), new_stop)
end

local function blockbotPaint() -- Obtain the walkbot target from the closest player, and draw the indicator circle for the current player
    local localOrigin = vector(entity.get_origin(localPlayer))

    if (hasFlag(localPlayer, flags.onground)) then
        local closestEnt, closestDist = nil, 100

        local players = entity.get_players(false)
        if (players ~= nil and #players > 0) then
            for i = 1, #players do
                if (players[i] ~= localPlayer) then
                    local entOrigin = vector(entity.get_origin(players[i]))
                    local distance = entOrigin:dist2d(localOrigin)

                    if (distance < closestDist) then
                        closestEnt, closestDist = players[i], distance
                    end
                end
            end

            if (closestEnt ~= nil) then
                if (onionBlockbot.table.currentEntity ~= closestEnt) then
                    notification("New Blockbot target: " .. entity.get_player_name(closestEnt), 2500, {menuR, menuG, menuB, menuA}, 4, 1):run()
                end

                onionBlockbot.table.isOn = true
                onionBlockbot.table.currentEntity = closestEnt
            end
        end
    end

    if (onionBlockbot.table.isOn) then
        local playerOrigin = vector(entity.get_origin(onionBlockbot.table.currentEntity))

        if (vector(localOrigin.x, localOrigin.y, playerOrigin.z):dist2d(playerOrigin) <= 20) then
            draw3D(playerOrigin, 20, { r = 66, g = 245, b = 96, a = 150 }, true, objects.circle)
        else
            draw3D(playerOrigin, 20, { r = 255, g = 255, b = 255, a = 150 }, true, objects.circle)
        end

        draw3D(vector(localOrigin.x, localOrigin.y, playerOrigin.z), 4, { r = 35, g = 35, b = 35, a = 150 }, true, objects.circle)
    end
end

local function blockbotMove(cmd) -- move with the selected player on the setup move callback, movement code modified from halflifefan's post viewtopic.php?id=10839
    if (onionBlockbot.table.isOn) then
        local localOrigin = vector(entity.get_origin(localPlayer))
        local entityVelocity = vector(entity.get_prop(onionBlockbot.table.currentEntity, "m_vecVelocity"))
        local entitySpeed = vector(entity.get_prop(onionBlockbot.table.currentEntity, "m_vecVelocity")):length2d()
        local serverOrigin = vector(entity.get_origin(onionBlockbot.table.currentEntity)) + entityVelocity * math.floor(client.latency() / globals.tickinterval() + 0.5) * globals.tickinterval()
        local dirYaw = select(2, localOrigin:to(serverOrigin):angles())
        local distance = localOrigin:dist2d(serverOrigin)

        cmd.move_yaw = dirYaw
        if (map(vector(entity.get_prop(localPlayer, "m_vecVelocity")):length2d(), 0, 250, 0, 12) < distance) then
            cmd.forwardmove = 450
        end
    end
end


--[[
    Thirdperson Function
--]]

local onionThirdperson = {
    collisionControl = ui.new_checkbox("Visuals", "Effects", "Thirdperson collisions"),
    distanceControl = ui.new_slider("Visuals", "Effects", "Thirdperson distance", 50, 200, 125)
}

local function thirdpersonValues()
    if (ui.get(onionThirdperson.collisionControl)) then
        cvar.cam_collision:set_int(1)
    else
        cvar.cam_collision:set_int(0)
    end

    cvar.c_mindistance:set_int(ui.get(onionThirdperson.distanceControl))
    cvar.c_maxdistance:set_int(ui.get(onionThirdperson.distanceControl))
end

ui.set_callback(onionThirdperson.collisionControl, thirdpersonValues)
ui.set_callback(onionThirdperson.distanceControl, thirdpersonValues)
thirdpersonValues()

--[[
    Extrapolated Position Function
    yeah ik it's pretty wrong and just uses your current speed as a constant
--]]

local onionExtrapolation = {
    control = ui.new_checkbox("Visuals", "Other ESP", "Teleport prediction")
}

local function extrapolatedPosition() -- just get current max charge and do some magical math to get an inaccurate answer (also server tickrate is hardcoded smd)
    if (ui.get(onionExtrapolation.control)) then
        if (ui.get(guiReferences.doubletap[1]) and ui.get(guiReferences.doubletap[2])) then
            local percent = (16 - ui.get(guiReferences.dtFakelag)) / 64
            local velX, velY, velZ = entity.get_prop(localPlayer, "m_vecVelocity")
            local originX, originY, originZ = entity.get_origin(localPlayer)
            local endX, endY = originX + velX * percent, originY + velY * percent

            local drawColor = { r = 255, g = 255, b = 255, a = 150 }
            if (ui.get(onionHolidays.control) ~= "None") then
                drawColor= { r = onionHolidays.globalColor[1], g = onionHolidays.globalColor[2], b = onionHolidays.globalColor[3], a = 150 }
            end

            draw3D({ x = endX, y = endY, z = originZ }, 8, drawColor, true, objects.circle)
        end
    end
end

--[[
    Dump API Functions
--]]

local onionDumpAPI = {
    control = nil,
    table = {}
}

local function dumpAPI(tbl, ind)
    onionDumpAPI.table[tbl] = true
    local s = {}
    local n = 0
    for k in pairs(tbl) do
        n = n + 1
        s[n] = k
    end

    for k, v in ipairs(s) do
        if (not tostring(v):find("weapons")) then
            print(ind, v)
            v = tbl[v]
            if type(v) == "table" and not onionDumpAPI.table[v] then
                dumpAPI(v, ind .. "\t")
            end
        end
    end
end

onionDumpAPI.control = ui.new_button("Misc", "Miscellaneous", "Dump Lua Functions", function() dumpAPI(_G, "") end)

--[[
    RS Function
--]]

local onionTextCleaner = {
    control = ui.new_checkbox("Misc", "Miscellaneous", "Clean reset score"),
    notification = notification("Your reset score command has been cleaned and silenced.", 3000, {menuR, menuG, menuB, menuA}, 4, 1)
}

local function cleanRS(str) -- allows you to mess up spelling /rs and auto converts !rs to /rs since /rs is silent on most servers
    if (string.len(str.text) <= 9) then
        if (string.find(str.text, "!") and string.find(string.lower(str.text), "r") and string.find(string.lower(str.text), "s")) then
            str.text = "say /rs" onionTextCleaner.notification:run()
        elseif (string.find(str.text, "/") and string.find(string.lower(str.text), "r") and string.find(string.lower(str.text), "s")) then
            str.text = "say /rs" onionTextCleaner.notification:run()
        end
    end
end

--[[
    Anti-AFK Function
--]]

local onionAFK = {
    control = ui.new_checkbox("Misc", "Miscellaneous", "Anti-AFK")
}

local function antiAFKMove(cmd)
    if (ui.get(onionAFK.control)) then
        cmd.in_left, cmd.in_right = true, true
    end
end

--[[
    Remove Advertisements Function
--]]

local onionAdverts = {
    control = ui.new_checkbox("Visuals", "Effects", "Remove adverts"),
    adStrings = {
        "decals/custom/uwujka/uwujkapl_logo_01", "decals/custom/14club/logo_decal",
        "decals/liberty/libertymaster", "/brokencore", "decals/intensity/intensity"
    }, materialAds = {},
}

local function removeAdvertisement() -- remove all materials related to the table above, material strings stolen from pilot's post viewtopic.php?id=31518
    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        onionAdverts.materialAds = {}

        for i = 1, #onionAdverts.adStrings do
            local material = materialsystem.find_materials(onionAdverts.adStrings[i])
            if (material ~= nil) then table.insert(onionAdverts.materialAds, material) end
        end

        if (#onionAdverts.materialAds > 0) then
            for i = 1, #onionAdverts.materialAds do
                for f = 1, #onionAdverts.materialAds[i] do
                    onionAdverts.materialAds[i][f]:set_material_var_flag(2, ui.get(onionAdverts.control))
                end
            end
        end

        notification("Added map advertisements have been cleared.", 1500, {menuR, menuG, menuB, menuA}, 4, 1):run()
    end
end

ui.set_callback(onionAdverts.control, removeAdvertisement)

--[[
    Hideshots Indicator
--]]

local onionHideshots = {
    control = ui.new_checkbox("Visuals", "Effects", "Hideshots indicator"),
}

local function drawHideshotsIndicator()
    if (ui.get(onionHideshots.control)) then
        if (ui.get(guiReferences.hideshots[1]) and ui.get(guiReferences.hideshots[2])) then
            renderer.indicator(205, 205, 205, 255, "HS")
        end
    end
end

--[[
    Player Logging Functions
--]]

local function setPlayerAlias(player, alias)
    if (player and alias) then
        local steamid, found = entity.get_steam64(player), false
        local dbTable = database.read("onionPlayerAliases")

        if (dbTable and #dbTable > 0) then
            for i = 1, #dbTable do
                if (dbTable[i].steamid == steamid) then
                    table.remove(dbTable, i) found = true
                    table.insert(dbTable, {steamid = steamid, alias = alias})
                    database.write("onionPlayerAliases", dbTable)
                end
            end

            if (not found) then
                table.insert(dbTable, {steamid = steamid, alias = alias})
                database.write("onionPlayerAliases", dbTable)
            end
        else
            database.write("onionPlayerAliases", {{steamid = steamid, alias = alias}});
        end
    end
end

local function getPlayerAlias(player, remove)
    if (player) then
        local steamid = entity.get_steam64(player)
        local dbTable = database.read("onionPlayerAliases")

        if (dbTable and #dbTable > 0) then
            for i = 1, #dbTable do
                if (dbTable[i].steamid == steamid) then

                    if (remove) then
                        table.remove(dbTable, i)
                        database.write("onionPlayerAliases", dbTable)
                        return
                    else
                        return dbTable[i].alias
                    end
                end
            end
        end
    end
end

local function removePlayerAlias(player)
    getPlayerAlias(player, true);
end

local function runPlayerAliases(player)
    if (player) then
        local alias = getPlayerAlias(player)
        if (alias) then
            local text = "An aliased player " .. alias .. ", has been found. Their logged in as " .. entity.get_player_name(player) .. "."
            notification(text, 4000, {menuR, menuG, menuB, menuA}, 4, 1):run() print(text)
        end
    else
        local entities = entity.get_players(false);

        if (entities and #entities > 0) then
            for i = 1, #entities do
                local alias = getPlayerAlias(entities[i]);
                
                if (alias) then
                    local text = "An aliased player " .. alias .. ", has been found. Their logged in as " .. entity.get_player_name(entities[i]) .. "."
                    notification(text, 4000, {menuR, menuG, menuB, menuA}, 4, 1):run() print(text)
                end
            end
        end
    end
end

--[[
    Player List Functions
--]]

local playerListControls = {
    { table = {}, reference = ui.new_checkbox("Players", "Adjustments", "Blockbot priority") },
    { table = {}, reference = ui.new_checkbox("Players", "Adjustments", "Killsay target") },
    { table = {}, reference = ui.new_checkbox("Players", "Adjustments", "Repeat target") },
    { table = {}, reference = ui.new_checkbox("Players", "Adjustments", "Ragebot target") },
}

local onionStealName = ui.new_button("Players", "Adjustments", "Steal username", function()
    local player = ui.get(guiReferences.playerList)
    local name = entity.get_player_name(player)
    ui.set(guiReferences.stealName, true)
    client.set_cvar("name", name .. " ")
end)

local onionStealTag = ui.new_button("Players", "Adjustments", "Steal clantag", function()
    local player = ui.get(guiReferences.playerList)
    local clantag = entity.get_prop(entity.get_player_resource(), "m_szClan", player)

    if (clantag ~= nil and clantag ~= "nil") then
        client.set_clan_tag(clantag)
    end
end)

local onionDumpWins = ui.new_button("Players", "Adjustments", "Dump wins", function()
    local player = ui.get(guiReferences.playerList)

    local wins = panorama.loadstring([[
        const newXUID = GameStateAPI.GetPlayerXuidStringFromEntIndex(]] .. player .. [[)
        return GameStateAPI.GetPlayerCompetitiveWins(newXUID)
    ]])()

    print(wins)
end)

local onionAliasText = ui.new_textbox("Players", "Adjustments", "Player alias")
local onionAliasSet = ui.new_button("Players", "Adjustments", "Set alias", function()
    local player = ui.get(guiReferences.playerList)
    setPlayerAlias(player, ui.get(onionAliasText))
    print("Alias has been set.")
end)

local onionAliasGet = ui.new_button("Players", "Adjustments", "Get alias", function()
    local player = ui.get(guiReferences.playerList)
    local alias = getPlayerAlias(player)
    if (alias and alias ~= "") then
        print(alias)
    else
        print("No alias has been found.")
    end
end)

local onionAliasRemove = ui.new_button("Players", "Adjustments", "Remove alias", function()
    local player = ui.get(guiReferences.playerList)
    removePlayerAlias(player)
end)

for i = 1, #playerListControls do -- modification of duke's post using tables so we don't need repetitive code viewtopic.php?id=19293
    ui.set_callback(playerListControls[i].reference, function()
        if (ui.get(playerListControls[i].reference)) then
            table.insert(playerListControls[i].table, ui.get(guiReferences.playerList))
        else
            local value, index = contains(playerListControls[i].table, ui.get(guiReferences.playerList))
            if (value) then
                table.remove(playerListControls[i].table, index)
            end
        end
    end)
end

ui.set_callback(guiReferences.playerList, function()
    for i = 1, #playerListControls do
        ui.set(playerListControls[i].reference, contains(playerListControls[i].table, ui.get(guiReferences.playerList)))
    end
end)

--[[
    Auto Team Selection Function
--]]

local onionTeamSelection =  {
    control = ui.new_combobox("Misc", "Miscellaneous", "Team selection", { "Off", "CT", "T" })
}

local function selectTeamEvent(event)
    if (client.userid_to_entindex(event.userid) == localPlayer) then
        local value = ui.get(onionTeamSelection.control)

        if (value ~= "Off") then
            if (value == "CT") then 
                client.exec("jointeam 3 1") 
            else
                client.exec("jointeam 2 1")
            end

            notification("You have automatically been put into the " .. value .. "s,", 1500, {menuR, menuG, menuB, menuA}, 4, 1):run()
        end
    end
end

--[[
    Killsay Function
--]]

local onionKillsay = {
    control = ui.new_combobox("Misc", "Miscellaneous", "Killsay", { "Off", "On", "Targetted" }),
    killMessages = {
        "1", "You suck.",
        "nice stevie wonder aim", "Missclick",
        "lick my sphincter", "*DEAD*",
    }
}

local function playerKilledEvent(event) -- Run killsay for every player when attacking or for specified players in the plist
    local attacker = client.userid_to_entindex(event.attacker)
    local attacked = client.userid_to_entindex(event.userid)

    if (attacker == localPlayer) then
        local value = ui.get(onionKillsay.control)

        if (value ~= "Off") then
            if (value == "On") then
                client.exec("say " .. onionKillsay.killMessages[client.random_int(1, #onionKillsay.killMessages)])
            else
                ui.set(guiReferences.playerList, attacked)
                if (contains(playerListControls[2].table, ui.get(guiReferences.playerList))) then 
                    client.exec("say " .. onionKillsay.killMessages[client.random_int(1, #onionKillsay.killMessages)])
                end
            end
        end
    end
end

--[[
    Repeat Text Function
--]]

local onionRepeatText = {
    control = ui.new_combobox("Misc", "Miscellaneous", "Repeat text", { "Off", "On", "Team Only", "Enemy Only", "Targetted" }),
    blacklistedCommands = { "rs", "rank", "top", "ban", "admin", "kick", "addban", "banip", "cancelvote",
                            "cvar", "execcfg", "help", "map", "rcon", "reloadadmins", "unban", "who", "beacon",
                            "burn", "chat", "csay", "gag", "hsay", "msay", "mute", "play", "psay", "rename",
                            "resetcvar", "say", "silence", "slap", "slay", "tsay", "ungag", "unmute", "unsilence",
                            "vote", "votealltalk", "voteban", "voteburn", "voteff", "votegravity", "votekick", "votemap", "voteslay" }
}

local function repeatTextEvent(chat) -- Run repeat text for every player when attacking or for specified players in the plist
    local writer = chat.entity

    if (writer ~= localPlayer) then
        local value = ui.get(onionRepeatText.control) local text = chat.text:gsub(";", "")
        if (string.sub(text, 1, 1) == "/" or string.sub(text, 1, 1) == "!") then
            text = string.sub(text, 2, #text)
        end

        for i = 1, #onionRepeatText.blacklistedCommands do
            if (string.sub(text, 1, #onionRepeatText.blacklistedCommands[i]) == onionRepeatText.blacklistedCommands[i]) then
                text = string.sub(text, #onionRepeatText.blacklistedCommands[i] + 1, #text)
            end
        end

        if (value ~= "Off") then
            if (value ~= "Targetted") then
                if (value == "Team Only") then
                    if (entity.is_enemy(writer)) then return end
                elseif (value == "Enemy Only") then
                    if (not entity.is_enemy(writer)) then return end
                end

                client.exec("say " .. text)
            else
                ui.set(guiReferences.playerList, writer)
                if (contains(playerListControls[3].table, ui.get(guiReferences.playerList))) then 
                    client.exec("say " .. text)
                end
            end
        end
    end
end

--[[
    ESP Distance Function
--]]

local onionESPDistance = {
    control = ui.new_slider("Visuals", "Player ESP", "Distance", 0, 5000, 0)
}

local function espDistancePaint() -- set plist settings when a player's origin is too far from the local player
    if (entity.is_alive(localPlayer)) then
        local value = ui.get(onionESPDistance.control)

        if (value ~= 0) then
            local players = entity.get_players(true)
            local localEyes = vector(client.eye_position())

            if (players ~= nil and #players > 0) then
                for i = 1, #players do
                    local playerOrigin = vector(entity.get_origin(players[i]))

                    if (localEyes:dist2d(playerOrigin) <= value) then
                        plist.set(players[i], "Disable visuals", false)
                    else
                        local playerHead = vector(entity.hitbox_position(players[i], 0))
                        local fraction, entIndex = client.trace_line(localPlayer, localEyes.x, localEyes.y, localEyes.z, playerHead.x, playerHead.y, playerHead.z)
                        local fraction2, entIndex2 = client.trace_line(localPlayer, localEyes.x, localEyes.y, localEyes.z, playerOrigin.x, playerOrigin.y, playerOrigin.z)

                        if (entIndex == players[i] or entIndex2 == players[i]) then
                            plist.set(players[i], "Disable visuals", false)
                        else
                            plist.set(players[i], "Disable visuals", true)
                        end
                    end
                end
            end
        else
            local players = entity.get_players(true)
            if (players ~= nil and #players > 0) then
                for i = 1, #players do
                    plist.set(players[i], "Disable visuals", false)
                end
            end
        end
    end
end

--[[
    Ragebot Playerlist Targetting  
--]]

local onionRagebotTarget = {
    control = ui.new_checkbox("Rage", "Aimbot", "Playerlist targetting")
}

local function targettingPaint(disable)
    local players = entity.get_players(false)
    if (players ~= nil and #players > 0) then
        for i = 1, #players do
            local value = ui.get(guiReferences.playerList);
            ui.set(guiReferences.playerList, players[i])
            local hasValue = contains(playerListControls[4].table, ui.get(guiReferences.playerList))
            if (not ui.get(onionRagebotTarget.control)) then hasValue = true; end
            plist.set(players[i], "Add to whitelist", not hasValue);
            if (value ~= nil) then
                ui.set(guiReferences.playerList, value)
            end
        end
    end
end

--[[
    Hitmarker Text Function
--]]

local onionHitmarker = {
    control = ui.new_checkbox("Visuals", "Other ESP", "Word hitmarker"),
    hitTable = {}, 
    hitboxTable = {
        {0, 4}, {1, 0}, {2, 6}, {3, 5},
        {4, 19}, {5, 17}, {6, 11}, 
        {7, 10}, {nil, 5}
    }, hitWords = { "OWNED", "OOF", "SMASH", "BOOM" },
    wordColors = {{35, 70, 226}, {49, 124, 225}, {217, 226, 0}, {65, 222, 91}, {221, 124, 30}},
    holidaySwitch = false
}

local function hitmarkerEvent(event) -- add hitmarker information to a table to grab from our paint callback
    if (ui.get(onionHitmarker.control)) then
        local entAttacker = client.userid_to_entindex(event.attacker)
        local entAttacked = client.userid_to_entindex(event.userid)

        if (entAttacker == localPlayer) then
            local endVec
            local set = false
            
            for i = 1, #onionHitmarker.hitboxTable do
                if (i == #onionHitmarker.hitboxTable and not set) then
                    endVec = vector(entity.hitbox_position(entAttacked, onionHitmarker.hitboxTable[i][2]))
                elseif (onionHitmarker.hitboxTable[i][1] == event.hitgroup) then
                    endVec = vector(entity.hitbox_position(entAttacked, onionHitmarker.hitboxTable[i][2]))
                    set = true
                end
            end
            
            if (ui.get(onionHolidays.control) ~= "None") then
                if (holidaySwitch) then
                    table.insert(onionHitmarker.hitTable, { endVec, globals.curtime(), onionHitmarker.hitWords[client.random_int(1, #onionHitmarker.hitWords)], onionHolidays.colors[1]})
                else
                    table.insert(onionHitmarker.hitTable, { endVec, globals.curtime(), onionHitmarker.hitWords[client.random_int(1, #onionHitmarker.hitWords)], onionHolidays.colors[2]})
                end

                holidaySwitch = not holidaySwitch
            else
                table.insert(onionHitmarker.hitTable, { endVec, globals.curtime(), onionHitmarker.hitWords[client.random_int(1, #onionHitmarker.hitWords)], onionHitmarker.wordColors[client.random_int(1, #onionHitmarker.wordColors)] })
            end
        end
    end
end

local function hitmarkerPaint() -- draw the hitmarker from information in the hitTable table obtained from the hitmarker event
    if (ui.get(onionHitmarker.control)) then
        if (#onionHitmarker.hitTable > 0) then
            for i = 1, #onionHitmarker.hitTable do
                if (type(onionHitmarker.hitTable[i]) == "table" and onionHitmarker.hitTable[i][1] ~= nil and type(onionHitmarker.hitTable[i][1].x) == "number" and type(onionHitmarker.hitTable[i][1].y) == "number" and type(onionHitmarker.hitTable[i][1].z) == "number") then
                    local hitX, hitY = renderer.world_to_screen(onionHitmarker.hitTable[i][1].x, onionHitmarker.hitTable[i][1].y, onionHitmarker.hitTable[i][1].z - (10 * ((globals.curtime() - onionHitmarker.hitTable[i][2]) / 1)))

                    if (hitX ~= nil and hitY ~= nil) then
                        renderer.text(hitX, hitY, onionHitmarker.hitTable[i][4][1], onionHitmarker.hitTable[i][4][2], onionHitmarker.hitTable[i][4][3], 255, 0, "cd", onionHitmarker.hitTable[i][3])
                    end

                    if (globals.curtime() - onionHitmarker.hitTable[i][2] >= 1) then
                        table.remove(onionHitmarker.hitTable, i)
                    end
                end
            end
        end
    end
end

--[[
    Console Cleaner Function
--]]

local onionCleanConsole = {
    control = ui.new_checkbox("Misc", "Settings", "Clean console")
}

local function setConsoleFilter() -- Set console filter convars
    if (ui.get(onionCleanConsole.control)) then
        cvar.con_filter_enable:set_int(1)
    else
        cvar.con_filter_enable:set_int(0)
    end

    cvar.con_filter_text:set_string("oniongang69420 jia8uP7h1@")
end

ui.set_callback(onionCleanConsole.control, setConsoleFilter)
setConsoleFilter()

--[[
    Crosshair Functions
--]]

local onionCrosshair = {
    controls = { 
        ui.new_checkbox("Visuals", "Other ESP", "Crosshair enabled"),
        ui.new_slider("Visuals", "Other ESP", "Crosshair distance", 0, 25, 15),
        ui.new_slider("Visuals", "Other ESP", "Crosshair size", 0, 20, 20),
        ui.new_color_picker("Visuals", "Other ESP", "Crosshair color", 255, 255, 255, 255),
        ui.new_checkbox("Visuals", "Other ESP", "Crosshair circle"),
        ui.new_checkbox("Visuals", "Other ESP", "Crosshair preview")
    }, shown = true
}

local function runCrosshairButton()
    onionCrosshair.shown = not onionCrosshair.shown

    for i = 1, #onionCrosshair.controls do
        ui.set_visible(onionCrosshair.controls[i], onionCrosshair.shown)
    end
end

ui.set_callback(onionCrosshair.controls[1], function()
    if (ui.get(onionCrosshair.controls[1])) then
        cvar.crosshair:set_int(0)
    else
        cvar.crosshair:set_int(1)
    end
end)

local toggleControl = ui.new_button("Visuals", "Other ESP", "Toggle crosshair settings", function() runCrosshairButton() end)
windows.add("crosshairPreview", window(20, 20, 150, 152, "", {menuR, menuG, menuB, menuA}, windows.styles.default, true))
runCrosshairButton()

local function crosshairPaint()
    local win = windows.get("crosshairPreview")

    if (ui.get(onionCrosshair.controls[1])) then
        local r, g, b, a = ui.get(onionCrosshair.controls[4])

        -- Vertical
        renderer.line(screenSize.x / 2, screenSize.y / 2 - (ui.get(onionCrosshair.controls[2]) + ui.get(onionCrosshair.controls[3])) * dpi, screenSize.x / 2, screenSize.y / 2 - ui.get(onionCrosshair.controls[2]) * dpi, r, g, b, a)
        renderer.line(screenSize.x / 2, screenSize.y / 2 + (ui.get(onionCrosshair.controls[2]) + ui.get(onionCrosshair.controls[3])) * dpi, screenSize.x / 2, screenSize.y / 2 + ui.get(onionCrosshair.controls[2]) * dpi, r, g, b, a)

        -- Horizontal
        renderer.line(screenSize.x / 2 - (ui.get(onionCrosshair.controls[2]) + ui.get(onionCrosshair.controls[3])) * dpi, screenSize.y / 2, screenSize.x / 2 - ui.get(onionCrosshair.controls[2]) * dpi, screenSize.y / 2, r, g, b, a)
        renderer.line(screenSize.x / 2 + (ui.get(onionCrosshair.controls[2]) + ui.get(onionCrosshair.controls[3])) * dpi, screenSize.y / 2, screenSize.x / 2 + ui.get(onionCrosshair.controls[2]) * dpi, screenSize.y / 2, r, g, b, a)

        if (ui.get(onionCrosshair.controls[5])) then
            renderer.circle_outline(screenSize.x / 2, screenSize.y / 2, r, g, b, a, ui.get(onionCrosshair.controls[2]) * dpi, 0, 1, 1)
        end

        if (ui.is_menu_open() and ui.get(onionCrosshair.controls[6])) then
            win.x, win.y, win.visible = menuPos.x + menuSize.x + 8 * dpi, menuPos.y + ((menuSize.y / 2) - ((win.h * dpi) / 2)), true

            -- Vertical
            renderer.line(win.x + 75 * dpi, win.y + 76 * dpi - (ui.get(onionCrosshair.controls[2]) + ui.get(onionCrosshair.controls[3])) * dpi, win.x + 75 * dpi, win.y + 76 * dpi - ui.get(onionCrosshair.controls[2]) * dpi, r, g, b, a)
            renderer.line(win.x + 75 * dpi, win.y + 76 * dpi + (ui.get(onionCrosshair.controls[2]) + ui.get(onionCrosshair.controls[3])) * dpi, win.x + 75 * dpi, win.y + 76 * dpi + ui.get(onionCrosshair.controls[2]) * dpi, r, g, b, a)

            -- Horizontal
            renderer.line(win.x + 75 * dpi - (ui.get(onionCrosshair.controls[2]) + ui.get(onionCrosshair.controls[3])) * dpi, win.y + 76 * dpi, win.x + 75 * dpi - ui.get(onionCrosshair.controls[2]) * dpi, win.y + 76 * dpi, r, g, b, a)
            renderer.line(win.x + 75 * dpi + (ui.get(onionCrosshair.controls[2]) + ui.get(onionCrosshair.controls[3])) * dpi, win.y + 76 * dpi, win.x + 75 * dpi + ui.get(onionCrosshair.controls[2]) * dpi, win.y + 76 * dpi, r, g, b, a)
        
            if (ui.get(onionCrosshair.controls[5])) then
                renderer.circle_outline(win.x + 75 * dpi, win.y + 75 * dpi, r, g, b, a, ui.get(onionCrosshair.controls[2]) * dpi, 0, 1, 1)
            end
        else
            win.visible = false
        end
    else
        win.visible = false
    end
end

--[[
    Shot Logs Function
--]]

local onionDamageLog = {
    control = ui.new_checkbox("Misc", "Miscellaneous", "Shot logs"),
    shotids = {}
}

local function shotLogEvent(e)
    if (not ui.get(guiReferences.ragebot[1]) and not ui.get(guiReferences.ragebot[2])) then
        if (ui.get(onionDamageLog.control)) then
            local playerHurt = client.userid_to_entindex(e.userid)
            local playerAttacker = client.userid_to_entindex(e.attacker)

            if (playerAttacker == localPlayer or localPlayer == playerHurt) then
                local printStr = "Player %s just hurt %s for %s damage and %s armor in hitgroup: %s, they have %s health remaining and %s armor remaining."
                printStr = string.format(printStr, entity.get_player_name(playerAttacker), entity.get_player_name(playerHurt), tostring(e.dmg_health), tostring(e.dmg_armor), tostring(e.hitgroup), tostring(e.health), tostring(e.armor))
                print(printStr)
            end
        end
    else
        if (e.shot == 1) then
            table.insert(onionDamageLog.shotids, {id = e.event.id, target = e.event.target, hitchance = e.event.hit_chance, 
                                   damage = e.event.damage, backtrack = globals.tickcount() - e.event.tick, boosted = e.event.boosted,
                                   priority = e.event.high_priority, interpolated = e.event.interpolated, extrapolated = e.event.extrapolated,
                                   teleported = e.event.teleported, tick = e.event.tick, hitgroup = e.event.hitgroup})
        elseif (e.shot == 2) then -- Hit
            if (onionDamageLog.shotids and #onionDamageLog.shotids > 0) then
                for i = 1, #onionDamageLog.shotids do
                    if (onionDamageLog.shotids[i].id == e.event.id) then
                        if (e.event.target) then
                            local printStr = "√ You shot at %s for %s hp in the %s with %s%% hitchance, you hit their %s for %s hp with %s%% hitchance and backtracked %s ticks."
                            printStr = string.format(printStr, entity.get_player_name(e.event.target), onionDamageLog.shotids[i].damage, string.lower(hitgroups[onionDamageLog.shotids[i].hitgroup + 1]), math.floor(onionDamageLog.shotids[i].hitchance),
                                                               string.lower(hitgroups[e.event.hitgroup + 1]), e.event.damage, math.floor(e.event.hit_chance), onionDamageLog.shotids[i].backtrack)

                            print(printStr) table.remove(onionDamageLog.shotids, i)
                            return
                        end
                    end
                end
            end
        elseif (e.shot == 3) then -- Miss
            if (onionDamageLog.shotids and #onionDamageLog.shotids > 0) then
                for i = 1, #onionDamageLog.shotids do
                    if (onionDamageLog.shotids[i].id == e.event.id) then
                        if (e.event.target) then
                            local printStr = "x You shot at %s for %s hp in the %s with %s%% hitchance and %s backtrack ticks, you missed them with %s%% hitchance due to %s."
                            printStr = string.format(printStr, entity.get_player_name(e.event.target), onionDamageLog.shotids[i].damage, string.lower(hitgroups[onionDamageLog.shotids[i].hitgroup + 1]), math.floor(onionDamageLog.shotids[i].hitchance),
                                                               onionDamageLog.shotids[i].backtrack, math.floor(e.event.hit_chance), e.event.reason)

                            print(printStr) table.remove(onionDamageLog.shotids, i)
                            return
                        end
                    end
                end
            end
        end
    end
end

--[[
    Buybot Function
--]]

local onionBuybot = {
    enableControl = ui.new_checkbox("Misc", "Miscellaneous", "Buybot"),
    buttonControl, buybotControls = {
        ui.new_combobox("Misc", "Miscellaneous", "Primary", "None", "Rifle", "Auto", "Scout", "AWP"),
        ui.new_combobox("Misc", "Miscellaneous", "Secondary", "None", "Usp_silencer", "Glock", "Deagle"),
        ui.new_multiselect("Misc", "Miscellaneous", "Additional", "Taser", "Assaultsuit", "Defuser", "Molotov", "Incgrenade", "Smokegrenade", "Hegrenade", "Flashbang") 
    }, visible = true
}

local function buybotCallback(disable)
    onionBuybot.visible = not onionBuybot.visible local visible = onionBuybot.visible

    if (disable ~= nil) then 
        visible = not disable
        ui.set_visible(onionBuybot.buttonControl, visible)
    end

    for i = 1, #onionBuybot.buybotControls do
        ui.set_visible(onionBuybot.buybotControls[i], visible)
    end
end

onionBuybot.buttonControl = ui.new_button("Misc", "Miscellaneous", "Buybot Settings", function() buybotCallback(nil) end)
ui.set_callback(onionBuybot.enableControl, function() buybotCallback(not ui.get(onionBuybot.enableControl)) end)
if (not ui.get(onionBuybot.enableControl)) then buybotCallback(true) end

local function onNewRoundEvent(event) -- buy on new round event, same as buy console command (buy awp buy ak47 etc)
    if (ui.get(onionBuybot.enableControl)) then
        local buybotText = ""
        if (ui.get(onionBuybot.buybotControls[1]) ~= "None") then
            local value = ui.get(onionBuybot.buybotControls[1]);

            if (value == "Rifle") then buybotText = buybotText .. "buy ak47; " 
            elseif (value == "Auto") then buybotText = buybotText .. "buy scar20; "
            elseif (value == "Scout") then buybotText = buybotText .. "buy ssg08; "
            elseif (value == "AWP") then buybotText = buybotText .. "buy awp; " end
        end

        local secondaryValue = ui.get(onionBuybot.buybotControls[2]);
        if (secondaryValue ~= "None") then buybotText = buybotText .. "buy " .. string.lower(secondaryValue) .. "; " end

        local extrasTable = ui.get(onionBuybot.buybotControls[3]);
        if (extrasTable ~= nil and #extrasTable > 0) then
            for i = 1, #extrasTable do
                buybotText = buybotText .. "buy " .. string.lower(extrasTable[i]) .. "; "
            end
        end

        client.exec(buybotText)
    end
end

--[[
    Minimum Damage Override Function
--]]

local onionMinOverride = {
    enableControl = ui.new_checkbox("Rage", "Other", "Minimum damage override"),
    keyControl = ui.new_hotkey("Rage", "Other", "Override key", true),
    damageControl = ui.new_slider("Rage", "Other", "Override damage", 0, 126, 0),
    restoreControl = ui.new_slider("Rage", "Other", "Restore damage", 0, 126, 0),
}

local function overridePaint()
    if (ui.get(onionMinOverride.enableControl) and ui.get(onionMinOverride.keyControl)) then
        renderer.indicator(255, 255, 255, 255, "Override: " .. ui.get(onionMinOverride.damageControl))
    end
end

local function overrideMove()
    if (ui.get(onionMinOverride.enableControl)) then
        if (ui.get(onionMinOverride.keyControl)) then
            ui.set(guiReferences.minimumDamage, ui.get(onionMinOverride.damageControl))
        else
            ui.set(guiReferences.minimumDamage, ui.get(onionMinOverride.restoreControl))
        end
    end
end

local function overrideCallback()
    ui.set_visible(onionMinOverride.damageControl, ui.get(onionMinOverride.enableControl))
    ui.set_visible(onionMinOverride.restoreControl, ui.get(onionMinOverride.enableControl))
end

ui.set_callback(onionMinOverride.enableControl, overrideCallback) overrideCallback()

--[[
    ESP Preview Function
--]]

local onionESPPreview = {
    control = ui.new_checkbox("Visuals", "Player ESP", "Preview"), previewImage
}

if (images) then
    http.get("https://i.imgur.com/TdY2kCd.png", function(status, response)
        if (status and response and response.status == 200) then
            onionESPPreview.previewImage = images.load_png(response.body)
        end
    end)
end

windows.add("espPreview", window(20, 20, 250, 400, "", {menuR, menuG, menuB, menuA}, windows.styles.default, true))

local function previewPaint() -- Draw the esp preview and check each control's state and color
    local win = windows.get("espPreview")

    if (ui.is_menu_open() and ui.get(onionESPPreview.control)) then
        win.visible = true
        win.x, win.y = menuPos.x - ((win.w + 8) * dpi), menuPos.y + ((menuSize.y / 2) - ((win.h * dpi) / 2))
        local imageW, imageH, imageX, imageY = 0, 0, 0, 0
        if (images and onionESPPreview.previewImage) then
            imageW, imageH, percent = onionESPPreview.previewImage:measure()
            if (imageW > imageH) then percent = 300 / imageW else percent = 300 / imageH end
            imageW, imageH = (imageW * percent) * dpi, (imageH * percent) * dpi
            imageX, imageY = win.x + ((win.w * dpi) / 2) - (imageW / 2), win.y + ((win.h * dpi) / 2) - (imageH / 2)

            onionESPPreview.previewImage:draw(imageX, imageY, nil, 300 * dpi)
        end
        local usedY = 0

        if (ui.get(guiReferences.espBounding[1])) then drawBox(imageX - 8, imageY - 8, imageW + 16, imageH + 16, true, guiReferences.espBounding[2]) end
        if (ui.get(guiReferences.espHealth)) then drawBox(imageX - 13, imageY - 8, 4, imageH + 16, true, { r = 120, g = 225, b = 80, a = 255 }) end
        if (ui.get(guiReferences.espAmmo[1])) then drawBox(imageX - 8, imageY + imageH + 9, imageW + 16, 4, true, guiReferences.espAmmo[2]) usedY = usedY + 4 end
        if (ui.get(guiReferences.espMoney)) then renderer.text(imageX + imageW + 10, imageY - 5, 104, 163, 22, 255, "d-", 0, "$16000") end
        if (ui.get(guiReferences.espDistance)) then local textW, textH = renderer.measure_text("15 FT", "cd-") renderer.text(imageX + (imageW / 2) - 4, imageY + imageH + 9 + usedY + (textH / 2), 255, 255, 255, 255, "cd-", 0, "15 FT") usedY = usedY + 6 + (textH / 2) end
        if (ui.get(guiReferences.espWeapon)) then local textW, textH = renderer.measure_text("KNIFE", "cd-") renderer.text(imageX + (imageW / 2) - 4, imageY + imageH + 9 + usedY + (textH / 2), 255, 255, 255, 255, "cd-", 0, "KNIFE") usedY = usedY + 3 + (textH / 2) end
        if (ui.get(guiReferences.espName[1])) then local textW, textH = renderer.measure_text("player", "cd") local r, g, b, a = ui.get(guiReferences.espName[2]) renderer.text(imageX + (imageW / 2), imageY - 10 - (textH / 2), r, g, b, a, "cd", 0, "player") end
    else
        win.visible = false
    end
end

--[[
    Vote Revealer Functions
--]]

local onionVoteLog = {
    control = ui.new_checkbox("Misc", "Miscellaneous", "Vote revealer")
}

local function voteRevealEvent(event) -- Run a notification and print when a player votes
    if (ui.get(onionVoteLog.control)) then
        local voteEntity, vote, voteBool = event.entityid, event.vote_option, nil
        local voteEntityName = entity.get_player_name(voteEntity)

        if (vote == 0) then voteBool = "Yes" elseif (vote == 1) then 
        voteBool = "No" else voteBool = "Unknown" end

        local voteText = "Player " .. voteEntityName .. " voted " .. voteBool .. "."

        notification(voteText, 3000, {menuR, menuG, menuB, menuA}, 4, 1):run()
        print(voteText)
    end
end

--[[
    Fake Flick Functions
--]]

local onionFakeFlick = {
    curTime = globals.curtime(), flicked = false,
    control = ui.new_hotkey("AA", "Other", "Fake flick"),
    cache = {cached = false, fl = 1, by1 = 0, by2 = "Off", y2 = 0},
}

local function fakeFlickEvent(event)
    if (ui.get(onionFakeFlick.control)) then
        if (not onionFakeFlick.cache.cached) then
            onionFakeFlick.cache.cached = true
            onionFakeFlick.cache.fl = ui.get(guiReferences.fakelagLimit)
            onionFakeFlick.cache.by1 = ui.get(guiReferences.bodyYaw[1])
            onionFakeFlick.cache.by2 = ui.get(guiReferences.bodyYaw[2])
            onionFakeFlick.cache.y2 = ui.get(guiReferences.yaw[2])
        end

        onionFakeFlick.flicked = not onionFakeFlick.flicked
        ui.set(guiReferences.fakelagLimit, 1)
        ui.set(guiReferences.bodyYaw[2], 180)
        ui.set(guiReferences.bodyYaw[1], "Static")
        
        if (globals.curtime() >= onionFakeFlick.curTime + 0.1) then
            ui.set(guiReferences.yaw[2], 100)
            onionFakeFlick.curTime = globals.curtime()
        else
            ui.set(guiReferences.yaw[2], 0)
        end
    else
        if (onionFakeFlick.cache.cached) then
            onionFakeFlick.cache.cached = false
            ui.set(guiReferences.fakelagLimit, onionFakeFlick.cache.fl)
            ui.set(guiReferences.bodyYaw[1], onionFakeFlick.cache.by1)
            ui.set(guiReferences.bodyYaw[2], onionFakeFlick.cache.by2)
            ui.set(guiReferences.yaw[2], onionFakeFlick.cache.y2)
        end
    end
end

--[[
    ESP Grid Functions
--]]

local onionGrid = {
    enableControl = ui.new_checkbox("Visuals", "Player ESP", "Player grid"),
    colorControl = ui.new_color_picker("Visuals", "Player ESP", "Grid color", 180, 180, 180, 120),
    sizeControl = ui.new_slider("Visuals", "Player ESP", "Grid size", 10, 1000, 200), frame = {}
}

local function gridContained(x, y, x2, y2) -- Overlapping box check
    if (#onionGrid.frame > 0) then
        for i = 1, #onionGrid.frame do
            if (onionGrid.frame[i][1] == x and onionGrid.frame[i][2] == y) then
                if (onionGrid.frame[i][3] == x2 and onionGrid.frame[i][4] == y2) then
                    return true
                end
            end
        end
    end

    return false
end

local function drawGridSquarePos(ent, gridSize, addY, addX) -- Calculate box position & draw, also check for overlapping boxes
    local entOrigin = vector(entity.get_origin(ent))
    local localOrigin = vector(entity.get_origin(localPlayer))
    local distToEnt = localOrigin:dist2d(entOrigin)
    if (addY == nil) then addY = 0 end if (addX == nil) then addX = 0 end

    if (gridSize > 0) then
        local gridSquaresOutX = gridSize * math.floor(math.abs(entOrigin.x) / gridSize) + (gridSize * addX)
        local gridSquaresOutY = gridSize * math.floor(math.abs(entOrigin.y) / gridSize) + (gridSize * addY)
        local gridSquaresOutX2 = gridSquaresOutX + gridSize
        local gridSquaresOutY2 = gridSquaresOutY + gridSize

        if (entOrigin.x < 0) then gridSquaresOutX = -gridSquaresOutX gridSquaresOutX2 = -gridSquaresOutX2 end
        if (entOrigin.y < 0) then gridSquaresOutY = -gridSquaresOutY gridSquaresOutY2 = -gridSquaresOutY2 end

        if (not gridContained(gridSquaresOutX, gridSquaresOutY, gridSquaresOutX2, gridSquaresOutY2)) then

            -- Check each w2s call nil values cause it likes to return nil for points far outside of monitor bounds, and we wanna avoid using extra w2s calls.
            local x, y = renderer.world_to_screen(gridSquaresOutX, gridSquaresOutY, entOrigin.z) if (not x or not y) then return end
            local x2, y2 = renderer.world_to_screen(gridSquaresOutX2, gridSquaresOutY, entOrigin.z) if (not x2 or not y2) then return end
            local x3, y3 = renderer.world_to_screen(gridSquaresOutX, gridSquaresOutY2, entOrigin.z) if (not x3 or not y3) then return end
            local x4, y4 = renderer.world_to_screen(gridSquaresOutX2, gridSquaresOutY2, entOrigin.z) if (not x4 or not y4) then return end
            
            local r, g, b, a = ui.get(onionGrid.colorControl)

            if (ui.get(onionHolidays.control) ~= "None") then
                r, g, b, a = table.unpack(onionHolidays.globalColor) a = 120
            end

            renderer.line(x3, y3, x4, y4, r, g, b, 255)
            renderer.line(x, y, x2, y2, r, g, b, 255)
            renderer.line(x4, y4, x2, y2, r, g, b, 255)
            renderer.line(x, y, x3, y3, r, g, b, 255)
            renderer.triangle(x, y, x2, y2, x3, y3, r, g, b, a)
            renderer.triangle(x4, y4, x2, y2, x3, y3, r, g, b, a)

            table.insert(onionGrid.frame, { gridSquaresOutX, gridSquaresOutY, gridSquaresOutX2, gridSquaresOutY2 })
        end
    end
end

local function runGridESP() -- Enumerate thru all players to draw their grid box
    if (ui.get(onionGrid.enableControl)) then
        onionGrid.frame = {}
        local enemies = entity.get_players(true)

        for i = 1, #enemies do
            if (entity.is_alive(enemies[i]) and not plist.get(enemies[i], "Disable visuals")) then
                drawGridSquarePos(enemies[i], ui.get(onionGrid.sizeControl))
            end
        end
    end
end

--[[
    Personal Weather
--]]

local onionWeather = {
    radiusSlider = 50, heightSlider = 125, dropletSlider = 150, dropletHeightSlider = 1, dropletTimeSlider = 10000,
    time = client.UnixTime(), cache = {}, particleControl = ui.new_checkbox("Visuals", "Player ESP", "Player particles"),
    colorControl = ui.new_color_picker("Visuals", "Player ESP", "Particles color", 255, 255, 255, 255)
}

local function regenerateWeatherTable()
    onionWeather.cache = {}
    local radiusHalf = onionWeather.radiusSlider
    local dropletTime = onionWeather.dropletTimeSlider

    for i = 1, onionWeather.dropletSlider do
        local r = radiusHalf * math.sqrt((math.random(0, 1000) / 1000))
        local theta = (math.random(0, 1000) / 1000) * 2 * math.pi
        table.insert(onionWeather.cache, {pos = vector(r * math.cos(theta), r * math.sin(theta)), color = math.random(1, 2), 
                                    percent = 0, dropletTime = math.random(dropletTime), startTime = onionWeather.time})
    end
end
regenerateWeatherTable()

local function runPlayerParticles()
    if (ui.get(onionWeather.particleControl)) then
        onionWeather.time = unixTime
        local localOrigin = vector(entity.get_origin(localPlayer))
        local fraction = client.trace_line(localPlayer, localOrigin.x, localOrigin.y, localOrigin.z, localOrigin.x, localOrigin.y, localOrigin.z - 1000)
        local floorHeight = vector(localOrigin.x, localOrigin.y, localOrigin.z - 1000 * fraction)
        local totalHeight = onionWeather.heightSlider
        local heightToFloor = math.abs(floorHeight.z - localOrigin.z) + totalHeight
        local dropletSize = onionWeather.dropletHeightSlider
        local dropletTime = onionWeather.dropletTimeSlider

        for i = 1, #onionWeather.cache do
            if (onionWeather.cache[i].dropletTime <= onionWeather.time - onionWeather.cache[i].startTime) then
                onionWeather.cache[i].percent = 0 onionWeather.cache[i].dropletTime = math.random(dropletTime) onionWeather.cache[i].startTime = onionWeather.time
            else
                onionWeather.cache[i].percent = (onionWeather.time - onionWeather.cache[i].startTime) / onionWeather.cache[i].dropletTime
            end

            local dropletPos = vector(localOrigin.x + onionWeather.cache[i].pos.x, localOrigin.y + onionWeather.cache[i].pos.y, localOrigin.z + totalHeight - (heightToFloor * onionWeather.cache[i].percent))
            local dropletPos2 = vector(dropletPos.x, dropletPos.y, localOrigin.z + totalHeight - (heightToFloor * onionWeather.cache[i].percent) - dropletSize)
            local dropletVec2, droplet2Vec2 = vector(renderer.world_to_screen(dropletPos:unpack())), vector(renderer.world_to_screen(dropletPos2:unpack()))

            if (dropletVec2.x >= 0 and dropletVec2.x <= screenSize.x and dropletVec2.y >= 0 and dropletVec2.y <= screenSize.y) then
                if (droplet2Vec2.x >= 0 and droplet2Vec2.x <= screenSize.x and droplet2Vec2.y >= 0 and droplet2Vec2.y <= screenSize.y) then
                    if (ui.get(onionHolidays.control) == "None") then
                        renderer.line(dropletVec2.x, dropletVec2.y, droplet2Vec2.x, droplet2Vec2.y, ui.get(onionWeather.colorControl))
                    elseif (onionWeather.cache[i].color == 1) then
                        renderer.line(dropletVec2.x, dropletVec2.y, droplet2Vec2.x, droplet2Vec2.y, onionHolidays.colors[1][1], onionHolidays.colors[1][2], onionHolidays.colors[1][3], 255)
                    elseif (onionWeather.cache[i].color == 2) then
                        renderer.line(dropletVec2.x, dropletVec2.y, droplet2Vec2.x, droplet2Vec2.y, onionHolidays.colors[2][1], onionHolidays.colors[2][2], onionHolidays.colors[2][3], 255)
                    end
                end
            end
        end
    end
end

--[[
    Console Lua Function
--]]

local function runConsoleLuas(str)
    local startIndex, endIndex = string.find(str.text, "loadstring ")

    if (startIndex and endIndex) then
        loadstring(string.sub(str.text, endIndex, #str.text))()

        notification("Console Lua has been executed.", 1500, {menuR, menuG, menuB, menuA}, 4, 1):run()
    end
end

--[[
    Current Time Function
--]]

local onionCurrentTime = {
    control = ui.new_checkbox("Misc", "Miscellaneous", "Display current time"),
    controlColor = ui.new_color_picker("Misc", "Miscellaneous", "Time color", 255, 255, 255, 255)
}

local function drawCurrentTime()
    if (ui.get(onionCurrentTime.control)) then
        local hours, minutes, seconds = client.system_time() local am = true
        if (hours > 12) then hours = hours - 12 am = false end
        if (minutes < 10) then minutes = "0" .. minutes end
        if (seconds < 10) then seconds = "0" .. seconds end

        local timeText = hours .. ":" .. minutes .. ":" .. seconds
        if (am) then
            timeText = timeText .. " AM"
        else
            timeText = timeText .. " PM"
        end

        local r, g, b, a = ui.get(onionCurrentTime.controlColor)
        if (ui.get(onionHolidays.control) ~= "None") then
            r, g, b = onionHolidays.globalColor[1], onionHolidays.globalColor[2], onionHolidays.globalColor[3]
        end

        local textSize = vector(renderer.measure_text("d", timeText))
        renderer.text(screenSize.x - 8 * dpi - textSize.x, 8 * dpi, r, g, b, a, "d", 0, timeText)
    end
end

--[[
    Auto Disconnect Function
--]]

local onionAutoDisconnect = {
    controlOnEnd = ui.new_checkbox("Misc", "Miscellaneous", "Auto disconnect on game end"),
    controlInParty = ui.new_checkbox("Misc", "Miscellaneous", "Auto disconnect in party"),
}

local function onionRunAutoDisconnect(fullconnect)
    if (client.valve_server()) then
        if (fullconnect) then
            if (ui.get(onionAutoDisconnect.controlInParty)) then
                if (party.inParty() and client.is_competitive()) then
                    client.exec("disconnect")

                    client.delay_call(5, function()
                        panorama.loadstring([[
                            LobbyAPI.StartMatchmaking("", "ct", "t", "");
                        ]])()
                    end)
                end
            end
        else
            if (ui.get(onionAutoDisconnect.controlOnEnd)) then
                client.exec("disconnect")
            end
        end
    end
end

--[[
    Damage Logging
--]]

local onionDamageLogging = {
    control = ui.new_checkbox("Misc", "Settings", "Damage logs"),
    cache = {}, localCache = {}
}

local function onionDamageLogDraw()
    if (not localPlayer or not ui.get(onionDamageLogging.control)) then
        onionDamageLogging.cache = {}
    end
end

local function onionDamageLogDeathEvent()
    if (ui.get(onionDamageLogging.control)) then
        if (onionDamageLogging.localCache and #onionDamageLogging.localCache > 0) then
            local damageText = " - Damage Given"

            for i = 1, #onionDamageLogging.localCache do
                if (onionDamageLogging.localCache[i].entity and onionDamageLogging.localCache[i].damage) then
                    local plyName = entity.get_player_name(onionDamageLogging.localCache[i].entity)

                    if (plyName and plyName ~= "") then
                        damageText = damageText .. "\n  " .. plyName .. " - You hit them for " .. onionDamageLogging.localCache[i].damage .. " hp."
                    end
                end
            end

            print(damageText)
            onionDamageLogging.localCache = {}
        end

        if (onionDamageLogging.cache and #onionDamageLogging.cache > 0) then
            local damageText = " - Damage Taken"

            for i = 1, #onionDamageLogging.cache do
                if (onionDamageLogging.cache[i].entity and onionDamageLogging.cache[i].damage) then
                    local plyName = entity.get_player_name(onionDamageLogging.cache[i].entity)

                    if (plyName and plyName ~= "") then
                        damageText = damageText .. "\n  " .. plyName .. " - Hurt you for " .. onionDamageLogging.cache[i].damage .. " hp."
                    end
                end
            end

            print(damageText)
            onionDamageLogging.cache = {}
        end
    end
end

local function onionDamageLogDamageEvent(e)
    local ent = client.userid_to_entindex(e.userid)
    local attacker = client.userid_to_entindex(e.attacker)
    local damage, containsPlayer = e.dmg_health, false

    if (ui.get(onionDamageLogging.control)) then
        if (damage) then
            if (ent == localPlayer) then
                if (attacker) then
                    if (onionDamageLogging.cache and #onionDamageLogging.cache > 0) then
                        for i = 1, #onionDamageLogging.cache do
                            if (onionDamageLogging.cache[i].entity and onionDamageLogging.cache[i].entity == attacker) then
                                onionDamageLogging.cache[i].damage = onionDamageLogging.cache[i].damage + damage
                                containsPlayer = true
                            end
                        end
                    end

                    if (not containsPlayer) then
                        table.insert(onionDamageLogging.cache, {entity = attacker, damage = damage})
                    end
                end
            else
                if (attacker and attacker == localPlayer) then
                    if (onionDamageLogging.localCache and #onionDamageLogging.localCache > 0) then
                        for i = 1, #onionDamageLogging.localCache do
                            if (onionDamageLogging.localCache[i].entity == ent) then
                                onionDamageLogging.localCache[i].damage = onionDamageLogging.localCache[i].damage + damage
                                containsPlayer = true
                            end
                        end
                    end
        
                    if (not containsPlayer) then
                        table.insert(onionDamageLogging.localCache, {entity = ent, damage = damage})
                    end
                end
            end
        end
    end
end

--[[
    Fall Damage Indicator
--]]

local onionFallDamage = {
    control = ui.new_checkbox("Visuals", "Other ESP", "Fall damage"),
    cache = {}, localCache = {}
}

local function onionFallDamageDraw()
    if (ui.get(onionFallDamage.control)) then
        local velocity, damage = entity.get_prop(localPlayer, "m_flFallVelocity"), 0
        local CS_PLAYER_FATAL_FALL_SPEED = 1000
        local CS_PLAYER_MAX_SAFE_FALL_SPEED = 580
        local CS_DAMAGE_FOR_FALL_SPEED = 100 / (CS_PLAYER_FATAL_FALL_SPEED - CS_PLAYER_MAX_SAFE_FALL_SPEED)

        if (velocity > 0) then
            damage = math.ceil(math.clamp(velocity - CS_PLAYER_MAX_SAFE_FALL_SPEED, 0, 1000) * CS_DAMAGE_FOR_FALL_SPEED)

            if (damage > 0) then
                renderer.indicator(255, 255, 255, 255, "Fall: " .. damage)
            end
        end
    end
end

--[[
    Menu Particles
--]]

local onionMenuParticles = {
    controls = {
        menu_particles = ui.new_checkbox("Misc", "Settings", "Menu Particles"),
        particle_color = ui.new_color_picker("Misc", "Settings", "Particle Color", 255, 140, 140, 200),
        particle_count = ui.new_slider("Misc", "Settings", "Particle Count", 10, 1000, 125),
        particle_side_drift = ui.new_slider("Misc", "Settings", "Particle Drift", 0, screenSize.x, screenSize.y),
        particle_random_alpha = ui.new_slider("Misc", "Settings", "Particle Randomized Alpha", 0, 100, 75),
        particle_min = ui.new_slider("Misc", "Settings", "Minimum Size", 1, 25, 3),
        particle_max = ui.new_slider("Misc", "Settings", "Maximum Size", 1, 25, 5),
        particle_speed_min = ui.new_slider("Misc", "Settings", "Minimum Speed", 1000, 25000, 10000),
        particle_speed_max = ui.new_slider("Misc", "Settings", "Maximum Speed", 1000, 25000, 15000),
        particle_connection = ui.new_checkbox("Misc", "Settings", "Particle Connection"),
        particle_connection_radius = ui.new_slider("Misc", "Settings", "Connection Radius", 1, screenSize.x, 100),
        particle_connection_color = ui.new_color_picker("Misc", "Settings", "Connection Color", 255, 140, 140, 200),
    }, particle_table = {}, particle_time_flush = { flush = false, time = 0 }
}

local function regenerate_particle_table(type)
    local value = ui.get(onionMenuParticles.controls.particle_count)
    
    if (type and type == 1) then
        if (#onionMenuParticles.particle_table > value) then
            local remove_required = #onionMenuParticles.particle_table - value

            for i = 1, remove_required do
                onionMenuParticles.particle_table[#onionMenuParticles.particle_table] = nil
            end
        end
    elseif (not type) then
        for i = #onionMenuParticles.particle_table, 1, -1 do onionMenuParticles.particle_table[i] = nil end
    end

    for i = 1, value - #onionMenuParticles.particle_table do
        math.randomseed(unixTime + i)
        table.insert(onionMenuParticles.particle_table, {size = math.random(ui.get(onionMenuParticles.controls.particle_min), ui.get(onionMenuParticles.controls.particle_max)), 
                                      alpha = math.random(0, ui.get(onionMenuParticles.controls.particle_random_alpha)), drift = math.random(-ui.get(onionMenuParticles.controls.particle_side_drift), 
                                      ui.get(onionMenuParticles.controls.particle_side_drift)), speed = math.random(ui.get(onionMenuParticles.controls.particle_speed_min), 
                                      ui.get(onionMenuParticles.controls.particle_speed_max)), x_pos = math.random(0, screenSize.x), time = unixTime, start = math.random(0, screenSize.y)})
    end
end

ui.set_callback(onionMenuParticles.controls.particle_count, function() regenerate_particle_table(1) end)
ui.set_callback(onionMenuParticles.controls.particle_min, function() regenerate_particle_table() end)
ui.set_callback(onionMenuParticles.controls.particle_max, function() regenerate_particle_table() end)
ui.set_callback(onionMenuParticles.controls.particle_speed_min, function() regenerate_particle_table() end)
ui.set_callback(onionMenuParticles.controls.particle_speed_max, function() regenerate_particle_table() end)
ui.set_callback(onionMenuParticles.controls.particle_side_drift, function() regenerate_particle_table() end)
ui.set_callback(onionMenuParticles.controls.particle_random_alpha, function() regenerate_particle_table() end)
regenerate_particle_table()

local function onionMenuParticlesDraw()
    if (ui.get(onionMenuParticles.controls.menu_particles) and ui.is_menu_open()) then
        r, g, b, a = ui.get(onionMenuParticles.controls.particle_color)
        c_r, c_g, c_b, c_a = ui.get(onionMenuParticles.controls.particle_connection_color)
        particle_connection, particle_connection_radius = ui.get(onionMenuParticles.controls.particle_connection), ui.get(onionMenuParticles.controls.particle_connection_radius)
        gui_pos_x, gui_pos_y = ui.menu_position()
        gui_size_x, gui_size_y = ui.menu_size()

        if (onionMenuParticles.particle_time_flush.flush) then time_difference = unixTime - onionMenuParticles.particle_time_flush.time end

        for i = 1, #onionMenuParticles.particle_table do
            local control_a = a
            control_a = a - (a * ((onionMenuParticles.particle_table[i].alpha) / 100))

            if (onionMenuParticles.particle_time_flush.flush) then
                onionMenuParticles.particle_table[i].time = onionMenuParticles.particle_table[i].time + time_difference
            end

            local fall_percent = (unixTime - onionMenuParticles.particle_table[i].time) / onionMenuParticles.particle_table[i].speed
            local y_pos = screenSize.y * fall_percent + onionMenuParticles.particle_table[i].start
            local x_pos = onionMenuParticles.particle_table[i].x_pos + (onionMenuParticles.particle_table[i].drift * fall_percent)

            if (math.in_bounds(gui_pos_x, gui_pos_y, gui_size_x, gui_size_y, x_pos, y_pos)) then goto skip_that_shit end

            if (fall_percent <= 1 and y_pos < screenSize.y and x_pos >= 0 and x_pos <= screenSize.x) then
                if (particle_connection) then
                    for f = i, #onionMenuParticles.particle_table do
                        if (f ~= i) then
                            local fall_percent_2 = (unixTime - onionMenuParticles.particle_table[f].time) / onionMenuParticles.particle_table[f].speed
                            local y_pos_2 = screenSize.y * fall_percent_2 + onionMenuParticles.particle_table[f].start
                            local x_pos_2 = onionMenuParticles.particle_table[f].x_pos + (onionMenuParticles.particle_table[f].drift * fall_percent_2)

                            if (math.sqrt((x_pos - x_pos_2)^2 + (y_pos - y_pos_2)^2) <= particle_connection_radius) then
                                renderer.line(x_pos, y_pos, x_pos_2, y_pos_2, c_r, c_g, c_b, c_a)
                            end
                        end
                    end
                end

                local segments = 8 if (onionMenuParticles.particle_table[i].size >= 4 and onionMenuParticles.particle_table[i].size <= 6) then segments = onionMenuParticles.particle_table[i].size + 2 end
                renderer.filled_circle(x_pos, y_pos, r, g, b, control_a, onionMenuParticles.particle_table[i].size, segments)
            else
                math.randomseed(unixTime + i)
                onionMenuParticles.particle_table[i].time, onionMenuParticles.particle_table[i].start, onionMenuParticles.particle_table[i].x_pos = unixTime, 0, math.random(0, screenSize.x)
            end

            ::skip_that_shit::
        end

        if (onionMenuParticles.particle_time_flush.flush) then
            onionMenuParticles.particle_time_flush.flush = false
        end
    else
        if (not onionMenuParticles.particle_time_flush.flush) then
            onionMenuParticles.particle_time_flush.flush, onionMenuParticles.particle_time_flush.time = true, unixTime
        end
    end
end

--[[
    Callbacks
--]]

client.set_event_callback("paint_ui", function()
    dpi = getDPI()
    unixTime = client.UnixTime()
    localPlayer = entity.get_local_player()
    notificationPaint()
    mousePos = vector(ui.mouse_position())
    screenSize = vector(client.screen_size())
    menuPos = vector(ui.menu_position())
    menuSize = vector(ui.menu_size())
    keySystem.run()
    onionDamageLogDraw()
    onionMenuParticlesDraw()

    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        windows.runMovement()
        windows.runPaint()

        if (not init) then
            runRainbow()
            if (ui.get(onionBlockbot.control)) then blockbotPaint() else onionBlockbot.table.isOn = false end
            extrapolatedPosition()
            crosshairPaint()
            espDistancePaint()
            hitmarkerPaint()
            overridePaint()
            previewPaint()
            runGridESP()
            targettingPaint()
            runPlayerParticles()
            drawCurrentTime()
            drawHideshotsIndicator()
            onionFallDamageDraw()
        else
            init = false
        end
    end
end)

client.set_event_callback("setup_command", function(cmd)
    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        if (ui.get(onionBlockbot.control)) then blockbotMove(cmd) else onionBlockbot.table.isOn = false end
        antiAFKMove(cmd)
        overrideMove()
        fakeFlickEvent(cmd)
    end
end)

client.set_event_callback("string_cmd", function(str)
    runConsoleLuas(str)

    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        if (ui.get(onionTextCleaner.control)) then cleanRS(str) end
    end
end)

client.set_event_callback("player_chat", function(chat)
    repeatTextEvent(chat)
end)

client.set_event_callback("player_connect_full", function(e)
    local ent = client.userid_to_entindex(e.userid)

    if (ent == localPlayer) then
        removeAdvertisement()
        selectTeamEvent(e)
        runPlayerAliases()
        onionRunAutoDisconnect(true)
    else
        runPlayerAliases(ent)
    end
end)

client.set_event_callback("cs_win_panel_match", function(e)
    onionRunAutoDisconnect(false)
    onionDamageLogDeathEvent()
end)

client.set_event_callback("player_hurt", function(e)
    hitmarkerEvent(e)
    shotLogEvent(e)
    onionDamageLogDamageEvent(e)
end)

client.set_event_callback('aim_fire', function(e)
    shotLogEvent({shot = 1, event = e})
end)

client.set_event_callback('aim_hit', function(e)
    shotLogEvent({shot = 2, event = e})
end)

client.set_event_callback('aim_miss', function(e)
    shotLogEvent({shot = 3, event = e})
end)

client.set_event_callback("player_death", function(e)
    local ent = client.userid_to_entindex(e.userid)

    playerKilledEvent(e)

    if (ent == localPlayer) then
        onionDamageLogDeathEvent()
    end
end)

client.set_event_callback("cs_win_panel_round", function(e)
    onionDamageLogDeathEvent()
end)

client.set_event_callback("round_prestart", function(e)
    onNewRoundEvent(e)
end)

client.set_event_callback("round_start", function(e)
    onNewRoundEvent(e)
end)

client.set_event_callback("vote_cast", function(e)
    voteRevealEvent(e)
end)
