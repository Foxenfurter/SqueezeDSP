**SqueezeDSP**

This is a plugin for Squeezebox server which will allow DSP to be run on the server.

**Features**

Processing is designed for mono or Stereo signals and can be configured on a per play basis including disabling DSP for specific players.
Audio formats supported  - includes a custom converstion profile for the following formats: aac, aif, alc, alcx, ape, flc, mov, mp3, mp4, mp4x, mpc, ogg, ogf, ops, spt, wav, wma, wmal, wmap, wvp 

DSD, MQA are not supported

Streaming from Qobuz, Deezer, Tidal, Spotify etc supported.
 
depending upon player output is 24 bit flac or 16 bit wav file

The plugin has been tested on windows 10, pi 3B, docker, Ubuntu via VirtualBox and MacOS via VirtualBox

There are performance limitations on a pi 3B but it can now handle 192k sampling input at under 50% load with no dropouts

Save and Load Presets
Impulse convolution via pre-generated impulse files
clipping meter - which keeps shows an indicator for the last tracks played
Preamp (gain reduction only)
Delay - one channel in ms
Balance
Width (boost apparent stereo width)
Loudness - Volume compensation control
multi-band peaking, High Pass, Low Shelf, High Shelf and Low Pass filter (freq, gain, Q)
visualization of filters

Facility to load in text filters directly from REW & wav FIR filters.

Engine re-written in golang

See WIKI for more info https://github.com/Foxenfurter/SqueezeDSP/wiki
