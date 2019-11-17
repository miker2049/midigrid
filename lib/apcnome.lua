-- [[--

-- cheapskate lib for getting midi grid devices to behave like monome grid devices 
--   --]]
-- local apcnome ={}
local apcnome= { 
  midi_id = nil
}
local og_dev_add, og_dev_remove

function apcnome.find_midi_device_id()
    local found_id = nil
    for i, dev in pairs(midi.devices) do
        local name = string.lower(dev.name)
        if apcnome.name_matches(name) then
            found_id = dev.id
        end
    end
    return found_id
end

function apcnome.connect(dummy_id)
    apcnome.set_midi_handler()
    return apcnome
end

function apcnome.set_key_handler(key_handler)
    apcnome.set_midi_handler()
    apcnome.key = key_handler
end

function apcnome.setup_connect_handling()
    og_dev_add = midi.add
    og_dev_remove = midi.remove

    midi.add = apcnome.handle_dev_add
    midi.remove = apcnome.handle_dev_remove
end

function apcnome.name_matches(name)
    return (name == 'apc mini')
end

function apcnome.handle_dev_add(id, name, dev)
    og_dev_add(id, name, dev)

    apcnome.update_devices()

    if (apcnome.name_matches(name)) and (id ~= apcnome.midi_id) then
        apcnome.midi_id = id
        apcnome.device = dev
        apcnome.set_midi_handler()
    end
end

function apcnome.handle_dev_remove(id)
    og_dev_remove(id)
    apcnome.update_devices()
end

function apcnome.set_midi_handler()
    if apcnome.midi_id == nil then
        return
    end

    if midi.devices[apcnome.midi_id] ~= nil then
        midi.devices[apcnome.midi_id].event = apcnome.handle_key_midi
        apcnome.device=midi.devices[apcnome.midi_id] 
    else
        apcnome.midi_id = nil
    end
end
function apcnome.cleanup() 
  apcnome.key = nil
end
function apcnome.update_devices() 
  midi.update_devices()

  local new_id = apcnome.find_midi_device_id()

  -- Only set id/handler when helpful
  if (apcnome.midi_id ~= new_id) and (new_id ~= nil) then
    apcnome.midi_id = new_id
    return apcnome.set_midi_handler()
  end

  return (apcnome.midi_id ~= nil)
end
--here we have the 'grid' this looks literally like the grid notes as they are mapped on the apc, they can be changed for other devices
--note though, that a call to this table will look backwards, i.e, to get the visual x=1 and y=2, you have to enter apcgrid[2][1], not the other way around!
local apcgrid ={{56,57,58,59,60,61,62,63},
                {48,49,50,51,52,53,54,55},
                {40,41,42,43,44,45,46,47},
                {32,33,34,35,36,37,38,39},
                {24,25,26,27,28,29,30,31},
                {16,17,18,19,20,21,22,23},
                {8,9,10,11,12,13,14,15},
                {0,1,2,3,4,5,6,7}
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


--here is the connection
-- apcnome = midi.connect()
--here is our ledbuf to buffer data just like a real grid
apcnome.ledbuf={}
apcnome.rows = #apcgrid[1]
apcnome.cols = #apcgrid

function apcnome.handle_key_midi(event)
  -- tab.print(event)
  local note = event[2]
  local coords = apcnotecoords[note]
  local x, y
  if coords then
    x, y = coords[1],coords[2] 
    print(x,y)
    -- local s = parsed.type =='note_on' and 1 or 0
    local s = event[1] ==0x90 and 1 or 0
    if apcnome.key ~= nil then 
      -- apcnome.key(apcnome.midi_id, y, x, s)
      apcnome.key(x, y, s)
    end
  else
    print("missing coords!")
  end
end

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
    note = ((x<9 and x>0) and (y<9 and y>0)) and apcgrid[y][x] or null 
    vel = brightness(z)
    if note then
      -- local data = apcnome.to_data({type="note_on",ch=1,note=note,vel=vel})
      table.insert(self.ledbuf,0x90)
      table.insert(self.ledbuf,note)
      table.insert(self.ledbuf,vel)
    else
      --debugger, probably want to comment this out if you are being messyy
      print("no note found! coordinates....  x:"..x.."  y:"..y.."  z:"..z)
    end
  end
end


--sending our buff
function apcnome:refresh() 
  if self.device then
    -- self:send(self.ledbuf)
    midi.devices[apcnome.midi_id]:send(self.ledbuf)
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
        table.insert(self.ledbuf,0x90)
        table.insert(self.ledbuf,note)
        table.insert(self.ledbuf,vel)
      end
      -- it is unclear to me sometimes if a call to all in a regular grid requires a subsequent refresh, have this here in case
      -- self:refresh()
    end
  end
end

apcnome.setup_connect_handling()
apcnome.update_devices()
return apcnome
