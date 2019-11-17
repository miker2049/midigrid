-- [[--
--  cheapskate library for apc, 2 pages
--  contains within itself a full 128 grid table, that can be viewed and played with by changing the two buttons at the bottom of the apc
-- --]]

--start on "page" 1
local apcpage=1

--make the grid buf
local gridbuf={}
for i=1,16 do
  gridbuf[i]={}
  for j=1,8 do
    gridbuf[i][j]=0
  end
end

local apcgrid ={{56,57,58,59,60,61,62,63},
                {48,49,50,51,52,53,54,55},
                {40,41,42,43,44,45,46,47},
                {32,33,34,35,36,37,38,39},
                {24,25,26,27,28,29,30,31},
                {16,17,18,19,20,21,22,23},
                {8,9,10,11,12,13,14,15},
                {0,1,2,3,4,5,6,7}
              }
local auxcol = {82,83,84,85,86,87,88,89}
local auxrow = {64,65,66,67,68,69,70,71}

--set your left right page numbers here...
local leftpage = auxrow[3]
local rightpage = auxrow[4]


--getting the two pages set up
apcnotecoords1={}
apcnotecoords2={}
for i,v in ipairs(apcgrid) do
  for j,k in ipairs(v) do
    apcnotecoords1[k]={j,i}
  end
end

for i,v in ipairs(apcgrid) do
  for j,k in ipairs(v) do
    apcnotecoords2[k]={j+8,i}
  end
end
apcnotecoords = {apcnotecoords1,apcnotecoords2}


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

--initializing
apcnome = midi.connect()

apcnome.ledbuf={}

apcnome.rows = #apcgrid[1]
apcnome.cols = #apcgrid
function apcnome.to_data(msg)
  if msg.type then
    return to_data[msg.type](msg)
  else
    error('failed to serialize midi message')
  end
end


function apcnome:led(x, y, z) 
  gridbuf[x][y]=z
  --if we aint on the right page dont bother
  if x>8 and apcpage==1 then
    return
  end
  if x<8 and apcpage==2 then
    return
  end

  if self.device then
    chan = 1

    if apcpage==1 then
      note = apcgrid[y][x] 
    elseif apcpage==2 then
      note = apcgrid[y][x-8]
    end

    vel = brightness(z)
    if note then
      local data = apcnome.to_data({type="note_on",ch=1,note=note,vel=vel})
      for i,v in ipairs(data) do
        table.insert(self.ledbuf,data[i])
      end
    else
      --debugger
      print("no note found! coordinates....  x:"..x.."  y:"..y.."  z:"..z)
    end
  end
end

-- sure there is more elegant way!
function apcnome.changepage(page)
  -- apcnome:all(0)
  if page==1 then
    for i=1,8 do
      for j=1,8 do
        -- print(gridbuf[i][j])
        apcnome:led(i,j,gridbuf[i][j])
      end
    end
  elseif page==2 then
    for i=9,16 do
      for j=1,8 do
        -- print(gridbuf[i][j])
        apcnome:led(i,j,gridbuf[i][j])
      end
    end
  end
  apcnome:refresh()
end

function apcnome.event(data)
  local parsed = midi.to_msg(data)
  --first, intercept page selectors
  if parsed.note==leftpage and parsed.type=='note_on' and apcpage ~= 1 then
    apcpage=1
    apcnome:send({type="note_on",ch=1,note=auxrow[4],vel=0})
    apcnome:send({type="note_on",ch=1,note=auxrow[3],vel=1})
    apcnome.changepage(apcpage)
  elseif parsed.note==rightpage and parsed.type=='note_on' and apcpage ~= 2  then
    apcpage=2
    apcnome:send({type="note_on",ch=1,note=auxrow[3],vel=0})
    apcnome:send({type="note_on",ch=1,note=auxrow[4],vel=1})
    apcnome.changepage(apcpage)
  elseif parsed.note > -1 and parsed.note < 64 then
    local coords = apcnotecoords[apcpage][parsed.note]
    local x, y
    if coords then
      x, y = coords[1],coords[2] 
      local s = parsed.type =='note_on' and 1 or 0
      apcnome.key(x,y,s)
    else
      local coords = apcnotecoords[apcpage][parsed.note]
      local x, y
      print("missing coords!",x,y,s)
    end
  else
    print("unmapped key")
  end
end

function apcnome:refresh() 
  if self.device then
    self:send(self.ledbuf)
    self.ledbuf={}
  end
end

function apcnome:all(vel)
  vel = brightness(vel)
  if self.device then
    self.ledbuf={}
    for x=1, 16 do
      for y=1, 8 do
        local data
        gridbuf[x][y]=vel
        chan = 1
        if (apcpage==1 and x<9) then
          note = apcgrid[y][x] 
          data =self.to_data({type="note_on",ch=1,note=note,vel=vel})
        elseif (apcpage==2 and x>8) then
          note = apcgrid[y][x-8]
          data =self.to_data({type="note_on",ch=1,note=note,vel=vel})
        end
        if data then
          for i,v in ipairs(data) do
            table.insert(self.ledbuf,data[i])
          end
        end
      end
      -- if this is needed
      -- self:refresh()
    end
  end
end
--init on page 1
apcnome:all(0)
for i=0,126 do
  apcnome:send({type="note_on",ch=1,note=i,vel=0})
end
apcnome:send({type="note_on",ch=1,note=auxrow[3],vel=1})

return apcnome
