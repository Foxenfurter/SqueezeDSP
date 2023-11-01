=pod
 Moved config settings to own file so as to be easier to manage
 
=cut

sub get_config_revision
{
	my $configrevision = "0.0.10";
	return $configrevision;
}


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

sub template_WAV16
{
	return <<'EOF1';
aac wav * $CLIENTID$
	# IF
	[faad] -q -w -f 1 $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

aif wav * $CLIENTID$
	# IF
	[sox] -t aiff $FILE$ -t wav - | [$CONVAPP$] --id="$CLIENTID$" --input=$FILE$ --skip=$START$ --be=true --wav=true --d=16

alc wav * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

alcx wav * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16


ape wav * $CLIENTID$
	# F
	[mac] $FILE$ - -d | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

flc wav * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -dcs $START$ $END$ -- $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

mov wav * $CLIENTID$
	# FR
	[mov123] $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --be=true --d=16

mp3 wav * $CLIENTID$
	# IFD:{RESAMPLE=--resample %D}
	[sox] -t mp3 $FILE$ -t wav $RESAMPLE$ - | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

mp4 wav * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

mp4x wav * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=16 

mpc wav * $CLIENTID$
	# IR
	[mppdec] --silent --prev --gain 3 - - | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

ogg wav * $CLIENTID$
	# IFD:{RESAMPLE=-r %D}
	[sox] -t ogg $FILE$ -t wav $RESAMPLE$ - | [$CONVAPP$] --id="$CLIENTID$" --be=true --d=16

ogf wav *  $CLIENTID$
	# IFRD:{RESAMPLE=-r %d}
	[flac] --ogg -dcs -- $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

spt wav * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $URL$ --bitrate 320 --disable-discovery --disable-audio-cache $START$ | [SqueezeDSP] --id=$CLIENTID$ --wav=false --r=44100 --wavo=true --d=16

wav wav * $CLIENTID$
	# FT:{START=-skip %t}
	[$CONVAPP$] --id="$CLIENTID$" --input=$FILE$ --skip=$START$ --wav=true --d=16

wma wav * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$] -id="$CLIENTID$" --d=16

wvp wav * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - | [$CONVAPP$] --id="$CLIENTID$" --wav=true --d=16

EOF1
}


sub template_FLAC24
{
	return <<'EOF1';
aac flc * $CLIENTID$
	# IFB:{BITRATE=--abr %B}
	[faad] -q -w -f 1 $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -

aif flc * $CLIENTID$
	# IFT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -cs --totally-silent $START$ $END$ -- $FILE$ | [sox] -q -t flac - -t wav - | [$CONVAPP$]  --id="$CLIENTID$" --wav=true --wavo=true --d=24| [flac] -cs -0 --totally-silent -


alc flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

alcx flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -


ape flc * $CLIENTID$
	# F
	[mac] $FILE$ - -d | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -

flc flc * $CLIENTID$
	# FRIT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -dcs --totally-silent $START$ $END$ -- $FILE$ |  [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24| [flac] -cs -0 --totally-silent -

mov flc * $CLIENTID$
	# FR
	[mov123] $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --be=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -

mp3 flc * $CLIENTID$
	# IFD:{RESAMPLE=--resample %D}
	[sox] -t mp3 $FILE$ -t wav $RESAMPLE$ - | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -

mp4 flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

mp4x flc  * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$  | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

mpc flc * $CLIENTID$
	# IR
	[mppdec] --silent --prev --gain 3 - - | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -

ogg flc * $CLIENTID$
	# IFRD:{RESAMPLE=-r %D}
	[sox] -t ogg $FILE$ -t wav $RESAMPLE$ - | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -


ogf flc *  $CLIENTID$
	# IFRD:{RESAMPLE=-r %d}
	[flac] --ogg -dcs -- $FILE$ |  [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24|  [sox] -q --ignore-length -t wav - -t flac -C 0 $RESAMPLE$ -


ops flc * $CLIENTID$
	# IFB:{BITRATE=--abr %B}D:{RESAMPLE=--resample %D}
	[sox] -q -t opus $FILE$ -t wav - | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -

spt flc * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $URL$ --bitrate 320 --disable-discovery --disable-audio-cache  $START$ | [SqueezeDSP] --id=$CLIENTID$ --wav=false --r=44100 --wavo=true --d=24 | [flac] -cs -0 --totally-silent --ignore-chunk-sizes -

wav flc * $CLIENTID$
	# FT:{START=-skip %t}
	[$CONVAPP$] --id="$CLIENTID$" --input=$FILE$ --skip=$START$ --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -

wma flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24| [flac] -cs -0 --totally-silent -
	
wmal flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -
	
wmap flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wmadec] -w $PATH$ | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -


wvp flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - | [$CONVAPP$] --id="$CLIENTID$" --wav=true --wavo=true --d=24 | [flac] -cs -0 --totally-silent -


EOF1
}
1
;