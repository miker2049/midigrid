--[[ cheapskate lib for getting midi grid devices to behave like monome grid devices
     two things are run before returning, `setup_connect_handling()` and `update_devices()`.
     `setup_connect_handling()` copies over 'og' midi "add" and "remove" callbacks, and
     provides its own add and remove handlers, i.e. the call backs for:
       - `midi.add()`
       - `midi.remove()`
       - `midi.update_devices()`
     `find_midi_device_id()` iterates through `midi.devices` to see if the name matches, then
     returns `id`, this system manages its own ids, which is why you have to initialize it and
     why first, you connect to it (`midigrid.connect()`), which returns a midigrid object and
     does `set_midi_handler()`
]]

local midigrid = include('midigrid/lib/base')
local vgrid = include('midigrid/lib/vgrid')

function midigrid.init(layout)
 local midi_devices = midigrid._find_midigrid_devices() or 'none'
  
  -- If no midi devices found
  if #midi_devices == 0 then
      print('No supported device found')
      -- Return the core grid ??
      -- return midigrid.core_grid
      return
  end
  
  vgrid.init(layout)
  vgrid.attach_devices(midi_devices)
end

return midigrid