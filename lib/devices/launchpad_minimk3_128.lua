local launchpad = include('midigrid/lib/devices/launchpad_minimk3')

launchpad.grid_notes= {
  {88,78,68,58,48,38,28,18},
  {87,77,67,57,47,37,27,17},
  {86,76,66,56,46,36,26,16},
  {85,75,65,55,45,35,25,15},
  {84,74,64,54,44,34,24,14},
  {83,73,63,53,43,33,23,13},
  {82,72,62,52,42,32,22,12},
  {81,71,61,51,41,31,21,11}
}

launchpad.device_name = 'launchpad_minimk3_128'

return launchpad
