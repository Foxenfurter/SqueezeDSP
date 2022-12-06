package Plugins::SqueezeDSP::Plugin;
=pod version history
	# ----------------------------------------------------------------------------
	# SqueezeDSP\Plugin.pm - a SlimServer plugin.
	# Makes a remote-control user interface, and writes settings files, which
	# provide parameters for operation of a convolution and filter engine.
	
	# ----------------------------------------------------------------------------
	#
	#
	#
	# Revision history:
	#
	#	
	#Initial version
	#
	
	0.0.7 - Fox:
			Using JSON files for config
	0.0.5 - Fox:
			This is a fully working initial version
			All code has eben migrated to refer to SqueezeDSP
			code relating to the signal generator has been removed.
			code relating to the jive menu has been removed and moved into a separate pm file, which is not referenced or used.
			At this point, I think it is unlikely that the Jive menus will be re-instated
=cut

use strict;
use base qw(Slim::Plugin::Base);
use Slim::Utils::Misc;
use Slim::Utils::OSDetect;
use File::Spec::Functions qw(:ALL);
use File::Path;
use File::Copy;
use FindBin qw($Bin);
use XML::Simple;
use JSON::XS qw(decode_json);
use Data::Dumper;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

use Slim::Player::TranscodingHelper;

use Plugins::SqueezeDSP::Settings;

use Plugins::SqueezeDSP::TemplateConfig;

{
	if($^O =~ /Win32/) {
		require Win32;
	}
}

# ------ names and versions ------

# Revision number.
# Anytime the revision number is incremented, the plugin will rewrite the
# slimserver-convert.conf, requiring restart.
#
my $revision = "0.0.06";
use vars qw($VERSION);
$VERSION = $revision;

# Names and name-related constants...
#
#mytag is used in the menu system
my $thistag = "squeezedsp";
my $thisapp = "SqueezeDSP";
#used for the dsp program binary
my $binary;
#used for the xml tags
my $settingstag = "SqueezeDSPSettings";
#used for writing config
my $confBegin = "SqueezeDSP#begin";
my $confEnd = "SqueezeDSP#end";
my $modeAdjust       = "PLUGIN.SqueezeDSP.Adjust";
my $modeValue        = "PLUGIN.SqueezeDSP.Value";
my $modePresets      = "PLUGIN.SqueezeDSP.Presets";
my $modeSettings     = "PLUGIN.SqueezeDSP.Settings";
my $modeEqualization = "PLUGIN.SqueezeDSP.Equalization";
my $modeRoomCorr     = "PLUGIN.SqueezeDSP.RoomCorrection";
my $modeMatrix       = "PLUGIN.SqueezeDSP.Matrix";
#my $modeSigGen       = "PLUGIN.SqueezeDSP.SignalGenerator";
my $modeAmbisonic    = "PLUGIN.SqueezeDSP.Ambisonic";

my $log = Slim::Utils::Log->addLogCategory({ 'category' => 'plugin.' . $thistag, 'defaultLevel' => 'WARN', 'description'  => $thisapp });

my $prefs = preferences('plugin.' . $thistag);

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

# the usual convolver controlled by this plugin is called SqueezeDSP - this is
# the command inserted in custom-convert.conf
#

my $convolver = "SqueezeDSP";
my $configPath = "";
#use the revision number from the config file
my $myconfigrevision = get_config_revision();
	


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


# ------ other globals this module ------


my %noFunctions = ();  # const
my $needUpgrade = 0;
my $fatalError;
my $pluginDataDir;            # <appdata>\squeezedsp
my $pluginSettingsDataDir;    # <appdata>\squeezedsp\Settings     used for settings and presets
my $pluginImpulsesDataDir;    # <appdata>\squeezedsp\Impulses     used for room correction impulse filters
my $pluginMatrixDataDir;      # <appdata>\squeezedsp\Matrix       used for cross-feed matrix impulse filters
my $pluginMeasurementDataDir; # <appdata>\squeezedsp\Measurement  used for measurement sweeps and noise samples
my $pluginTempDataDir;        # <appdata>\squeezedsp\Temp         used for any temporary stuff
my @presetsMenuChoices;
my @presetsMenuValues;
my $doneJiveInit = 0;

sub keyval
{
	# from a key like '123.special' get 'special'
	my $k = shift;
	$k =~ s/^[\d]*\.//;
	return $k;
}

sub debug
{
	my $txt = shift;
	$log->info( $thisapp .": " . $txt . "\n");
	#Putting an error here for easier debug
	$log->error( "Fox: " .  $txt . "\n" );
}


sub oops
{
	my ( $client, $desc, $message ) = @_;
	$log->warn( "oops: " . $desc . ' - ' . $message );
	$client->showBriefly( { line => [ $desc, $message ] } , 2);
}

sub fatal
{
	my ( $client, $desc, $message ) = @_;
	$log->error( "fatal: " . $desc . ' - ' . $message );
	$client->showBriefly( { line => [ $desc, $message ] } , 2);
	$fatalError = $message;
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

sub newConfigPath
{
	my @rootdirs = Slim::Utils::PluginManager::dirsFor($thisapp,'enabled');
	for my $d (@rootdirs)
	{
		if( $d =~ m/$thisapp/i )
		{
			my $cp = catdir( $d, 'custom-convert.conf' );
			debug( "New CP:" . $cp );
			
			return $cp;
		}
	}
	fatal ("can't find directory with custom-convert.conf");
	return;
}

#Setup path to Binary - may need to compile more versions to support this
sub binaries {
	my $os = Slim::Utils::OSDetect::details();
	
	if ($os->{'os'} eq 'Linux') {

		if ($os->{'osArch'} =~ /x86_64/) {
			return qw(/publishLinux-x64/SqueezeDSP );
		}
		if ($os->{'binArch'} =~ /i386/) {
			return qw(/publishLinux-x86/SqueezeDSP);
		}
		if ($os->{'osArch'} =~ /aarch64/) {
			return qw(/publishlinux-arm64/SqueezeDSP) ;
		}
		if ($os->{'binArch'} =~ /armhf/) {
			return qw( /publishlinux-arm/SqueezeDSP );
		}
		if ($os->{'binArch'} =~ /arm/) {
			return qw( /publishlinux-arm/SqueezeDSP );
		}
		
		# fallback to offering all linux options for case when architecture detection does not work
		return qw( /publishLinux-x86/SqueezeDSP );
	}
	
	if ($os->{'os'} eq 'Unix') {
	
		if ($os->{'osName'} =~ /freebsd/) {
			return qw( /publishLinux-x64/SqueezeDSP );
		}
		
	}	
	
	if ($os->{'os'} eq 'Darwin') {
		return qw(/publishOsx-x64/SqueezeDSP );
	}
		
	if ($os->{'os'} eq 'Windows') {
		return qw(\publishWin64\SqueezeDSP.exe);
	}	
	
}



# ------ slimserver delegates and initialization ------

sub getFunctions
{
	return \%noFunctions;
}

sub getDisplayName
{
	return 'PLUGIN_SQUEEZEDSP_DISPLAYNAME';
}

sub getpluginVersion
{
 return $revision;	
}

sub enabled
{
	return 1;
}

sub initPlugin
{
	my $class = shift;
	$class->SUPER::initPlugin( @_ );

	debug( "plugin " . $revision . " enabled" );
	
	# AMB and UHJ file types really are WAV
	Slim::Formats::Playlists->registerParser('amb', 'Slim::Formats::Wav');
	Slim::Formats::Playlists->registerParser('uhj', 'Slim::Formats::Wav');

	# Register json/CLI functions
	#                                                                                         |requires Client
	#                                                                                         |  |is a Query
	#                                                                                         |  |  |has Tags
	#                                                                                         |  |  |  |Function to call
	#                                                                                         C  Q  T  F
	Slim::Control::Request::addDispatch([$thistag . '.current'],                             [1, 1, 0, \&currentQuery]);		# read current settings
	Slim::Control::Request::addDispatch([$thistag . '.filters'],                             [1, 1, 0, \&filtersQuery]);		# read lists of filters
	Slim::Control::Request::addDispatch([$thistag . '.setval'],                              [1, 1, 1, \&setvalCommand]);		# set a pref value
	Slim::Control::Request::addDispatch([$thistag . '.seteq'],                               [1, 1, 1, \&seteqCommand]);		# set an EQ value pair
	Slim::Control::Request::addDispatch([$thistag . '.saveas'],                              [1, 1, 1, \&saveasCommand]);		# save as preset-file
	#Slim::Control::Request::addDispatch([$thistag . '.topmenu'],                             [1, 1, 1, \&topmenuCommand]);		# top menu for Jive
	#Slim::Control::Request::addDispatch([$thistag . '.settingsmenu', '_index', '_quantity'], [1, 1, 1, \&settingsmenuCommand]);	# settings sub-menu for Jive
	#Slim::Control::Request::addDispatch([$thistag . '.ambimenu', '_index', '_quantity'],     [1, 1, 1, \&ambimenuCommand]);		# amb settings sub-menu for Jive

	my $appdata;
	#This is where preferences are stored.


    $appdata = Slim::Utils::Prefs::dir();
	# Make sure our appdata directory exists, if at all possible
	# Note: linux requires this already created, with owner slimserver
	$pluginDataDir = catdir( $appdata, $thisapp );
	mkdir( $pluginDataDir );

	# The folder where all settings data lives (filters, settings files, presets, etc)
	$pluginSettingsDataDir = catdir( $pluginDataDir, 'Settings' );
	mkdir( $pluginSettingsDataDir );

	$pluginImpulsesDataDir = catdir( $pluginDataDir, 'Impulses' );
	mkdir( $pluginImpulsesDataDir );

	$pluginMatrixDataDir = catdir( $pluginDataDir, 'MatrixImpulses' );
	mkdir( $pluginMatrixDataDir );

	$pluginMeasurementDataDir = catdir( $pluginDataDir, 'Measurement' );
	mkdir( $pluginMeasurementDataDir );

	$pluginTempDataDir = catdir( $pluginDataDir, 'Temp' );
	mkdir( $pluginTempDataDir );
		
	my $bin = $class->binaries;
	debug( "Fox plugin path: " . $bin . " binary" );
	my $exec = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin', $bin);
	debug( "Fox plugin path: " . $exec . " exec" );
	#extension is only used for windows
	my $binExtension = ".exe";
	# set extension for windows
	if (Slim::Utils::OSDetect::details()->{'os'} ne 'Windows') {
		$binExtension = ""	;
	}		
	if (!-e $exec) {
		$log->warn("$exec not executable");
		return;
	}
	#derive standard binary path
	$bin = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/", $convolver . $binExtension);
	debug('standard binary path: ' . $bin);
	# copy correct binary into bin folder unless it already exists
	unless (-e $bin) {
		debug('copying binary' . $exec );
		copy( $exec , $bin)  or die "copy failed: $!";
		#we know only windows has an extension, now set the binary
		if ( $binExtension == "") {
				debug('executable not having \'x\' permission, correcting');
				chmod (0555, $bin);
				
		}	
	}
	
	#do any cleanup
	housekeeping();
	#do any app config settings, simplifies handover to SqueezeDSP app
	my $appConfig = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/", 'squeezeDSP_config.json');
	my $soxbinary = Slim::Utils::Misc::findbin('sox');
	#needs updating to amend json...
	#amendPluginConfig($appConfig, 'soxExe', $soxbinary);
	
	# Subscribe to player connect/disconnect messages
	Slim::Control::Request::subscribe(
		\&clientEvent,
		[['client'],['new','reconnect','disconnect']]
	);
}

sub housekeeping
{
	# Clean up temp directory as it tends to get full. Only want to get rid of filters and some json files
	unlink glob catdir ( $pluginTempDataDir, "/",  '*.filter');
	unlink glob catdir ( $pluginTempDataDir , "/", '*.json');
	
}

sub amendPluginConfig()
{
	#routine for adding a value to a key in the app config.
	my $myXML = shift;
	my $myKey = shift;
	my $myValue = shift;
	debug('Fox amend file: ' .  $myXML . ' for key =' . $myKey . ' value= ' . $myValue );
	my  $simple = XMLin($myXML, ForceArray => 1,
                         KeepRoot   => 1,
                         KeyAttr    => [], );
	my $found = 0;						

	my $str = "";
	#this returns the number of low values in the add array
	my $Elements = @{$simple->{configuration}[0]->{appSettings}[0]->{add}} ;
	# now loop through the structure and see if myKey exists
	#I am sure this could be done more neatly, but it works!
	my $count = 0;
	for (my $count = 0 ; $count < $Elements  ; $count++)
	{
		#get the key
		$str = $simple->{configuration}[0]->{appSettings}[0]->{add}[$count]->{key} ;
		#compare to the key we want
		if ($str eq $myKey)
		{
			debug (	$str . " value found " ) ;
			#set value
			$simple->{configuration}[0]->{appSettings}[0]->{add}[$count]->{value} = $myValue;
			$found = 1;		
		}
	}
	#ok we didn't find it, so we now push the value in.	
    if ($found == 0) { 
		debug ("Adding Key");
		push @{ $simple->{configuration}[0]{appSettings}[0]{add} }, { key  => $myKey,
                                                        value => $myValue,
                                                      };
		}
	#now save the updated cml	
	print XMLout($simple, KeepRoot => 1, OutputFile => $myXML, );

}


sub shutdown
{
	Slim::Control::Request::unsubscribe( \&clientEvent );
}

sub clientEvent {
	my $request = shift;
	my $client  = $request->client;
	
	if ( !defined $client ) {
		return;
	}
	
	initConfiguration( $client );
	
	
=pod remove Jive stuff as we are not using it
	if( !$doneJiveInit )
	{
		# Register the top-level jive "EQ" node (client-independent)
		my $node = {
				id => $thistag,
				text => Slim::Utils::Strings::string(getDisplayName()),
				weight => 5,
				node => 'extras',
		};
		Slim::Control::Jive::registerPluginNode( $node );
		debug( $thistag . " node registered" );
		$doneJiveInit = 1;
	}

	my @menuItems = jiveTopMenu( $client );
	Slim::Control::Jive::registerPluginMenu( \@menuItems, $thistag, $client );
=cut 
}


sub initConfiguration
{
	# called when a client first appears
	# (not on plugin init, because we need the client ID)
	#
	my $client = shift;
	debug( "client " . $client->id() ." name " . $client->name ." initializing" );

	# Check the current and previous installed versions of the plugin,
	# in case we need to upgrade the prefs store (for this client)
	#
	my $prevrev = $prefs->client($client)->get( 'version' ) || '0.0.0.0';
	

	# Write this .conf with sections for every client
	# (because the convolver needs clientID as parameter)
	# (and because different clients can have different transcode rules, eg SB1 doesn't understand FLAC)
	# This is only run when the plugin main-menu is loaded
	# since initPlugin seems to happen before the clients() list is ready, or something

	$fatalError = undef;
	
	my $upgradeReason = '';
	my @origLines;

	# Make a list of all client IDs, we'll need it later
	my @clientIDs = sort map { $_->id() } Slim::Player::Client::clients();
	my @foundClients;


	# Pre... flag used to upgrade the prefs format.
	my $PRE_0_9_21 = 0;
	my $tryMoveConfig = 0;
	

	# Is there an existing transcode configuration file?
	@origLines = ();
	$configPath = newConfigPath();
	if( -f $configPath )
	{
		# Does the convert file need to be upgraded?
		# Read the whole thing into an array to find out.
		# - if there's a header section with older version numbers
		# - if any current client IDs are missing. (Note: Client::clients() gives the currently-active client list, not the all-ever-known list...

		open( CONFIG, "$configPath" ) || do { fatal( $client, undef, "Can't read from $configPath" ); return 0; };
		@origLines = <CONFIG>;
		close( CONFIG );

		#my @revs = split /\./, $revision;

		my @revs = split /\./, $myconfigrevision;
		for( @origLines )
		{
			if( m/#$confBegin#rev\:(.*)#client\:(.*)#/i )
			{
				my @test = split /\./, $1;
				for my $ver ( @revs )
				{
					my $vert = shift( @test ) || 0;
					next if $vert == $ver;  # file is same version as me
					
					# useful to force versions to be same.
					# this step ignores templates that are lower than in the config. I think it is useful to ignore this so that we amend on any difference. 
					# Although we should expect the number to incremented upwards. 
					# last if $vert > $ver;  # file is later than me
					# debug ("Script version higher than config: " . $ver . " - " . $vert );
					debug ("Template version higher than config: " . $ver . " - " . $vert );
					#$upgradeReason = "Previous version $1 less than my $revision ($vert less than $ver)" unless $needUpgrade;
					$upgradeReason = "Previous version $1 less than my $myconfigrevision ($vert less than $ver)" unless $needUpgrade;
					$needUpgrade = 1;
					last;
				}
				push( @foundClients, $2 );
			}
        #continue looping through as otherwise we bale as soon as the version is read			
        #	last if $needUpgrade;
		}
		@foundClients = sort @foundClients;
		# original code don't need to do this if we need and upgrade
		unless( $needUpgrade )
		{
			for my $c (@clientIDs)
			{
				my $ok = 0;
				#loop through all the found clients vs clients
				for my $cc (@foundClients)
				{
					if( $c eq $cc )
					{
						#if found client matches a client
						$ok = 1;
						last;
					}
				}
				unless( $ok )
				{
					$upgradeReason = "Client $c was not yet registered" unless $needUpgrade;
					$needUpgrade = 1;
					debug ("Client $c was not yet registered" );
					push( @foundClients, $c );
					last;
				}
			}
		}
	}
	else
	{
		# Need to create the config file from scratch
		debug ("Config Not found, new one created" );
		$upgradeReason = "New configuration" unless $needUpgrade;
		$needUpgrade = 1;
		@foundClients = @clientIDs;
	}
	
	upgradePrefs( $prevrev, $PRE_0_9_21, @foundClients );
	
	return unless $needUpgrade;

	# Recreate -convert.conf
	# by copying our template() for each known client
	debug( "Need to rewrite " . $configPath . " (" .$upgradeReason . ")" );

	open( OUT, ">$configPath" ) || do { fatal( $client, undef, "Can't write to $configPath" ); return; };

	my $now = localtime;
	print OUT "# Modified by $thisapp, $now: $upgradeReason\n";

	my $copying = 1;
	foreach ( @origLines )
	{
		#This should be searching for existing lines containing update reasons - original had a bug which added a lots of blanks based
		print OUT if m/# Modified by $thisapp/i;
		
	}
	# Add a line to create some white space
	print OUT "\n";

	foreach my $clientID ( @foundClients )
	{
		print OUT "# #$confBegin#rev:$myconfigrevision#client:$clientID# ***** BEGIN AUTOMATICALLY GENERATED SECTION - DO NOT EDIT ****\n";

		my $n = template( $clientID );
		print OUT $n;
	
		print OUT "\n";
		print OUT "# #$confEnd#client:$clientID# ***** END AUTOMATICALLY GENERATED SECTION - DO NOT EDIT *****\n";
		print OUT "\n";
	}
	
	print OUT "";
	close( OUT );
	
	#restart will trigger a re-writeso re-set need upgrade to off.
	$needUpgrade = 0;
	my $myRestart = Slim::Player::TranscodingHelper::loadConversionTables();
	debug( "Reload Conversion Tables" );
}



# ------ web interface ------

sub webPages
{
	my $class = shift;

	if( Slim::Utils::PluginManager->isEnabled("Plugins::SqueezeDSP::Plugin") )
	{
		Slim::Web::Pages->addPageFunction("plugins/SqueezeDSP/index.html", \&handleWebIndex);
		Slim::Web::Pages->addPageFunction("plugins/SqueezeDSP/squeezedsp.png", \&handleWebStatic);
		Slim::Web::Pages->addPageLinks("plugins", { $class->getDisplayName => 'plugins/SqueezeDSP/index.html' });
		Slim::Web::Pages->addPageLinks("icons",   { $class->getDisplayName => 'plugins/SqueezeDSP/squeezedsp.png' });
	}
	else
	{
		Slim::Web::Pages->addPageLinks("plugins", { $class->getDisplayName => undef });
		Slim::Web::Pages->addPageLinks("icons",   { $class->getDisplayName => undef });
	}
}

sub handleWebIndex
{
	my ( $client, $params ) = @_;
	if( $client = Slim::Player::Client::getClient($params->{player}) )
	{
		return Slim::Web::HTTP::filltemplatefile('plugins/SqueezeDSP/index.html', $params);

	}
}

sub handleWebStatic
{
	my ( $client, $params ) = @_;
	debug( $params->{"path"} );
	return Slim::Web::HTTP::getStaticContent( $params->{"path"}, $params );
}


# ------ preferences ------

# For easy access, our preferences are written to one file per client,
# in the plugin data directory; file is named by the client ID.
# These files are written immediately a pref is set (so the app can respond fast).
#
# NOTE: the files we write are ONLY read by the convolver app, not by this plugin;
# the plugin UI will always take precedence over any manual edits.

sub getPrefFile
{
	my $client = shift;
	#return catdir( $pluginSettingsDataDir, join('_', split(/:/, $client->id())) . '.settings.conf' );
	return catdir( $pluginSettingsDataDir, join('_', split(/:/, $client->id())) . '.settings.json' );
}


sub getPref
{
	my ( $client, $prefName ) = @_;
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
#write to JSON file
{
	my $client = shift;
	my $file = shift;
	#set variable to hold, start, seperator  end of line as they are all the same in json
	my $mySOL = "\"";
	my $myvalSep = "\" \: \"";
	my $myEOL = "\",\n";
	my $myFieldStart = "\" \: {\n";
	my $myFieldEnd = "},\n";
	
	my ( $vol, $dir, $fil ) = splitpath( $file );
	debug( "savePrefs " . $fil );
	open( OUT, ">$file" ) or  do { oops( $client, undef, "Preferences could not be saved to $file." ); return 0; };
	
	print OUT "{\n";
	print OUT " " . $mySOL ."Revision" .  $myvalSep . $revision . $myEOL ;	
	#print OUT " \"Revision\" :\" " . $revision . "\",\n";
	print OUT " " .  $mySOL . "Client" . $myFieldStart;
	print OUT " " x 3 .  $mySOL . "ID" . $myvalSep . $client->id() . $myEOL	;
	#print OUT " \"Client\" : \" " . $client->id() . "\",\n";
	
	#Special treatment for Ambisonic decode attributes
	#---------------Was in a separate function - easier to handle here
	print OUT " " x 3 .  $mySOL . "AmbisonicDecode" . $myFieldStart;

	my $ambtype = getPref( $client, 'ambtype' );		# UHJ, Blumlein or Crossed
	my $ambangle = getPref( $client, 'band' . $AMBANGLEKEY . "value" );	# Angle for cardioid-type
	my $ambdirect = getPref( $client, 'band' . $AMBDIRECTKEY . "value" );	# Directivity for cardioid-type
	my $ambjw = getPref( $client, 'band' . $AMBJWKEY . "value" );		# jW mix for for metacardioid-type
	my $ambrotZ = getPref( $client, 'band' . $AMBROTATEZKEY . "value" );	# Rotation about Z (rotate)
	my $ambrotY = getPref( $client, 'band' . $AMBROTATEYKEY . "value" );	# Rotation about Y (tumble)
	my $ambrotX = getPref( $client, 'band' . $AMBROTATEXKEY . "value" );	# Rotation about X (tilt)
	print OUT " " x 4 .  $mySOL . "Type" . $myvalSep . $ambtype . $myEOL ;
	#my $ret = "Type=\"" . $ambtype . "\" ";
	if( $ambtype eq 'Crossed' )
	{
		print OUT " " x 5 .  $mySOL . "Cardioid" . $myvalSep . $ambdirect . $myEOL ;
		print OUT " " x 5 .  $mySOL . "Angle" . $myvalSep . $ambangle . $myEOL ;
		#$ret = $ret . ( "Cardioid=\"" . $ambdirect . "\" Angle=\"" . $ambangle . "\" " ); 
	}
	elsif( $ambtype eq 'Crossed+jW' )
	{
		print OUT " " x 5 .  $mySOL . "Cardioid" . $myvalSep . $ambdirect . $myEOL ;
		print OUT " " x 5 .  $mySOL . "Angle" . $myvalSep . $ambangle . $myEOL ;
		print OUT " " x 5 .  $mySOL . "jW" . $myvalSep . $ambjw . $myEOL ;
		#$ret = $ret . ( "Cardioid=\"" . $ambdirect . "\" Angle=\"" . $ambangle . "\" jW=\"" . $ambjw . "\" " );
	}
	print OUT " " x 5 .  $mySOL . "RotateZ" . $myvalSep . $ambrotZ . $myEOL ;
	print OUT " " x 5 .  $mySOL . "RotateY" . $myvalSep . $ambrotY . $myEOL ;
	print OUT " " x 5 .  $mySOL . "RotateX" . $myvalSep . $ambrotX . $myEOL ;
		
	#$ret = $ret . ( "RotateZ=\"" . $ambrotZ . "\" RotateY=\"" . $ambrotY . "\" RotateX=\"" . $ambrotX . "\" " );
	
	#print OUT "    <AmbisonicDecode " . AmbisonicAttributes( $client ) . " />\n";	
	print OUT " " x 3 . $myFieldEnd;
	#----------------End of Ambisonic
	print OUT " " x 3 .  $mySOL . "SignalGenerator" . $myFieldStart ;
	print OUT " " x 5 .  $mySOL . "Type" . $myvalSep . "None" . $myEOL ;	
	print OUT " " x 3 . $myFieldEnd;
	#print OUT "    <SignalGenerator " . SigGenAttributes( $client ) . " />\n";

	print OUT " " x 3 .  $mySOL . "Matrix" . $myvalSep . Slim::Utils::Unicode::utf8encode( getPref( $client, 'matrix' ) || '' ) . $myEOL ;
	#print OUT "    <Matrix>" . Slim::Utils::Unicode::utf8encode( getPref( $client, 'matrix' ) || '' ) . "</Matrix>\n";
	print OUT " " x 3 .  $mySOL . "Width" . $myvalSep . ( getPref( $client, 'band' . $WIDTHKEY . 'value' ) || 0 ) . $myEOL	;
	#print OUT "    <Width>" . ( getPref( $client, 'band' . $WIDTHKEY . 'value' ) || 0 ) . "</Width>\n";
	print OUT " " x 3 .  $mySOL . "Balance" . $myvalSep . ( getPref( $client, 'band' . $BALANCEKEY . 'value' ) || 0 ) . $myEOL	;
	#print OUT "    <Balance>" . ( getPref( $client, 'band' . $BALANCEKEY . 'value' ) || 0 ) . "</Balance>\n";
	print OUT " " x 3 .  $mySOL . "Skew" . $myvalSep . ( getPref( $client, 'band' . $SKEWKEY . 'value' ) || 0 ) . $myEOL	;
#	print OUT "    <Skew>" . ( getPref( $client, 'band' . $SKEWKEY . 'value' ) || 0 ) . "</Skew>\n";
#	print OUT "    <Depth>" . ( getPref( $client, 'band' . $DEPTHKEY . 'value' ) || 0 ) . "</Depth>\n";
	print OUT " " x 3 .  $mySOL . "Filter" . $myvalSep .  Slim::Utils::Unicode::utf8encode( getPref( $client, 'filter' ) || '' ) . $myEOL	;
	#print OUT "    <Filter>" . Slim::Utils::Unicode::utf8encode( getPref( $client, 'filter' ) || '' ) . "</Filter>\n";
	
	# Now process EQ - bands and all
	my $bandcount = getPref( $client, 'bands' );
	
	print OUT " " x 3 .  $mySOL . "EQ" . $myFieldStart;
	print OUT " " x 4 .  $mySOL . "Bands" . $myvalSep . $bandcount . $myEOL	;
	print OUT " " x 4 .  $mySOL . "Band\" : [\n";
	
	#print OUT "    <EQ Bands=\"" . $bandcount . "\">\n";
	for( my $n = 0; $n < $bandcount; $n++ )
	{
		print OUT " " x 4 .  "{\n";
		my $f = getPref( $client, 'b' . $n . 'freq' ) || defaultFreq( $client, $n, $bandcount );
		my $v = getPref( $client, 'b' . $n . 'value' ) || 0;
		print OUT " " x 5 .  $mySOL . "Freq" . $myvalSep .  $f . $myEOL	;
		print OUT " " x 5 .  $mySOL . "Gain" . $myvalSep .  $v . $myEOL	;
		print OUT " " x 5 .  $mySOL . "Q" . $myvalSep .  "1.41" . $myEOL	;
		#print OUT "      <Band Freq=\"" . $f . "\">" . $v . "</Band>\n";
		print OUT " " x 4 .  "}\n";
	}
	
	print OUT " " x 4 .  $mySOL . "]\n";
	#print OUT "    </EQ>\n";
	print OUT " " x 3 . $myFieldEnd ;
	print OUT " " x 3 .  $mySOL . "Loudness" . $myvalSep .  ( getPref( $client, 'band' . $QUIETNESSKEY . 'value' ) || 0 ) . $myEOL	;
	#print OUT "    <Quietness>" . ( getPref( $client, 'band' . $QUIETNESSKEY . 'value' ) || 0 ) . "</Quietness>\n";
	my $fl = getPref( $client, 'band' . $FLATNESSKEY . 'value' );
	print OUT " " x 3 .  $mySOL . "Flatness" . $myvalSep .  ( defined($fl) ? $fl : 10 ) . $myEOL ;
	
	#print OUT "    <Flatness>" . ( defined($fl) ? $fl : 10 ) . "</Flatness>\n";
	
	print OUT " "  . $myFieldEnd ;
	print OUT  $myFieldEnd;
	
	
	close( OUT );
	return 1;
}
sub loadPrefs_new
{
	#load from JSON file	
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
	#setPref( $client, 'siggen', $doc->{Client}->{SignalGenerator} );
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
sub savePrefs_old
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
	#print OUT "    <SignalGenerator " . SigGenAttributes( $client ) . " />\n";
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
	#setPref( $client, 'siggen', $doc->{Client}->{SignalGenerator} );
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
=pod no more sig gens
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
=cut
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

sub upgradePrefs
{
	my ( $prevrev, $PRE_0_9_21, @clientIDs ) = @_;
	return if ( $prevrev eq $revision ) && !$PRE_0_9_21;
	debug( "upgrade from " . $prevrev . " to " . $revision );
	
	foreach my $clientID ( @clientIDs )
	{
		debug( "client " . $clientID );
		my $client = Slim::Player::Client::getClient( $clientID );
		if( defined( $client ) )
		{

			
			unless( $prevrev eq $revision )
			{
				setPref( $client, "version", $revision );
			}
		}
	}
}



# ----- The CLI requests -----


# CLI command to get the current status detail
sub currentQuery
{
	my $request = shift;
	my $client = $request->client();
	debug( "query: current" );

	if( $request->isNotQuery([[$thistag . '.current']]) )
	{
		$request->setStatusBadDispatch();
		return;
	}

	$request->addResult("Revision",  $revision);

	# The filters, stripping path but leaving the extension
	my $filt = ( getPref( $client, 'matrix' ) || '' );
	my ( $vol, $dir, $fil ) = splitpath( $filt );
	$request->addResult("Matrix",    $fil );

	$filt = ( getPref( $client, 'filter' ) || '' );
	($vol, $dir, $fil) = splitpath( $filt );
	$request->addResult("Filter",    $fil );

	$request->addResult("Amb",        getPref( $client, 'ambtype' ) );
	$request->addResult("Bands",      getPref( $client, 'bands' ) );
	$request->addResult("Quietness",  getPref( $client, 'band' . $QUIETNESSKEY . 'value' ) );
	$request->addResult("Flatness",   getPref( $client, 'band' . $FLATNESSKEY . 'value' ) );
	$request->addResult("Width",      getPref( $client, 'band' . $WIDTHKEY . 'value' ) );
	$request->addResult("Balance",    getPref( $client, 'band' . $BALANCEKEY . 'value' ) );
	$request->addResult("Skew",       getPref( $client, 'band' . $SKEWKEY . 'value' ) );
#	$request->addResult("Depth",      getPref( $client, 'band' . $DEPTHKEY . 'value' ) );
	$request->addResult("AmbAngle",   getPref( $client, 'band' . $AMBANGLEKEY . 'value' ) );
	$request->addResult("AmbDirect",  getPref( $client, 'band' . $AMBDIRECTKEY . 'value' ) );
	$request->addResult("AmbjW",      getPref( $client, 'band' . $AMBJWKEY . 'value' ) );
	$request->addResult("AmbRotateZ", getPref( $client, 'band' . $AMBROTATEZKEY . 'value' ) );
	$request->addResult("AmbRotateY", getPref( $client, 'band' . $AMBROTATEYKEY . 'value' ) );
	$request->addResult("AmbRotateX", getPref( $client, 'band' . $AMBROTATEXKEY . 'value' ) );

	# The current EQ freq/gain values
	my $bandcount = getPref( $client, 'bands' );
	my $cnt = 0;
	for( my $n = 0; $n < $bandcount; $n++ )
	{
		my $f = getPref( $client, 'b' . $n . 'freq' ) || defaultFreq( $client, $n, $bandcount );
		my $v = getPref( $client, 'b' . $n . 'value' ) || 0;
		$request->addResultLoop( 'EQ_loop', $cnt, $f, $v );
		$cnt++;
	}

	# Include the client's "current.json" file if we can
	# decode_json(...)

	my $json = catdir( $pluginTempDataDir, join('_', split(/:/, $client->id())) . '.current.json' );
	open( CURR, "$json" ) || do
	{
		debug( "Can't read from $json" );
		$request->setStatusDone();
		return;
	};
	my @jsdata = <CURR>;
	close(CURR);
	debug( "@jsdata" );
	eval
	{
		my $current = decode_json("@jsdata");
#		debug(Data::Dump::dump($current));
		$cnt = 0;
		my @pts = $current->{'Points_loop'};
#		debug(Data::Dump::dump(@pts));
		foreach my $v ( @pts )
		{
			my @vv = @$v;
			foreach my $f( @vv )
			{
				my %h = %$f;
				foreach my $ff( keys %h )
				{
					$request->addResultLoop( 'Points_loop', $cnt, $ff, $h{$ff} );
					$cnt++;
				}
			}
		}
	}; # ignore exceptions

	$request->setStatusDone();
}


# CLI command to get lists of filters and presets

sub getFiltersListNoNone
{
	my $client = shift;
	my $folder = shift;
	my $nopath = shift;
	my %impulses = ();

	my $types = qr/\.(?:(wav))$/i;
	opendir( DIR, $folder ) or do { return %impulses; };
	for my $item ( readdir(DIR) )
	{
		my $itemPath = $item;
		my $fullPath = catdir( $folder, $item );
		if( -f $fullPath )
		{
			if( $item =~ $types )
			{
				$item =~ s/\.(?:(wav))$//i;
				$impulses{$nopath ? $itemPath : $fullPath} = $item;
			}
		}
	}
	closedir( DIR );
	return %impulses;
}

sub getFiltersList
{
	my $client = shift;
	my $folder = shift;
	my $nopath = shift;
	my %impulses = ( '-' => $client->string('PLUGIN_SQUEEZEDSP_FILTERNONE') );
	my %more = getFiltersListNoNone( $client, $folder, $nopath );
	@impulses{keys %more} = values %more;
	return %impulses;
}

sub currentFilter
{
	my $client = shift;
	return getPref( $client, 'filter' ) || '-';
}


sub filtersQuery
{
	my $request = shift;
	my $client = $request->client();
	debug( "query: filters" );

	if( $request->isNotQuery([[$thistag . '.filters']]) )
	{
		$request->setStatusBadDispatch();
		return;
	}

	# return "Filter_loop" and "Matrix_loop" with list of the available filters
	# and "Preset_loop" with list of the available presets
	# (only their short names, not full paths)

	my %filters = getFiltersListNoNone( $client, $pluginImpulsesDataDir, 1 );
	my $cnt = 0;
	foreach my $ff( sort { uc($a) cmp uc($b) } keys %filters )
	{
		$request->addResultLoop( 'Filter_loop', $cnt, 0, $ff );
		$cnt++;
	}

	%filters = getFiltersListNoNone( $client, $pluginMatrixDataDir, 1 );
	$cnt = 0;
	foreach my $ff( sort { uc($a) cmp uc($b) } keys %filters )
	{
		$request->addResultLoop( 'Matrix_loop', $cnt, 0, $ff );
		$cnt++;
	}

	my %presets = getPresetsListNoNone( $client, 1 );
	$cnt = 0;
	foreach my $ff( sort { uc($a) cmp uc($b) } keys %presets )
	{
		$request->addResultLoop( 'Preset_loop', $cnt, 0, $ff );
		$cnt++;
	}

	$request->setStatusDone();
}


# CLI command to set a prefs value
sub setvalCommand
{
	my $request = shift;
	my $client = $request->client();
	debug( "command: setval" );

	if( $request->isNotQuery([[$thistag . '.setval']]) )
	{
		oops( $client, undef, "setval not command" );
		$request->setStatusBadDispatch();
		return;
	}

	my $key = $request->getParam('key');
	if( !$key )
	{
		oops( $client, undef, "setval, no key!" );
		$request->setStatusBadDispatch();
		return;
	}

	my $val = $request->getParam('val');
	debug( "command: setval($key,$val)" );

	# Check this command is OK
	my %cmds = ();
	$cmds{'Amb'}        = 'ambtype';
	$cmds{'Bands'}      = 'bands';
	$cmds{'SigGen'}     = 'siggen';
	$cmds{'SigFreq'}    = 'sigfreq';
	$cmds{'Filter'}     = 'filter';
	$cmds{'Matrix'}     = 'matrix';
	$cmds{'Preset'}     = 'preset';
	# Quietness etc can be called by friendly-name (e.g. from web ui) or by internal-name (e.g. from jive)
	$cmds{'Quietness'}  = 'band' . $QUIETNESSKEY . 'value';
	$cmds{'Flatness'}   = 'band' . $FLATNESSKEY . 'value';
	$cmds{'Width'}      = 'band' . $WIDTHKEY . 'value';
	$cmds{'Balance'}    = 'band' . $BALANCEKEY . 'value';
	$cmds{'Skew'}       = 'band' . $SKEWKEY . 'value';
	$cmds{'AmbAngle'}   = 'band' . $AMBANGLEKEY . 'value';
	$cmds{'AmbDirect'}  = 'band' . $AMBDIRECTKEY . 'value';
	$cmds{'AmbjW'}      = 'band' . $AMBJWKEY . 'value';
	$cmds{'AmbRotateZ'} = 'band' . $AMBROTATEZKEY . 'value';
	$cmds{'AmbRotateY'} = 'band' . $AMBROTATEYKEY . 'value';
	$cmds{'AmbRotateX'} = 'band' . $AMBROTATEXKEY . 'value';
	$cmds{'band' . $QUIETNESSKEY . 'value'}  = 'band' . $QUIETNESSKEY . 'value';
	$cmds{'band' . $FLATNESSKEY . 'value'}   = 'band' . $FLATNESSKEY . 'value';
	$cmds{'band' . $WIDTHKEY . 'value'}      = 'band' . $WIDTHKEY . 'value';
	$cmds{'band' . $BALANCEKEY . 'value'}    = 'band' . $BALANCEKEY . 'value';
	$cmds{'band' . $SKEWKEY . 'value'}       = 'band' . $SKEWKEY . 'value';
	$cmds{'band' . $AMBANGLEKEY . 'value'}   = 'band' . $AMBANGLEKEY . 'value';
	$cmds{'band' . $AMBDIRECTKEY . 'value'}  = 'band' . $AMBDIRECTKEY . 'value';
	$cmds{'band' . $AMBJWKEY . 'value'}      = 'band' . $AMBJWKEY . 'value';
	$cmds{'band' . $AMBROTATEZKEY . 'value'} = 'band' . $AMBROTATEZKEY . 'value';
	$cmds{'band' . $AMBROTATEYKEY . 'value'} = 'band' . $AMBROTATEYKEY . 'value';
	$cmds{'band' . $AMBROTATEXKEY . 'value'} = 'band' . $AMBROTATEXKEY . 'value';

	my $bandcount = getPref( $client, 'bands' );
	for( my $n = 0; $n < $bandcount; $n++ )
	{
		$cmds{ 'b' . $n . 'freq' }  = 'b' . $n . 'freq';
		$cmds{ 'b' . $n . 'value' } = 'b' . $n . 'value';
	}

	my $prf = $cmds{$key};
	debug( "command: setval($key=" . $prf . ")" );

	if( !defined($prf) )
	{
		oops( $client, undef, "setval, key $key is not valid!" );
		$request->setStatusBadDispatch();
		return;
	}
	if( $prf eq 'bands' )
	{
		# special treatment since this affects each band value

		

		# Set the band count
		setBandCount( $client, $val );

		# ShowBriefly to tell jive users that the band count has been set
		my $line = $client->string('PLUGIN_SQUEEZEDSP_CHOSEN_BANDS');
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );
		
=pod remove jive menu stuff as we are not using it
		# First clear out the old Jive top menu, since it will change
		jiveClearTopMenu( $client );
		# Refresh the Jive main menu
		my @menuItems = jiveTopMenu( $client );
		Slim::Control::Jive::registerPluginMenu( \@menuItems, $thistag, $client );
		Slim::Control::Jive::refreshPluginMenus( $client );
=cut
	}
	elsif( $prf eq 'filter' || $prf eq 'matrix' )
	{
		# incoming value is just file name, no path, no extension
		setFilterValue( $client, $prf, $val );
	}
	elsif( $prf eq 'preset' )
	{
		# incoming value is the name of an *existing preset* - load it
		loadPresetFile( $client, $val );
	}
	elsif( $prf eq 'siggen' )
	{
		setSigGen( $client, $val );
	}
	elsif( $prf eq 'sigfreq' )
	{
		setSigFreq( $client, $val );
	}
	else
	{
		# Set the value
		setPref( $client, $prf, $val );

		# To find something appropriate to display, we could look up the $prf
		# in the main menu's items (yuk!).  But easier just to say "ok, got it".

		my $line = $client->string('PLUGIN_SQUEEZEDSP_CHOSEN_VALUE');
		#displays an alert on any jive enabled client
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 1 } );
	}
	$request->setStatusDone();
}


sub setFilterValue( $client, $prf, $val )
{
	my ( $client, $prf, $val ) = @_;
	my $path;
	if( $val eq '-' || $val eq '' )
	{
		# that's OK
		setPref( $client, $prf, $val );
		my $msg = ( $prf eq 'matrix' ) ? 'PLUGIN_SQUEEZEDSP_CHOSEN_MATRIXFILTERNONE' : 'PLUGIN_SQUEEZEDSP_CHOSEN_RCFILTERNONE';
		my $line = $client->string( $msg );
		#displays an alert on any jive enabled client
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );
		return;
	}
	if( $prf eq 'matrix' )
	{
		$path = catdir( $pluginMatrixDataDir, $val );
	}
	else
	{
		$path = catdir( $pluginImpulsesDataDir, $val );
	}
	if( -f $path )
	{
		setPref( $client, $prf, $path );
		my $msg = ( $prf eq 'matrix' ) ? 'PLUGIN_SQUEEZEDSP_CHOSEN_MATRIXFILTER' : 'PLUGIN_SQUEEZEDSP_CHOSEN_RCFILTER';
		my $line = $client->string( $msg );
		#displays an alert on any jive enabled client
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );
	}
	else
	{
		debug( "Can't set, file $path does not exist" );
	}
}


sub getPresetsListNoNone
{
	my $client = shift;
	my $nopath = shift;
	my %presets = ();

	my $types = qr/\.(?:(preset\.conf))$/i;
	if( opendir( DIR, $pluginSettingsDataDir ) )
	{
		for my $item ( readdir(DIR) )
		{
			my $itemPath = $item;
			my $fullPath = catdir( $pluginSettingsDataDir, $item );
			if( -f $fullPath )
			{
				if( $item =~ $types )
				{
					$item =~ s/\.(?:(preset\.conf))$//i;
					$presets{$nopath ? $itemPath : $fullPath} = $item;
				}
			}
		}
		closedir( DIR );
	}
	return %presets
}

sub getPresetsList
{
	my $client = shift;
	my $nopath = shift;
	my %presets = ( '-' => $client->string('PLUGIN_SQUEEZEDSP_SAVEPRESETAS') );
	my %more = getPresetsListNoNone( $client, $nopath );
	@presets{keys %more} = values %more;
	return %presets;
}

sub initPresetsChoices
{
	my $client = shift;
	my %presets = getPresetsList( $client, 0 );
	@presetsMenuValues = sort { uc($a) cmp uc($b) } keys %presets;
	@presetsMenuChoices = map $presets{$_}, @presetsMenuValues;
}


sub loadPresetFile( $client, $val )
{
	my ( $client, $val ) = @_;
	my $path = catdir( $pluginSettingsDataDir, $val );
	if( -f $path )
	{
		loadPrefs( $client, $path, undef );
	}
	else
	{
		debug( "Can't set, file $path does not exist" );
	}

}


# CLI command to set an EQ value (freq and gain both at once)
# (not used from Jive, only from web UI)
sub seteqCommand
{
	my $request = shift;
	my $client = $request->client();
	debug( "command: seteq" );

	if( $request->isNotQuery([[$thistag . '.seteq']]) )
	{
		oops( $client, undef, "seteq not command" );
		$request->setStatusBadDispatch();
		return;
	}

	my $band = $request->getParam('band');
	if( !defined($band) )
	{
		oops( $client, undef, "seteq, no band!" );
		$request->setStatusBadDispatch();
		return;
	}

	my $bandcount = getPref( $client, 'bands' );
	if( $band >= $bandcount )
	{
		oops( $client, undef, "seteq, band $band count $bandcount!" );
		$request->setStatusBadDispatch();
		return;
	}
	my $freq = $request->getParam('freq');
	my $gain = $request->getParam('gain');
	debug( "command: seteq($band,$freq,$gain)" );

	setPref( $client, 'b' . $band . 'freq', $freq );
	setPref( $client, 'b' . $band . 'value', $gain );
	$request->setStatusDone();
}


sub saveasCommand
{
	my $request = shift;
	my $client = $request->client();
	debug( "command: saveas" );
	debug(Data::Dump::dump($request));

	if( $request->isNotQuery([[$thistag . '.saveas']]) )
	{
		oops( $client, undef, "saveas not command" );
		$request->setStatusBadDispatch();
		return;
	}

	my $key = $request->getParam('preset');
	if( !$key )
	{
		oops( $client, undef, "saveas, no preset name!" );
		$request->setStatusBadDispatch();
		return;
	}

	debug( "command: saveas($key)" );

	my $file = catdir( $pluginSettingsDataDir, join('_', split(/:/, $key)) . '.preset.conf' );
	setPref( $client, 'preset', $file );
	savePrefs( $client, $file );

	my $line = $client->string('PLUGIN_SQUEEZEDSP_PRESET_SAVED');
	#displays an alert on any jive enabled client
	$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );

	$request->setStatusDone();
}



# ----- The templates for slimserver-convert.conf -----


sub template
{
	# find the appropriate template depending on client type
	my $clientID = shift;
	my $client = Slim::Player::Client::getClient( $clientID );
	my $template;
	if( !defined( $client ) )
	{
		debug( "template? client " . $clientID . " not defined!" );
		$template = template_FLAC24();  # bah
	}

	elsif( Slim::Player::Client::contentTypeSupported( $client, 'flc' ) && ( $client->model() ne "softsqueeze" ) )
	{
		
			# if the player supports flac, use it
			# except for softsqueeze, which doesn't decode FLAC24 properly
			debug( "client " . $clientID . " is " . $client->model() . ", using FLAC24" );
			$template = template_FLAC24();

	}
	else
	{
			debug( "client " . $clientID . " is " . $client->model() . ", using WAV16" );
			$template = template_WAV16();
	}

	# Fix up the variable bits
	my $pipeout;
	my $pipenul;
	if( Slim::Utils::OSDetect::OS() eq 'win' )
	{
		$pipeout = '#PIPE#';
		$pipenul = '';
	}
	else
	{
		$pipeout = '/dev/fd/4';
		$pipenul = '4>&1 1>/dev/null'
	}

	$template =~ s/\$CONVAPP\$/$convolver/g;
	$template =~ s/\$CLIENTID\$/$clientID/g;
	$template =~ s/\$PIPEOUT\$/$pipeout/g;
	$template =~ s/\$PIPENUL\$/$pipenul/g;
	return $template;
}



1;
