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

--local midigrid = include('midigrid/lib/base')
local supported_devices = include('midigrid/lib/supported_devices')
local vgrid = include('midigrid/lib/vgrid')

local midigrid = {
  vgrid = vgrid,
  core_grid = grid,
  core_midi_add = nil,
  core_midi_remove = nil,

}

function midigrid.init(layout)
  vgrid.init(layout)
end

function midigrid._find_midigrid_devices()
  local found_device = nil
  local mounted_devices = {}

  for _, dev in pairs(midi.devices) do
    found_device = supported_devices.find_midi_device_type(dev)
    if found_device then mounted_devices[found_device.id] = found_device end
  end

  return mounted_devices
end

function midi_grid._load_midi_devices(midi_devices)
  local connected_devices = {}
  for midi_id,midi_device_type in pairs(midi_devices) do
    local device = include('midigrid/devices/'..midi_device_type)
    device.midi_id = id
    connected_devices[id] = device
  end
  return connected_devices
end

function midigrid.connect(dummy_id)
  if midigrid.vgrid == nil then
    -- User is calling connect without calling init, default to 64 button layout
    midigrid.vgrid = vgrid.init('64')
  end

  local midi_devices = midigrid._find_midigrid_devices()

  -- If no midi devices found
  if #midi_devices == 0 then
       print('No supported device found')
       -- Make midigrid transparent if no devices found and return the core grid connect()
       return midigrid.core_grid.connect()
  end

  local connected_devices = midi_grid._load_midi_devices(midi_devices)
  vgrid.attach_devices(connected_devices)

  midigrid.setup_connect_handling()

  return midigrid
end

function midigrid.setup_connect_handling()
    midigrid.core_midi_add = midi.add
    midigrid.core_midi_remove = midi.remove
    midi.add = midigrid._handle_dev_add
    midi.remove = midigrid._handle_dev_remove
end

function midigrid._handle_dev_add(id, name, dev)
    midigrid.core_midi_add(id, name, dev)
    -- midigrid.update_devices()
end

function midigrid._handle_dev_remove(id)
    midigrid.core_midi_remove(id)
    -- midigrid.update_devices()
end

function midigrid.update_devices()
    --WTF does this do?
    midi.update_devices()
end

return midigrid
