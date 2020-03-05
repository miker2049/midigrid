local device={
  --here we have the 'grid' this looks literally like the grid notes as they are mapped on the apc, they can be changed for other devices
  --note though, that a call to this table will look backwards, i.e, to get the visual x=1 and y=2, you have to enter midigrid[2][1], not the other way around!
  grid_notes= {
    {56,57,58,59,60,61,62,63},
    {48,49,50,51,52,53,54,55},
    {40,41,42,43,44,45,46,47},
    {32,33,34,35,36,37,38,39},
    {24,25,26,27,28,29,30,31},
    {16,17,18,19,20,21,22,23},
    { 8, 9,10,11,12,13,14,15},
    { 0, 1, 2, 3, 4, 5, 6, 7}
  },
  note_to_grid_lookup = {}, -- Intentionally left empty 
  width=8,
  height=8,
  
  midi_id = 1,
  refresh_counter = 0,
  
  -- This MUST contain 15 values that corospond to brightness. these can be strings or tables if you midi send handler requires (e.g. RGB)
  brightness_map = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15},
  
  --these are the keys in the apc to the sides of our apc, not necessary for strict grid emulation but handy!
  --they are up to down, so 82 is the auxkey to row 1
  auxcol = {82,83,84,85,86,87,88,89},
  --left to right, 64 is aux key to column 1
  auxrow = {64,65,66,67,68,69,70,71},

  -- the currently displayed quad on the device
  current_quad = 1,
  -- here we set the buttons to use when switching quads in multi-quad mode
  upper_left_quad_button = 66,
  upper_right_quad_button = 67,
  
  force_full_refresh = false,

  device_name = 'generic'
}

--function expects grid brightness from 0-15 and converts in so your midi controller can understand, 
-- these values need to be adjusted for your controller!
function device:brightness_handler(val)
  -- remember tables start at 1, but brightness starts at 0
  return self.brightness_map[val+1]
end

function device:update_aux()
  --TODO: Aux Rows / Cols
end

function device:change_quad(quad)
    self.current_quad = quad
    self.force_full_refresh = true
end

function device._reset(self)
  if self.reset_device_msg then
    midi.devices[self.midi_id]:send(self.reset_device_msg)
  else
    --TODO: Reset all leds on device
  end
end

function device._update_led(self,x,y,z)
  local vel = self.brightness_map[z+1]
  local note = self.grid_notes[y][x]
  local midi_msg = {0x90,note,vel}
  midi.devices[self.midi_id]:send(midi_msg)
end

function device.event(self,vgrid,event)
  -- type="note_on", note, vel, ch
  -- Note that midi msg already translates note on vel 0 to note off type
  local midi_msg = midi.to_msg(event)
  
  -- Debug incomming midi messages
  -- tab.print(midi_msg)

  -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
  -- device-dependent. Reject cc "notes" here.
  if (midi_msg.type == 'note_on' or midi_msg.type == 'note_off') then
    local key = self.note_to_grid_lookup[midi_msg.note]
    if key then
      local key_state = (midi_msg.type == 'note_on') and 1 or 0
      self._key_callback(self.current_quad,key['x'],key['y'],key_state)
    else
      print("Unhandled midi note: " .. midi_msg.note)
    end
  elseif (midi_msg.type == 'cc') then
    
    if (self.cc_handler) then 
      self:cc_handler(vgrid,midi_msg) 
    else
      -- unhandled CC msg, please leave commented, devices with rotatry encoders or pots output a lot of CC messages.
      --print('Unhandled CC '.. midi_msg.cc)
    end
  end
end
  
device._key_callback = function() print('no vgrid event handle callback attached!') end

function device:refresh(vgrid)
  local quad = vgrid.quads[self.current_quad]
  if self.refresh_counter > 9 then
    self.force_full_refresh = true
    self.refresh_counter = 0
  end
  if self.force_full_refresh then
    quad.each_with(quad,self,self._update_led)
    self.force_full_refresh = false
  else
    quad.updates_with(quad,self,self._update_led)
    self.refresh_counter=self.refresh_counter+1
  end
  --TODO Quads can be displayed on multiple devices 
  quad:reset_updates()
  --TODO: update "Mirrored" rows / cols
  self:update_aux()
end

function device:create_rev_lookups()
  for col = 1,self.height do
    for row = 1,self.width do
      self.note_to_grid_lookup[self.grid_notes[col][row]] = {x=row,y=col}
    end
  end
end

return device
