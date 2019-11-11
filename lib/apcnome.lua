local apcgrid ={{56,57,58,59,60,61,62,63},
                {48,49,50,51,52,53,54,55},
                {40,41,42,43,44,45,46,47},
                {32,33,34,35,36,37,38,39},
                {24,25,26,27,28,29,30,31},
                {16,17,18,19,20,21,22,23},
                {8,9,10,11,12,13,14,15},
                {0,1,2,3,4,5,6,7}
              }
local function toBits(num)
  -- returns a table of bits, least significant first.
  local t={} -- will contain the bits
  while num>0 do
    local rest=math.fmod(num,2)
    t[#t+1]=rest
    num=(num-rest)/2
  end
  return t
end



local function brightness(val)
  --corresponds here to the 4 available states on apc: 0(off), 1(green) , 3(yellow), 5(red)
  if val == 0 then
    return 0
  elseif (val > 0) and (val < 8) then
    return 1
  elseif (val > 7) and (val < 12) then
    return 3
  elseif (val > 11) and (val < 16) then
    return 5
  else
    return 0
  end
end
--these are the keys in the apc to the side of our apcapcnome
--they are up to down, so 82 is the auxkey to row 0
local auxcol = {82,83,84,85,86,87,88,89}
local auxrow = {}--TODO

apcnome = midi.connect()
apcnome.ledbuf={}

--From midi.core...
local to_data = {
  -- FIXME: should all subfields have default values (ie note/vel?)
  note_on = function(msg)
      return {0x90 + (msg.ch or 1) - 1, msg.note, msg.vel or 100}
    end,
  note_off = function(msg)
      return {0x80 + (msg.ch or 1) - 1, msg.note, msg.vel or 100}
    end,
  cc = function(msg)
      return {0xb0 + (msg.ch or 1) - 1, msg.cc, msg.val}
    end,
  pitchbend = function(msg)
      return {0xe0 + (msg.ch or 1) - 1, msg.val & 0x7f, (msg.val >> 7) & 0x7f}
    end,
  key_pressure = function(msg)
      return {0xa0 + (msg.ch or 1) - 1, msg.note, msg.val}
    end,
  channel_pressure = function(msg)
      return {0xd0 + (msg.ch or 1) - 1, msg.val}
    end,
  program_change = function(msg)
      return {0xc0 + (msg.ch or 1) - 1, msg.val}
    end,
  start = function(msg)
      return {0xfa}
    end,
  stop = function(msg)
      return {0xfc}
    end,
  continue = function(msg)
      return {0xfb}
    end,
  clock = function(msg)
      return {0xf8}
    end,
  song_position = function(msg)
      return {0xf2, msg.lsb, msg.msb}
    end,
  song_select = function(msg)
      return {0xf3, msg.val}
    end
}

--- convert msg to data (midi bytes).
-- @tparam table msg : 
-- @treturn table data : table of midi status and data bytes
function apcnome.to_data(msg)
  if msg.type then
    return to_data[msg.type](msg)
  else
    error('failed to serialize midi message')
  end
end

setmetatable(apcnome,{ledbuf={}})
function apcnome.notecoord(note,vel)
  local x = (note%8)+1
  local y = 7 - math.floor(note/8)+1
  return x,y,vel
end

function apcnome:led(x, y, z) 
  -- print("led!")
  if self.device then
    chan = 1
    note = apcgrid[x][y]
    vel = brightness(z)
    -- self:note_on(note,vel,chan)
    local data = apcnome.to_data({type="note_on",ch=1,note=note,vel=vel})
    -- tab.print(data)
    for i,v in ipairs(data) do
      table.insert(self.ledbuf,data[i])
    end
  end
end

function apcnome:refresh() 
  if self.device then
    self:send(self.ledbuf)
    self.ledbuf={}
  end
end
function apcnome:all(vel)
  if self.device then
    self.ledbuf={}
    for x=1, #apcgrid do
      for y=1, #apcgrid[x] do
        chan = 1
        note = apcgrid[x][y]
        vel = brightness(vel)
        local data = apcnome.to_data({type="note_on",ch=1,note=note,vel=vel})
        for i,v in ipairs(data) do
          table.insert(self.ledbuf,data[i])
        end
      end
      -- self:note_on(apcgrid[x][y],brightness(vel),1)
      -- if this is needed
      -- self:refresh()
    end
  end
end
return apcnome
