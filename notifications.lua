-- Prevent multiple instances of the script running and choose the newer one
if MaticzplNotifications ~= nil and MaticzplNotifications.version > 1 then
    return
end

MaticzplNotifications = {
    lastTimeChecked = nil,
    request = nil,
    FPrequest = nil,
    saveCache = {},
    notifications = {},
    hoveringOnButton = false,
    windowOpen = false,
    scrolled = 0,
    version = 1
}

local json = {}
local notif = MaticzplNotifications
local MANAGER = rawget(_G, "MANAGER")    


--Ik this code is awful but interface from tpt api is very limiting
local mouseX = 0
local mouseY = 0
local justClicked = false
local holdingScroll = false
local scrollLimit = 0
function MaticzplNotifications.DrawMenuContent()
    local function hover(x,y,dx,dy)       
        mouseX = x
        mouseY = y        
    end
    local function click(x,y,button)
        -- inside window
        if x > 418 and y > 250 and x < 418 + 193 and y < 250 + 156 and notif.windowOpen then
            justClicked = true

            if x > 418 and x < 418 + 12 and y > 261 and y < 250 + 156 then
                holdingScroll = true
            end
            return false
        end
    end
    local function unclick(x,y,button,reason)
        justClicked = false
        holdingScroll = false
    end


    --Window
    gfx.fillRect(418,250,193,156,   0,0,0)
    gfx.drawRect(418,250,193,156,   255,255,255)



    --Exit button
    local exitIsHovering = mouseX > 418 and mouseX < 418 + 12 and mouseY > 250 and mouseY < 250 + 12 and notif.windowOpen
    if exitIsHovering then
        gfx.fillRect(418,250,12,12, 128,128,128)        
    end
    gfx.drawRect(418,250,12,12,     255,255,255)
    gfx.drawText(418+3,250+2,"X")

    --Scroll Bar
    local scrollFieldHeight = 250 + 156 - 263
    local barRatio = math.min(1 - (scrollLimit * -5 / 156),1)
    local barHeight = math.max(scrollFieldHeight * barRatio,10)
    if holdingScroll and barHeight < 141 then
        -- Wolfram alpha saved me here xd
        notif.scrolled = - ((scrollLimit*(mouseY - (263 + barHeight / 2))) / (barHeight - 141))
    end

    if notif.scrolled > 0 then
        notif.scrolled = 0
    end    
    if notif.scrolled < scrollLimit then
        notif.scrolled = scrollLimit
    end
    if scrollLimit ~= 0 then      
        local scrollFraction = notif.scrolled / scrollLimit
        local barPos = 263 + ((250 + 154 - barHeight - 263) * scrollFraction)
        gfx.fillRect(420,barPos,8,barHeight, 128,128,128)    
    else
        gfx.fillRect(420,263,8,156 - 15, 128,128,128)    
    end    

    --Vertical line
    gfx.drawLine(418+11,250,418+11,250 + 155)

    local y = 252 + notif.scrolled * 5
    local lastTitleY = y

    for i, n in ipairs(notif.notifications) do      
        local prev = notif.notifications[i-1]
        
        local saveID = n.save
        local title = n.title
        local msg = n.message

        --Group title
        if prev == nil or prev.title ~= title then
            lastTitleY = y
            if y >= 252 and y <= 250+156 - 10 then         
                gfx.drawLine(418+12,y - 2,418 + 192,y - 2)     
                gfx.drawText(418+15,y,title)
            end
            local sx,sy = gfx.textSize(title)
            y = y + sy
        end
        --Message
        if y >= 252 and y <= 250+156 - 10 then         
            gfx.drawText(418+22,y,msg,200,200,200)    
        end    
        local sx,sy = gfx.textSize(msg)
        y = y + sy
   
        local next = notif.notifications[i+1]
        if next == nil or next.title ~= title then
            if mouseX > 418 + 12 and mouseX < 418 + 193 and mouseY > lastTitleY and mouseY < y and mouseY > 250 and mouseY < 250 + 156 then
                local boxY = math.max(lastTitleY-1,251)
                gfx.drawRect(418 + 12,boxY,193 - 13,math.min(y - lastTitleY-1,boxY - 251 + 154))
                if justClicked then
                    sim.loadSave(saveID)
                end
            end
        end

        scrollLimit = -math.max((y - 250 - 154) / 5 - notif.scrolled, 0) 
    end


    event.register(event.mousedown,click)
    event.register(event.mousemove,hover)
    event.register(event.mouseup,unclick)

    if exitIsHovering and justClicked then        
        notif.windowOpen = false
        notif.notifications = {} 
        for id, value in pairs(notif.saveCache) do
            MANAGER.savesetting("MaticzplNotifications",id,notif.SaveToString(value))      
        end    
        return false
    end    
    justClicked = false
end


-- Request save data from the server
-- Called automatically every 10 minutes
function MaticzplNotifications.CheckForChanges()
    local name = tpt.get_name()
    if name ~= "" then                 
        notif.request = http.get("https://powdertoy.co.uk/Browse.json?Start=0&Count=30&Search_Query=user%3A"..name)
        notif.FPrequest = http.get("https://powdertoy.co.uk/Browse.json")
    end 
end

-- Called when recieved response from teh server after calling CheckForUpdates()
function MaticzplNotifications.OnResponse(response,fpresponse)
    local function split (input, sep)
        if sep == nil then
            sep = "%s"
        end
        local t={}
        for str in string.gmatch(input, "([^"..sep.."]+)") do
            table.insert(t, str)
        end
        return t
    end

    
    local saves, success = pcall(function() return json.parse(response).Saves end)
    if not success then 
        print("Error fetching saves from server. Try again later") 
        return
    end

    local fp,success = pcall(function() return json.parse(fpresponse).Saves end)
    if not success then 
        print("Error fetching FP from server. Try again later")         
        return
    end

    if notif.saveCache ~= nil then
        for _, save in ipairs(saves) do
            local isFP = 0
            for _, fpSave in pairs(fp) do
                if fpSave.ID == save.ID then
                    isFP = 1
                end
            end
            save.FP = isFP

            local cached = notif.saveCache[save.ID]
            if cached == nil then
                local saved = MANAGER.getsetting("MaticzplNotifications",""..save.ID)
                if saved == nil then
                    notif.saveCache[save.ID] = {}
                    notif.saveCache[save.ID].ScoreUp = save.ScoreUp
                    notif.saveCache[save.ID].ScoreDown = save.ScoreDown
                    notif.saveCache[save.ID].Comments = save.Comments    
                    notif.saveCache[save.ID].FP = 0--isFP
                    cached = notif.saveCache[save.ID]                
                else
                    local saved = split(saved,"|")
                    notif.saveCache[save.ID] = {}
                    notif.saveCache[save.ID].ScoreUp = saved[2]
                    notif.saveCache[save.ID].ScoreDown = saved[3]
                    notif.saveCache[save.ID].Comments = saved[4]
                    notif.saveCache[save.ID].FP = saved[5]
                    cached = notif.saveCache[save.ID]
                end
            end

            if isFP ~= cached.FP then
                if isFP == 1 then
                    notif.AddNotification("This save is now on FP!!!",save.ShortName,save.ID)   
                else                    
                    notif.AddNotification("This save went off FP.",   save.ShortName,save.ID)  
                end            
            end
            local new = save.ScoreUp - cached.ScoreUp
            if new ~= 0 then
                notif.AddNotification(new.." new Upvotes!\x0F\1\255\1\238\129\139",save.ShortName,save.ID)            
            end
            new = save.ScoreDown - cached.ScoreDown
            if new ~= 0 then
                notif.AddNotification(new.." new Downvotes\br\238\129\138",save.ShortName,save.ID)                
            end
            new = save.Comments - cached.Comments
            if new ~= 0 then
                notif.AddNotification(new.." new Comments",save.ShortName,save.ID)               
            end
        end
    else
        notif.saveCache = {}
    end

    -- Save new data
    for i, save in ipairs(saves) do
        notif.saveCache[save.ID] = save
    end
end

-- Message to display in notification
-- Title by which multiple notifications will be grouped
-- saveID optional to open save on click
function MaticzplNotifications.AddNotification(message,title,saveID)    
    local notification = {
        ["save"] = saveID,
        ["title"] = title,
        ["message"] = message
    }
    table.insert(notif.notifications, notification)     
end

-- Draws the red circle notification button. Called every frame
function MaticzplNotifications.DrawNotifications()
    local number = #notif.notifications

    if number == 0 then
        return
    end

    local posX = 572
    local posY = 415
    if tpt.version.jacob1s_mod ~= nil then
        posX = 585
    end

    local w,h = gfx.textSize(number)

    local brig = 0
    if notif.hoveringOnButton then
        brig = 80
    end

    gfx.fillCircle(posX,posY,6,6,120,brig,brig)
    gfx.fillCircle(posX,posY,5,5,255,brig,brig)  
    gfx.drawText(posX + 1 -(w / 2),posY + 2 -(h / 2),number,255,255,255)
end

-- Used for saving current state of saves
function MaticzplNotifications.SaveToString(save)
    local separator = "|"

    return save.ID..separator..save.ScoreUp..separator..save.ScoreDown..separator..save.Comments..separator..save.FP
end


function MaticzplNotifications.Mouse(x,y,dx,dy)
    local posX = 572
    local posY = 415
    if tpt.version.jacob1s_mod ~= nil then
        posX = 585
    end

    notif.hoveringOnButton = math.abs(posX - x) < 5 and math.abs(posY - y) < 5 and #notif.notifications > 0
end

function MaticzplNotifications.OnClick(x,y,button)
    if notif.hoveringOnButton then
        notif.scrolled = 0
        notif.windowOpen = true

        notif.DrawMenuContent()
        return false
    end
end

function MaticzplNotifications.Scroll(x,y,d)
    d = d / math.abs(d) --clamp to 1 / -1

    --In window
    if x > 418 and y > 250 and x < 418 + 193 and y < 250 + 156 and notif.windowOpen then
        notif.scrolled = notif.scrolled + d
        return false
    end
end

function MaticzplNotifications.Tick()
    local time = os.time(os.date("!*t"))

    if time - notif.lastTimeChecked > (10 * 60) then
        notif.lastTimeChecked = time

        notif.CheckForChanges()
    end

    if notif.request ~= nil and notif.request:status() == "done" and notif.FPrequest ~= nil and notif.request:status() == "done" then
        notif.OnResponse(notif.request:finish(),notif.FPrequest:finish())
        notif.request = nil
        notif.FPrequest = nil
        MANAGER.savesetting("MaticzplNotifications","lastTime",notif.lastTimeChecked)                    
    end


    notif.DrawNotifications()

    if notif.windowOpen then
        notif.DrawMenuContent()
    end
end

notif.lastTimeChecked = MANAGER.getsetting("MaticzplNotifications","lastTime") or 0

event.register(event.tick,notif.Tick)
event.register(event.mousemove,notif.Mouse)
event.register(event.mousedown,notif.OnClick)
event.register(event.mousewheel,notif.Scroll)


---------------------------------------------------------------------------------
-- JSON parsing from https://gist.github.com/tylerneylon/59f4bcf316be525b30ab  --
-- Credit to tylerneylon                                                       --
-- Stated to be public domain by the author (check comments in the link)       --
---------------------------------------------------------------------------------
--#region
local function skip_delim(str, pos, delim, err_if_missing)
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) ~= delim then
        if err_if_missing then
            error('Expected ' .. delim .. ' near position ' .. pos)
        end
        return pos, false
    end
    return pos + 1, true
end
local function parse_str_val(str, pos, val)
    val = val or ''
    local early_end_error = 'End of input found while parsing string.'
    if pos > #str then error(early_end_error) end
    local c = str:sub(pos, pos)
    if c == '"'  then return val, pos + 1 end
    if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
    -- We must have a \ character.
    local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
    local nextc = str:sub(pos + 1, pos + 1)
    if not nextc then error(early_end_error) end
    return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end
local function parse_num_val(str, pos)
    local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
    local val = tonumber(num_str)
    if not val then error('Error parsing number at position ' .. pos .. '.') end
    return val, pos + #num_str
end
json.null = {}
function json.parse(str, pos, end_delim)
    pos = pos or 1
    if pos > #str then error('Reached unexpected end of input.') end
    local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
    local first = str:sub(pos, pos)
    if first == '{' then  -- Parse an object.
        local obj, key, delim_found = {}, true, true
        pos = pos + 1
        while true do
            key, pos = json.parse(str, pos, '}')
            if key == nil then return obj, pos end
            if not delim_found then error('Comma missing between object items.') end
            pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
            obj[key], pos = json.parse(str, pos)
            pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '[' then  -- Parse an array.
        local arr, val, delim_found = {}, true, true
        pos = pos + 1
        while true do
            val, pos = json.parse(str, pos, ']')
            if val == nil then return arr, pos end
            if not delim_found then error('Comma missing between array items.') end
            arr[#arr + 1] = val
            pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '"' then  -- Parse a string.
        return parse_str_val(str, pos + 1)
    elseif first == '-' or first:match('%d') then  -- Parse a number.
        return parse_num_val(str, pos)
    elseif first == end_delim then  -- End of an object or array.
        return nil, pos + 1
    else  -- Parse true, false, or null.
        local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
        for lit_str, lit_val in pairs(literals) do
            local lit_end = pos + #lit_str - 1
            if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
        end
        local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
        error('Invalid json syntax starting at ' .. pos_info_str)
    end
end
--#endregion