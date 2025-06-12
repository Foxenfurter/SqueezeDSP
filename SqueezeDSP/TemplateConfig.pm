=pod
 Moved config settings to own file so as to be easier to manage
 
=cut

sub get_config_revision
{
	my $configrevision = "0.1.09";
	return $configrevision;
}

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

sub template_WAV16
{
	return <<'EOF1';

aac flc * $CLIENTID$
	# IF
	[faad] -q -w -f 2 $FILE$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM  --Clientid="$CLIENTID$" --bitsout=16

aif flc * $CLIENTID$
	# IF
	[$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

alc flc * $CLIENTID$
# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=-r %d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=16 | [sox] -q -t wav - -t wav -C 0 $RESAMPLE$ -

alcx flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1$START$ $END$ $FILE$  | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=16

ape flc * $CLIENTID$
	# F
	[mac] $FILE$ - -d | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16 

flc flc * $CLIENTID$
	# IFT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -dcs --force-raw-format --endian=little --sign=signed $START$ $END$ -- $FILE$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM  --Clientid="$CLIENTID$" --bitsout=16-ignore-chunk-sizes -

mov flc * $CLIENTID$
	# FR
	[mov123] $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16 
	
mp3 flc * $CLIENTID$
	# IF
	[lame] --mp3input --decode --silent $FILE$ - | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=16

mp4 flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=16

mp4x flc  * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=16

mpc flc * $CLIENTID$
	# IR
	[mppdec] --silent --prev --gain 3 - - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16 

ogg flc * $CLIENTID$
	# IFRD:{RESAMPLE=-r %D}
	[sox] -t ogg $FILE$ -t wav $RESAMPLE$ - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16 

ogf flc * $CLIENTID$
	# IFR
	[flac] --ogg -dcs --force-raw-format --endian=little --sign=signed  -- $FILE$ | [$CONVAPP$]  [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$	--formatin=PCM  --Clientid="$CLIENTID$" --bitsout=16 

ops flc * $CLIENTID$
	# IFB:{BITRATE=--abr %B}D:{RESAMPLE=--resample %D}
	[sox] -q -t opus $FILE$ -t wav - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16 

spt flc * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $URL$ --bitrate 320 --disable-discovery --disable-audio-cache $START$  | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM  --Clientid="$CLIENTID$" --bitsout=16

wav flc * $CLIENTID$
	# IF
	[$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=16 

wma flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] $PATH$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM --Clientid="$CLIENTID$" --bitsout=16
	
wmal flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] $PATH$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM --Clientid="$CLIENTID$" --bitsout=16 
	
wmap flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wmadec] $PATH$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM --Clientid="$CLIENTID$" --bitsout=16 


wvp flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16 


EOF1
}


sub template_FLAC24
{
	return <<'EOF1';

aac flc * $CLIENTID$
	# IF
	[faad] -q -w -f 2 $FILE$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs --totally-silent --compression-level-0 --ignore-chunk-sizes -

aif flc * $CLIENTID$
	# IF
	[$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent -

alc flc * $CLIENTID$
# FT:{START=-j %s}U:{END=-e %u}D:{RESAMPLE=-r %d}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=24 | [sox] -q -t wav - -t flac -C 0 $RESAMPLE$ -

alcx flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

ape flc * $CLIENTID$
	# F
	[mac] $FILE$ - -d | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

flc flc * $CLIENTID$
	# IFT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -dcs --force-raw-format --endian=little --sign=signed $START$ $END$ -- $FILE$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent --ignore-chunk-sizes -

mov flc * $CLIENTID$
	# FR
	[mov123] $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -
	
mp3 flc * $CLIENTID$
	# IF
	[lame] --mp3input --decode --silent $FILE$ - | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent -

mp4 flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

mp4x flc  * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  | [$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

mpc flc * $CLIENTID$
	# IR
	[mppdec] --silent --prev --gain 3 - - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

ogg flc * $CLIENTID$
	# IFRD:{RESAMPLE=-r %D}
	[sox] -t ogg $FILE$ -t wav $RESAMPLE$ - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

ogf flc * $CLIENTID$
	# IFR
	[flac] --ogg -dcs --force-raw-format --endian=little --sign=signed  -- $FILE$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM  --Clientid="$CLIENTID$"  --bitsout=24  | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

ops flc * $CLIENTID$
	# IFB:{BITRATE=--abr %B}D:{RESAMPLE=--resample %D}
	[sox] -q -t opus $FILE$ -t wav - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

spt flc * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $URL$ --bitrate 320 --disable-discovery --disable-audio-cache $START$  | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$ --formatin=PCM  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent -

wav flc * $CLIENTID$
	# IF
	[$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

wma flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] $PATH$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent -
	
wmal flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] $PATH$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -
	
wmap flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wmadec] $PATH$ | [$CONVAPP$] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --channels=$CHANNELS$ --formatin=PCM --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -


wvp flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -



EOF1
}
1
;