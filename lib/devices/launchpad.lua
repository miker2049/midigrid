local launchpad = include('midigrid/lib/devices/generic_device')

launchpad.grid_notes= {
  {  0,  1,  2,  3,  4,  5,  6,  7,  8 },
  { 16, 17, 18, 19, 20, 21, 22, 23,  24},
  { 32, 33, 34, 35, 36, 37, 38, 39,  40},
  { 48, 49, 50, 51, 52, 53, 54, 55,  56},
  { 64, 65, 66, 67, 68, 69, 70, 71,  72},
  { 80, 81, 82, 83, 84, 85, 86, 87,  88},
  { 96, 97, 98, 99,100,101,102,103,  104},
  {112,113,114,115,116,117,118,119,  120}
}

launchpad.width = 9

-- Original - Sets clear and copy bits!?!
--launchpad.brightness_map = {0,28,28,60,60,60,29,29,29,62,62,63,63,13,13,15}

--[[ Valid Launchpad colours based on bits 0..1 Red, 4..5 Green
id  color 
0, 16, 32, 48 - Full Green
1, 17, 33, 49 
2, 18, 34, 50
3, 19, 35, 51 - Full Orange
]]--
-- Tropical
launchpad.brightness_map = {0,16,16,32,32,48,48,49,49,33,33,50,50,34,34,51}
-- Sunrise
--launchpad.brightness_map = {0,16,16,32,32,48,48,49,49,50,50,33,33,51,2,3}
-- Rainbow
--launchpad.brightness_map = {0, 16, 32, 48, 1, 17, 33, 49, 2, 18, 34, 50, 3, 19, 35, 51}

launchpad.reset_device_msg = { 0xB0, 0x00, 0x00 }

launchpad.quad_leds = { CC = {108,109,110,111} }

launchpad.cc_event_handlers = {}
launchpad.cc_event_handlers[108] = function(self,val) self:change_quad(1) end
launchpad.cc_event_handlers[109] = function(self,val) self:change_quad(2) end
launchpad.cc_event_handlers[110] = function(self,val) self:change_quad(3) end
launchpad.cc_event_handlers[111] = function(self,val) self:change_quad(4) end

-- TODO move back to generic device?
function launchpad:cc_handler(vgrid,midi_msg)
  if self.cc_event_handlers[midi_msg.cc] then
    self.cc_event_handlers[midi_msg.cc](self,midi_msg.val)
  else
    print('Unhandled CC '.. midi_msg.cc)
  end
end

launchpad.device_name = 'launchpad'

return launchpad