local ffi = require("ffi");
local vector = require("vector");
local http = require("gamesense/http");
local images = require("gamesense/images");

local localPlayer = entity.get_local_player();
local Initialization = true;
local menuR, menuG, menuB, menuA = ui.get(ui.reference("Misc", "Settings", "Menu color"))
local mouseX, mouseY;
local scrW, scrH;
local dpi;
local menuX, menuY = ui.menu_position();
local menuW, menuH = ui.menu_size();

--[[
    Hot Enumerators
--]]

local moveType = {
    none = 0, isometric = 1, walk = 2,
    step = 3, fly = 4, flygravity = 5, 
    vphysics = 6, push = 7, noclip = 8,
    ladder = 9, observer = 10, custom = 11
};

local flags = {
    onground = 1, ducking = 2, waterjump = 3,
    ontrain = 4, inrain = 5, frozen = 6,
    atcontrols = 7, client = 8, fakeclient = 9, inwater = 10
};

--[[
    Required Functions
--]]

local dpiControl = ui.reference("Misc", "Settings", "DPI scale");
local function getDPI() -- since the dpi control returns a string with a % sign do some magical wizardry to remove it
    local dpi = ui.get(dpiControl):gsub('[%c%p%s]', '');

    if (pcall(function() tonumber(dpi) end)) then
        return tonumber(dpi) / 100;
    else
        return 1;
    end
end

local function inMoveType(ent, movetype)
    return entity.get_prop(ent, "m_movetype") == movetype;
end

local function hasFlag(ent, flag)
    return bit.band(flag, entity.get_prop(ent, "m_fFlags")) ~= 0;
end

local function degToRad(deg)
    return deg * math.pi / 180;
end

local function fromAng(vec)
    return vector(math.cos(degToRad(vec.x)) * math.cos(degToRad(vec.y)), math.cos(degToRad(vec.x)) * math.sin(degToRad(vec.y)), -1 * math.sin(degToRad(vec.x)));
end

local function trace(entSkip, vector1, vector2) -- replacement function to the regular trace that returns the ending vector aswell
    local percent, hitEnt = client.trace_line(entity.get_local_player(), vector1.x, vector1.y, vector1.z, vector2.x, vector2.y, vector2.z);
    local endVector = vector(vector1.x + (vector2.x - vector1.x * percent), vector1.y + (vector2.y - vector1.y * percent), vector1.z + (vector2.z - vector1.z * percent));

    return percent, hitEnt, endVector;
end

local function traceCrosshair() -- trace to the end of your crosshair using eye angles
    local traceDist = 10000; -- Suck my nutts

    local eye = vector(client.camera_position());
    local camX, camY, camZ = client.camera_angles();
    local cam = fromAng(vector(camX, camY, camZ));
    local crosshairLocation = vector(eye.x + cam.x * traceDist, eye.y + cam.y * traceDist, eye.z + cam.z * traceDist);
    local percent, hitEnt = client.trace_line(entity.get_local_player(), eye.x, eye.y, eye.z, crosshairLocation.x, crosshairLocation.y, crosshairLocation.z);
    crosshairLocation = vector(eye.x + cam.x * (traceDist * percent), eye.y + cam.y * (traceDist * percent), eye.z + cam.z * (traceDist * percent));

    return percent, hitEnt, crosshairLocation;
end

function math.clamp(number, min, max)
    if (number >= max) then
        return max;
    elseif (number <= min) then
        return min;
    else
        return number;
    end
end

local function numberToNumber(num1, num2, percent)
    return math.clamp(num1 + (num2 - num1) * percent, 0, 255);
end

--[[
    Rendering Functions
--]]

local object3D = {
    circle = 1, cone = 2, cylinder = 3
};

function draw3D(origin, radius, color, outline, type, height)
    local localPlayer = entity.get_local_player();
    radius = radius * dpi;
    if (not type) then type = 1; end
    if (type == 1) then height = 0; end

    if (localPlayer) then
        local prevScreenPosX, prevScreenPosY, prevScreenPosX2, prevScreenPosY2 = 0, 0, 0, 0;
        local step = math.pi * 2 / 72;
        local addedRotation = (math.pi * 2 * radius) / 360;

        local screenPosX, screenPosY = 0, 0;
        local screenPosX2, screenPosY2 = 0, 0;

        local screenX, screenY = renderer.world_to_screen(origin.x, origin.y, origin.z);
        local screenX2, screenY2 = renderer.world_to_screen(origin.x, origin.y, origin.z + height);

        for rotation = 0, math.pi * 2, step do
            local posX, posY, posZ = radius * math.cos(rotation + 1) + origin.x, radius * math.sin(rotation + 1) + origin.y, origin.z;
            screenPosX, screenPosY = renderer.world_to_screen(posX, posY, posZ);

            if (type == 1 or type == 2) then
                if (prevScreenPosX ~= 0 and prevScreenPosY ~= 0) then
                    renderer.triangle(screenPosX, screenPosY, screenX2, screenY2, prevScreenPosX, prevScreenPosY, color.r, color.g, color.b, color.a)
                    if (outline) then renderer.line(screenPosX, screenPosY, prevScreenPosX, prevScreenPosY, color.r, color.g, color.b, 255); end
                end
            elseif (type == 3) then
                screenPosX2, screenPosY2 = renderer.world_to_screen(posX, posY, posZ + height);

                if (prevScreenPosX ~= 0 and prevScreenPosY ~= 0) then
                    -- Sides
                    renderer.triangle(screenPosX, screenPosY, prevScreenPosX, prevScreenPosY, screenPosX2, screenPosY2, color.r, color.g, color.b, color.a)
                    renderer.triangle(prevScreenPosX2, prevScreenPosY2, prevScreenPosX, prevScreenPosY, screenPosX2, screenPosY2, color.r, color.g, color.b, color.a)

                    -- Top / Bottom
                    renderer.triangle(screenPosX, screenPosY, screenX, screenY, prevScreenPosX, prevScreenPosY, color.r, color.g, color.b, color.a)
                    renderer.triangle(screenPosX2, screenPosY2, screenX2, screenY2, prevScreenPosX2, prevScreenPosY2, color.r, color.g, color.b, color.a)

                    if (outline) then renderer.line(screenPosX, screenPosY, prevScreenPosX, prevScreenPosY, color.r, color.g, color.b, 255); end
                    if (outline) then renderer.line(screenPosX2, screenPosY2, prevScreenPosX2, prevScreenPosY2, color.r, color.g, color.b, 255); end
                end

                prevScreenPosX2, prevScreenPosY2 = screenPosX2, screenPosY2;
            end

            prevScreenPosX, prevScreenPosY = screenPosX, screenPosY;
        end
    end
end

local function drawBox(x, y, w, h, outline, color)
    local newCol = {};

    if (type(color) == "table") then newCol = color; else
        local r, g, b, a = ui.get(color);
        newCol = { r = r, g = g, b = b, a = a };
    end

    function rect(x, y, w, h, col) -- Why the fuck does renderer.line have some autistic alpha value that you can't change?
        renderer.rectangle(x, y, w, 1, col.r, col.g, col.b, col.a); -- Left to Right
        renderer.rectangle(x + w - 1, y, 1, h, col.r, col.g, col.b, col.a); -- Right side Top to Bottom
        renderer.rectangle(x, y, 1, h, col.r, col.g, col.b, col.a); -- Left side Top to Bottom
        renderer.rectangle(x, y + h - 1, w, 1, col.r, col.g, col.b, col.a); -- Bottom Left to Right
    end

    if (outline) then
        rect(x, y, w, h, {r = 0, g = 0, b = 0, a = 255});

        if (w >= 6 and h >= 6) then
            rect(x + 1, y + 1, w - 2, h - 2, newCol);
            rect(x + 2, y + 2, w - 4, h - 4, {r = 0, g = 0, b = 0, a = 255});
        else
            --[[
                Wierd ass bug here with directX rendering, bars are 1 pixel off when 2 pixels wide, 
                adding 1 pixel long side will make it 3 wide but adding 1 pixel on the 2 pixel side will make it the given length even tho it should be length + 1 :shrug:
                I will not do that tho because I have dignity and self respect ;)
            ]]
            if (w >= 6) then
                renderer.rectangle(x + 1, y + 1, w - 2, h - 2, newCol.r, newCol.g, newCol.b, newCol.a);
            else
                renderer.rectangle(x + 1, y + 1, w - 2, h - 2, newCol.r, newCol.g, newCol.b, newCol.a);
            end
        end
    else
        rect(x, y, w, h, newCol);
    end
end

--[[
    Input Library
--]]

local keySystem = {};
keySystem.__index = keySystem;

keys = {};

local function newKey(key)
    if (type(key) ~= "number") then key = 0x01; end

    return setmetatable({ key = key, down = false, pressed = { pressed = false, x = 0, y = 0 }, released = { released = false, x = 0, y = 0 } }, keySystem);
end

function keySystem.addKey(key)
    local contains = false;
    for i = 1, #keys do
        if (keys[i].key == key.key) then
            contains = true;
        end
    end

    if (not contains) then
        table.insert(keys, key);
    end
end

function keySystem.removeKey(key)
    if (#keys > 0) then
        for i = 1, #keys do
            if (keys[i].key == key) then
                table.remove(keys, i);
                return;
            end
        end
    end
end

function keySystem.getKey(key)
    if (#keys > 0) then
        for i = 1, #keys do
            if (keys[i].key == key) then
                return keys[i];
            end
        end
    end
end

function keySystem.run()
    if (#keys > 0) then
        for i = 1, #keys do
            if (client.key_state(keys[i].key)) then
                if (keys[i].down == false) then
                    keys[i].down = true;
                    keys[i].pressed = { pressed = true, x = mouseX, y = mouseY };
                else
                    keys[i].pressed.pressed = false;
                end
            else
                if (keys[i].down == true) then
                    keys[i].down, keys[i].pressed.pressed, keys[i].released = false, false, { released = true, x = mouseX, y = mouseY };
                else
                    keys[i].released.released = false;
                end
            end
        end
    end
end

--[[
    Window Library
--]]

local windows = {};
windows.__index = windows;
windows.styles = { default = 1, skeet = 2 };

local hudWindows = {};

local function window(x, y, w, h, text, color, styling, disableInput, visible)
    if (type(text) ~= "string") then text = ""; end
    if (type(styling) ~= "number") then styling = windows.styles.default; end
    if (type(x) ~= "number") then x = 0; end if (type(y) ~= "number") then y = 0; end
    if (type(w) ~= "number") then w = 0; end if (type(h) ~= "number") then h = 0; end
    if (type(disableInput) ~= "boolean") then disableInput = false; end
    if (type(visible) ~= "boolean") then visible = true; end
    
    if (#color > 0) then
        for i = 1, #color do
            if (type(color[i]) ~= "number") then
                color[i] = 255;
            else
                if (color[i] > 255) then color[i] = 255; end
                if (color[i] < 0) then color[i] = 0; end
            end
        end
    end

    return setmetatable({ x = x, y = y, w = w, h = h, text = text, color = color, styling = styling, mouse = { x = 0, y = 0, isSelected = false }, disableInput = disableInput, visible = visible }, windows);
end

function windows:pointInside(x, y)
    if (x >= self.x and x <= self.x + self.w) then
        if (y >= self.y and y <= self.y + self.h) then
            return true;
        end
    end

    return false;
end

function windows.add(identifier, windowObject)
    local contains = false;
    for i = 1, #hudWindows do
        if (hudWindows[i].id == identifier) then
            contains = true;
        end
    end

    if (not contains) then
        table.insert(hudWindows, { id = identifier, window = windowObject });
    end
end

function windows.remove(identifier)
    if (#hudWindows > 0) then
        for i = 1, #hudWindows do
            if (hudWindows[i].id == identifier) then
                table.remove(hudWindows, i);
                return;
            end
        end
    end
end

function windows.get(identifier)
    if (#hudWindows > 0) then
        for i = 1, #hudWindows do
            if (hudWindows[i].id == identifier) then
                return hudWindows[i].window;
            end
        end
    end
end

keySystem.addKey(newKey(0x01));

function windows.runMovement()
    local mouseKey = keySystem.getKey(0x01);

    if (mouseKey ~= nil) then
        if (mouseKey.pressed.pressed) then
            if (#hudWindows > 0) then
                for i = 1, #hudWindows do
                    if (hudWindows[i].window:pointInside(mouseKey.pressed.x, mouseKey.pressed.y) and not hudWindows[i].window.disableInput and hudWindows[i].window.visible) then
                        hudWindows[i].window.mouse.isSelected = true;
                        hudWindows[i].window.mouse.x, hudWindows[i].window.mouse.y = mouseKey.pressed.x - hudWindows[i].window.x, mouseKey.pressed.y - hudWindows[i].window.y;
                        return;
                    end
                end
            end
        end

        if (#hudWindows > 0) then
            for i = 1, #hudWindows do
                if (hudWindows[i].window ~= nil) then
                    if (mouseKey.down) then
                        if (hudWindows[i].window.mouse.isSelected == true and not hudWindows[i].window.disableInput and hudWindows[i].window.visible) then
                            hudWindows[i].window.x, hudWindows[i].window.y = mouseX - hudWindows[i].window.mouse.x, mouseY - hudWindows[i].window.mouse.y;
                        end
                    else
                        hudWindows[i].window.mouse.isSelected = false;
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
                    renderer.rectangle(hudWindows[i].window.x, hudWindows[i].window.y, hudWindows[i].window.w * dpi, 2 * dpi, hudWindows[i].window.color[1], hudWindows[i].window.color[2], hudWindows[i].window.color[3], 255);
                    renderer.rectangle(hudWindows[i].window.x, hudWindows[i].window.y + (2 * dpi), hudWindows[i].window.w * dpi, (hudWindows[i].window.h * dpi) - (2 * dpi), 35, 35, 35, 180);
                else
                    -- drawing from wish
                    local c = { 10, 60, 40, 40, 40, 60, 20 };
                    for i = 0, 6, 1 do
                        renderer.rectangle(hudWindows[i].window.x + i, hudWindows[i].window.y + i, hudWindows[i].window.w * dpi - (i * 2), hudWindows[i].window.h * dpi - (i * 2), c[i + 1], c[i + 1], c[i + 1], 255);
                    end
                end
            end
        end
    end
end

--[[
    Notification Library
--]]

local note = {};
note.__index = note;
note.easing = { linear = 1, easeIn = 2, easeOut = 3, easeInOut = 4 };
note.anchor = { topLeft = 1, topRight = 2, bottomLeft = 3, bottomRight = 4 };

local notifications = {};

local function notification(text, ms, color, easing, anchor)
    if (type(text) ~= "string") then text = ""; end
    if (type(ms) ~= "number") then ms = 1000; end
    if (type(easing) ~= "number") then easing = note.easing.linear; end
    if (type(anchor) ~= "number") then anchor = note.anchor.topLeft; end
    
    if (#color > 0) then
        for i = 1, #color do
            if (type(color[i]) ~= "number") then
                color[i] = 255;
            else
                if (color[i] > 255) then color[i] = 255; end
                if (color[i] < 0) then color[i] = 0; end
            end
        end
    end

    return setmetatable({ text = text, ms = { time = ms, startTime = globals.realtime() }, color = color, easing = easing, anchor = anchor }, note);
end

function note:run()
    table.insert(notifications, { text = self.text, ms = { time = self.ms.time, startTime = globals.realtime() }, color = self.color, easing = self.easing, anchor = self.anchor });
end

function note.remove(index)
    if (type(index) == "number") then
        table.remove(notifications, index);
    end
end

local function easingWidth(easing, width, percent) -- https://easings.net/
    if (easing == 2) then
        percent = percent^4;
    elseif (easing == 3) then
        percent = 1 - (1 - percent)^4;
    elseif (easing == 4) then
        if (percent < 0.5) then 
            percent = 8 * percent^4; 
        else 
            percent = 1 - (-2 * percent + 2)^4 / 2; 
        end 
    end

    return width - (width * percent);
end

local function notificationPaint()
    if (#notifications > 0) then
        local usedY = { tl = 0, tr = 0, bl = 0, br = 0 };
        local scrW, scrH = client.screen_size();

        for i = #notifications, 1, -1 do
            if (globals.realtime() - notifications[i].ms.startTime >= (notifications[i].ms.time / 1000)) then
                note.remove(i);
            else               
                local textW, textH = renderer.measure_text("d", notifications[i].text);
                local padding = 8;
                local render = { x = 0, y = 0, w = (textW + padding * 2) * dpi, h = 22 * dpi };
                local percent = 0;
                
                if (globals.realtime() - notifications[i].ms.startTime > (notifications[i].ms.time / 2) / 1000) then
                    percent = ((globals.realtime() - notifications[i].ms.startTime) - ((notifications[i].ms.time / 2) / 1000)) / ((notifications[i].ms.time / 2) / 1000);
                end

                local sub = easingWidth(notifications[i].easing, render.w + 10, percent);

                if (notifications[i].anchor == 1) then
                    render.x, render.y = sub - ((textW + padding * 2) * dpi), 10 + usedY.tl; usedY.tl = usedY.tl + 30;
                elseif (notifications[i].anchor == 2) then      
                    render.x, render.y = scrW - sub, 10 + usedY.tr; usedY.tr = usedY.tr + 30;
                elseif (notifications[i].anchor == 3) then
                    render.x, render.y = sub - ((textW + padding * 2) * dpi), scrH - render.h - 10 - usedY.bl; usedY.bl = usedY.bl + 30;
                else
                    render.x, render.y = scrW - sub, scrH - render.h - 10 - usedY.br; usedY.br = usedY.br + 30;
                end

                renderer.rectangle(render.x, render.y, render.w, render.h, 20, 20, 20, 255);
                renderer.rectangle(render.x, render.y, render.w, 2 * dpi, 65, 65, 65, 255);
                renderer.rectangle(render.x, render.y, easingWidth(1, render.w, (globals.realtime() - notifications[i].ms.startTime) / (notifications[i].ms.time/ 1000)), 2 * dpi, notifications[i].color[1], notifications[i].color[2], notifications[i].color[3], 255);
                renderer.text(render.x + ((8 + (textW / 2)) * dpi), render.y + (render.h / 2), 255, 255, 255, 255, "cd", 0, notifications[i].text);
            end
        end
    end
end

--[[
    UI Initialization bs
--]]

local disabledReferences = {
    { name = "Damage Logging", reference = ui.reference("Misc", "Miscellaneous", "Log damage dealt"), disabled = true, canGet = true },
    { name = "Blockbot", reference = ui.reference("Misc", "Movement", "Blockbot"), disabled = false, canGet = true },
    { name = "Username Stealer", reference = ui.reference("Misc", "Miscellaneous", "Steal player name"), disabled = false, canGet = false },
};

if (disabledReferences ~= nil and #disabledReferences > 0) then -- Sets all the references above to be invisible due to being remade
    client.exec("clear");
    for i = 1, #disabledReferences do
        if (disabledReferences[i].canGet and type(ui.get(disabledReferences[i].reference)) == "boolean") then
            ui.set(disabledReferences[i].reference, false);
        end
        
        ui.set_visible(disabledReferences[i].reference, false);

        if (disabledReferences[i].disabled) then
            print("Option: " .. disabledReferences[i].name .. " has been disabled.");
        else
            print("Option: " .. disabledReferences[i].name .. " has been replaced.");
        end
    end

    notification("UI has been initialized.", 2500, {menuR, menuG, menuB, menuA}, 4, 1):run();
end

--[[
    Christmas Mode
--]]

function client.UnixTime()
    local a, b, c, d = client.system_time();
    local unix = client.unix_time();

    return unix * 1000 + d;
end

local onionChristmasMode = ui.new_checkbox("Misc", "Settings", "Christmas mode");
local onionChristmasTime = client.UnixTime(); local onionChristmasSwitch = false;
local onionChristmasGlobalColor = {255, 255, 255, 255};

local christmasColors = {
    {49, 235, 55, 255},
    {245, 64, 82, 255},
}

local function runRainbow()
    if (ui.get(onionChristmasMode)) then
        local christmasPercent = (client.UnixTime() - onionChristmasTime) / 2500;
        local newPercent = easingWidth(3, 1, christmasPercent);

        if (onionChristmasSwitch) then
            onionChristmasGlobalColor = {numberToNumber(49, 245, newPercent), numberToNumber(235, 64, newPercent), numberToNumber(55, 82, newPercent), 255};
        else
            onionChristmasGlobalColor = {numberToNumber(245, 49, newPercent), numberToNumber(64, 235, newPercent), numberToNumber(82, 55, newPercent), 255};
        end

        if (christmasPercent > 1) then
            onionChristmasSwitch = not onionChristmasSwitch;
            onionChristmasTime = client.UnixTime();
        end
    end
end

--[[
    Blockbot Function
--]]

local onionBlockbot = ui.new_hotkey("Misc", "Movement", "Blockbot", false);
local blockbot = { currentEntity, isOn = false }

local function map(n, start, stop, new_start, new_stop)
    local value = (n - start) / (stop - start) * (new_stop - new_start) + new_start
    return new_start < new_stop and math.max(math.min(value, new_stop), new_start) or math.max(math.min(value, new_start), new_stop)
end

local function blockbotPaint() -- Obtain the walkbot target from the closest player, and draw the indicator circle for the current player
    local localOrigin = vector(entity.get_origin(localPlayer));

    if (hasFlag(localPlayer, flags.onground)) then
        local closestEnt, closestDist = nil, 100;

        local players = entity.get_players(false);
        if (players ~= nil and #players > 0) then
            for i = 1, #players do
                if (players[i] ~= localPlayer) then
                    local entOrigin = vector(entity.get_origin(players[i]));
                    local distance = entOrigin:dist2d(localOrigin);

                    if (distance < closestDist) then
                        closestEnt, closestDist = players[i], distance;
                    end
                end
            end

            if (closestEnt ~= nil) then
                if (blockbot.currentEntity ~= closestEnt) then
                    notification("New Blockbot target: " .. entity.get_player_name(closestEnt), 2500, {menuR, menuG, menuB, menuA}, 4, 1):run();
                end

                blockbot.isOn = true;
                blockbot.currentEntity = closestEnt;
            end
        end
    end

    if (blockbot.isOn) then
        local playerOrigin = vector(entity.get_origin(blockbot.currentEntity));

        if (vector(localOrigin.x, localOrigin.y, playerOrigin.z):dist2d(playerOrigin) <= 20) then
            draw3D(playerOrigin, 20, { r = 66, g = 245, b = 96, a = 150 }, true, object3D.circle);
        else
            draw3D(playerOrigin, 20, { r = 255, g = 255, b = 255, a = 150 }, true, object3D.circle);
        end

        draw3D(vector(localOrigin.x, localOrigin.y, playerOrigin.z), 4, { r = 35, g = 35, b = 35, a = 150 }, true, object3D.circle);
    end
end

local function blockbotMove(cmd) -- move with the selected player on the setup move callback, movement code modified from halflifefan's post viewtopic.php?id=10839
    if (blockbot.isOn) then
        local localOrigin = vector(entity.get_origin(localPlayer));
        local entityVelocity = vector(entity.get_prop(blockbot.currentEntity, "m_vecVelocity"));
        local entitySpeed = vector(entity.get_prop(blockbot.currentEntity, "m_vecVelocity")):length2d();
        local serverOrigin = vector(entity.get_origin(blockbot.currentEntity)) + entityVelocity * math.floor(client.latency() / globals.tickinterval() + 0.5) * globals.tickinterval();
        local dirYaw = select(2, localOrigin:to(serverOrigin):angles());
        local distance = localOrigin:dist2d(serverOrigin);

        cmd.move_yaw = dirYaw;
        if (map(vector(entity.get_prop(localPlayer, "m_vecVelocity")):length2d(), 0, 250, 0, 12) < distance) then
            cmd.forwardmove = 450;
        end
    end
end


--[[
    Thirdperson Function
--]]

local onionThirdpersonCollision = ui.new_checkbox("Visuals", "Effects", "Thirdperson collisions");
local onionThirdpersonDistance = ui.new_slider("Visuals", "Effects", "Thirdperson distance", 50, 200, 125);

local function thirdpersonValues()
    if (ui.get(onionThirdpersonCollision)) then
        cvar.cam_collision:set_int(1)
    else
        cvar.cam_collision:set_int(0)
    end

    cvar.c_mindistance:set_int(ui.get(onionThirdpersonDistance));
    cvar.c_maxdistance:set_int(ui.get(onionThirdpersonDistance));
end

ui.set_callback(onionThirdpersonCollision, thirdpersonValues);
ui.set_callback(onionThirdpersonDistance, thirdpersonValues);
thirdpersonValues();

--[[
    Extrapolated Position Function
    yeah ik it's pretty wrong and just uses your current speed as a constant
--]]

local onionExtrapolation = ui.new_checkbox("Visuals", "Other ESP", "Teleport prediction");
local doubleTapRef, doubleTapRef2 = ui.reference("Rage", "Other", "Double tap");
local doubleTapSlideRef = ui.reference("Rage", "Other", "Double tap fake lag limit");

local function extrapolatedPosition() -- just get current max charge and do some magical math to get an inaccurate answer (also server tickrate is hardcoded smd)
    if (ui.get(doubleTapRef) and ui.get(doubleTapRef2)) then
        local percent = (16 - ui.get(doubleTapSlideRef)) / 64;
        local velX, velY, velZ = entity.get_prop(localPlayer, "m_vecVelocity");
        local originX, originY, originZ = entity.get_origin(localPlayer);
        local endX, endY = originX + velX * percent, originY + velY * percent;

        local drawColor = { r = 255, g = 255, b = 255, a = 150 };
        if (ui.get(onionChristmasMode)) then
            drawColor= { r = onionChristmasGlobalColor[1], g = onionChristmasGlobalColor[2], b = onionChristmasGlobalColor[3], a = 150 }
        end

        draw3D({ x = endX, y = endY, z = originZ }, 8, drawColor, true, object3D.circle);
    end
end

--[[
    RS Function
--]]

local onionRSCleaner = ui.new_checkbox("Misc", "Miscellaneous", "Clean reset score");
local rsNotify = notification("Your reset score command has been cleaned and silenced.", 3000, {menuR, menuG, menuB, menuA}, 4, 1);

local function cleanRS(str) -- allows you to mess up spelling /rs and auto converts !rs to /rs since /rs is silent on most servers
    if (string.len(str.text) <= 9) then
        if (string.find(str.text, "!") and string.find(string.lower(str.text), "r") and string.find(string.lower(str.text), "s")) then
            str.text = "say /rs"; rsNotify:run();
        elseif (string.find(str.text, "/") and string.find(string.lower(str.text), "r") and string.find(string.lower(str.text), "s")) then
            str.text = "say /rs"; rsNotify:run();
        end
    end
end

--[[
    Anti-AFK Function
--]]

local onionRSCleaner = ui.new_checkbox("Misc", "Miscellaneous", "Anti-AFK");

local function antiAFKMove(cmd)
    if (ui.get(onionRSCleaner)) then
        cmd.in_left, cmd.in_right = true, true;
    end
end

--[[
    Material Modification Function
--]]

local onionAntiAdverts = ui.new_checkbox("Visuals", "Effects", "Remove adverts");

local materialAdStrings = {
    "decals/custom/uwujka/uwujkapl_logo_01", "decals/custom/14club/logo_decal",
    "decals/liberty/libertymaster", "/brokencore", "decals/intensity/intensity"
};

local materialAds = {};

local function removeAdvertisement() -- remove all materials related to the table above, material strings stolen from pilot's post viewtopic.php?id=31518
    materialAds = {};

    for i = 1, #materialAdStrings do
        local material = materialsystem.find_materials(materialAdStrings[i]);
        if (material ~= nil) then table.insert(materialAds, material); end
    end

    if (#materialAds > 0) then
        for i = 1, #materialAds do
            for f = 1, #materialAds[i] do
                materialAds[i][f]:set_material_var_flag(2, ui.get(onionAntiAdverts));
            end
        end
    end
end

ui.set_callback(onionAntiAdverts, removeAdvertisement);
removeAdvertisement();

--[[
    Player List Functions
--]]

local playerListRef = ui.reference("Players", "Players", "Player List");
local stealNameRef = ui.reference("Misc", "Miscellaneous", "Steal player name");

local playerListControls = {
    { table = {}, reference = ui.new_checkbox("Players", "Adjustments", "Blockbot priority") },
    { table = {}, reference = ui.new_checkbox("Players", "Adjustments", "Killsay target") },
};

local onionStealName = ui.new_button("Players", "Adjustments", "Steal username", function()
    local player = ui.get(playerListRef);
    local name = entity.get_player_name(player);
    ui.set(stealNameRef, true);
    client.set_cvar("name", name .. " ");
end);

local onionStealTag = ui.new_button("Players", "Adjustments", "Steal clantag", function()
    local player = ui.get(playerListRef);
    local clantag = entity.get_prop(entity.get_player_resource(), "m_szClan", player);

    if (clantag ~= nil and clantag ~= "nil") then
        client.set_clan_tag(clantag);
    end
end);

local function contains(table, key)
    for index, value in pairs(table) do
        if value == key then return true, index end
    end
    return false, nil
end

for i = 1, #playerListControls do -- modification of duke's post using tables so we don't need repetitive code viewtopic.php?id=19293
    ui.set_callback(playerListControls[i].reference, function()
        if (ui.get(playerListControls[i].reference)) then
            table.insert(playerListControls[i].table, ui.get(playerListRef))
        else
            local value, index = contains(playerListControls[i].table, ui.get(playerListRef))
            if (value) then
                table.remove(playerListControls[i].table, index);
            end
        end
    end);
end

ui.set_callback(playerListRef, function()
    for i = 1, #playerListControls do
        ui.set(playerListControls[i].reference, contains(playerListControls[i].table, ui.get(playerListRef)));
    end
end);

--[[
    Auto Team Selection Function
--]]

local onionTeamSelection = ui.new_combobox("Misc", "Miscellaneous", "Team selection", { "Off", "CT", "T" });

local function selectTeamEvent(event)
    if (client.userid_to_entindex(event.userid) == localPlayer) then
        local value = ui.get(onionTeamSelection);

        if (value ~= "Off") then
            if (value == "CT") then 
                client.exec("jointeam 3 1") 
            else
                client.exec("jointeam 2 1")
            end
        end
    end
end

--[[
    Killsay Function
--]]

local onionKillsaySetting = ui.new_combobox("Misc", "Miscellaneous", "Killsay", { "Off", "On", "Targetted" });

local killMessages = {
    "1", "You suck.",
    "nice stevie wonder aim", "Missclick",
    "lick my sphincter", "*DEAD*",
};

local function playerKilledEvent(event) -- Run killsay for every player when attacking or for specified players in the plist
    local attacker = client.userid_to_entindex(event.attacker);
    local attacked = client.userid_to_entindex(event.userid);

    if (attacker == localPlayer) then
        local value = ui.get(onionKillsaySetting);

        if (value ~= "Off") then
            if (value == "On") then
                client.exec("say " .. killMessages[client.random_int(1, #killMessages)]);
            else
                ui.set(playerListRef, attacked);
                if (contains(playerListControls[2].table, ui.get(playerListRef))) then 
                    client.exec("say " .. killMessages[client.random_int(1, #killMessages)]);
                end
            end
        end
    end
end

--[[
    ESP Distance Function
--]]

local onionESPDistance = ui.new_slider("Visuals", "Player ESP", "Distance", 0, 5000, 0);

local function espDistancePaint() -- set plist settings when a player's origin is too far from the local player
    if (entity.is_alive(localPlayer)) then
        local value = ui.get(onionESPDistance);

        if (value ~= 0) then
            local players = entity.get_players(true);
            local localEyes = vector(client.eye_position());

            if (players ~= nil and #players > 0) then
                for i = 1, #players do
                    local playerOrigin = vector(entity.get_origin(players[i]));

                    if (localEyes:dist2d(playerOrigin) <= value) then
                        plist.set(players[i], "Disable visuals", false);
                    else
                        local playerHead = vector(entity.hitbox_position(players[i], 0));
                        local fraction, entIndex = client.trace_line(localPlayer, localEyes.x, localEyes.y, localEyes.z, playerHead.x, playerHead.y, playerHead.z);
                        local fraction2, entIndex2 = client.trace_line(localPlayer, localEyes.x, localEyes.y, localEyes.z, playerOrigin.x, playerOrigin.y, playerOrigin.z);

                        if (entIndex == players[i] or entIndex2 == players[i]) then
                            plist.set(players[i], "Disable visuals", false);
                        else
                            plist.set(players[i], "Disable visuals", true);
                        end
                    end
                end
            end
        else
            local players = entity.get_players(true);
            if (players ~= nil and #players > 0) then
                for i = 1, #players do
                    plist.set(players[i], "Disable visuals", false);
                end
            end
        end
    end
end

--[[
    Hitmarker Text Function
--]]

local onionHitmarker = ui.new_checkbox("Visuals", "Other ESP", "Word hitmarker");

local hitTable = {};
local hitboxTable = {
    {0, 4}, {1, 0}, {2, 6}, {3, 5},
    {4, 19}, {5, 17}, {6, 11}, 
    {7, 10}, {nil, 5}
};

local hitWords = {"OWNED", "OOF", "SMASH", "BOOM"};
local wordColors = {
    {35, 70, 226}, {49, 124, 225}, {217, 226, 0}, 
    {65, 222, 91}, {221, 124, 30}
};

local function hitmarkerEvent(event) -- add hitmarker information to a table to grab from our paint callback
    if (ui.get(onionHitmarker)) then
        local entAttacker = client.userid_to_entindex(event.attacker);
        local entAttacked = client.userid_to_entindex(event.userid);

        if (entAttacker == localPlayer) then
            local endVec;
            local set = false;
            
            for i = 1, #hitboxTable do
                if (i == #hitboxTable and not set) then
                    endVec = vector(entity.hitbox_position(entAttacked, hitboxTable[i][2]));
                elseif (hitboxTable[i][1] == event.hitgroup) then
                    endVec = vector(entity.hitbox_position(entAttacked, hitboxTable[i][2]));
                    set = true;
                end
            end
            
            if (ui.get(onionChristmasMode)) then
                table.insert(hitTable, { endVec, globals.curtime(), hitWords[client.random_int(1, #hitWords)], christmasColors[client.random_int(1, #christmasColors)]});
            else
                table.insert(hitTable, { endVec, globals.curtime(), hitWords[client.random_int(1, #hitWords)], wordColors[client.random_int(1, #wordColors)] });
            end
        end
    end
end

local function hitmarkerPaint() -- draw the hitmarker from information in the hitTable table obtained from the hitmarker event
    if (ui.get(onionHitmarker)) then
        if (#hitTable > 0) then
            for i = 1, #hitTable do
                if (type(hitTable[i]) == "table" and hitTable[i][1] ~= nil and type(hitTable[i][1].x) == "number" and type(hitTable[i][1].y) == "number" and type(hitTable[i][1].z) == "number") then
                    local hitX, hitY = renderer.world_to_screen(hitTable[i][1].x, hitTable[i][1].y, hitTable[i][1].z - (10 * ((globals.curtime() - hitTable[i][2]) / 1)));

                    if (hitX ~= nil and hitY ~= nil) then
                        renderer.text(hitX, hitY, hitTable[i][4][1], hitTable[i][4][2], hitTable[i][4][3], 255, 0, "cd", hitTable[i][3]);
                    end

                    if (globals.curtime() - hitTable[i][2] >= 1) then
                        table.remove(hitTable, i);
                    end
                end
            end
        end
    end
end

--[[
    Console Cleaner Function
--]]

local onionCleanConsole = ui.new_checkbox("Misc", "Settings", "Clean console");

local function setConsoleFilter() -- Set console filter convars
    if (ui.get(onionCleanConsole)) then
        cvar.con_filter_enable:set_int(1);
    else
        cvar.con_filter_enable:set_int(0);
    end

    cvar.con_filter_text:set_string("oniongang69420 jia8uP7h1@");
end

ui.set_callback(onionCleanConsole, setConsoleFilter);
setConsoleFilter();

--[[
    Crosshair Functions
--]]

local crosshairControls = {};
local crosshairShown = true;
local function runCrosshairButton()
    crosshairShown = not crosshairShown;

    for i = 1, #crosshairControls do
        ui.set_visible(crosshairControls[i], crosshairShown);
    end
end

local onionToggleCrosshairRef = ui.new_button("Visuals", "Other ESP", "Toggle crosshair settings", function() runCrosshairButton(); end);

crosshairControls = {
    ui.new_checkbox("Visuals", "Other ESP", "Crosshair enabled"),
    ui.new_slider("Visuals", "Other ESP", "Crosshair distance", 0, 100, 15),
    ui.new_slider("Visuals", "Other ESP", "Crosshair size", 0, 100, 20),
    ui.new_color_picker("Visuals", "Other ESP", "Crosshair color", 255, 255, 255, 255),
};

ui.set_callback(crosshairControls[1], function()
    if (ui.get(crosshairControls[1])) then
        cvar.crosshair:set_int(0);
    else
        cvar.crosshair:set_int(1);
    end
end);

runCrosshairButton();

local function crosshairPaint()
    local r, g, b, a = ui.get(crosshairControls[4]);

    -- Vertical
    renderer.line(scrW / 2, scrH / 2 - (ui.get(crosshairControls[2]) + ui.get(crosshairControls[3])) * dpi, scrW / 2, scrH / 2 - ui.get(crosshairControls[2]) * dpi, r, g, b, a);
    renderer.line(scrW / 2, scrH / 2 + (ui.get(crosshairControls[2]) + ui.get(crosshairControls[3])) * dpi, scrW / 2, scrH / 2 + ui.get(crosshairControls[2]) * dpi, r, g, b, a);

    -- Horizontal
    renderer.line(scrW / 2 - (ui.get(crosshairControls[2]) + ui.get(crosshairControls[3])) * dpi, scrH / 2, scrW / 2 - ui.get(crosshairControls[2]) * dpi, scrH / 2, r, g, b, a);
    renderer.line(scrW / 2 + (ui.get(crosshairControls[2]) + ui.get(crosshairControls[3])) * dpi, scrH / 2, scrW / 2 + ui.get(crosshairControls[2]) * dpi, scrH / 2, r, g, b, a);

    renderer.circle_outline(scrW / 2, scrH / 2, r, g, b, a, ui.get(crosshairControls[2]) * dpi, 0, 1, 1)
end

--[[
    Damage Logs Function
--]]

local onionDamageLog = ui.new_checkbox("Misc", "Miscellaneous", "Damage logs");

local function damageLogEvent(event)
    if (ui.get(onionDamageLog)) then
        local playerHurt = client.userid_to_entindex(event.userid);
        local playerAttacker = client.userid_to_entindex(event.attacker);

        if (playerAttacker == localPlayer or localPlayer == playerHurt) then
            local printStr = "Player %s just hurt %s for %s damage and %s armor in hitgroup: %s, they have %s health remaining and %s armor remaining.";
            printStr = string.format(printStr, entity.get_player_name(playerAttacker), entity.get_player_name(playerHurt), tostring(event.dmg_health), tostring(event.dmg_armor), tostring(event.hitgroup), tostring(event.health), tostring(event.armor));
            print(printStr);
        end
    end
end

--[[
    Buybot Function
--]]

local onionBuybotEnabled = ui.new_checkbox("Misc", "Miscellaneous", "Buybot");
local onionBuybot = ui.new_textbox("Misc", "Miscellaneous", "Buybot");

local function buybotCallback() ui.set_visible(onionBuybot, ui.get(onionBuybotEnabled)); end
ui.set_callback(onionBuybotEnabled, buybotCallback); buybotCallback();

local function onNewRoundEvent(event) -- buy on new round event, same as buy console command (buy awp; buy ak47; etc)
    if (ui.get(onionBuybotEnabled)) then
        local buybotText = ui.get(onionBuybot);
        local buybotLines = {};

        for str in buybotText:gmatch("[^ ]+") do
            table.insert(buybotLines, str);
        end

        local endText = "";

        for i = 1, #buybotLines do
            endText = endText .. "buy " .. buybotLines[i] .. "; "; 
        end

        client.exec(endText);
    end
end

--[[
    Minimum Damage Override Function
--]]

local onionMinimumOverride = ui.new_checkbox("Rage", "Other", "Minimum damage override");
local onionMinimumOverrideKey = ui.new_hotkey("Rage", "Other", "Override key", true);
local onionMinimumOverrideDamage = ui.new_slider("Rage", "Other", "Override damage", 0, 126, 0);
local onionMinimumOverrideRestore = ui.new_slider("Rage", "Other", "Restore damage", 0, 126, 0);

local onionDamageRef = ui.reference("Rage", "Aimbot", "Minimum damage");

local function overridePaint()
    if (ui.get(onionMinimumOverride) and ui.get(onionMinimumOverrideKey)) then
        renderer.indicator(255, 255, 255, 255, "Override: " .. ui.get(onionMinimumOverrideDamage));
    end
end

local function overrideMove()
    if (ui.get(onionMinimumOverride) and ui.get(onionMinimumOverrideKey)) then
        ui.set(onionDamageRef, ui.get(onionMinimumOverrideDamage));
    else
        ui.set(onionDamageRef, ui.get(onionMinimumOverrideRestore));
    end
end

local function overrideCallback()
    ui.set_visible(onionMinimumOverrideDamage, ui.get(onionMinimumOverride));
    ui.set_visible(onionMinimumOverrideRestore, ui.get(onionMinimumOverride));
end

ui.set_callback(onionMinimumOverride, overrideCallback); overrideCallback();

--[[
    ESP Preview Function
    kinda useless since you can look at a player, but I was bored so why not
--]]

local onionESPPreview = ui.new_checkbox("Visuals", "Player ESP", "Preview");
local espPreviewImage;
http.get("https://i.imgur.com/TdY2kCd.png", function(status, response)
    if (status and response.status == 200) then
        espPreviewImage = images.load_png(response.body);
    end
end);

windows.add("espPreview", window(20, 20, 250, 400, "", {menuR, menuG, menuB, menuA}, windows.styles.default, true));

-- had nice table for references but cant return two ui references inside a table so it was either this or static colors
local espBounding, espBoundingColor = ui.reference("Visuals", "Player ESP", "Bounding box")
local espHealth = ui.reference("Visuals", "Player ESP", "Health bar")
local espName, espNameColor = ui.reference("Visuals", "Player ESP", "Name")
local espWeapon = ui.reference("Visuals", "Player ESP", "Weapon text")
local espAmmo, espAmmoColor = ui.reference("Visuals", "Player ESP", "Ammo")
local espDistance = ui.reference("Visuals", "Player ESP", "Distance")
local espMoney = ui.reference("Visuals", "Player ESP", "Money")

local function previewPaint() -- Draw the esp preview and check each control's state and color
    local win = windows.get("espPreview");

    if (ui.is_menu_open() and ui.get(onionESPPreview) and espPreviewImage ~= nil) then
        win.visible = true;
        win.x, win.y = menuX - ((win.w + 8) * dpi), menuY + ((menuH / 2) - ((win.h * dpi) / 2));
        local imageW, imageH, percent = espPreviewImage:measure();
        if (imageW > imageH) then percent = 300 / imageW; else percent = 300 / imageH; end
        imageW, imageH = (imageW * percent) * dpi, (imageH * percent) * dpi;
        local imageX, imageY = win.x + ((win.w * dpi) / 2) - (imageW / 2), win.y + ((win.h * dpi) / 2) - (imageH / 2);

        espPreviewImage:draw(imageX, imageY, nil, 300 * dpi)
        local usedY = 0;

        if (ui.get(espBounding)) then drawBox(imageX - 8, imageY - 8, imageW + 16, imageH + 16, true, espBoundingColor); end
        if (ui.get(espHealth)) then drawBox(imageX - 13, imageY - 8, 4, imageH + 16, true, { r = 120, g = 225, b = 80, a = 255 }); end
        if (ui.get(espAmmo)) then drawBox(imageX - 8, imageY + imageH + 9, imageW + 16, 4, true, espAmmoColor); usedY = usedY + 4; end
        if (ui.get(espMoney)) then renderer.text(imageX + imageW + 10, imageY - 5, 104, 163, 22, 255, "d-", 0, "$16000"); end
        if (ui.get(espDistance)) then local textW, textH = renderer.measure_text("15 FT", "cd-"); renderer.text(imageX + (imageW / 2) - 4, imageY + imageH + 9 + usedY + (textH / 2), 255, 255, 255, 255, "cd-", 0, "15 FT"); usedY = usedY + 6 + (textH / 2); end
        if (ui.get(espWeapon)) then local textW, textH = renderer.measure_text("KNIFE", "cd-"); renderer.text(imageX + (imageW / 2) - 4, imageY + imageH + 9 + usedY + (textH / 2), 255, 255, 255, 255, "cd-", 0, "KNIFE"); usedY = usedY + 3 + (textH / 2); end
        if (ui.get(espName)) then local textW, textH = renderer.measure_text("player", "cd"); local r, g, b, a = ui.get(espNameColor); renderer.text(imageX + (imageW / 2), imageY - 10 - (textH / 2), r, g, b, a, "cd", 0, "player"); end
    else
        win.visible = false;
    end
end

--[[
    Vote Revealer Functions
--]]

local onionVoteLog = ui.new_checkbox("Misc", "Miscellaneous", "Vote Revealer");

local function voteRevealEvent(event) -- Run a notification and print when a player votes
    if (ui.get(onionVoteLog)) then
        local voteEntity = event.entityid;
        local vote = event.vote_option;
        local voteBool;
        local voteEntityName = entity.get_player_name(voteEntity);

        if (vote == 0) then voteBool = "Yes"; elseif (vote == 1) then 
        voteBool = "No"; else voteBool = "Unknown"; end

        local voteText = "Player " .. voteEntityName .. " voted " .. voteBool .. ".";

        notification(voteText, 3000, {menuR, menuG, menuB, menuA}, 4, 1):run();
        print(voteText);
    end
end

--[[
    Fake Flick Functions
--]]

local onionFlickCurtime = globals.curtime();
local onionFakeFlick = ui.new_hotkey("AA", "Other", "Fake Flick")
local onionYawRef1, onionYawRef2 = ui.reference("AA","Anti-aimbot angles","Yaw")
local onionBodyYawRef1, onionBodyYawRef2 = ui.reference("AA","Anti-aimbot angles","Body yaw")
local onionFakelagLimitRef, onionFlicked = ui.reference("AA","Fake lag","Limit"), false

local function fakeFlickEvent(event)
    onionFlicked = not onionFlicked;
    
    if (ui.get(onionFakeFlick)) then
        ui.set(onionFakelagLimitRef, 1)
    else
        ui.set(onionFakelagLimitRef, 14)
    end

    ui.set(onionBodyYawRef2, 180)
    ui.set(onionBodyYawRef1, "Static")
    if globals.curtime() > onionFlickCurtime + 0.1 and ui.get(onionFakeFlick) then
        ui.set(onionYawRef2, 100)
        onionFlickCurtime = globals.curtime()
    else
        ui.set(onionYawRef2, 0)
    end
end

--[[
    ESP Grid Functions
--]]

local onionGridESP = ui.new_checkbox("Visuals", "Player ESP", "Grid ESP");
local onionGridESPColor = ui.new_color_picker("Visuals", "Player ESP", "Grid Color", 180, 180, 180, 120);
local onionGridESPSize = ui.new_slider("Visuals", "Player ESP", "Grid ESP Size", 10, 1000, 200);

local gridFrame = {};

local function gridContained(x, y, x2, y2) -- Overlapping box check
    if (#gridFrame > 0) then
        for i = 1, #gridFrame do
            if (gridFrame[i][1] == x and gridFrame[i][2] == y) then
                if (gridFrame[i][3] == x2 and gridFrame[i][4] == y2) then
                    return true;
                end
            end
        end
    end

    return false;
end

local function drawGridSquarePos(ent, gridSize, addY, addX) -- Calculate box position & draw, also check for overlapping boxes
    local entOrigin = vector(entity.get_origin(ent));
    local localOrigin = vector(entity.get_origin(localPlayer));
    local distToEnt = localOrigin:dist2d(entOrigin);
    if (addY == nil) then addY = 0; end if (addX == nil) then addX = 0; end

    if (gridSize > 0) then
        local gridSquaresOutX = gridSize * math.floor(math.abs(entOrigin.x) / gridSize) + (gridSize * addX);
        local gridSquaresOutY = gridSize * math.floor(math.abs(entOrigin.y) / gridSize) + (gridSize * addY);
        local gridSquaresOutX2 = gridSquaresOutX + gridSize;
        local gridSquaresOutY2 = gridSquaresOutY + gridSize;

        if (entOrigin.x < 0) then gridSquaresOutX = -gridSquaresOutX; gridSquaresOutX2 = -gridSquaresOutX2; end
        if (entOrigin.y < 0) then gridSquaresOutY = -gridSquaresOutY; gridSquaresOutY2 = -gridSquaresOutY2; end

        if (not gridContained(gridSquaresOutX, gridSquaresOutY, gridSquaresOutX2, gridSquaresOutY2)) then

            -- Check each w2s call nil values cause it likes to return nil for points far outside of monitor bounds, and we wanna avoid using extra w2s calls.
            local x, y = renderer.world_to_screen(gridSquaresOutX, gridSquaresOutY, entOrigin.z); if (not x or not y) then return; end
            local x2, y2 = renderer.world_to_screen(gridSquaresOutX2, gridSquaresOutY, entOrigin.z); if (not x2 or not y2) then return; end
            local x3, y3 = renderer.world_to_screen(gridSquaresOutX, gridSquaresOutY2, entOrigin.z); if (not x3 or not y3) then return; end
            local x4, y4 = renderer.world_to_screen(gridSquaresOutX2, gridSquaresOutY2, entOrigin.z); if (not x4 or not y4) then return; end
            
            local r, g, b, a = ui.get(onionGridESPColor);

            if (ui.get(onionChristmasMode)) then
                r, g, b, a = table.unpack(onionChristmasGlobalColor); a = 120;
            end

            renderer.line(x3, y3, x4, y4, r, g, b, 255)
            renderer.line(x, y, x2, y2, r, g, b, 255)
            renderer.line(x4, y4, x2, y2, r, g, b, 255)
            renderer.line(x, y, x3, y3, r, g, b, 255)
            renderer.triangle(x, y, x2, y2, x3, y3, r, g, b, a)
            renderer.triangle(x4, y4, x2, y2, x3, y3, r, g, b, a)

            table.insert(gridFrame, { gridSquaresOutX, gridSquaresOutY, gridSquaresOutX2, gridSquaresOutY2 });
        end
    end
end

local function runGridESP() -- Enumerate thru all players to draw their grid box
    if (ui.get(onionGridESP)) then
        gridFrame = {};
        local enemies = entity.get_players(true);

        for i = 1, #enemies do
            if (entity.is_alive(enemies[i]) and not plist.get(enemies[i], "Disable visuals")) then
                drawGridSquarePos(enemies[i], ui.get(onionGridESPSize));
            end
        end
    end
end

--[[
    Personal Weather
--]]

local radiusSlider, heightSlider, dropletSlider, dropletHeightSlider, dropletTimeSlider = 50, 125, 150, 1, 10000;
local weatherUnixTime = client.UnixTime();

local weatherCache = {};
local function regenerateWeatherTable()
    weatherCache = {};
    local radiusHalf = radiusSlider
    local dropletTime = dropletTimeSlider

    for i = 1, dropletSlider do
        local r = radiusHalf * math.sqrt((math.random(0, 1000) / 1000));
        local theta = (math.random(0, 1000) / 1000) * 2 * math.pi;
        table.insert(weatherCache, {pos = vector(r * math.cos(theta), r * math.sin(theta)), color = math.random(1, 2), 
                                    percent = 0, dropletTime = math.random(dropletTime), startTime = weatherUnixTime});
    end
end

local onionPlayerParticles = ui.new_checkbox("Visuals", "Player ESP", "Player Particles");
local onionPlayerParticlesColor = ui.new_color_picker("Visuals", "Player ESP", "Particles Color", 255, 255, 255, 255);
regenerateWeatherTable();

local function runPlayerParticles()
    if (ui.get(onionPlayerParticles)) then
        weatherUnixTime = client.UnixTime();
        local localOrigin = vector(entity.get_origin(localPlayer))
        local fraction = client.trace_line(localPlayer, localOrigin.x, localOrigin.y, localOrigin.z, localOrigin.x, localOrigin.y, localOrigin.z - 1000);
        local floorHeight = vector(localOrigin.x, localOrigin.y, localOrigin.z - 1000 * fraction);
        local totalHeight = heightSlider;
        local heightToFloor = math.abs(floorHeight.z - localOrigin.z) + totalHeight;
        local dropletSize = dropletHeightSlider;
        local dropletTime = dropletTimeSlider;

        for i = 1, #weatherCache do
            if (weatherCache[i].dropletTime <= weatherUnixTime - weatherCache[i].startTime) then
                weatherCache[i].percent = 0; weatherCache[i].dropletTime = math.random(dropletTime); weatherCache[i].startTime = weatherUnixTime;
            else
                weatherCache[i].percent = (weatherUnixTime - weatherCache[i].startTime) / weatherCache[i].dropletTime;
            end

            local dropletPos = vector(localOrigin.x + weatherCache[i].pos.x, localOrigin.y + weatherCache[i].pos.y, localOrigin.z + totalHeight - (heightToFloor * weatherCache[i].percent));
            local dropletPos2 = vector(dropletPos.x, dropletPos.y, localOrigin.z + totalHeight - (heightToFloor * weatherCache[i].percent) - dropletSize);
            local dropletVec2, droplet2Vec2 = vector(renderer.world_to_screen(dropletPos:unpack())), vector(renderer.world_to_screen(dropletPos2:unpack()));

            if (dropletVec2.x >= 0 and dropletVec2.x <= scrW and dropletVec2.y >= 0 and dropletVec2.y <= scrH) then
                if (droplet2Vec2.x >= 0 and droplet2Vec2.x <= scrW and droplet2Vec2.y >= 0 and droplet2Vec2.y <= scrH) then
                    if (not ui.get(onionChristmasMode)) then
                        renderer.line(dropletVec2.x, dropletVec2.y, droplet2Vec2.x, droplet2Vec2.y, ui.get(onionPlayerParticlesColor));
                    elseif (weatherCache[i].color == 1) then
                        renderer.line(dropletVec2.x, dropletVec2.y, droplet2Vec2.x, droplet2Vec2.y, christmasColors[1][1], christmasColors[1][2], christmasColors[1][3], 255);
                    elseif (weatherCache[i].color == 2) then
                        renderer.line(dropletVec2.x, dropletVec2.y, droplet2Vec2.x, droplet2Vec2.y, christmasColors[2][1], christmasColors[2][2], christmasColors[2][3], 255);
                    end
                end
            end
        end
    end
end

--[[
    Callbacks
--]]

client.set_event_callback("paint_ui", function()
    dpi = getDPI();
    localPlayer = entity.get_local_player();
    notificationPaint();
    mouseX, mouseY = ui.mouse_position();
    scrW, scrH = client.screen_size();
    menuX, menuY = ui.menu_position();
    menuW, menuH = ui.menu_size();
    keySystem.run();

    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        windows.runMovement();
        windows.runPaint();

        if (not Initialization) then
            runRainbow();
            if (ui.get(onionBlockbot)) then blockbotPaint(); else blockbot.isOn = false; end
            if (ui.get(onionExtrapolation)) then extrapolatedPosition(); end
            if (ui.get(crosshairControls[1])) then crosshairPaint(); end
            espDistancePaint();
            hitmarkerPaint();
            overridePaint();
            previewPaint();
            runGridESP();
            runPlayerParticles();
        else
            Initialization = false;
        end
    end
end);

client.set_event_callback("setup_command", function(cmd)
    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        if (ui.get(onionBlockbot)) then blockbotMove(cmd); else blockbot.isOn = false; end
        antiAFKMove(cmd);
        overrideMove();
        fakeFlickEvent(cmd);
    end
end);

client.set_event_callback("string_cmd", function(str)
    if (localPlayer ~= nil and entity.is_alive(localPlayer)) then
        if (ui.get(onionRSCleaner)) then cleanRS(str); end
    end
end);

client.set_event_callback("player_connect_full", function(e)
    removeAdvertisement();
    selectTeamEvent(e);
end);

client.set_event_callback("player_hurt", function(e)
    hitmarkerEvent(e);
    damageLogEvent(e);
end);

client.set_event_callback("player_death", function(e)
    playerKilledEvent(e);
end);

client.set_event_callback("round_prestart", function(e)
    onNewRoundEvent(e);
end);

client.set_event_callback("vote_cast", function(e)
    voteRevealEvent(e);
end);
