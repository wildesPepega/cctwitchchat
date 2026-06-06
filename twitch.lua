-- =====================================================
--  Twitch Chat Client for CC: Tweaked
--  Version 1.6
--
--  Features:
--    - Login stored locally (obfuscated), hidden token entry
--    - Real Twitch name colors (mapped to CC palette)
--    - Own-name mention highlight
--    - Monitor support (scrolling chat history)
--    - Multi-channel read (/join, /switch)
--    - 7TV emote name highlighting (global + channel)
--    - Auto-update from a GitHub repo
--
--  Usage: edit twitch  ->  paste  ->  run: twitch
-- =====================================================

local VERSION = "1.6"

-- ---- Update source (edit these to point at YOUR repo) ----
local REPO_USER   = "wildesPepega"
local REPO_NAME   = "cctwitchchat"
local REPO_BRANCH = "main"
local VER_URL  = ("https://raw.githubusercontent.com/%s/%s/%s/version.txt"):format(REPO_USER, REPO_NAME, REPO_BRANCH)
local CODE_URL = ("https://raw.githubusercontent.com/%s/%s/%s/twitch.lua"):format(REPO_USER, REPO_NAME, REPO_BRANCH)

local CONFIG_FILE = "twitch_login.dat"
local IRC_URL = "wss://irc-ws.chat.twitch.tv:443"

-- =====================================================
--  AUTO-UPDATER
-- =====================================================
local function checkUpdate()
  if REPO_USER == "" or REPO_NAME == "" then return end -- not configured
  local ok, r = pcall(http.get, VER_URL)
  if not ok or not r then return end
  local remote = r.readAll():gsub("%s+", "")
  r.close()
  if remote ~= "" and remote ~= VERSION then
    print("Update available: " .. remote .. " (local " .. VERSION .. ")")
    print("Downloading...")
    local ok2, cr = pcall(http.get, CODE_URL)
    if ok2 and cr then
      local code = cr.readAll()
      cr.close()
      local path = shell.getRunningProgram()
      local f = fs.open(path, "w")
      f.write(code)
      f.close()
      print("Updated to " .. remote .. ". Rebooting...")
      sleep(1.5)
      os.reboot()
    else
      print("Could not download update, continuing on " .. VERSION)
      sleep(1)
    end
  end
end

checkUpdate()

-- =====================================================
--  LOGIN STORAGE (XOR obfuscation - NOT real encryption)
-- =====================================================
local OBF_KEY = "cc-twitch-keysalt-9183"

local function xorCipher(text, key)
  local out = {}
  for i = 1, #text do
    local tb = text:byte(i)
    local kb = key:byte((i - 1) % #key + 1)
    out[i] = string.char(bit32.bxor(tb, kb))
  end
  return table.concat(out)
end

local function toHex(s)
  return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end
local function fromHex(h)
  return (h:gsub("%x%x", function(cc) return string.char(tonumber(cc, 16)) end))
end

local function saveLogin(token, nick)
  local blob = nick .. "\n" .. token
  local enc = toHex(xorCipher(blob, OBF_KEY))
  local f = fs.open(CONFIG_FILE, "w")
  f.write(enc)
  f.close()
end

local function loadLogin()
  if not fs.exists(CONFIG_FILE) then return nil, nil end
  local f = fs.open(CONFIG_FILE, "r")
  local enc = f.readAll()
  f.close()
  local blob = xorCipher(fromHex(enc), OBF_KEY)
  local nick, token = blob:match("^(.-)\n(.+)$")
  return token, nick
end

local TOKEN, NICK = loadLogin()

if not TOKEN or not NICK then
  term.clear(); term.setCursorPos(1, 1)
  term.setTextColor(colors.purple)
  print("=====================================")
  term.setTextColor(colors.white)
  print("      Twitch Login - First Setup")
  term.setTextColor(colors.purple)
  print("=====================================")
  term.setTextColor(colors.white)

  write("Twitch username: ")
  NICK = read():lower()

  print("Enter OAuth token (hidden input).")
  print("Format: oauth:xxxxxxxx")
  write("Token: ")
  TOKEN = read("*")
  if not TOKEN:match("^oauth:") then
    TOKEN = "oauth:" .. TOKEN
  end

  saveLogin(TOKEN, NICK)
  term.setTextColor(colors.lime)
  print("Login saved. (/logout to remove)")
  term.setTextColor(colors.white)
  sleep(1.5)
end

-- =====================================================
--  MONITOR
-- =====================================================
local monitor = peripheral.find("monitor")
if monitor then
  monitor.setTextScale(0.5)
  monitor.setBackgroundColor(colors.black)
  monitor.clear()
  monitor.setCursorPos(1, 1)
end

-- =====================================================
--  UTF-8 HANDLING
--  This CC build uses Latin-1 byte display (ae=228 etc.), so we convert
--  between UTF-8 (Twitch) and single-byte Latin-1 (CC) in both directions.
-- =====================================================
-- =====================================================
--  INCOMING DECODING (UTF-8 from Twitch -> CC Latin-1 bytes)
--  Twitch sends UTF-8. This CC build can show Latin-1 bytes directly,
--  so we decode UTF-8 and keep codepoints <=255 as a single byte.
--  Codepoints above 255 (emoji etc.) can't be shown -> '?'.
-- =====================================================
local function sanitize(str)
  local out = {}
  local i = 1
  local n = #str
  while i <= n do
    local b = str:byte(i)
    if b < 0x80 then
      out[#out+1] = string.char(b)
      i = i + 1
    elseif b >= 0xC0 and b < 0xE0 then
      -- 2-byte sequence
      local b2 = str:byte(i+1) or 0
      local cp = (b - 0xC0) * 0x40 + (b2 - 0x80)
      out[#out+1] = (cp <= 255) and string.char(cp) or "?"
      i = i + 2
    elseif b >= 0xE0 and b < 0xF0 then
      -- 3-byte sequence (always > 255) -> not displayable
      out[#out+1] = "?"
      i = i + 3
    elseif b >= 0xF0 then
      -- 4-byte sequence (emoji etc.)
      out[#out+1] = "?"
      i = i + 4
    else
      -- stray continuation byte
      out[#out+1] = "?"
      i = i + 1
    end
  end
  return table.concat(out)
end

-- =====================================================
--  OUTGOING ENCODING (CC -> UTF-8 for Twitch)
--  This CC build stores chars as Latin-1/Unicode bytes (e.g. ae=228),
--  so any byte 128..255 IS the Unicode codepoint and just needs UTF-8 encoding.
-- =====================================================
local function utf8encode(cp)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 0x40),
                       0x80 + (cp % 0x40))
  else
    return string.char(0xE0 + math.floor(cp / 0x1000),
                       0x80 + (math.floor(cp / 0x40) % 0x40),
                       0x80 + (cp % 0x40))
  end
end

local function toUTF8(str)
  local out = {}
  for i = 1, #str do
    local b = str:byte(i)
    out[#out+1] = utf8encode(b)  -- byte value == codepoint for Latin-1
  end
  return table.concat(out)
end

-- =====================================================
--  COLOR MAPPING: hex (#RRGGBB) -> nearest CC color
-- =====================================================
local ccPalette = {
  [colors.white]     = {0xF0,0xF0,0xF0},
  [colors.orange]    = {0xF2,0xB2,0x33},
  [colors.magenta]   = {0xE5,0x7F,0xD8},
  [colors.lightBlue] = {0x99,0xB2,0xF2},
  [colors.yellow]    = {0xDE,0xDE,0x6C},
  [colors.lime]      = {0x7F,0xCC,0x19},
  [colors.pink]      = {0xF2,0xB2,0xCC},
  [colors.gray]      = {0x4C,0x4C,0x4C},
  [colors.lightGray] = {0x99,0x99,0x99},
  [colors.cyan]      = {0x4C,0x99,0xB2},
  [colors.purple]    = {0xB2,0x66,0xE5},
  [colors.blue]      = {0x33,0x66,0xCC},
  [colors.brown]     = {0x7F,0x66,0x4C},
  [colors.green]     = {0x57,0xA6,0x4E},
  [colors.red]       = {0xCC,0x4C,0x4C},
  [colors.black]     = {0x19,0x19,0x19},
}

local function hexToCC(hex)
  local r = tonumber(hex:sub(2,3), 16)
  local g = tonumber(hex:sub(4,5), 16)
  local b = tonumber(hex:sub(6,7), 16)
  if not (r and g and b) then return nil end
  local best, bestDist = colors.white, math.huge
  for col, rgb in pairs(ccPalette) do
    local dr, dg, db = r-rgb[1], g-rgb[2], b-rgb[3]
    local dist = dr*dr + dg*dg + db*db
    if dist < bestDist then bestDist = dist; best = col end
  end
  return best
end

local nameColors = { colors.red, colors.orange, colors.yellow, colors.lime,
                     colors.cyan, colors.lightBlue, colors.pink, colors.magenta }
local function colorForUser(name)
  local sum = 0
  for i = 1, #name do sum = sum + name:byte(i) end
  return nameColors[(sum % #nameColors) + 1]
end

local function timestamp()
  -- os.epoch("local") gives real wall-clock ms since 1970 (unlike os.time(),
  -- which is in-game day time). Convert to HH:MM in local time.
  local secs = math.floor(os.epoch("local") / 1000)
  local h = math.floor(secs / 3600) % 24
  local m = math.floor(secs / 60) % 60
  return string.format("%02d:%02d", h, m)
end

local function parseColor(tagPart)
  if not tagPart then return nil end
  local hex = tagPart:match("color=(#%x%x%x%x%x%x)")
  if hex then return hexToCC(hex) end
  return nil
end

-- Twitch sends a unique per-message id in the tags (id=...). We use it to
-- guarantee each message is shown exactly once, no matter how it arrives.
local function parseMsgId(tagPart)
  if not tagPart then return nil end
  return tagPart:match("id=([%w%-]+)")
end

-- =====================================================
--  7TV EMOTES
--  Endpoints (verified):
--    global:  https://7tv.io/v3/emote-sets/global
--    channel: https://7tv.io/v3/users/twitch/{twitch_id}
--  Twitch user id resolved via decapi (no app key needed).
-- =====================================================
local emoteSet = {}        -- lookup: lowercased emote name -> true
local EMOTE_COLOR = colors.cyan

local function addEmotesFromJson(json)
  if type(json) ~= "table" then return 0 end
  local count = 0
  -- global endpoint: { emotes = { {name=...}, ... } }
  -- channel endpoint: { emote_set = { emotes = { {name=...}, ... } } }
  local list = json.emotes
  if not list and json.emote_set then list = json.emote_set.emotes end
  if type(list) == "table" then
    for _, e in ipairs(list) do
      if e and e.name then
        emoteSet[e.name:lower()] = true
        count = count + 1
      end
    end
  end
  return count
end

local function fetchJson(url)
  local ok, r = pcall(http.get, url, { ["Accept"] = "application/json" })
  if not ok or not r then return nil end
  local body = r.readAll()
  r.close()
  local data = textutils.unserialiseJSON(body)
  return data
end

local function resolveTwitchId(login)
  -- decapi returns the plain numeric id as text
  local ok, r = pcall(http.get, "https://decapi.me/twitch/id/" .. login)
  if not ok or not r then return nil end
  local id = r.readAll():gsub("%s+", "")
  r.close()
  if id:match("^%d+$") then return id end
  return nil
end

local function loadEmotes(channelLogin, logFn)
  -- global set
  local g = fetchJson("https://7tv.io/v3/emote-sets/global")
  local gc = addEmotesFromJson(g)
  logFn("7TV global emotes: " .. gc)

  -- channel set
  local id = resolveTwitchId(channelLogin)
  if id then
    local c = fetchJson("https://7tv.io/v3/users/twitch/" .. id)
    local cc = addEmotesFromJson(c)
    logFn("7TV channel emotes: " .. cc)
  else
    logFn("Could not resolve channel id (no channel emotes).")
  end
end

-- =====================================================
--  WORD WRAP
--  Wrap a string to a given width at word boundaries.
--  Continuation lines get an indent so they line up under the message.
-- =====================================================
local function wrapText(str, width, indent)
  indent = indent or 0
  if width < 1 then width = 1 end
  local lines = {}
  local pad = string.rep(" ", indent)
  local current = ""

  local function isEmpty() return current == "" or current == pad end
  local function pushLine()
    table.insert(lines, current)
    current = pad
  end

  for word in str:gmatch("%S+") do
    -- a single word longer than the available width: hard-split it
    while #current + #word + (isEmpty() and 0 or 1) > width and #word > (width - #pad) do
      if isEmpty() then
        local take = width - #current
        if take < 1 then take = 1 end
        current = current .. word:sub(1, take)
        word = word:sub(take + 1)
        pushLine()
      else
        pushLine()
      end
    end
    if isEmpty() then
      current = current .. word
    elseif #current + 1 + #word <= width then
      current = current .. " " .. word
    else
      pushLine()
      current = current .. word
    end
  end
  if not isEmpty() then table.insert(lines, current) end
  if #lines == 0 then lines = { "" } end
  return lines
end

-- =====================================================
--  DISPLAY
-- =====================================================
local history = {}
local MAX_HISTORY = 200
local scrollOffset = 0   -- 0 = bottom (newest). Higher = scrolled up.

local function redrawMonitor()
  if not monitor then return end
  monitor.setBackgroundColor(colors.black)
  monitor.clear()
  local w, h = monitor.getSize()
  local textW = w - 1            -- reserve last column for the scroll arrows
  if textW < 1 then textW = w end

  -- clamp scroll offset to valid range
  local maxOffset = math.max(0, #history - h)
  if scrollOffset > maxOffset then scrollOffset = maxOffset end
  if scrollOffset < 0 then scrollOffset = 0 end

  -- which slice of history to show
  local endLine = #history - scrollOffset
  local startLine = math.max(1, endLine - h + 1)
  local row = 1
  for i = startLine, endLine do
    local line = history[i]
    if line then
      monitor.setCursorPos(1, row)
      if line.highlight then
        monitor.setBackgroundColor(colors.gray)
      else
        monitor.setBackgroundColor(colors.black)
      end
      monitor.setTextColor(line.color or colors.white)
      monitor.write(line.text:sub(1, textW))
    end
    row = row + 1
  end

  -- draw scroll arrows in the last column (top = up, bottom = down)
  monitor.setBackgroundColor(colors.gray)
  monitor.setTextColor(scrollOffset < maxOffset and colors.white or colors.lightGray)
  monitor.setCursorPos(w, 1)
  monitor.write("^")
  monitor.setTextColor(scrollOffset > 0 and colors.white or colors.lightGray)
  monitor.setCursorPos(w, h)
  monitor.write("v")
  monitor.setBackgroundColor(colors.black)
end

local function pushMonitorLine(text, color, highlight)
  if not monitor then return end
  local w = select(1, monitor.getSize())
  local textW = w - 1            -- reserve last column for arrows
  if textW < 1 then textW = w end
  -- wrap to monitor text width, indent continuation lines by 2
  local wrapped = wrapText(text, textW, 2)
  local atBottom = (scrollOffset == 0)
  for _, ln in ipairs(wrapped) do
    table.insert(history, { text = ln, color = color or colors.white, highlight = highlight })
  end
  while #history > MAX_HISTORY do table.remove(history, 1) end
  -- if the user was at the bottom, stay pinned to newest; otherwise keep
  -- their scroll position steady as new lines arrive
  if not atBottom then
    scrollOffset = scrollOffset + #wrapped
  end
  redrawMonitor()
end

-- write the message text to the terminal, coloring emote words
-- write message text to terminal with word wrap + emote coloring.
-- startCol = column where the text begins (after the prefix);
-- continuation lines indent to that same column.
local function writeTerminalText(text, startCol)
  local w = select(1, term.getSize())
  local indent = startCol - 1
  if indent < 0 then indent = 0 end
  if indent > w - 4 then indent = 0 end  -- prefix too wide; don't indent
  local pad = string.rep(" ", indent)

  local col = startCol  -- current cursor column (1-based)

  for word in text:gmatch("%S+") do
    local wlen = #word
    -- need a space before the word unless we're at the start of a line
    local needSpace = (col > startCol) and 1 or 0

    -- wrap if the word (plus leading space) won't fit
    if col + needSpace + wlen - 1 > w and col > startCol then
      print("")               -- new line
      write(pad)
      col = indent + 1
      needSpace = 0
    end

    if needSpace == 1 then write(" "); col = col + 1 end

    -- a word longer than the line width: hard-split across lines
    while wlen > w - indent do
      local space = w - col + 1
      if space < 1 then
        print(""); write(pad); col = indent + 1; space = w - col + 1
      end
      local part = word:sub(1, space)
      term.setTextColor(emoteSet[word:lower()] and EMOTE_COLOR or colors.white)
      write(part); term.setTextColor(colors.white)
      word = word:sub(space + 1)
      wlen = #word
      print(""); write(pad); col = indent + 1
    end

    term.setTextColor(emoteSet[word:lower()] and EMOTE_COLOR or colors.white)
    write(word)
    term.setTextColor(colors.white)
    col = col + wlen
  end
  print("")
end

local function printChatLine(user, text, userColor)
  user = sanitize(user)
  text = sanitize(text)
  userColor = userColor or colorForUser(user)

  local mentioned = text:lower():find(NICK:lower(), 1, true) ~= nil

  -- Terminal
  local prefix = "[" .. timestamp() .. "] " .. user .. ": "
  if mentioned then term.setBackgroundColor(colors.gray) end
  term.setTextColor(colors.lightGray); write("[" .. timestamp() .. "] ")
  term.setTextColor(userColor); write(user)
  term.setTextColor(colors.lightGray); write(": ")
  writeTerminalText(text, #prefix + 1)
  term.setBackgroundColor(colors.black)

  -- Monitor (wrapped to monitor width inside pushMonitorLine)
  pushMonitorLine("[" .. timestamp() .. "] " .. user .. ": " .. text,
                  userColor, mentioned)
end

local function systemLine(text, color)
  term.setTextColor(color or colors.lightGray)
  print(text)
  term.setTextColor(colors.white)
  pushMonitorLine("* " .. text, color or colors.lightGray, false)
end

-- =====================================================
--  STARTUP
-- =====================================================
term.clear(); term.setCursorPos(1, 1)
term.setTextColor(colors.purple)
print("=====================================")
term.setTextColor(colors.white)
print("     Twitch Chat Client  v" .. VERSION)
term.setTextColor(colors.purple)
print("=====================================")
term.setTextColor(colors.white)
print("Logged in as: " .. NICK)

write("Channel to write in? #")
local channelInput = read()
local CHANNEL = "#" .. channelInput:gsub("^#", ""):lower()
local channelLogin = channelInput:gsub("^#", ""):lower()

if monitor then
  systemLine("Monitor found - chat history shown there.", colors.lime)
else
  systemLine("No monitor found - terminal only.", colors.gray)
end

-- load 7TV emotes for this channel
systemLine("Loading 7TV emotes...", colors.gray)
loadEmotes(channelLogin, function(m) systemLine("  " .. m, colors.gray) end)

-- connect
systemLine("Connecting to Twitch...", colors.gray)
local ws, err = http.websocket(IRC_URL)
if not ws then
  systemLine("Connection failed: " .. tostring(err), colors.red)
  return
end

ws.send("PASS " .. TOKEN)
ws.send("NICK " .. NICK)
ws.send("CAP REQ :twitch.tv/tags twitch.tv/commands")
ws.send("JOIN " .. CHANNEL)
systemLine("Connected to " .. CHANNEL, colors.lime)

local joined = { [CHANNEL] = true }

local function showHelp()
  systemLine("Commands:", colors.yellow)
  systemLine("  /join <channel>    - join another channel (read)", colors.gray)
  systemLine("  /switch <channel>  - change channel you write to", colors.gray)
  systemLine("  /channels          - list joined channels", colors.gray)
  systemLine("  /clear             - clear history", colors.gray)
  systemLine("  /logout            - delete stored login", colors.gray)
  systemLine("  /help              - this help", colors.gray)
  systemLine("  /quit              - exit", colors.gray)
end
showHelp()

-- =====================================================
--  LISTENER (line-by-line, de-duplicated)
-- =====================================================
-- Remember recently seen message ids so a message is never shown twice,
-- regardless of duplicate JOINs, repeated frames, or server resends.
local seenIds = {}        -- id -> true
local seenOrder = {}      -- queue of ids to cap memory
local SEEN_MAX = 300

local function alreadySeen(id)
  if not id then return false end
  if seenIds[id] then return true end
  seenIds[id] = true
  table.insert(seenOrder, id)
  if #seenOrder > SEEN_MAX then
    local old = table.remove(seenOrder, 1)
    seenIds[old] = nil
  end
  return false
end

-- Queue of our own messages awaiting server confirmation (FIFO).
-- We only display them once Twitch echoes them back (proof of delivery).
local pending = {}   -- list of { text=..., channel=... }

local function handleLine(line)
  if line == "" then return end
  if line:sub(1, 4) == "PING" then
    ws.send("PONG :tmi.twitch.tv")
    return
  end

  local tagPart, rest = line:match("^@([^ ]+) (.+)$")
  if not tagPart then rest = line end

  -- NOTICE = server feedback, often a rejection reason for our message
  local noticeText = rest:match("^:[^ ]* NOTICE [^ ]+ :(.+)")
  if noticeText then
    noticeText = noticeText:gsub("[\r\n]", "")
    -- a rejected message stays pending; drop the oldest so it isn't shown
    if #pending > 0 then table.remove(pending, 1) end
    systemLine("Not delivered: " .. sanitize(noticeText), colors.red)
    return
  end

  local user, text = rest:match("^:([%w_]+)![^ ]* PRIVMSG [^ ]+ :(.+)")
  if not (user and text) then return end

  text = text:gsub("[\r\n]", "")

  -- our own message echoed back as PRIVMSG = confirmation it was delivered.
  -- this is the only signal carrying both the text and a unique id, so we
  -- rely on it exclusively to display own messages.
  if user:lower() == NICK:lower() then
    if #pending > 0 then table.remove(pending, 1) end
    printChatLine(user, text, colorForUser(NICK))
    return
  end

  -- de-dup: prefer the unique Twitch id; fall back to a user+text fingerprint
  local id = parseMsgId(tagPart) or (user .. "|" .. text)
  if alreadySeen(id) then return end

  local userColor = parseColor(tagPart)
  printChatLine(user, text, userColor)
end

local function listener()
  while true do
    local msg = ws.receive()
    if msg then
      for line in (msg .. "\n"):gmatch("(.-)\r?\n") do
        handleLine(line)
      end
    end
  end
end

-- =====================================================
--  SENDER / COMMANDS
-- =====================================================
local function sender()
  while true do
    term.setTextColor(colors.lightBlue); write(CHANNEL .. " > ")
    term.setTextColor(colors.white)
    local input = read()

    if input == "/quit" then
      ws.close()
      systemLine("Bye.", colors.gray)
      return

    elseif input == "/help" then
      showHelp()

    elseif input == "/clear" then
      history = {}
      scrollOffset = 0
      if monitor then redrawMonitor() end
      systemLine("History cleared.", colors.gray)

    elseif input == "/channels" then
      local list = {}
      for ch in pairs(joined) do list[#list+1] = ch end
      systemLine("Channels: " .. table.concat(list, ", "), colors.yellow)

    elseif input == "/logout" then
      if fs.exists(CONFIG_FILE) then fs.delete(CONFIG_FILE) end
      systemLine("Login deleted. Re-enter on next start.", colors.yellow)
      ws.close()
      return

    elseif input:match("^/join ") then
      local ch = "#" .. input:match("^/join (.+)"):gsub("^#", ""):lower()
      if joined[ch] then
        systemLine("Already joined: " .. ch, colors.yellow)
      else
        ws.send("JOIN " .. ch); joined[ch] = true
        systemLine("Joined: " .. ch, colors.lime)
      end

    elseif input:match("^/switch ") then
      local ch = "#" .. input:match("^/switch (.+)"):gsub("^#", ""):lower()
      if not joined[ch] then ws.send("JOIN " .. ch); joined[ch] = true end
      CHANNEL = ch
      systemLine("Now writing to: " .. CHANNEL, colors.lime)

    elseif input ~= "" then
      table.insert(pending, { text = input, channel = CHANNEL })
      ws.send("PRIVMSG " .. CHANNEL .. " :" .. toUTF8(input))
      -- not shown yet; appears once Twitch echoes it back (confirmed delivery)
    end
  end
end

-- =====================================================
--  MONITOR TOUCH (scroll arrows)
--  Requires an Advanced Monitor. Tapping the top-right cell scrolls up,
--  the bottom-right cell scrolls down. Other taps jump to newest.
-- =====================================================
local function touchHandler()
  if not monitor then
    -- nothing to handle; sleep forever so parallel keeps the others running
    while true do os.pullEvent("monitor_touch") end
  end
  while true do
    local _, side, x, y = os.pullEvent("monitor_touch")
    local w, h = monitor.getSize()
    local step = math.max(1, math.floor(h / 2))
    if x >= w then
      -- clicked the arrow column
      if y <= math.floor(h / 2) then
        scrollOffset = scrollOffset + step      -- up = older
      else
        scrollOffset = scrollOffset - step      -- down = newer
      end
      redrawMonitor()
    else
      -- tap anywhere else jumps back to newest
      scrollOffset = 0
      redrawMonitor()
    end
  end
end

parallel.waitForAny(sender, listener, touchHandler)
