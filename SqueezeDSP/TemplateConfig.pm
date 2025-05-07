=pod
 Moved config settings to own file so as to be easier to manage
 
=cut

sub get_config_revision
{
	my $configrevision = "0.1.03";
	return $configrevision;
}

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

aac wav * $CLIENNTID$
	# IF
	[faad] -q -w -f 1 $FILE$ | [sox] -q --ignore-length -t wav - -t wav - | [$CONVAPP$] --Clientid="$CLIENTID$"  --bitsout=16

aif wav * $CLIENNTID$
	# IF
	[sox] -t aiff $FILE$ -t wav - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

alc wav * $CLIENNTID$
	# IFT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

alcx wav * $CLIENNTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

ape wav * $CLIENNTID$
	# F
	[mac] $FILE$ - -d | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

flc wav * $CLIENNTID$
	# IFT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -dcs --force-raw-format --endian=little --sign=signed $START$ $END$ -- $FILE$ | [sox] -r $SAMPLERATE$ -b  $SAMPLESIZE$ -e signed-integer -c $CHANNELS$ --endian little  -t raw - -t wav - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

mov wav * $CLIENNTID$
	# FR
	[mov123] $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16
	
mp3 wav * $CLIENNTID$
	# IF
	[lame] --mp3input --decode -t --silent $FILE$ - | [SqueezeDSP] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$	--formatin=PCM  --Clientid="$CLIENTID$" --bitsout=16

mp4 wav * $CLIENNTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

mp4x flc  * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

mpc wav * $CLIENNTID$
	# IR
	[mppdec] --silent --prev --gain 3 - - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

ogg wav * $CLIENNTID$
	# IFRD:{RESAMPLE=-r %D}
	[sox] -t ogg $FILE$ -t wav $RESAMPLE$ - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

ogf flc * $CLIENTID$
	# IFRD:{RESAMPLE=-r %d}
	[flac] --ogg -dcs -- $FILE$ | [sox] -q --ignore-length -t wav - -t wav -C 0 $RESAMPLE$ - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16  

ops wav * $CLIENNTID$
	# IFB:{BITRATE=--abr %B}D:{RESAMPLE=--resample %D}
	[sox] -q -t opus $FILE$ -t wav - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16

spt wav * $CLIENNTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $URL$ --bitrate 320 --disable-discovery --disable-audio-cache $START$  | [$CONVAPP$] --Clientid="$CLIENTID$" --formatin=PCM  --samplerate=44100 --bitsin=16  --channels=2 --bitsout=16

wav wav * $CLIENNTID$
	# IFT:{START=-skip %t}
	[$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=16

wma wav * $CLIENNTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=16
	
wmal wav * $CLIENNTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -
	
wmap wav * $CLIENNTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wmadec] -w $PATH$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -


wvp wav * $CLIENNTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

EOF1
}


sub template_FLAC24
{
	return <<'EOF1';

aac flc * $CLIENTID$
	# IF
	[faad] -q -w -f 1 $FILE$ | [sox] -q --ignore-length -t wav - -t wav - | [$CONVAPP$] --Clientid="$CLIENTID$"  --bitsout=24 | [flac] -cs --totally-silent --compression-level-0 --ignore-chunk-sizes -

aif flc * $CLIENTID$
	# IF
	[sox] -t aiff $FILE$ -t wav - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent -

alc flc * $CLIENTID$
	# IFT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

alcx flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

ape flc * $CLIENTID$
	# F
	[mac] $FILE$ - -d | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

flc flc * $CLIENTID$
	# IFT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -dcs --force-raw-format --endian=little --sign=signed $START$ $END$ -- $FILE$ | [sox] -r $SAMPLERATE$ -b  $SAMPLESIZE$ -e signed-integer -c $CHANNELS$ --endian little  -t raw - -t wav - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent -

mov flc * $CLIENTID$
	# FR
	[mov123] $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -
	
mp3 flc * $CLIENTID$
	# IF
	[lame] --mp3input --decode -t --silent $FILE$ - | [SqueezeDSP] --bitsin=$SAMPLESIZE$ --samplerate=$SAMPLERATE$ --be=false --channels=$CHANNELS$	--formatin=PCM  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent -

mp4 flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

mp4x flc  * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

mpc flc * $CLIENTID$
	# IR
	[mppdec] --silent --prev --gain 3 - - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

ogg flc * $CLIENTID$
	# IFRD:{RESAMPLE=-r %D}
	[sox] -t ogg $FILE$ -t wav $RESAMPLE$ - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

ogf flc * $CLIENTID$
	# IFRD:{RESAMPLE=-r %d}
	[flac] --ogg -dcs -- $FILE$ | [sox] -q --ignore-length -t wav - -t wav -C 0 $RESAMPLE$ - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

ops flc * $CLIENTID$
	# IFB:{BITRATE=--abr %B}D:{RESAMPLE=--resample %D}
	[sox] -q -t opus $FILE$ -t wav - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

spt flc * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $URL$ --bitrate 320 --disable-discovery --disable-audio-cache $START$  | [sox] -r $SAMPLERATE$ -b  $SAMPLESIZE$ -e signed-integer -c $CHANNELS$ --endian little  -t raw - -t wav - | [$CONVAPP$] --Clientid="$CLIENTID$" |  [flac] -cs -0 --totally-silent -

wav flc * $CLIENTID$
	# IFT:{START=-skip %t}
	[$CONVAPP$] --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -

wma flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24 | [flac] -cs -0 --totally-silent -
	
wmal flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -
	
wmap flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wmadec] -w $PATH$ | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -


wvp flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - | [$CONVAPP$]  --Clientid="$CLIENTID$" --bitsout=24  | [flac] -cs -0 --totally-silent -


EOF1
}
1
;