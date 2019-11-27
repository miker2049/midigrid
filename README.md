

# norns midigrid library

A few helper scripts for emulating and using midi grids like a monome grid, on the monome norns.

Two scripts in the lib folder to include in scripts as 'grid', config files in the config folder for setups with different devices.


<a id="org23244c6"></a>

## instructions
Install by downloading this repo into your dust scripts folder, and calling the library like regular norns libraries, i.e, `include('midigrid/lib/midigrid')`.  

`midigrid.lua` and `apcmini_config.lua` is documented in the scripts themselves, setting up a new config file also means it needs to be loaded into the script itself:
```lua
-----------------------------
--loading up config file here
-----------------------------
local config = include('midigrid/config/apcmini_config')
-- local config = include('midigrid/config/launchpad_config')
-- local config = include('midigrid/config/untz_config')
-----------------------------
```
Then, in whatever script you are working in, it works well to override the global grid object with our own local one:
```lua
--adding this to script
local grid = include('cheapskate/lib/midigrid')
--or this
local grid = include('cheapskate/lib/midigrid_2pages')
--which allows this call to work with our midi grid
local g = grid.connect()
```
Previous issues with the midi device being blocked are resolved with this new implementation taken from ryanlaws [lunchpaid](https://github.com/ryanlaws/lunchpaid).

If a script expects incoming midi, **you need to set your midi device to a slot other than 1.**

Finally, each config file has a `device_name` parameter that may need to be adjusted for different versions of launchpad.  Check what the name of the device is on norns and adjust accordingly.  

<a id="orgb475cd5"></a>

## two page mode

This script aims to emulate a 128 (16x8) grid by spreading a virtual grid buffer over two grid pages that you can toggle with auxiliary buttons


<a id="orgd95a7df"></a>

### apc mini

By default, the left and right arrow buttons on the bottom row of buttons on the grid


<a id="org8d9d20c"></a>

### launchpad

The toggle buttons are the top two column buttons in launchpad auxiliary column.  need to set them up so they can be the left and right arrows but this is non trivial as the top auxiliary buttons on the launchpad send control (176) messages not note on.

## todos

### TODO key aliasing feature, to use auxiliary keys in different ways per script
<a id="org2979fc0"></a>

### TODO add config files for launchpad (and untz maybe)


<a id="orgfb9e746"></a>

### TODO allow config files to overide led and all functions, for more native launchpad support


<a id="org75aa3b0"></a>

### DONE add cols and rows function


<a id="org04ac368"></a>

### DONE make page changing more efficient code wise


<a id="org3b00ee5"></a>

### DONE consider how to make this more sensible with the midi device number thing&#x2026;


<a id="org23362ea"></a>

## scripts

Notes for norns scripts that either work or I wanna make work, or need a little love to make work
all have only been tested on the apc mini


<a id="orgd1a7656"></a>

### step

works, need to block out midi


<a id="org4a0b355"></a>

### strum

works but with midi blocking


<a id="org1077a0a"></a>

### mlr64

[mlr64](https://github.com/noiserock/custom64)
works!


<a id="org1065623"></a>

### earthsea for apc mini

1.  this is pretty much ready to go, use the earthsea from the ash library

    its glitchy and not sure why
    working but glitchy?


<a id="org563c70e"></a>

### vials for apc mini

1.  I think this can be implemented as just split view toggle

    if view2 then {new mapping}

2.  status

    works pretty great two pages


<a id="org4f0d50f"></a>

### meadowphysics, this is one to look at

1.  basic mode is simple, just subtract by half

2.  Reset, Output, and Speeds

    this just needs a speed interface&#x2026;
    if (config)

3.  if rules then choose with encoder


<a id="org2780522"></a>

### strides

this one should be easy too, the second half of the grid is just pulled up from an alt key


<a id="orgd9cade2"></a>

### shfts

a toggle button for the two views


<a id="orgfc45182"></a>

### cranes

this is split in two, but horizontally, so going to need to be a little more sophisticated in the mapping


<a id="org617fd29"></a>

### ekombi

just make it half as precise


<a id="org462156d"></a>

### takt

maybe just a two pager?


<a id="org42b704d"></a>

### foulplay

only 64 ready to go!


<a id="org42e7176"></a>

### zellen

good to go with rows and cols, and adjusting led values


<a id="org7827ad6"></a>

### isoseq

just the max pattern length needs to change

