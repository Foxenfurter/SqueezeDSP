package Plugins::SqueezeDSP::DspManager;

# Relocate all preferences here if possible
# ------ preferences ------

# For easy access, our preferences are written to one file per client,
# in the plugin data directory; file is named by the client ID.
# These files are written immediately a pref is set (so the app can respond fast).
#
# NOTE: the files we write are ONLY read by the convolver app, not by this plugin;
# the plugin UI will always take precedence over any manual edits.
use strict;
use Plugins::SqueezeDSP::Plugin;

use base qw(Slim::Plugin::Base);
use Slim::Utils::Misc;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use base qw(Slim::Web::Settings);

use Plugins::SqueezeDSP::Plugin;
use Plugins::SqueezeDSP::Settings;

my $thistag = "squeezedsp";
my $thisapp = "SqueezeDSP";

my $log = logger('plugin.' . $thistag);
my $prefs = preferences('plugin.' . $thistag);
my $plugin;


my $modeAdjust       = "PLUGIN.SqueezeDSP.Adjust";
my $modeValue        = "PLUGIN.SqueezeDSP.Value";
my $modePresets      = "PLUGIN.SqueezeDSP.Presets";
my $modeSettings     = "PLUGIN.SqueezeDSP.Settings";
my $modeEqualization = "PLUGIN.SqueezeDSP.Equalization";
my $modeRoomCorr     = "PLUGIN.SqueezeDSP.RoomCorrection";
my $modeMatrix       = "PLUGIN.SqueezeDSP.Matrix";
my $modeSigGen       = "PLUGIN.SqueezeDSP.SignalGenerator";
my $modeAmbisonic    = "PLUGIN.SqueezeDSP.Ambisonic";

# these sort alphabetically
my $BALANCEKEY = 'B';   # balance (left/right amplitude alignment)
my $WIDTHKEY = 'W';     # width   (mid/side amplitude alignment)
my $SKEWKEY = 'S';      # skew    (left/right time alignment, under "settings")
my $DEPTHKEY = 'D';     # depth   (matrix filter time alignment, under "settings")
my $QUIETNESSKEY = 'L';
my $FLATNESSKEY = 'F';
my $SETTINGSKEY = "-s-";
my $PRESETSKEY = "-p-";
my $ERRORKEY = "-";
my $AMBANGLEKEY = "X1";
my $AMBDIRECTKEY = "X2";
my $AMBJWKEY = "X3";
my $AMBROTATEZKEY = "XR1";
my $AMBROTATEYKEY = "XR2";
my $AMBROTATEXKEY = "XR3";

# ------ equalization channel stuff ------


# The Bark scale: 0, 100, 200, 300, 400, 510, 630, 770, 920, 1080, 1270, 1480, 1720, 2000, 2320, 2700, 3150, 3700, 4400, 5300, 6400, 7700, 9500, 12000, 15500
# Or there are lots of choices for octave scales, although they maybe have less-than-optimal resolution in high mids:
#  a440      55    110  220  440   880  1760  3520  7040  14080
#  or ISO    62.5  125  250  500  1000  2000  4000  8000  16000     (notice the quaintly round numbers)
#  or,       60    120  240  480   960  1920  3840  7680  15360     (we use this one, for no particular reason)
# (of course the octaves could be subdivided to 1/3 (classic 31-band EQ) or 2/3 (15-band EQ), but that just seems silly here)
#
# The choices here are
#      2-band:  bass        (0)       treble
#      3-band:  bass        mid       treble
#      5-band:   1     2     3     4     5
#      9-band:   1  2  3  4  5  6  7  8  9
# For 2-band EQ we approximate the classic Baxandall tone control by assuming "mid" is fixed at 0dB.
# For higher numbers of bands, each band level is individually adjustable. Interpolation should use cosine shelves.
#

# Lists of center frequencies for each mode
my @fq1 = ( 960 );
my @fq2 = ( 60, 15360 );
my @fq3 = ( 60, 960, 15360 );
my @fq5 = ( 60, 240, 960, 3840, 15360 );
my @fq9 = ( 60, 120, 240, 480, 960, 1920, 3840, 7680, 15360 );
# 15 and 31 for good measure - NOT the standard centers though
my @fq15 = ( 25, 40, 63, 100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300, 10000, 16000 );
my @fq31 = ( 20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000, 20000 );

my $settingstag = "SqueezeDSPSettings";
my $thistag = 'squeezedsp' ; #Plugins::SqueezeDSP::Plugin->getthistag();
my $prefs = preferences('plugin.' . $thistag);
my $revision ;

sub setmyRevision
{
	$revision = shift;		
}

#Let's add some defaults

sub defaultPrefs
{
	my $client = shift;
	my $p;
	$p = 'ambtype';                         setPref( $client, $p, "UHJ" ) unless getPref( $client, $p );
	$p = 'bands';                           setBandCount( $client, 2 )  unless getPref( $client, $p );
	$p = 'band' . $QUIETNESSKEY . 'value';  setPref( $client, $p, 0 )   unless getPref( $client, $p );
	$p = 'band' . $FLATNESSKEY . 'value';   setPref( $client, $p, 10 )  unless getPref( $client, $p );
	$p = 'band' . $WIDTHKEY . 'value';      setPref( $client, $p, 0 )   unless getPref( $client, $p );
	$p = 'band' . $BALANCEKEY . 'value';    setPref( $client, $p, 0 )   unless getPref( $client, $p );
	$p = 'band' . $SKEWKEY . 'value';       setPref( $client, $p, 0 )   unless getPref( $client, $p );
#	$p = 'band' . $DEPTHKEY . 'value';      setPref( $client, $p, 0 )   unless getPref( $client, $p );
	$p = 'band' . $AMBANGLEKEY . 'value';   setPref( $client, $p, 90 )  unless getPref( $client, $p );
	$p = 'band' . $AMBDIRECTKEY . 'value';  setPref( $client, $p, 0.6 ) unless getPref( $client, $p );
	$p = 'band' . $AMBJWKEY . 'value';      setPref( $client, $p, 0 )   unless getPref( $client, $p );
	$p = 'band' . $AMBROTATEZKEY . 'value'; setPref( $client, $p, 0 )   unless getPref( $client, $p );
	$p = 'band' . $AMBROTATEYKEY . 'value'; setPref( $client, $p, 0 )   unless getPref( $client, $p );
	$p = 'band' . $AMBROTATEXKEY . 'value'; setPref( $client, $p, 0 )   unless getPref( $client, $p );
}
my $log = Slim::Utils::Log->addLogCategory({ 'category' => 'plugin.' . $thistag, 'defaultLevel' => 'WARN', 'description'  => $thistag });
sub debug
{
	my $txt = shift;
	#$log->info( $thisapp .": " . $txt . "\n");
	#Putting an error here for easier debug
	$log->error( "DSPManager: " .  $txt . "\n" );
}


# Format a value (bass level -> "+3dB", etc)
sub valuelabel
{
	my $client = shift;
	my $item = shift;
	my $valu = shift;
	my $labl = ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_DECIBELS' );
	my $sign = ( $valu > 0 ) ? '+' : '';
	my $extra = ( $valu == 0 ) ? ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_EQ_FLAT' ) : '';
	if( $item eq $QUIETNESSKEY )
	{
		$sign = '';
		$labl = '';
		$extra = ( $valu == 0 ) ? ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_QUIETNESS_OFF' ) : '';
	}
	elsif( $item eq $FLATNESSKEY )
	{
		$sign = '';
		$labl = '';
		$extra = ( $valu == 10 ) ? ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_FLATNESS_FLAT' ) : '';
	}
	elsif( ($item eq $SKEWKEY) || ($item eq $DEPTHKEY) )
	{
		$labl = ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_SAMPLES' );
		$extra = '';
	}
	elsif( ($item eq $AMBANGLEKEY) || ($item eq $AMBROTATEZKEY) || ($item eq $AMBROTATEYKEY) || ($item eq $AMBROTATEXKEY) )
	{
		$sign = '';
		$labl = ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_DEGREES' );
		$extra = '';
	}
	elsif( $item eq $AMBDIRECTKEY )
	{
		$sign = '';
		$labl = '';
		# hypercardioid is 0.3333 (1/3)
		# supercardioid is 0.5773 (sqrt3/3)
		if( $valu==0 )    { $extra = ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_AMBI_DIRECT_FIGURE8' ); }
		if( $valu==0.33 ) { $extra = ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_AMBI_DIRECT_HYPERCARDIOID' ); }
		if( $valu==0.58 ) { $extra = ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_AMBI_DIRECT_SUPERCARDIOID' ); }
		if( $valu==1 )    { $extra = ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_AMBI_DIRECT_CARDIOID' ); }
	}
	elsif( $item eq $AMBJWKEY )
	{
		$sign = '';
		$labl = '';
		$extra = '';
	}
	return $sign . $valu . $labl . $extra;
}

# Format a frequency/band
sub freqlabel
{
	my $client = shift;
	my $item = shift;
	my $bandcount = getPref( $client, 'bands' );
	my $freq = getPref( $client, 'b' . $item . 'freq' ) || defaultFreq( $client, $item, $bandcount );
	my $labl = undef;
	if( $item =~ /^\d*$/ )
	{
		if( $bandcount==2 )
		{
			my @v = ( 'PLUGIN_SQUEEZEDSP_BASS', 'PLUGIN_SQUEEZEDSP_TREBLE' );
			$labl = $client->string( $v[$item] );
		}
		elsif( $bandcount==3 )
		{
			my @v = ( 'PLUGIN_SQUEEZEDSP_BASS', 'PLUGIN_SQUEEZEDSP_MID', 'PLUGIN_SQUEEZEDSP_TREBLE' );
			$labl = $client->string( $v[$item] );
		}
		else
		{
			if( $freq > 1000 )
			{
				$labl = ( int( $freq / 100 ) / 10 ) . ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_KILOHERTZ' );
			}
			else
			{
				$labl = int( $freq ) . ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_HERTZ' );
			}
		}
	}
	return $labl;
}

sub defaultFreq
{
	my $client = shift;
	my $item = shift;
	my $bandcount = shift || getPref( $client, 'bands' );
	my @bandfreqs = defaultFreqs( $client, $bandcount );
	return $bandfreqs[$item];
}

sub defaultFreqs
{
	my $client = shift;
	my $bandcount = shift || getPref( $client, 'bands' ) || 2;
	my @bandfreqs = @fq2;
	if( $bandcount==2 )
	{
		@bandfreqs = @fq2;
	}
	elsif( $bandcount==3 )
	{
		@bandfreqs = @fq3;
	}
	elsif( $bandcount==5 )
	{
		@bandfreqs = @fq5;
	}
	elsif( $bandcount==9 )
	{
		@bandfreqs = @fq9;
	}
	elsif( $bandcount==15 )
	{
		@bandfreqs = @fq15;
	}
	elsif( $bandcount==31 )
	{
		@bandfreqs = @fq31;
	}
	else
	{
		# Some silly number of bands.
		# Divide up the range from 60 to 15360 anyway.  TBD
	}
	return @bandfreqs;
}



sub getPrefFile
{
	my $client = shift;
	my $settingsDir = getpluginSettingsDataDir();
	return catdir( $settingsDir, join('_', split(/:/, $client->id())) . '.settings.conf' );
}


sub getPref
{
	my ( $client, $prefName ) = @_;
	debug ("getpref ".$prefName. " for client " );
	return $prefs->client( $client )->get( $prefName );
}

sub setPref
{
	my ( $client, $prefName, $prefValue ) = @_;
	my $prev = $prefs->client( $client )->get( $prefName );
	$prefs->client( $client )->set( $prefName, $prefValue );

	unless( $prefValue eq $prev )
	{
		debug( "setPref " . $prefName . "=" . $prefValue );

		unless( $prefName eq 'mainmenu' || $prefName eq 'settingsmenu' || $prefName eq 'equalizationmenu' )
		{
			# write to {client}.settings.conf (as XML, for easy consumption by the convolver)
			my $file = getPrefFile( $client );
			savePrefs( $client, $file );
		}
	}
}

sub delPref
{
	my ( $client, $prefName ) = @_;
	$prefs->client( $client )->remove( $prefName ) if $prefs->client( $client )->exists( $prefName );
}

sub savePrefs
{
	my $client = shift;
	my $file = shift;
	my ( $vol, $dir, $fil ) = splitpath( $file );
	debug( "savePrefs " . $fil );
	open( OUT, ">$file" ) or  do { oops( $client, undef, "Preferences could not be saved to $file." ); return 0; };
	print OUT "<?xml version=\"1.0\"?>\n";
	print OUT "<$settingstag Revision=\"" . $revision . "\">\n";
	print OUT "  <Client ID=\"" . $client->id() . "\">\n";
	#print OUT "  <Client ID=\"" . $client->id() . "\" PlayerName=\"" . $client->name . "\">\n";
	print OUT "    <AmbisonicDecode " . AmbisonicAttributes( $client ) . " />\n";
	print OUT "    <SignalGenerator " . SigGenAttributes( $client ) . " />\n";
	print OUT "    <Matrix>" . Slim::Utils::Unicode::utf8encode( getPref( $client, 'matrix' ) || '' ) . "</Matrix>\n";
	print OUT "    <Width>" . ( getPref( $client, 'band' . $WIDTHKEY . 'value' ) || 0 ) . "</Width>\n";
	print OUT "    <Balance>" . ( getPref( $client, 'band' . $BALANCEKEY . 'value' ) || 0 ) . "</Balance>\n";
	print OUT "    <Skew>" . ( getPref( $client, 'band' . $SKEWKEY . 'value' ) || 0 ) . "</Skew>\n";
#	print OUT "    <Depth>" . ( getPref( $client, 'band' . $DEPTHKEY . 'value' ) || 0 ) . "</Depth>\n";
	print OUT "    <Filter>" . Slim::Utils::Unicode::utf8encode( getPref( $client, 'filter' ) || '' ) . "</Filter>\n";
	my $bandcount = getPref( $client, 'bands' );
	print OUT "    <EQ Bands=\"" . $bandcount . "\">\n";
	for( my $n = 0; $n < $bandcount; $n++ )
	{
		my $f = getPref( $client, 'b' . $n . 'freq' ) || defaultFreq( $client, $n, $bandcount );
		my $v = getPref( $client, 'b' . $n . 'value' ) || 0;
		print OUT "      <Band Freq=\"" . $f . "\">" . $v . "</Band>\n";
	}
	print OUT "    </EQ>\n";
	print OUT "    <Quietness>" . ( getPref( $client, 'band' . $QUIETNESSKEY . 'value' ) || 0 ) . "</Quietness>\n";
	my $fl = getPref( $client, 'band' . $FLATNESSKEY . 'value' );
	print OUT "    <Flatness>" . ( defined($fl) ? $fl : 10 ) . "</Flatness>\n";
	print OUT "  </Client>\n";
	print OUT "</$settingstag>\n";
	close( OUT );
	return 1;
}

sub loadPrefs
{
	my ( $client, $file, $desc ) = @_;
	debug( "loadPrefs " . $file );
	unless( -f $file )
	{
		oops( $client, $desc, "File $file not found." );
		return;
	}
	my $xml = new XML::Simple( suppressempty => '' );
	my $doc = $xml->XMLin( $file );

	setPref( $client, 'preset', $file );
	setPref( $client, 'siggen', $doc->{Client}->{SignalGenerator} );
	setPref( $client, 'ambtype', $doc->{Client}->{AmbisonicDecode}->{Type} );
	setPref( $client, 'band' . $AMBANGLEKEY . 'value',  $doc->{Client}->{AmbisonicDecode}->{Angle} );
	setPref( $client, 'band' . $AMBDIRECTKEY . 'value', $doc->{Client}->{AmbisonicDecode}->{Cardioid} );
	setPref( $client, 'band' . $AMBJWKEY . 'value', $doc->{Client}->{AmbisonicDecode}->{jW} );
	setPref( $client, 'band' . $AMBROTATEZKEY . 'value', $doc->{Client}->{AmbisonicDecode}->{RotateZ} );
	setPref( $client, 'band' . $AMBROTATEYKEY . 'value', $doc->{Client}->{AmbisonicDecode}->{RotateY} );
	setPref( $client, 'band' . $AMBROTATEXKEY . 'value', $doc->{Client}->{AmbisonicDecode}->{RotateX} );
	setPref( $client, 'filter', $doc->{Client}->{Filter} );
	setPref( $client, 'matrix', $doc->{Client}->{Matrix} );
	my $bandcount = $doc->{Client}->{EQ}->{Bands};
	# Read bands from conf
	my %h = ();
	my $n = 0;
	foreach $b (@{$doc->{Client}->{EQ}->{Band}})
	{
		my $f = $b->{Freq}; $f += 0;
		next if $f < 10;
		next if $f > 22000;
		my $v = $b->{content}; $v += 0;
		$h{$f} = $v;
		$n++;
		last if $n >= $bandcount;
	}
	my @freqs = sort { $a <=> $b } keys %h;
	my @values = map $h{$_}, @freqs;
	setBandCount( $client, scalar(@freqs) );
	for( $n=0; $n<scalar(@freqs); $n++ )
	{
		setPref( $client, 'b' . $n . 'freq', $freqs[$n] );
		setPref( $client, 'b' . $n . 'value', $values[$n] );
	}
	setPref( $client, 'band' . $QUIETNESSKEY . 'value', $doc->{Client}->{Quietness} );
	setPref( $client, 'band' . $FLATNESSKEY . 'value', $doc->{Client}->{Flatness} );
	setPref( $client, 'band' . $WIDTHKEY . 'value', $doc->{Client}->{Width} );
	setPref( $client, 'band' . $BALANCEKEY . 'value', $doc->{Client}->{Balance} );
	setPref( $client, 'band' . $SKEWKEY . 'value', $doc->{Client}->{Skew} );
#	setPref( $client, 'band' . $DEPTHKEY . 'value', $doc->{Client}->{Depth} );

	defaultPrefs( $client );

	my $line = $client->string('PLUGIN_SQUEEZEDSP_PRESET_LOADED');
	$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );
}

sub closestFreq
{
	my ( $f, %h ) = @_;
	return (sort { abs($a-$f)<=>abs($b-$f) } keys %h)[0];
}

sub setBandCount
{
	my $client = shift;
	my $bandcount = shift;

	$bandcount = int( $bandcount );
	return if( $bandcount<2 );

	my $prevcount = getPref( $client, 'bands' ) || 2;
	debug( "setBandCount " . $bandcount . ", was " . $prevcount );
	if( $bandcount != $prevcount )
	{
		# When the number of bands changes

		# Make a hashtable of the current values/frequencies
		my %h = ();
		for( my $n=0; $n<$prevcount; $n++ )
		{
			my $f = getPref( $client, 'b' . $n . 'freq' ) || defaultFreq( $client, $n, $prevcount );
			$h{$f} = getPref( $client, 'b' . $n . 'value' ) || 0;
		}

		# Get an array of the default band frequencies we'll map to
		my @freqs = defaultFreqs( $client, $bandcount );

		# Where the frequency matches, use the closest old value
		for( my $n=0; $n<$bandcount; $n++ )
		{
			my $f = $freqs[$n];
			my $oldf = closestFreq($f,%h);
			my $oldv = $h{$oldf};
			debug( "closest to $f is $oldf (=$oldv)" );
			setPref( $client, 'b' . $n . 'freq', $f );
			setPref( $client, 'b' . $n . 'value', $oldv || 0 );
		}

		# Delete any unused prefs
		for( my $n=$bandcount; $n<$prevcount; $n++ )
		{
			delPref( $client, 'b' . $n . 'freq' );
			delPref( $client, 'b' . $n . 'value' );
		}
	}
	setPref( $client, 'bands', $bandcount );
}

sub AmbisonicAttributes
{
	my $client = shift;
	my $ambtype = getPref( $client, 'ambtype' );		# UHJ, Blumlein or Crossed
	my $ambangle = getPref( $client, 'band' . $AMBANGLEKEY . "value" );	# Angle for cardioid-type
	my $ambdirect = getPref( $client, 'band' . $AMBDIRECTKEY . "value" );	# Directivity for cardioid-type
	my $ambjw = getPref( $client, 'band' . $AMBJWKEY . "value" );		# jW mix for for metacardioid-type
	my $ambrotZ = getPref( $client, 'band' . $AMBROTATEZKEY . "value" );	# Rotation about Z (rotate)
	my $ambrotY = getPref( $client, 'band' . $AMBROTATEYKEY . "value" );	# Rotation about Y (tumble)
	my $ambrotX = getPref( $client, 'band' . $AMBROTATEXKEY . "value" );	# Rotation about X (tilt)
	my $ret = "Type=\"" . $ambtype . "\" ";
	if( $ambtype eq 'Crossed' )
	{
		$ret = $ret . ( "Cardioid=\"" . $ambdirect . "\" Angle=\"" . $ambangle . "\" " ); 
	}
	elsif( $ambtype eq 'Crossed+jW' )
	{
		$ret = $ret . ( "Cardioid=\"" . $ambdirect . "\" Angle=\"" . $ambangle . "\" jW=\"" . $ambjw . "\" " );
	}
	$ret = $ret . ( "RotateZ=\"" . $ambrotZ . "\" RotateY=\"" . $ambrotY . "\" RotateX=\"" . $ambrotX . "\" " );
	return $ret;
}

sub SigGenAttributes
{
	my $client = shift;
	my $siggen = getPref( $client, 'siggen' );
	my $sigfreq = getPref( $client, 'sigfreq' ) || 1000;

	if( $siggen eq 'Ident' )
	{
		return( "Type=\"Ident\" L=\"" . $client->string('PLUGIN_SQUEEZEDSP_SIGGEN_IDENT_L') . "\" R=\"" . $client->string('PLUGIN_SQUEEZEDSP_SIGGEN_IDENT_R') . "\"" ); 
	}
	if( $siggen eq 'Sweep' )
	{
		return( "Type=\"Sweep\" Length=\"" . "45" . "\"" ); 
	}
	if( $siggen eq 'SweepShort' )
	{
		return( "Type=\"Sweep\" Length=\"" . "20" . "\"" ); 
	}
	if( $siggen eq 'SweepEQL' )
	{
		return( "Type=\"Sweep\" Length=\"" . "45" . "\" UseEQ=\"L\"" ); 
	}
	if( $siggen eq 'SweepEQR' )
	{
		return( "Type=\"Sweep\" Length=\"" . "45" . "\" UseEQ=\"R\"" ); 
	}
	elsif( $siggen eq 'Pink' )
	{
		return( "Type=\"Pink\" Mono=\"true\"" ); 
	}
	elsif( $siggen eq 'PinkEQ' )
	{
		return( "Type=\"Pink\" Mono=\"true\" UseEQ=\"true\"" ); 
	}
	elsif( $siggen eq 'PinkSt' )
	{
		return( "Type=\"Pink\" Mono=\"false\"" ); 
	}
	elsif( $siggen eq 'PinkStEQ' )
	{
		return( "Type=\"Pink\" Mono=\"false\" UseEQ=\"true\"" ); 
	}
	elsif( $siggen eq 'White' )
	{
		return( "Type=\"White\"" ); 
	}
	elsif( $siggen eq 'Sine' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\"" ); 
	}
	elsif( $siggen eq 'Quad' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\"" ); 
	}
	elsif( $siggen eq 'Square' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\"" ); 
	}
	elsif( $siggen eq 'BLSquare' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\"" ); 
	}
	elsif( $siggen eq 'Triangle' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\"" ); 
	}
	elsif( $siggen eq 'BLTriangle' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\"" ); 
	}
	elsif( $siggen eq 'Sawtooth' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\"" ); 
	}
	elsif( $siggen eq 'BLSawtooth' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\"" ); 
	}
	elsif( $siggen eq 'Intermodulation' )
	{
		return( "Type=\"" . $siggen . "\" Freq1=\"" . "19000" . "\" Freq2=\"" . "20000" . "\"" ); 
	}
	elsif( $siggen eq 'ShapedBurst' )
	{
		return( "Type=\"" . $siggen . "\" Freq=\"" . $sigfreq . "\" Cycles=\"" . "4" . "\""  ); 
	}
	else
	{
		return( "Type=\"None\"" ); 
	}
}





1
;