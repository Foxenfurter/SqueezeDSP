package Plugins::SqueezeDSP::TemplateConfig;
=pod
 Moved config settings to own file so as to be easier to manage
 
=cut

sub get_config_revision
{
	my $configrevision = "0.2.01";
	return $configrevision;
}

# 0.2.01 Amended all settings to use new SqueezeDSP adapter Eliminated wav16 replace with MP3
# 0.1.11 corrected ogf line which had duplicate convolver app.
# 0.1.10 added hls flc and wav
# 1.0.9 alc format is sensitive to where the parameters are for faad, standardised for all faad based transcoding
# 1.0.8 Change to mp3 as raw format caused chipmunk chatter on talkSport, issue with wmadec decoding addressed
# 1.0.7 Correction to mp4 and mp4x, alc, alcx formats
# 1.0.6 Correction to ogf format
# 1.0.5 major tidy up. SqueezeDSP can handle raw pcm and aif properly now so no need for intermediate Sox process. fixed some typos and formatting errors too, mainly on 16 bit.
# 1.0.4 one off beta fix
# 1.03 fix for pausing Qobuz
# transcode for 24-bit FLAC output (sb2, sb3, transporter)
# aac & mp4 added by jb
# deleted aap entry - jb
# replaced alc - jb
# added spt (spotty) (jb)
# changed FLAC compressions level to 0 (was 5)
# v.05 amended flac to FRIT - needed change to DSP to handle error when track skipping
# amended Ogg-flc, wasn't playing, but now working. amended aac to make it more standard, no diff noted however
# amended aif file, now playing (bit of a long path); added mp4x and alcx
# v.07 added in mapping for ogf and corrected spt wav mapiing for 16 bit
# v.08 aif not being used in preference to default, change command header
# v.09 amended settings for Spotty, use URL not FILE fixed bit rate and removed reliance on SoX for PCM to Wav conversion
# v.10 amended settings for mp3, use sox instead of lame as problem with skipping within a track.
# v.11 amended settings for aif, use sox instead of flac for 24 bit, wasn't working and brings it into line with 16 bit.

sub template_MP3
{
	return <<'EOF1';

aac mp3 * $CLIENTID$
	# IFD:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 2 $FILE$ |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3

aif mp3 * $CLIENTID$
	# IFD:{RESAMPLE=--maxSampleRate=%d}
	 [$CONVAPP$] --input $FILE$ --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3 

alc mp3 * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3

alcx mp3 * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  |  [$CONVAPP$]  --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3

ape mp3 * $CLIENTID$
	# FD:{RESAMPLE=--maxSampleRate=%d}
	[mac] $FILE$ - -d |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3

dsf mp3 * $CLIENTID$
	# FT:{START=-ss %s}U:{END=-to %u}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$  $END$ -ar 384000 -f wav - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3 

dff mp3 * $CLIENTID$
	# FT:{START=-ss %s}U:{END=-to %u}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$ $END$ -ar 384000 -f wav - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3 

flc mp3 * $CLIENTID$
	# IFT:{START=--skip=%t}U:{END=--until=%v}D:{RESAMPLE=--maxSampleRate=%d}
	[flac] -dcs --force-raw-format --endian=little --sign=signed $START$ $END$ -- $FILE$ |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ --Clientid="$CLIENTID$" $RESAMPLE$ --bitsout=24 --formatout=MP3

hls mp3 * $CLIENTID$
	# RB:{BITRATE=-B %B}T:{START=-ss %s}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet  -i $FILE$ -f s24le - |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM  --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

mov mp3 * $CLIENTID$
	# FRD:{RESAMPLE=--maxSampleRate=%d}
	[mov123] $FILE$ |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3

mp3 mp3 * $CLIENTID$
	# IF
	[lame] --mp3input --decode --silent $FILE$ - |  [$CONVAPP$] --trackURL=$URL$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

mp4 mp3 * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

mp4x mp3  * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

mpc mp3 * $CLIENTID$
	# IRD:{RESAMPLE=--maxSampleRate=%d}
	[mppdec] --silent --prev --gain 3 - - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

ogg mp3 * $CLIENTID$
	# IFRD:{RESAMPLE=--maxSampleRate=%d}
	[sox] -t ogg $FILE$ -t wav  - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

ogf mp3 * $CLIENTID$
	# IFRD:{RESAMPLE=--maxSampleRate=%d}
	[flac] --ogg -dcs --force-raw-format --endian=little --sign=signed  -- $FILE$ |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

ops mp3 * $CLIENTID$
	# IFB:{BITRATE=--abr %B}D:{RESAMPLE=--maxSampleRate=%d}
	[sox] -q -t opus $FILE$ -t wav - |  [$CONVAPP$]  --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

spt mp3 * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $URL$ --bitrate 320 --disable-discovery --disable-audio-cache $START$  |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM  --trackURL=$URL$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3

wav mp3 * $CLIENTID$
	# IFD:{RESAMPLE=--maxSampleRate=%d}
	 [$CONVAPP$] --input $FILE$ --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3 

wma mp3 * $CLIENTID$
	# FT:{START=-ss %t}U:{END=-to %v}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$ $END$ -f s24le - |  [$CONVAPP$] --bitsin=24 --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3

wmal mp3 * $CLIENTID$
	# FT:{START=-ss %t}U:{END=-to %v}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$ $END$ -f s24le - |  [$CONVAPP$] --bitsin=24 --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3

wmap mp3 * $CLIENTID$
	# FT:{START=-ss %t}U:{END=-to %v}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$ $END$ -f s24le - |  [$CONVAPP$] --bitsin=24 --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=MP3

wvp mp3 * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}D:{RESAMPLE=--maxSampleRate=%d}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=MP3


EOF1
}


sub template_FLAC24
{
	return <<'EOF1';

aac flc * $CLIENTID$
	# IFD:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 2 $FILE$ |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

aif flc * $CLIENTID$
	# IFD:{RESAMPLE=--maxSampleRate=%d}
	 [$CONVAPP$] --input $FILE$ --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

alc flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ |  [$CONVAPP$]  --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

alcx flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ |  [$CONVAPP$]  --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

ape flc * $CLIENTID$
	# FD:{RESAMPLE=--maxSampleRate=%d}
	[mac] $FILE$ - -d |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

dsf flc * $CLIENTID$
	# FT:{START=-ss %s}U:{END=-to %u}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$  $END$ -ar 384000 -f wav - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

dff flc * $CLIENTID$
	# FT:{START=-ss %s}U:{END=-to %u}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$ $END$ -ar 384000 -f wav - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

flc flc * $CLIENTID$
	# IFT:{START=--skip=%t}U:{END=--until=%v}D:{RESAMPLE=--maxSampleRate=%d}
	[flac] -dcs --force-raw-format --endian=little --sign=signed $START$ $END$ -- $FILE$ |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ --Clientid="$CLIENTID$" $RESAMPLE$ --bitsout=24 --formatout=FLC

hls flc * $CLIENTID$
	# RB:{BITRATE=-B %B}T:{START=-ss %s}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet  -i $FILE$ -f s24le - |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM  --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

mov flc * $CLIENTID$
	# FRD:{RESAMPLE=--maxSampleRate=%d}
	[mov123] $FILE$ |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

mp3 flc * $CLIENTID$
	# IF
	[lame] --mp3input --decode --silent $FILE$ - |  [$CONVAPP$] --trackURL=$URL$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

mp4 flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

mp4x flc  * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=--maxSampleRate=%d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$  --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

mpc flc * $CLIENTID$
	# IRD:{RESAMPLE=--maxSampleRate=%d}
	[mppdec] --silent --prev --gain 3 - - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

ogg flc * $CLIENTID$
	# IFRD:{RESAMPLE=--maxSampleRate=%d}
	[sox] -t ogg $FILE$ -t wav - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

ogf flc * $CLIENTID$
	# IFRD:{RESAMPLE=--maxSampleRate=%d}
	[flac] --ogg -dcs --force-raw-format --endian=little --sign=signed  -- $FILE$ |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

ops flc * $CLIENTID$
	# IFB:{BITRATE=--abr %B}D:{RESAMPLE=--maxSampleRate=%d}
	[sox] -q -t opus $FILE$ -t wav - |  [$CONVAPP$]  --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

spt flc * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $URL$ --bitrate 320 --disable-discovery --disable-audio-cache $START$  |  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM  --trackURL=$URL$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC

wav flc * $CLIENTID$
	# IFD:{RESAMPLE=--maxSampleRate=%d}
	 [$CONVAPP$] --input $FILE$ --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC 

wma flc * $CLIENTID$
	# FT:{START=-ss %t}U:{END=-to %v}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$ $END$ -f s24le - |  [$CONVAPP$] --bitsin=24 --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

wmal flc * $CLIENTID$
	# FT:{START=-ss %t}U:{END=-to %v}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$ $END$ -f s24le - |  [$CONVAPP$] --bitsin=24 --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC

wmap flc * $CLIENTID$
	# FT:{START=-ss %t}U:{END=-to %v}D:{RESAMPLE=--maxSampleRate=%d}
	[ffmpeg] -loglevel quiet $START$ -i $FILE$ $END$ -f s24le - |  [$CONVAPP$] --bitsin=24 --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$" --bitsout=24 --formatout=FLC


wvp flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}D:{RESAMPLE=--maxSampleRate=%d}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - |  [$CONVAPP$] --trackURL=$URL$ $RESAMPLE$ --Clientid="$CLIENTID$"  --bitsout=24 --formatout=FLC



EOF1
}
1
;