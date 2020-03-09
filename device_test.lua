local device = include('midigrid/lib/devices/launchpad')
--local device2 = include('midigrid/devices/launchpad')

--device.midi_id = 2
--device2.midi_id = 1

device:_reset()
--device2:_reset()

device:_send_cc(108,4)
device:_send_cc(109,8)
device:_send_cc(110,12)
device:_send_cc(111,16)

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
 