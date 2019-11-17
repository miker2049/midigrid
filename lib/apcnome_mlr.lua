-- [[--
-- cheapskate lib for getting midi grid devices to behave like monome grid devices 
--   --]]


--here we have the 'grid' this looks literally like the grid notes as they are mapped on the apc, they can be changed for other devices
--note though, that a call to this table will look backwards, i.e, to get the visual x=1 and y=2, you have to enter apcgrid[2][1], not the other way around!
-- local apcgrid ={{56,57,58,59,60,61,62,63},
--                 {48,49,50,51,52,53,54,55},
--                 {40,41,42,43,44,45,46,47},
--                 {32,33,34,35,36,37,38,39},
--                 {24,25,26,27,28,29,30,31},
--                 {16,17,18,19,20,21,22,23},
--                 {8,9,10,11,12,13,14,15},
--                 {0,1,2,3,4,5,6,7}
--               }
local auxrow = {64,65,66,67,68,69,70,71}
local apcgrid =
{
  {64,65,66,nil,67,68,69,70,nil,nil,nil,nil,nil,nil,71,98},
  {56,57,58,59,60,61,62,63,48,49,50,51,52,53,54,55},
  {40,41,42,43,44,45,46,47,32,33,34,35,36,37,38,39},
  {24,25,26,27,28,29,30,31,16,17,18,19,20,21,22,23},
  {8,9,10,11,12,13,14,15,0,1,2,3,4,5,6,7},
  {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
  {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
  {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil}
}
--here, using the grid above, we generate the table to help us go the other way around
--so, if you press a midi note and you wanna know what it is, this will have an index with our coordinates
local apcnotecoords={}

for i,v in ipairs(apcgrid) do
  for j,k in ipairs(v) do
    apcnotecoords[k]={j,i}
  end
end


--here, the function expects a brightness val and spits out another val so your midi controller can understand, these values are generally great for apc with most scripts, but will also need to be adjusted for other controllers!
--corresponds here to the 4 available states on apc: 0(off), 1(green) , 3(yellow), 5(red)
local function brightness(val)
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
--these are the keys in the apc to the sides of our apc, not necessary for strict grid emulation but handy!
--they are up to down, so 82 is the auxkey to row 1
local auxcol = {82,83,84,85,86,87,88,89}
--left to right, 64 is aux key to column 1
local auxrow = {64,65,66,67,68,69,70,71}

--here is midi helper functions I have in here directly... could probably just call them from the midi class but feels better to have them in here
--From midi.core...
local to_data = {
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

--here is the connection
apcnome = midi.connect()
--here is our ledbuf to buffer data just like a real grid
apcnome.ledbuf={}
apcnome.rows = #apcgrid
apcnome.cols = #apcgrid[1]

function apcnome.to_data(msg)
  if msg.type then
    return to_data[msg.type](msg)
  else
    error('failed to serialize midi message')
  end
end

function apcnome:led(x, y, z) 
  if self.device then
    chan = 1
    --flag reversed here because thats actually what it is in lua table!!!, see above. this is clearer either way I think
    note = apcgrid[y][x]
    vel = brightness(z)
    if note then
      local data = apcnome.to_data({type="note_on",ch=1,note=note,vel=vel})
      for i,v in ipairs(data) do
        table.insert(self.ledbuf,data[i])
      end
    else
      --debugger, probably want to comment this out if you are being messyy
      print("no note found! coordinates....  x:"..x.."  y:"..y.."  z:"..z)
    end
  end
end

--kinda the hackiest part, need to separate it out from other midi events
function apcnome.event(data)
  local parsed = midi.to_msg(data)
  local coords = apcnotecoords[parsed.note]
  local x, y
  if coords then
    x, y = coords[1],coords[2] 
    local s = parsed.type =='note_on' and 1 or 0
    apcnome.key(x,y,s)
  else
    print("missing coords!")
  end
end

--sending our buff
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
      -- it is unclear to me sometimes if a call to all in a regular grid requires a subsequent refresh, have this here in case
      -- self:refresh()
    end
  end
end
--adjustments for mlr

return apcnome
