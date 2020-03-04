local device = include('midigrid/devices/launchpad')
--local device2 = include('midigrid/devices/launchpad')

--device.midi_id = 2
--device2.midi_id = 1

device:_reset()
--device2:_reset()

for i = 1,8 do
  device:_update_led(i,4,i-1)
  --device2:_update_led(i,4,i-1)
end
for i = 1,8 do
  device:_update_led(i,5,i+7)
  --device2:_update_led(i,5,i+7)
end

device:_update_led(1,1,15)
--device2:_update_led(2,1,15)
 