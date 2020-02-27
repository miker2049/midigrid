local supported_devices = {
  midi_devices = {
    {  midi_base_name: 'launchpad',        device_type:'launchpad' },
    {  midi_base_name: 'launchpad mini',   device_type:'launchpad' },
    {  midi_base_name: 'launchpad mini 2', device_type:'launchpad' }, --TODO remove once proper multi device implemented below
-- Currently implemnted
    {  midi_base_name: 'apcmini',          device_type:'apcmini' },   --TODO implement!
    {  midi_base_name: 'launchpad mk2'      device_type:'launchpadmk2' },--TODO implement!
    {  midi_base_name: 'launchpad pro 2'      device_type:'launchpadpro2' },--TODO implement!
--[[ known devices to be implemented, help required!
    {  midi_base_name: 'launchpad mk3'      device_type:'launchpadmk3' },
    {  midi_base_name: 'livid block'      device_type:'livid_block' },
]]--
  }
}

function supported_devices.find_midi_device_type(midi_device)
  local sysex_ident_resp = nil
  -- TODO get response to sysex indentify call
  local matched_device_type = nil
  for _,device_def in pairs(supported_devices.midi_devices) do
    if sysex_ident_resp and device_def.sysex_ident then
      --TODO use General Sysex ident call to try and ID device
    end
    -- Fall back to midi name matching
    -- TODO strip / ignore device name suffix for multiple devices
    if (device_def.midi_base_name == string.lower(midi_device.name)) then return device_def.device_type end
  end
  return nil
end
