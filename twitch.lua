-- =====================================================
--  Twitch Chat Client for CC: Tweaked
--  Version 1.0
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

local VERSION = "1.0"

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
  if REPO_USER == "YOUR_GITHUB_USERNAME" then return end -- not configured yet
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
--  UTF-8 HANDLING (CC has no full UTF-8 terminal)
-- =====================================================
local utf8map = {
  ["\195\164"]="ae", ["\195\182"]="oe", ["\195\188"]="ue",
  ["\195\132"]="Ae", ["\195\150"]="Oe", ["\195\156"]="Ue",
  ["\195\159"]="ss",
  ["\226\130\172"]="EUR",
  ["\226\128\153"]="'", ["\226\128\152"]="'",
  ["\226\128\156"]='"', ["\226\128\157"]='"',
  ["\226\128\147"]="-", ["\226\128\148"]="-",
}
local function sanitize(str)
  for seq, repl in pairs(utf8map) do str = str:gsub(seq, repl) end
  str = str:gsub("[\128-\255]", "?")
  return str
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
  return textutils.formatTime(os.time(), true)
end

local function parseColor(tagPart)
  if not tagPart then return nil end
  local hex = tagPart:match("color=(#%x%x%x%x%x%x)")
  if hex then return hexToCC(hex) end
  return nil
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
--  DISPLAY
-- =====================================================
local history = {}
local MAX_HISTORY = 200

local function redrawMonitor()
  if not monitor then return end
  monitor.clear()
  local w, h = monitor.getSize()
  local startLine = math.max(1, #history - h + 1)
  local row = 1
  for i = startLine, #history do
    local line = history[i]
    monitor.setCursorPos(1, row)
    if line.highlight then
      monitor.setBackgroundColor(colors.gray)
    else
      monitor.setBackgroundColor(colors.black)
    end
    monitor.setTextColor(line.color or colors.white)
    monitor.write(line.text:sub(1, w))
    row = row + 1
  end
  monitor.setBackgroundColor(colors.black)
end

local function pushMonitorLine(text, color, highlight)
  table.insert(history, { text = text, color = color or colors.white, highlight = highlight })
  while #history > MAX_HISTORY do table.remove(history, 1) end
  redrawMonitor()
end

-- write the message text to the terminal, coloring emote words
local function writeTerminalText(text)
  for word, sep in text:gmatch("([^%s]+)(%s*)") do
    if emoteSet[word:lower()] then
      term.setTextColor(EMOTE_COLOR)
    else
      term.setTextColor(colors.white)
    end
    write(word)
    term.setTextColor(colors.white)
    if sep ~= "" then write(sep) end
  end
  print("")
end

local function printChatLine(user, text, userColor)
  user = sanitize(user)
  text = sanitize(text)
  userColor = userColor or colorForUser(user)

  local mentioned = text:lower():find(NICK:lower(), 1, true) ~= nil

  -- Terminal
  if mentioned then term.setBackgroundColor(colors.gray) end
  term.setTextColor(colors.lightGray); write("[" .. timestamp() .. "] ")
  term.setTextColor(userColor); write(user)
  term.setTextColor(colors.lightGray); write(": ")
  writeTerminalText(text)
  term.setBackgroundColor(colors.black)

  -- Monitor (single color per line; emotes can't be per-word colored cheaply here)
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
ws.send("CAP REQ :twitch.tv/tags")
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
--  LISTENER (line-by-line, no duplicates)
-- =====================================================
local function handleLine(line)
  if line == "" then return end
  if line:sub(1, 4) == "PING" then
    ws.send("PONG :tmi.twitch.tv")
    return
  end

  local tagPart, rest = line:match("^@([^ ]+) (.+)$")
  if not tagPart then rest = line end

  local userColor = parseColor(tagPart)

  local user, text = rest:match("^:([%w_]+)![^ ]* PRIVMSG [^ ]+ :(.+)")
  if user and text then
    text = text:gsub("[\r\n]", "")
    if user:lower() ~= NICK:lower() then
      printChatLine(user, text, userColor)
    end
  end
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
      if monitor then monitor.clear() end
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
      ws.send("JOIN " .. ch); joined[ch] = true
      systemLine("Joined: " .. ch, colors.lime)

    elseif input:match("^/switch ") then
      local ch = "#" .. input:match("^/switch (.+)"):gsub("^#", ""):lower()
      if not joined[ch] then ws.send("JOIN " .. ch); joined[ch] = true end
      CHANNEL = ch
      systemLine("Now writing to: " .. CHANNEL, colors.lime)

    elseif input ~= "" then
      ws.send("PRIVMSG " .. CHANNEL .. " :" .. input)
      printChatLine(NICK, input, colorForUser(NICK))
    end
  end
end

parallel.waitForAny(sender, listener)
