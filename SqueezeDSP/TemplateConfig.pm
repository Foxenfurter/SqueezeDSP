=pod
 Moved config settings to own file so as to be easier to manage
 
=cut

sub get_config_revision
{
	my $configrevision = "0.1.05";
	return $configrevision;
}

sub template_WAV16
{
	return <<'EOF1';
aac wav * $CLIENTID$
	# IF
	[faad] -q -w -f 1 $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

aif wav * $CLIENTID$
	# FT:{START=-skip %t}
	[$CONVAPP$] -id "$CLIENTID$" -input $FILE$ $START$ -be -wav -d 16

alc wav * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

amb wav * $CLIENTID$
	# IFT:{START=-skip %t}
	[$CONVAPP$] -id "$CLIENTID$" -input $FILE$ $START$ -amb -d 16

ape wav * $CLIENTID$
	# F
	[mac] $FILE$ - -d | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

flc wav * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -dcs $START$ $END$ -- $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

mov wav * $CLIENTID$
	# FR
	[mov123] $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -be -d 16

mp3 wav * $CLIENTID$
	# IFD:{RESAMPLE=--resample %D}
	[lame] --mp3input --decode $RESAMPLE$ --silent $FILE$ - - | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

mp4 wav * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

mpc wav * $CLIENTID$
	# IR
	[mppdec] --silent --prev --gain 3 - - | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

ogg wav * $CLIENTID$
	# IFD:{RESAMPLE=-r %D}
	[sox] -t ogg $FILE$ -t wav $RESAMPLE$ -w - | [$CONVAPP$] -id "$CLIENTID$" -be -d 16

spt flc * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $FILE$ --disable-discovery --disable-audio-cache $START$ | [sox]  -q -t raw -b 16 -e signed -c 2 -r 44.1k -L - -t wav  - | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

uhj wav * $CLIENTID$
	# FT:{START=-skip %t}
	[$CONVAPP$] -id "$CLIENTID$" -input $FILE$ $START$ -wav -d 16

wav wav * $CLIENTID$
	# FT:{START=-skip %t}
	[$CONVAPP$] -id "$CLIENTID$" -input $FILE$ $START$ -wav -d 16

wma wav * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$] -id "$CLIENTID$" -d 16

wvp wav * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - | [$CONVAPP$] -id "$CLIENTID$" -wav -d 16

EOF1
}


# transcode for 24-bit FLAC output (sb2, sb3, transporter)
# aac & mp4 added by jb
# deleted aap entry - jb
# replaced alc - jb
# added spt (spotty) (jb)
# changed FLAC compressions level to 0 (was 5)
sub template_FLAC24
{
	return <<'EOF1';
aac flc * $CLIENTID$
	# IF
	[faad] -q -w -f 1 $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

aif flc * $CLIENTID$
	# FT:{START=-skip %t}
	[$CONVAPP$] -id "$CLIENTID$" -input $FILE$ $START$ -be -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

alc flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

amb flc * $CLIENTID$
	# IFT:{START=-skip %t}
	[$CONVAPP$] -id "$CLIENTID$" -input $FILE$ $START$ -amb -wavo -d 24 | [flac] -cs -0 --totally-silent -

ape flc * $CLIENTID$
	# F
	[mac] $FILE$ - -d | [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

flc flc * $CLIENTID$
	# FRIT:{START=--skip=%t}U:{END=--until=%v}
	[flac] -dcs --totally-silent $START$ $END$ -- $FILE$ |  [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

mov flc * $CLIENTID$
	# FR
	[mov123] $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -be -wavo -d 24 | [flac] -cs -0 --totally-silent -

mp3 flc * $CLIENTID$
	# IFD:{RESAMPLE=--resample %D}
	[lame] --mp3input --decode $RESAMPLE$ --silent $FILE$ - - | [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

mp4 flc * $CLIENTID$
	# FT:{START=-j %s}U:{END=-e %u}
	[faad] -q -w -f 1 $START$ $END$ $FILE$ | [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs --totally-silent -0 --ignore-chunk-sizes -

mpc flc * $CLIENTID$
	# IR
	[mppdec] --silent --prev --gain 3 - - | [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

ogg flc * $CLIENTID$
	# IFD:{RESAMPLE=-r %D}
	[sox] -t ogg $FILE$ -t wav $RESAMPLE$ -w - | [$CONVAPP$] -id "$CLIENTID$" -be -wavo -d 24 | [flac] -cs -0 --totally-silent -

spt flc * $CLIENTID$
	# RT:{START=--start-position %s}
	[spotty] -n Squeezebox -c "$CACHE$" --single-track $FILE$ --disable-discovery --disable-audio-cache $START$ | [sox]  -q -t raw -b 16 -e signed -c 2 -r 44.1k -L - -t wav  - | [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs -0 --totally-silent --ignore-chunk-sizes -

uhj flc * $CLIENTID$
	# FT:{START=-skip %t}
	[$CONVAPP$] -id "$CLIENTID$" -input $FILE$ $START$ -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

wav flc * $CLIENTID$
	# FT:{START=-skip %t}
	[$CONVAPP$] -id "$CLIENTID$" -input $FILE$ $START$ -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

wma flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$] -id "$CLIENTID$" -wavo -d 24 | [flac] -cs -0 --totally-silent -
	
wmal flc * $CLIENTID$
	# F:{PATH=%f}R:{PATH=%F}
	[wmadec] -w $PATH$ | [$CONVAPP$] -id "$CLIENTID$" -wavo -d 24 | [flac] -cs -0 --totally-silent -
	

wvp flc * $CLIENTID$
	# FT:{START=--skip=%t}U:{END=--until=%v}
	[wvunpack] $FILE$ -wq $START$ $END$ -o - | [$CONVAPP$] -id "$CLIENTID$" -wav -wavo -d 24 | [flac] -cs -0 --totally-silent -

EOF1
}
1
;