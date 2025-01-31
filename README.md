**SqueezeDSP**

This is a plugin for Squeezebox server which will allow DSP to be run on the server.

**Features**

Processing is designed for mono or Stereo signals and can be configured on a per play basis including disabling DSP for specific players.
Audio formats supported  - includes a custom converstion profile for the following formats: aac, aif, alc, alcx, ape, flc, mov, mp3, mp4, mp4x, mpc, ogg, ogf, ops, spt, wav, wma, wmal, wmap, wvp 

DSD, MQA are not supported

Streaming from Qobuz works with the limitation that skipping/pausing within a track will cause the player to move onto the next track.
 
depending upon player output is 24 bit flac or 16 bit wav file

The plugin has been tested on windows 10, pi 3B, docker, Ubuntu via VirtualBox and MacOS via VirtualBox

There are performance limitations on a pi 3B with dropouts occurring at 96k sampling and above. 

Save and Load Presets
Impulse convolution via pre-generated impulse files
clipping meter - which keeps shows an indicator for the last tracks played
Preamp (gain reduction only)
Delay - one channel in ms
Balance
Width (boost apparent stereo width)
Loudness - Volume compensation control
multi-band peaking filter (freq, gain, Q)
Seperate filters for High Pass, Low Shelf, High Shelf and Low Pass

Facility to load in text filters directly from REW.

**Planned Changes**

Amend PEQ filters so that the interface is unified - filter type will be a parameter when creating a new filter.
Add in a visualiser
port code to .net core 8 to further reduce binary size and improve performance

**Potential changes**

Gain override - allow gain to be above 0 DB.
Support crossover design
Support multi-channel audio
re-write processor in Rust

See WIKI for more info https://github.com/Foxenfurter/SqueezeDSP/wiki
