local launchpad={
  --here we have the 'grid' this looks literally like the grid notes as they are mapped on the apc, they can be changed for other devices
  --note though, that a call to this table will look backwards, i.e, to get the visual x=1 and y=2, you have to enter midigrid[2][1], not the other way around!
  grid_notes= {
    { 0, 1, 2, 3, 4, 5, 6, 7},
    {16,17,18,19,20,21,22,23},
    {32,33,34,35,36,37,38,39},
    {48,49,50,51,52,53,54,55},
    {64,65,66,67,68,69,70,71},
    {80,81,82,83,84,85,86,87},
    {96,97,98,99,100,101,102,103},
    {112,113,114,115,116,117,118,119}
  },
  --here, the function expects a brightness_handler val and spits out another val so your midi controller can understand, these values are generally great for apc with most scripts, but will also need to be adjusted for other controllers!
  --corresponds here to the launchpad led settings found in the manual
  brightness_handler = function (val)
    if val == 0 then
      return 0
    elseif (val > 0) and (val < 3) then --0-2
      --low green
      return 28
    elseif (val > 2) and (val < 6) then --3-5
      --full green
      return 60
    elseif (val > 5) and (val < 8) then --6--7
      --full yellow
      return 62
    elseif (val > 7) and (val < 11) then--8-10
      --low amber
      return 29
    elseif (val > 10) and (val < 13) then--11-12
      --full amber
      return 63
    elseif (val > 12) and (val < 15) then--13-14
      --low red
      return 13
    elseif (val > 14) and (val < 17) then--15-16
      --full red
      return 15
    else
      return 0
    end
  end,

  --these are the keys in the apc to the sides of our apc, not necessary for strict grid emulation but handy!
  --they are up to down, so 8 is the auxkey to row 1
  auxcol = {8,24,40,56,72,88,104,120},
  --need to impletement launchpad row, they are 176 messages instead, which messes stuff up right now
  auxrow = {},

  -- here is setting the left and right page buttons for two page mode
  leftpage_button=8,
  rightpage_button=24,

  device_name='launchpad'
  -- device_name='launchpad mini'
}

return launchpad
