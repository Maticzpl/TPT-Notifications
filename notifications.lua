-- Prevent multiple instances of the script running
if MaticzplNotifications ~= nil then
    return
end

if tpt.version.modid == 6 and MANAGER.getsetting("CRK","notifval") == "0" then -- Disable when notification settings turned off in Cracker1000's Mod
    return
end

MaticzplNotifications = {
    lastTimeChecked = nil,
    fpCompare = nil,
    requests = {},
    saveCache = {},
    notifications = {},
    hoveringOnButton = false,
    windowOpen = false,
    scrolled = 0,
    specialMessage = "",
    version = 1
}

local json = {}
local notif = MaticzplNotifications
local MANAGER = rawget(_G, "MANAGER")    
local warning, colorR, colorG, colorB, colorA = 0, 148,148,148,200 --Default colours

local function getcrackertheme() -- Reserved for Cracker1000's Mod
	colorR = ar
	colorG = ag
	colorB = ab
	colorA = al
end --End

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
        if x > 418 and y > 250 and x < 418 + 193 and y < 250 + 155 and notif.windowOpen then
            justClicked = true
            
            if x > 418 and x < 418 + 12 and y > 261 and y < 250 + 155 then
                holdingScroll = true
            end
            return false
        end
    end
    local function unclick(x,y,button,reason)
        justClicked = false
        holdingScroll = false
    end
    --Notification Banner
	gfx.fillRect(418,238,193,11,colorR, colorG, colorB, colorA)
	gfx.drawText(480,240,"Notification panel",255,255,255,tonumber(colorA)+50)
	
    --Window
    gfx.fillRect(418,250,193,155,0,0,0,200)
    gfx.drawRect(418,250,193,155,colorR, colorG, colorB, colorA)

    --Exit button
    local exitIsHovering = mouseX > 418 and mouseX < 418 + 12 and mouseY > 250 and mouseY < 250 + 12 and notif.windowOpen
    if exitIsHovering then
        gfx.fillRect(418,250,12,12,128,128,128,colorA) 
		gfx.drawText(395,252,"Exit",colorR, colorG, colorB, colorA)	
    end
    gfx.drawRect(418,250,12,12,colorR, colorG, colorB, colorA)
    gfx.drawText(418+3,250+2,"X")

    --Read All button
    local readAllHovering = mouseX > 418 and mouseX < 418 + 12 and mouseY > 261 and mouseY < 261 + 12 and notif.windowOpen
    if readAllHovering then
        gfx.fillRect(418,261,12,12,128,128,128)   
		gfx.drawText(375,263,"Read all",colorR, colorG, colorB, colorA)			
    end
    gfx.drawRect(418,261,12,12,colorR, colorG, colorB, colorA) 
    gfx.drawText(418+4,261+2,"A")
    
    --Scroll Bar
    local scrollY = 275
    local scrollFieldHeight = 250 + 155 - scrollY
    local barRatio = math.min(1 - (scrollLimit * -5 / 155),1)
    local barHeight = math.max(scrollFieldHeight * barRatio,10)
    if holdingScroll and barHeight + scrollY ~= 404 and scrollLimit ~= 0 then
        -- Wolfram alpha saved me here xd
        notif.scrolled = (scrollLimit*(-(mouseY - barHeight/2) + scrollY - 1)) / (barHeight + scrollY - 404)
    end
    
    if notif.scrolled > 0 then
        notif.scrolled = 0
    end    
    if notif.scrolled < scrollLimit then
        notif.scrolled = scrollLimit
    end
    if scrollLimit ~= 0 then      
        local scrollFraction = notif.scrolled / scrollLimit
        local barPos = scrollY + ((250 + 154 - barHeight - scrollY) * scrollFraction) - 1
        gfx.fillRect(420,barPos,8,barHeight,colorR, colorG, colorB, colorA)
    else
        gfx.fillRect(420,scrollY - 1,8,155 - 26, colorR, colorG, colorB, colorA)  
    end    
    
    --Vertical line
    gfx.drawLine(418+11,250,418+11,250 + 154,colorR, colorG, colorB, colorA)
        
	if #notif.notifications == 0 or notif.specialMessage ~= "" then
        local msg = "No notifications to show";
        msg = msg.."\n"..notif.specialMessage

        gfx.drawText(438,257,msg,228,228,228,255)
    else  
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
                if y >= 252 and y <= 250+155 - 10 then         
                    gfx.drawLine(418+12,y - 2,418 + 192,y - 2,colorR,colorG,colorB,colorA)     
                    gfx.drawText(418+15,y,title)
                end
                local sx,sy = gfx.textSize(title)
                y = y + sy
            end
            --Message
            if y >= 252 and y <= 250+155 - 10 then         
                gfx.drawText(418+22,y,msg,200,200,200)    
            end    
            local sx,sy = gfx.textSize(msg)
            y = y + sy
            
            local next = notif.notifications[i+1]
            if next == nil or next.title ~= title then
                if mouseX > 418 + 12 and mouseX < 418 + 193 and mouseY > lastTitleY and mouseY < y and mouseY > 250 and mouseY < 250 + 156 then
                    
                    local boxY = math.max(lastTitleY-1,251)
                    local height = math.min(y - boxY - 2,boxY + 155 - 253)
                    if height + boxY > 404 then --this is confusing
                        height = height - (height + boxY - 404)
                    end
                    gfx.drawRect(418 + 12,boxY,193 - 13,height)
                    
                    if justClicked then
                        local removing = i
                        while notif.notifications[removing].title == title do
                            table.remove(notif.notifications,removing)    
                            removing = removing - 1
                            if notif.notifications[removing] == nil then
                                break
                            end
                        end
                        notif.SaveNotifications()
                        
                        sim.loadSave(saveID)
                    end
                end
            end
            
            scrollLimit = -math.max((y - 250 - 154) / 5 - notif.scrolled, 0) 
        end
    end
  
    event.register(event.mousedown,click)
    event.register(event.mousemove,hover)
    event.register(event.mouseup,unclick)
    
    if exitIsHovering and justClicked then        
        notif.windowOpen = false
        notif.specialMessage = ""
        notif.SaveNotifications()
		warning = 0
        return false
    end    
    if readAllHovering and justClicked then      
        notif.notifications = {} 
        notif.SaveNotifications()
        return false
    end    
    justClicked = false
end
function MaticzplNotifications.ShowSpecialMesasge(msg)
    notif.specialMessage = msg;
	warning = 1
end

-- Request save data from the server
-- Called automatically every 5 minutes
function MaticzplNotifications.CheckForChanges()
    local name = tpt.get_name()
    if name ~= "" then          
        -- FP
        notif.fpCompare = http.get("https://powdertoy.co.uk/Browse.json?Start=0&Count=16");
        -- By date
        table.insert(notif.requests, http.get("https://powdertoy.co.uk/Browse.json?Start=0&Count=30&Search_Query=sort%3Adate user%3A"..name))
        table.insert(notif.requests, http.get("https://powdertoy.co.uk/Browse.json?Start=30&Count=30&Search_Query=sort%3Adate user%3A"..name))
        -- By votes
        table.insert(notif.requests, http.get("https://powdertoy.co.uk/Browse.json?Start=0&Count=30&Search_Query=user%3A"..name))
        table.insert(notif.requests, http.get("https://powdertoy.co.uk/Browse.json?Start=30&Count=30&Search_Query=user%3A"..name))
    end 
end

-- Called when recieved response from teh server after calling CheckForUpdates()
function MaticzplNotifications.OnResponse()
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
    
    local saves = {}
    for id, req in ipairs(notif.requests) do
        local res = req:finish()
        
        local success, found = pcall(json.parse,res)
        if not success then
            notif.ShowSpecialMesasge("Error while fetching saves\nfrom the server.")
            return
        end
        for k, v in pairs(found.Saves) do
            saves[v.ID] = v            
        end
    end

    local fpRes = notif.fpCompare:finish()
    local success, fpsaves = pcall(json.parse,fpRes)
    if not success then
        notif.ShowSpecialMesasge("Error while fetching FP from server.")
        return
    end
    fpsaves = fpsaves.Saves

    if notif.saveCache ~= nil then
        for id, save in pairs(saves) do
            local isFP = 0
            for _, fpSave in pairs(fpsaves) do
                if fpSave.ID == save.ID then
                    isFP = 1
                end
            end
            saves[id].FP = isFP
            
            local cached = notif.saveCache[save.ID]
            if cached == nil then
                local saved = MANAGER.getsetting("MaticzplNotifications",""..save.ID)
                if saved == nil then
                    notif.saveCache[save.ID] = {}
                    notif.saveCache[save.ID].ScoreUp = save.ScoreUp
                    notif.saveCache[save.ID].ScoreDown = save.ScoreDown
                    notif.saveCache[save.ID].Comments = save.Comments    
                    notif.saveCache[save.ID].FP = isFP
                    notif.saveCache[save.ID].ID = save.ID
                    cached = notif.saveCache[save.ID]              
                else
                    local saved = split(saved,"|")
                    notif.saveCache[save.ID] = {}
                    notif.saveCache[save.ID].ID = save.ID
                    notif.saveCache[save.ID].ScoreUp = saved[2]
                    notif.saveCache[save.ID].ScoreDown = saved[3]
                    notif.saveCache[save.ID].Comments = saved[4]
                    notif.saveCache[save.ID].FP = saved[5]
                    cached = notif.saveCache[save.ID]
                end
            end
            
            if tonumber(isFP) ~= tonumber(cached.FP) then
                if tonumber(isFP) == 1 then
                    notif.AddNotification("This save is now on FP!!!",save.ShortName,save.ID)   
                end 
                if tonumber(cached.FP) == 1 then                
                    notif.AddNotification("This save went off FP.",   save.ShortName,save.ID)  
                end            
            end
            local new = save.ScoreUp - cached.ScoreUp
            if new > 0 then
                notif.AddNotification(new.." new Upvotes!\x0F\1\255\1\238\129\139",save.ShortName,save.ID)            
            end
            new = save.ScoreDown - cached.ScoreDown
            if new > 0 then
                notif.AddNotification(new.." new Downvotes\br\238\129\138",save.ShortName,save.ID)                
            end
            new = save.Comments - cached.Comments
            if new > 0 then
                notif.AddNotification(new.." new Comments",save.ShortName,save.ID)               
            end
            MANAGER.savesetting("MaticzplNotifications",save.ID,notif.SaveToString(save))  
            notif.saveCache[save.ID] = save
        end
    else
        notif.saveCache = {}
    end
    
    notif.SaveNotifications()
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

function MaticzplNotifications.SaveNotifications()
    MANAGER.savesetting("MaticzplNotifications","Notifications",string.gsub(json.stringify(notif.notifications),"\"","~"))    
end

-- Draws the red circle notification button. Called every frame
local timerfornot = 255 -- Blinking not. dot
function MaticzplNotifications.DrawNotifications()

    local number = #notif.notifications
    
    if number > 99 then
        number = "99"
    end

    local posX = 572
    local posY = 415
    if tpt.version.jacob1s_mod ~= nil then
        posX = 584
    end
    if tpt.version.modid == 7 then --TPT Ultimata
        posX = 573
        posY = 435
    end
	if tpt.version.modid == 6 then --Cracker1000's Mod
          getcrackertheme()
    end
    local w,h = gfx.textSize(number)
    
    local nw,nh = gfx.textSize(tpt.get_name())
    
    if nw > 58 then
        gfx.fillRect(507,409,72,13,0,0,0,150)            
    end
    if number == 0 then
        gfx.fillCircle(posX,posY,5,5,50,50,50)
        gfx.fillCircle(posX,posY,4,4,60,60,60)
        gfx.drawText(posX + 1 -(w / 2),posY + 2 -(h / 2),number,128,128,128)
		    if warning == 1 then
gfx.drawText(570,412,"X",255,0,0,255)
end
        return
    end

    local brig = 0
    if notif.hoveringOnButton then
        brig = 80
    end
    if timerfornot > 0 then
        timerfornot = timerfornot - 2
    elseif timerfornot <= 0 then
        timerfornot = 255
    end
    
    gfx.fillCircle(posX,posY,6,6,120,brig,brig,timerfornot)
    gfx.fillCircle(posX,posY,5,5,255,brig,brig,timerfornot)
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
    
    notif.hoveringOnButton = math.abs(posX - x) < 5 and math.abs(posY - y) < 5
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
    if x > 418 and y > 250 and x < 418 + 193 and y < 250 + 155 and notif.windowOpen then
        notif.scrolled = notif.scrolled + d
        return false
    end
end

function MaticzplNotifications.Tick()
    local time = os.time(os.date("!*t"))
    
    if time - notif.lastTimeChecked > (5 * 60) then
        notif.lastTimeChecked = time
        
        notif.CheckForChanges()
    end
    
    local allDone = true;
    for _, req in ipairs(notif.requests) do
        if req:status() ~= "done" then
            allDone = false
            break
        end
    end    

    if allDone and notif.fpCompare ~= nil and notif.fpCompare:status() == "done" then   
        notif.OnResponse()
        notif.requests = {}
        notif.fpCompare = nil
        MANAGER.savesetting("MaticzplNotifications","lastTime",notif.lastTimeChecked)                    
    end
    
    
    notif.DrawNotifications()
    
    if notif.windowOpen then
        notif.DrawMenuContent()
    end
end

---------------------------------------------------------------------------------
-- JSON parsing from https://gist.github.com/tylerneylon/59f4bcf316be525b30ab  --
-- Credit to tylerneylon                                                       --
-- Stated to be public domain by the author (check comments in the link)       --
---------------------------------------------------------------------------------
--#region

local function kind_of(obj)
    if type(obj) ~= 'table' then return type(obj) end
    local i = 1
    for _ in pairs(obj) do
        if obj[i] ~= nil then i = i + 1 else return 'table' end
    end
    if i == 1 then return 'table' else return 'array' end
end
local function escape_str(s)
    local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
    local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
    for i, c in ipairs(in_char) do
        s = s:gsub(c, '\\' .. out_char[i])
    end
    return s
end
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
function json.stringify(obj, as_key)
    local s = {}  
    local kind = kind_of(obj)
    if kind == 'array' then
        if as_key then error('Can\'t encode array as key.') end
        s[#s + 1] = '['
        for i, val in ipairs(obj) do
            if i > 1 then s[#s + 1] = ', ' end
            s[#s + 1] = json.stringify(val)
        end
        s[#s + 1] = ']'
    elseif kind == 'table' then
        if as_key then error('Can\'t encode table as key.') end
        s[#s + 1] = '{'
        for k, v in pairs(obj) do
            if #s > 1 then s[#s + 1] = ', ' end
            s[#s + 1] = json.stringify(k, true)
            s[#s + 1] = ':'
            s[#s + 1] = json.stringify(v)
        end
        s[#s + 1] = '}'
    elseif kind == 'string' then
        return '"' .. escape_str(obj) .. '"'
    elseif kind == 'number' then
        if as_key then return '"' .. tostring(obj) .. '"' end
        return tostring(obj)
    elseif kind == 'boolean' then
        return tostring(obj)
    elseif kind == 'nil' then
        return 'null'
    else
        error('Unjsonifiable type: ' .. kind .. '.')
    end
    return table.concat(s)
end
json.null = {}
function json.parse(str, pos, end_delim)
    pos = pos or 1
    if pos > #str then error('Reached unexpected end of input.') end
    local pos = pos + #str:match('^%s*', pos)
    local first = str:sub(pos, pos)
    if first == '{' then
        local obj, key, delim_found = {}, true, true
        pos = pos + 1
        while true do
            key, pos = json.parse(str, pos, '}')
            if key == nil then return obj, pos end
            if not delim_found then error('Comma missing between object items.') end
            pos = skip_delim(str, pos, ':', true)
            obj[key], pos = json.parse(str, pos)
            pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '[' then 
        local arr, val, delim_found = {}, true, true
        pos = pos + 1
        while true do
            val, pos = json.parse(str, pos, ']')
            if val == nil then return arr, pos end
            if not delim_found then error('Comma missing between array items.') end
            arr[#arr + 1] = val
            pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '"' then 
        return parse_str_val(str, pos + 1)
    elseif first == '-' or first:match('%d') then
        return parse_num_val(str, pos)
    elseif first == end_delim then 
        return nil, pos + 1
    else
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
-- On launch
notif.lastTimeChecked = MANAGER.getsetting("MaticzplNotifications","lastTime") or 0
local notifJson = MANAGER.getsetting("MaticzplNotifications","Notifications")
if notifJson then
    local jsonStr = string.gsub(notifJson,"~","\"")
    notif.notifications = json.parse(jsonStr)  
end
event.register(event.tick,notif.Tick)
event.register(event.mousemove,notif.Mouse)
event.register(event.mousedown,notif.OnClick)
event.register(event.mousewheel,notif.Scroll)

local name = tpt.get_name()
if name == "" then          
    notif.ShowSpecialMesasge("You need to be logged in\nto use the notifications script.")
end