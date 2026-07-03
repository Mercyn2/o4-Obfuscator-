-- add prints color :)
local colors = {
  reset = "\27[0m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  magenta = "\27[35m",
  cyan = "\27[36m",
  white = "\27[37m",
  brightRed = "\27[91m",
  brightGreen = "\27[92m",
  brightYellow = "\27[93m",
  brightBlue = "\27[94m",
  brightMagenta = "\27[95m",
  brightCyan = "\27[96m",
  brightWhite = "\27[97m",
}

local function colorize(text, color)
  return colors[color] .. text .. colors.reset
end

local l = {}
function l:info(m)
  print(colorize("[INFO] ", "green") .. m)
end

function l:warn(m)
  print(colorize("[WARN] ", "yellow") .. m)
end

function l:error(m)
  error(colorize("[ERROR] ", "red") .. m, 2)
end

return l
