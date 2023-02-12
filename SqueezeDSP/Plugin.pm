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
	
	0.0.11	Fox: removing Debug settings - ready for release
	0.0.7 - Fox:
			Using JSON files for config - that is app config and for the DSP/EQ settings.
			fixed housekeeping issue
	0.0.5 - Fox:
			This is a fully working initial version
			All code has been migrated to refer to SqueezeDSP
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
use JSON;
#use JSON::XS qw(decode_json);
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
my $revision = "0.0.11";
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
#my $modeAmbisonic    = "PLUGIN.SqueezeDSP.Ambisonic";

my $log = Slim::Utils::Log->addLogCategory({ 'category' => 'plugin.' . $thistag, 'defaultLevel' => 'WARN', 'description'  => $thisapp });

my $prefs = preferences('plugin.' . $thistag);

# these sort alphabetically
my $BALANCEKEY = 'B';   # balance (left/right amplitude alignment)
my $DELAYKEY = 'S';      # skew    (left/right time alignment, under "settings")
my $LOUDNESSKEY = 'L';


my $SETTINGSKEY = "-s-";
my $PRESETSKEY = "-p-";
my $ERRORKEY = "-";
=pod no ambi stuff
my $FLATNESSKEY = 'F';
my $DEPTHKEY = 'D';     # depth   (matrix filter time alignment, under "settings")
my $WIDTHKEY = 'W';     # width   (mid/side amplitude alignment)

my $AMBANGLEKEY = "X1";
my $AMBDIRECTKEY = "X2";
my $AMBJWKEY = "X3";
my $AMBROTATEZKEY = "XR1";
my $AMBROTATEYKEY = "XR2";
my $AMBROTATEXKEY = "XR3";
=cut
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
my @fq0 = ( 0 );
# original values
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
#no measurements made
#my $pluginMeasurementDataDir; # <appdata>\squeezedsp\Measurement  used for measurement sweeps and noise samples
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
	#$log->error( "Fox: " .  $txt . "\n" );
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
	if( $item eq $LOUDNESSKEY )
	{
		$sign = '';
		$labl = '';
		$extra = ( $valu == 0 ) ? ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_LOUDNESS_OFF' ) : '';
	}
	

	
	elsif( ($item eq $DELAYKEY)) # || ($item eq $DEPTHKEY) )
	{
		$labl = ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_SAMPLES' );
		$extra = '';
	}
	
	return  $valu . $labl . $extra;
}

# Format a frequency/band
sub freqlabel
{
	my $client = shift;
	my $item = shift;
	my $bandcount = getPref( $client, 'EQBands' );
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
	my $bandcount = shift || getPref( $client, 'EQBands' );
	my @bandfreqs = defaultFreqs( $client, $bandcount );
	return $bandfreqs[$item];
}

sub defaultFreqs
{
	my $client = shift;
	# re-use the existing defaults but fill in the gaps by using the next highest default set
	# easier than re-writing or putting a full set of defaults in that no-one will use
	my $bandcount = shift || getPref( $client, 'EQBands' ) || 2;
	my @bandfreqs = @fq2;
	if( $bandcount==0 )
	{
		@bandfreqs = @fq0;
	}
	elsif($bandcount<=2 )
	{
		@bandfreqs = @fq2;
	}
	elsif( $bandcount==3 )
	{
		@bandfreqs = @fq3;
	}
	elsif( $bandcount<=5 )
	{
		@bandfreqs = @fq5;
	}
	elsif( $bandcount<=9 )
	{
		@bandfreqs = @fq9;
	}
	elsif( $bandcount<=15 )
	{
		@bandfreqs = @fq15;
	}
	elsif( $bandcount<=31 )
	{
		@bandfreqs = @fq31;
	}
	else
	{
		@bandfreqs = @fq31;
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
	#Slim::Formats::Playlists->registerParser('amb', 'Slim::Formats::Wav');
	#Slim::Formats::Playlists->registerParser('uhj', 'Slim::Formats::Wav');

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

#	$pluginMeasurementDataDir = catdir( $pluginDataDir, 'Measurement' );
#	mkdir( $pluginMeasurementDataDir );

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
	#need to copy camilladsp exe too.
	#my $cambinsrc = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin', $bin);
	
	my $camilladsp = "camilladsp";
	#rather than try and work out paths agin lets just re-use this for CamillaDSP
	my $cambinsrc = $class->binaries;
	$cambinsrc =~ s/$thisapp/$camilladsp/;
	my $cambinsrc = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin', $cambinsrc);
	
	my $cambinout = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/", $camilladsp . $binExtension);;
	debug('camilla binary source path: ' . $cambinsrc . ' and target path: ' .  $cambinout );
	debug('standard binary path: ' . $bin);
	# copy correct binary into bin folder unless it already exists
	unless (-e $bin) {
		debug('copying binary' . $exec );
		copy( $exec , $bin)  or die "copy failed: $!";
		copy( $cambinsrc , $cambinout)  or die "copy failed: $!";
		#we know only windows has an extension, now set the binary
		if ( $binExtension == "") {
				debug('executable not having \'x\' permission, correcting');
				chmod (0555, $bin);
				chmod (0555, $cambinout);
				
		}	
	}
	
	#do any cleanup
	housekeeping();
	#do any app config settings, simplifies handover to SqueezeDSP app
	my $appConfig = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/", 'squeezeDSP_config.json');
	
	my $soxbinary = Slim::Utils::Misc::findbin('sox');
	#needs updating to amend json...
	amendPluginConfig($appConfig, 'soxExe', $soxbinary);
	# find folder for log file

	my $logfile = catdir(Slim::Utils::OSDetect::dirsFor('log'), "squeezedsp.log");

	amendPluginConfig($appConfig, 'logFile',$logfile);
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
	unlink glob catdir ( $pluginTempDataDir, "/",  '*.filter.wav');
	# the grep step filters out files matching current.json pattern as these we want to keep!
	unlink grep { !/\current.json/ } glob catdir ( $pluginTempDataDir , "/", '*.json');
}

sub LoadJSONFile
{
	my $myinputJSONfile = shift;

	my $txt = do {                             			# do block to read file into variable
		local $/;                              			# slurp entire file
		open my $fh, "<", $myinputJSONfile or die $!;  	# open for reading
		<$fh>;                                 			# read and return file content
		
	};
	my $myoutputData = decode_json($txt);
	#print Dumper $myoutputData;
	
	return ($myoutputData);
	
}

sub SaveJSONFile
{
	my $myinputData = shift;
	my $myoutputJSONfile = shift;
	
	open my $fh, ">",$myoutputJSONfile;
	#print $fh encode_json($myinputData);
	#above works, but we want nice formatting - so
	print $fh JSON->new->pretty->encode($myinputData);
	close $fh;
	return ;
	
}

sub amendPluginConfig
{
	#routine for adding a value to a key in the app config.
	my $myJSONFile = shift;
	my $myKey = shift;
	my $myValue = shift;
		
	debug('Fox amend file: ' . $myJSONFile . ' for key =' . $myKey . ' value= ' . $myValue );
	#load JSON -> Amend -> save
	my $myConfig = LoadJSONFile ($myJSONFile);
	$myConfig->{settings}->{$myKey}  = $myValue;
	SaveJSONFile ($myConfig, $myJSONFile );

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

	#my @menuItems = jiveTopMenu( $client );
	#Slim::Control::Jive::registerPluginMenu( \@menuItems, $thistag, $client );

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
		Slim::Web::Pages->addPageLinks("plugins", { $class->getDisplayName => 'plugins/SqueezeDSP/index.html' });
		
		
		Slim::Web::Pages->addPageLinks("icons",   { $class->getDisplayName => '/plugins/SqueezeDSP/images/SqueezeDSP_svg.png' });
		#Slim::Web::Pages->addPageLinks("icons",   { $class->getDisplayName => '/plugins/SqueezeDSP/images/squeezedsp_col_svg.png' });
		
		#Slim::Web::Pages->addPageLinks("icons",   { $class->getDisplayName => '/Plugins/SqueezeDSP/SqueezeDSP.png' });
		
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
	#get the config file for the current player (client)
	my $client = shift;
	
	#return catdir( $pluginSettingsDataDir, join('_', split(/:/, $client->id())) . '.settings.conf' );
	my $file = catdir( $pluginSettingsDataDir, join('_', split(/:/, $client->id())) . ".settings.json" );
		
	return $file
}


sub getPref
{
	#get the value of the named pref for the player (client)
	#not very efficient, only using for defaults if I can

	my ( $client, $prefName ) = @_;
	
	my $file = getPrefFile( $client );
	my $myConfig = LoadJSONFile ($file);
	#return $myConfig->{Client}->{$prefName};
	#return $myConfig->client( $client )->get( $prefName );
	#====Added because of greater data complexity
	my $returnval;
			if ( $prefName eq "Delay.delay" ) { $returnval =  $myConfig->{Client}->{Delay}->{delay}  ; }
		elsif  ( $prefName eq  "Loudness.enabled" ) { $returnval =  $myConfig->{Client}->{Loudness}->{enabled}  ; }
		elsif  ( $prefName eq  "Loudness.low_boost" ) { $returnval =  $myConfig->{Client}->{Loudness}->{low_boost}  ; }
		elsif  ( $prefName eq  "Loudness.high_boost" ) { $returnval =  $myConfig->{Client}->{Loudness}->{high_boost}  ; }
		elsif  ( $prefName eq  "Loudness.reference_level" ) { $returnval =  $myConfig->{Client}->{Loudness}->{reference_level}  ;}
		elsif  ( $prefName eq  "Loudness.ramp_time" ) { $returnval =  $myConfig->{Client}->{Loudness}->{ramp_time}  ; }
		elsif  ( $prefName eq  "Highpass.enabled"  )   {    $returnval =  $myConfig->{Client}->{Highpass}->{enabled}  ;      }
		elsif  ( $prefName eq  "Highpass.freq"  )   {    $returnval =  $myConfig->{Client}->{Highpass}->{freq}  ;      }
		elsif  ( $prefName eq  "Highpass.q"  )   {    $returnval =  $myConfig->{Client}->{Highpass}->{q}  ;      }
		elsif  ( $prefName eq  "Highshelf.enabled"  )   {    $returnval =  $myConfig->{Client}->{Highshelf}->{enabled}  ;      }
		elsif  ( $prefName eq  "Highshelf.freq"  )   {    $returnval =  $myConfig->{Client}->{Highshelf}->{freq}  ;      }
		elsif  ( $prefName eq  "Highshelf.gain"  )   {    $returnval =  $myConfig->{Client}->{Highshelf}->{gain}  ;      }
		elsif  ( $prefName eq  "Highshelf.slope"  )   {    $returnval =  $myConfig->{Client}->{Highshelf}->{slope}  ;      }
		elsif  ( $prefName eq  "Lowpass.enabled"  )   {    $returnval =  $myConfig->{Client}->{Lowpass}->{enabled}  ;      }
		elsif  ( $prefName eq  "Lowpass.freq"  )   {    $returnval =  $myConfig->{Client}->{Lowpass}->{freq}  ;      }
		elsif  ( $prefName eq  "Lowpass.q"  )   {    $returnval =  $myConfig->{Client}->{Lowpass}->{q}  ;      }
		elsif  ( $prefName eq  "Lowshelf.enabled"  )   {    $returnval =  $myConfig->{Client}->{Lowshelf}->{enabled}  ;      }
		elsif  ( $prefName eq  "Lowshelf.freq"  )   {    $returnval =  $myConfig->{Client}->{Lowshelf}->{freq}  ;      }
		elsif  ( $prefName eq  "Lowshelf.gain"  )   {    $returnval =  $myConfig->{Client}->{Lowshelf}->{gain}  ;      }
		elsif  ( $prefName eq  "Lowshelf.slope"  )   {    $returnval =  $myConfig->{Client}->{Lowshelf}->{slope}  ;      }
	    	else
		{	
			 $returnval =  $myConfig->{Client}->{$prefName}  ;
		}
		return $returnval ;
	
	
}

sub setPref
{
	# set the named preference and value for the named player(client)
	# set the server maintained value and re-write the pref file if the value is different
	my ( $client, $prefName, $prefValue ) = @_;
	my $file = getPrefFile( $client );
	my $myConfig = LoadJSONFile ($file);
	debug( "setPref " . $prefName . "=" . $prefValue );
	# Control structure is not flat!
		if ( $prefName eq "Delay.delay" )
		{
			debug( "setPref in Delay Delay " . $prefName . " = " . $prefValue );
			$myConfig->{Client}->{Delay}->{delay} = $prefValue ;
		}
		elsif  ( $prefName eq  "Loudness.enabled" )
		{
			$myConfig->{Client}->{Loudness}->{enabled} = $prefValue ;			
		}
		elsif  ( $prefName eq  "Loudness.low_boost" )
		{
			$myConfig->{Client}->{Loudness}->{low_boost} = $prefValue ;			
		}
		elsif  ( $prefName eq  "Loudness.high_boost" )
		{
			$myConfig->{Client}->{Loudness}->{high_boost} = $prefValue ;			
		}
		elsif  ( $prefName eq  "Loudness.reference_level" )
		{
			$myConfig->{Client}->{Loudness}->{reference_level} = $prefValue ;			
		}
		elsif  ( $prefName eq  "Loudness.ramp_time" )
		{
			$myConfig->{Client}->{Loudness}->{ramp_time} = $prefValue ;			
		}
		elsif  ( $prefName eq  "Highpass.enabled"  )   {    $myConfig->{Client}->{Highpass}->{enabled} = $prefValue ;      }
		elsif  ( $prefName eq  "Highpass.freq"  )   {    $myConfig->{Client}->{Highpass}->{freq} = $prefValue ;      }
		elsif  ( $prefName eq  "Highpass.q"  )   {    $myConfig->{Client}->{Highpass}->{q} = $prefValue ;      }
		elsif  ( $prefName eq  "Highshelf.enabled"  )   {    $myConfig->{Client}->{Highshelf}->{enabled} = $prefValue ;      }
		elsif  ( $prefName eq  "Highshelf.freq"  )   {    $myConfig->{Client}->{Highshelf}->{freq} = $prefValue ;      }
		elsif  ( $prefName eq  "Highshelf.gain"  )   {    $myConfig->{Client}->{Highshelf}->{gain} = $prefValue ;      }
		elsif  ( $prefName eq  "Highshelf.slope"  )   {    $myConfig->{Client}->{Highshelf}->{slope} = $prefValue ;      }
		elsif  ( $prefName eq  "Lowpass.enabled"  )   {    $myConfig->{Client}->{Lowpass}->{enabled} = $prefValue ;      }
		elsif  ( $prefName eq  "Lowpass.freq"  )   {    $myConfig->{Client}->{Lowpass}->{freq} = $prefValue ;      }
		elsif  ( $prefName eq  "Lowpass.q"  )   {    $myConfig->{Client}->{Lowpass}->{q} = $prefValue ;      }
		elsif  ( $prefName eq  "Lowshelf.enabled"  )   {    $myConfig->{Client}->{Lowshelf}->{enabled} = $prefValue ;      }
		elsif  ( $prefName eq  "Lowshelf.freq"  )   {    $myConfig->{Client}->{Lowshelf}->{freq} = $prefValue ;      }
		elsif  ( $prefName eq  "Lowshelf.gain"  )   {    $myConfig->{Client}->{Lowshelf}->{gain} = $prefValue ;      }
		elsif  ( $prefName eq  "Lowshelf.slope"  )   {    $myConfig->{Client}->{Lowshelf}->{slope} = $prefValue ;      }

		
    	else
		{	
			$myConfig->{Client}->{$prefName} = $prefValue ;
		}

	
	SaveJSONFile ( $myConfig, $file );
}

=pod commenting out
sub setPref_old
{
# set the named preference and value for the named player(client)
# set the server maintained value and re-write the pref file if the value is different

	my ( $client, $prefName, $prefValue ) = @_;
	my $prev = $prefs->client( $client )->get( $prefName );
	$prefs->client( $client )->set( $prefName, $prefValue );

	unless( $prefValue eq $prev )
	{
		debug( "setPref " . $prefName . "=" . $prefValue );

		unless( $prefName eq 'mainmenu' || $prefName eq 'settingsmenu' || $prefName eq 'equalizationmenu' )
		{
			# write to {client}.settings.conf (as JSON, for easy consumption by the convolver)
			my $file = getPrefFile( $client );
			savePrefs( $client, $file );
		}
	}
}
=cut


sub delPref
{
	#remove the named preference for the player (client)

	my ( $client, $prefName ) = @_;
	$prefs->client( $client )->remove( $prefName ) if $prefs->client( $client )->exists( $prefName );
}

sub savePreset
{
	#much easier to simply copy the existing config to the preset location.

	my $client = shift;
	my $myPresetFile = shift;
	my $SourceFile = getPrefFile( $client );
	copy($SourceFile, $myPresetFile) or  do { oops( $client, undef, "Preferences could not be saved to $myPresetFile." ); return 0; };
	
}


sub savePrefs
{
#write to JSON file
#amended so that it will only save to a selected preset file
#the client specific file should be dynamic and is now the source for this call.

	my $client = shift;
	my $myJSONFile = shift;
	#set variable to hold, start, seperator  end of line as they are all the same in json
	my ( $vol, $dir, $fil ) = splitpath($myJSONFile);
	my $myTargetConfig = LoadJSONFile ($myJSONFile);
	my $SourceFile = getPrefFile( $client );
	my $mySourceConfig = LoadJSONFile ($SourceFile);
	
	
	debug( "savePrefs " . $fil );
	
	#=============The Writing bit
	
	$myTargetConfig->{Revision} = $revision;
	# The same routine is used for client specific as well as presets
	
	#$myConfig->{Client}->{ID}  = $client->id();
	#$myConfig->{Client}->{Name}  = $client->name;
		
	#$myTargetConfig->{Client}->{LeftBalance}->{parameters}->{gain}  = '-8';
	
	#============Now save to file
	SaveJSONFile ($myTargetConfig, $myJSONFile );

	return 1;
}

sub loadPrefs
{
	# load from a selected JSON file into the client json file
    # getting rid of server cache and just using client json file. Simpler and more robust.
	my ( $client, $file, $desc ) = @_;
	debug( "loadPrefs " . $file );

	unless( -f $file )
	{
		oops( $client, $desc, "File $file not found." );
		return;
	}
	
	# get doc from JSON file
	my $doc = LoadJSONFile ($file);
	#client config file
	my $myJSONFile = getPrefFile( $client );
	my $myConfig = LoadJSONFile ($myJSONFile);
	
	$myConfig->{Revision} = $revision;
	$myConfig->{Client}->{ID} = $client->id();
	$myConfig->{Client}->{Name} = $client->name;
	$myConfig->{Client}->{Preset} = $file;
	$myConfig->{Client}->{FIRWavFile} = $doc->{Client}->{FIRWavFile};
	$myConfig->{Client}->{MatrixFile} = $doc->{Client}->{MatrixFile} ;
	$myConfig->{Client}->{Preamp} = $doc->{Client}->{Preamp} ;
	
	$myConfig->{Client}->{Bypass} = $doc->{Client}->{Bypass} ;
	$myConfig->{Client}->{Balance} = $doc->{Client}->{Balance} ;
	$myConfig->{Client}->{Delay}->{delay} = $doc->{Client}->{Delay}->{delay} ;
	$myConfig->{Client}->{Delay}->{units} = $doc->{Client}->{Delay}->{units} ;
	$myConfig->{Client}->{EQBands} = $doc->{Client}->{EQBands};
	$myConfig->{Client}->{Loudness}->{enabled} = $doc->{Client}->{Loudness}->{enabled} ;
	$myConfig->{Client}->{Loudness}->{low_boost} =$doc->{Client}->{Loudness}->{low_boost} ;	
	$myConfig->{Client}->{Loudness}->{low_boost} =$doc->{Client}->{Loudness}->{low_boost} ;			
	$myConfig->{Client}->{Loudness}->{high_boost} = $doc->{Client}->{Loudness}->{high_boost} ;
	$myConfig->{Client}->{Loudness}->{reference_level} = $doc->{Client}->{Loudness}->{reference_level} ;			
	$myConfig->{Client}->{Loudness}->{ramp_time} = $doc->{Client}->{Loudness}->{ramp_time} ;	
	
	$myConfig->{Client}->{Highpass}->{enabled} = $doc->{Client}->{Highpass}->{enabled} ;
	$myConfig->{Client}->{Highpass}->{freq} = $doc->{Client}->{Highpass}->{freq} ;
	$myConfig->{Client}->{Highpass}->{q} = $doc->{Client}->{Highpass}->{q} ;
	$myConfig->{Client}->{Highshelf}->{enabled} = $doc->{Client}->{Highshelf}->{enabled} ;
	$myConfig->{Client}->{Highshelf}->{freq} = $doc->{Client}->{Highshelf}->{freq} ;
	$myConfig->{Client}->{Highshelf}->{gain} = $doc->{Client}->{Highshelf}->{gain} ;
	$myConfig->{Client}->{Highshelf}->{slope} = $doc->{Client}->{Highshelf}->{slope} ;
	$myConfig->{Client}->{Lowpass}->{enabled} = $doc->{Client}->{Lowpass}->{enabled} ;
	$myConfig->{Client}->{Lowpass}->{freq} = $doc->{Client}->{Lowpass}->{freq} ;
	$myConfig->{Client}->{Lowpass}->{q} = $doc->{Client}->{Lowpass}->{q} ;
	$myConfig->{Client}->{Lowshelf}->{enabled} = $doc->{Client}->{Lowshelf}->{enabled} ;
	$myConfig->{Client}->{Lowshelf}->{freq} = $doc->{Client}->{Lowshelf}->{freq} ;
	$myConfig->{Client}->{Lowshelf}->{gain} = $doc->{Client}->{Lowshelf}->{gain} ;
	$myConfig->{Client}->{Lowshelf}->{slope} = $doc->{Client}->{Lowshelf}->{slope} ;


	
	
	my $bandcount = $doc->{Client}->{EQBands};
	# Read bands from conf, but clear them first
	
	my $myBand = "";
	for ( my $n = 0; $n<=$bandcount; $n++ )
	{
		
		$myBand = 'EQBand_' . $n;
		$myConfig->{Client}->{$myBand}->{freq} = $doc->{Client}->{$myBand}->{freq};
		$myConfig->{Client}->{$myBand}->{gain} = $doc->{Client}->{$myBand}->{gain};
		$myConfig->{Client}->{$myBand}->{q} =  $doc->{Client}->{$myBand}->{q};
	}
	
	#now write the file
	SaveJSONFile ( $myConfig, $myJSONFile );
	
	# add anything that might be missing - should not overwrite
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
	#tries to map old eq values to current equailzer when band count changes
	#only going to do the deletion for now
	my $client = shift;
	my $bandcount = shift;
	$bandcount = int( $bandcount );
	# 0 is an allowable value
	#return if( $bandcount<2 );
	
	# get doc from JSON file
	#my $doc = LoadJSONFile ($file);
	#client config file
	my $myJSONFile = getPrefFile( $client );
	my $myConfig = LoadJSONFile ($myJSONFile);
	# the old routine tried to calculate gain for similar bands if the count changed.
	# whilst useful, this is a lot of work and probably going to be changed anyway,
	
	my $prevcount = ( $myConfig->{Client}->{EQBands} || 0 );
	debug( "setBandCount " . $bandcount . ", was " . $prevcount );
	if( $bandcount != $prevcount )
	{
		# When the number of bands changes
		my $myBand = "";
		
		# Make a hashtable of the current values/frequencies
		my %h = ();
		my %q = ();
		for( my $n=0; $n<$prevcount; $n++ )
		{
			$myBand = 'EQBand_' . $n;
			my $f  = $myConfig->{Client}->{$myBand}->{freq}  || defaultFreq( $client, $n, $prevcount );
			$h{$f} = $myConfig->{Client}->{$myBand}->{gain} || 0;
			$q{$f} = $myConfig->{Client}->{$myBand}->{q} || 1.41;
		}

		# Get an array of the default band frequencies we'll map to
		my @freqs = defaultFreqs( $client, $bandcount );

		# Where the frequency matches, use the closest old value
		for( my $n=0; $n<$bandcount; $n++ )
		{
			my $f = $freqs[$n];
			
			my $oldf = closestFreq($f,%h);
			
			my $oldv = $h{$oldf};
			my $oldq = $q{$oldf};
			$myBand = 'EQBand_' . $n;
			
			debug( "closest to $f is $oldf (=$oldv)" );
			# now that we can amend frequence we want the actual old value as saved
			
			#$myConfig->{Client}->{$myBand}->{freq} =  $f ;
			$myConfig->{Client}->{$myBand}->{freq} =  $oldf ;
			$myConfig->{Client}->{$myBand}->{gain} = $oldv || 0 ;
			$myConfig->{Client}->{$myBand}->{q} = $oldq || 1.41 ;
		}

		# Delete any unused prefs
		for( my $n=$bandcount; $n<$prevcount; $n++ )
		{
			$myBand = 'EQBand_' . $n;
			delete $myConfig->{Client}->{$myBand};
			#delPref( $client, $myBand  );
			#delPref( $client, 'b' . $n . 'gain' );
			#delPref( $client, 'b' . $n . 'q' );
		}
	}
	$myConfig->{Client}->{EQBands} = $bandcount;
	SaveJSONFile ($myConfig, $myJSONFile );
}

sub defaultPrefs
{
	my $client = shift;
	my $p;
	
	# only set a value to a default if it does not exist
	$p = 'Bypass';          	setPref( $client, $p, 0 )  	unless defined ( getPref( $client, $p ))	;
	$p = 'EQBands'; 		 	setBandCount( $client, 2 ) 	unless  defined ( getPref( $client, $p ))	;       
	#$p = 'Loudness';       	setPref( $client, $p, 0 )  ; #unless getPref( $client, $p ); }
	$p = 'Balance';          	setPref( $client, $p, 0 )  	unless defined ( getPref( $client, $p ))	;      
	$p = 'Loudness.enabled'; 	setPref( $client, $p, 0 )   unless defined ( getPref( $client, $p ))	;    
	$p = 'Preamp'; 			    setPref( $client, $p, -12 ) unless defined ( getPref( $client, $p ))	;
	$p = 'Delay.delay';  	    setPref( $client, $p, 0 )  	unless defined ( getPref( $client, $p ))	;  
	$p = 'Highpass.enabled';    setPref( $client,$p, 0 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Highpass.freq';       setPref( $client,$p, 30 ) 	unless defined ( getPref( $client, $p ))	; 
	$p = 'Highpass.q';      	setPref( $client,$p, 1 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Highshelf.enabled';   setPref( $client,$p, 0 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Highshelf.freq';      setPref( $client,$p, 8000 ) unless defined ( getPref( $client, $p ))	; 
	$p = 'Highshelf.gain';      setPref( $client,$p, 3 ) 	unless defined ( getPref( $client, $p )	); 
	$p = 'Highshelf.slope';   	setPref( $client, $p,6 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowpass.enabled';     setPref( $client,$p, 0 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowpass.freq';        setPref( $client,$p, 20000 ) unless defined ( getPref( $client, $p ))	;  
	$p = 'Lowpass.q';   		setPref( $client, $p,1 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowshelf.enabled';    setPref( $client,$p, 0 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowshelf.freq';       setPref( $client, $p,300 ) 	unless defined ( getPref( $client, $p ))	;  
	$p = 'Lowshelf.gain';       setPref( $client,$p, 6 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowshelf.slope';   	setPref( $client, $p, 6 ) 	unless defined ( getPref( $client, $p ))	;   

	
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
				setPref( $client, "Version", $revision );
			}
		}
	}
}



# ----- The CLI requests -----
# The requests below are mapped via the CLI so that client REST API calls invoke them

# CLI command to get the current status detail
sub currentQuery
{
	#Should be the first call made to load a config
	my $request = shift;
	my $client = $request->client();
	debug( "query: current" );

	if( $request->isNotQuery([[$thistag . '.current']]) )
	{
		$request->setStatusBadDispatch();
		return;
	}
	my $myJSONFile = getPrefFile( $client );
	unless( -f $myJSONFile )
	{
		#create default file if it does not exist
		debug( $client,  "Player Config File $myJSONFile not found. Creating" );
		#need to create file first
		my $myDefault = {Client=>{}};
		SaveJSONFile ($myDefault, $myJSONFile );
		defaultPrefs( $client );
	}
	
	my $myConfig = LoadJSONFile ($myJSONFile);
	
	$request->addResult("Revision",  $revision);
	$request->addResult("ClientName", $client->name);
	# The filters, stripping path but leaving the extension
	
	my $filt = ( $myConfig->{Client}->{MatrixFile}  || '' );
	my ( $vol, $dir, $fil ) = splitpath( $filt );
	$request->addResult("MatrixFile",    $fil );

	$filt = ( $myConfig->{Client}->{FIRWavFile} || '' );
	($vol, $dir, $fil) = splitpath( $filt );
	$request->addResult("FIRWavFile",    $fil );
	
	my $bandcount = $myConfig->{Client}->{EQBands};
	$request->addResult("EQBands",     $bandcount );
	
	$request->addResult("Preamp",     $myConfig->{Client}->{Preamp} );
	$request->addResult("Balance",     $myConfig->{Client}->{Balance} );
	
	$request->addResult("Bypass",     $myConfig->{Client}->{Bypass} );
	$request->addResult("Delay.delay", $myConfig->{Client}->{Delay}->{delay} );
	$request->addResult("Delay.units", $myConfig->{Client}->{Delay}->{units} );
	#problematics
	$request->addResult("Loudness.enabled", $myConfig->{Client}->{Loudness}->{enabled} );
	
	$request->addResult("Highpass.enabled" , $myConfig->{Client}->{Highpass}->{enabled}) ;
	$request->addResult("Highpass.freq" , $myConfig->{Client}->{Highpass}->{freq}) ;
	$request->addResult("Highpass.q" , $myConfig->{Client}->{Highpass}->{q}) ;
	$request->addResult("Highshelf.enabled" , $myConfig->{Client}->{Highshelf}->{enabled}) ;
	$request->addResult("Highshelf.freq" , $myConfig->{Client}->{Highshelf}->{freq}) ;
	$request->addResult("Highshelf.gain" , $myConfig->{Client}->{Highshelf}->{gain}) ;
	$request->addResult("Highshelf.slope" , $myConfig->{Client}->{Highshelf}->{slope}) ;
	$request->addResult("Lowpass.enabled" , $myConfig->{Client}->{Lowpass}->{enabled}) ;
	$request->addResult("Lowpass.freq" , $myConfig->{Client}->{Lowpass}->{freq}) ;
	$request->addResult("Lowpass.q" , $myConfig->{Client}->{Lowpass}->{q}) ;
	$request->addResult("Lowshelf.enabled" , $myConfig->{Client}->{Lowshelf}->{enabled}) ;
	$request->addResult("Lowshelf.freq" , $myConfig->{Client}->{Lowshelf}->{freq}) ;
	$request->addResult("Lowshelf.gain" , $myConfig->{Client}->{Lowshelf}->{gain}) ;
	$request->addResult("Lowshelf.slope" , $myConfig->{Client}->{Lowshelf}->{slope}) ;


	
	
	# The current EQ freq/gain values
	my $myBand = "";
	my $cnt = 0;
	for( my $n = 0; $n < $bandcount; $n++ )
	{
		$myBand = 'EQBand_' . $n;
		my $f = $myConfig->{Client}->{$myBand}->{freq} || defaultFreq( $client, $n, $bandcount );
		my $v = $myConfig->{Client}->{$myBand}->{gain} || 0;
		my $q = $myConfig->{Client}->{$myBand}->{q} || 1.41;
		# Ithink there is only 4 slots available in the result loop so concatenating gain and Q; will split on the client
		$request->addResultLoop( 'EQ_loop', $cnt, $f, $v . '|' . $q );
		$cnt++;
	}

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
		$request->addResultLoop( 'FIRWavFile_loop', $cnt, 0, $ff );
		$cnt++;
	}

	%filters = getFiltersListNoNone( $client, $pluginMatrixDataDir, 1 );
	$cnt = 0;
	foreach my $ff( sort { uc($a) cmp uc($b) } keys %filters )
	{
		$request->addResultLoop( 'MatrixFile_loop', $cnt, 0, $ff );
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
	
	# Check this command is OK - not validating for now as it will fail anyway and too much change
	my %cmds = ();
=pod values should be
	Preamp
	Balance
	FIRWavFile
	Matrix
	Preset
	EQBands
	Delay.delay
	Delay.unit
	Loudness.low_boost
	Loudness.high_boost
	Loudness.reference_level
	Loudness.ramp_time
	=== The values below should be set by EQ updates
	EQBAND_n.freq
	EQBAND_n.gain
	EQBAND_n.q
=cut 

	my $bandcount = getPref( $client, 'EQBands' );
=pod	
	for( my $n = 0; $n < $bandcount; $n++ )
	{
		$cmds{ 'b' . $n . 'freq' }  = 'b' . $n . 'freq';
		$cmds{ 'b' . $n . 'value' } = 'b' . $n . 'value';
	}

	my $prf = $cmds{$key};

	debug( "command: setval($key=" . $key . ")" );

	if( !defined($prf) )
	{
		oops( $client, undef, "setval, key $key is not valid!" );
		$request->setStatusBadDispatch();
		return;
	}
=cut
	if( $key eq 'EQBands' )
	{
		# special treatment since this affects each band value

		# Set the band count
		setBandCount( $client, $val );

		# ShowBriefly to tell jive users that the band count has been set
		my $line = $client->string('PLUGIN_SQUEEZEDSP_CHOSEN_BANDS');
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );

	}
	elsif( $key eq 'FIRWavFile' || $key eq 'MatrixFile' )
	{
		# incoming value is just file name, no path, no extension
		setFilterValue( $client, $key, $val );
	}
	elsif( $key eq 'Preset' )
	{
		# incoming value is the name of an *existing preset* - load it
		loadPresetFile( $client, $val );
	}

	else
	{
		# Set the value
		setPref( $client, $key, $val );

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
	#amended path to replace backslash
	my ( $client, $prf, $val ) = @_;
	my $path;
	if( $val eq '-' || $val eq '' )
	{
		# that's OK
		setPref( $client, $prf, $val );
		my $msg = ( $prf eq 'matrixfile' ) ? 'PLUGIN_SQUEEZEDSP_CHOSEN_MATRIXFILTERNONE' : 'PLUGIN_SQUEEZEDSP_CHOSEN_RCFILTERNONE';
		my $line = $client->string( $msg );
		#displays an alert on any jive enabled client
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );
		return;
	}
	if( $prf eq 'MatrixFile' )
	{
		$path = catdir( $pluginMatrixDataDir, $val );
		#replace double slash with forward slash, commenting out for consistency
		#$path =~ s#\\#/#g;

	}
	else
	{
		$path = catdir( $pluginImpulsesDataDir, $val );
		#$path =~ s#\\#/#g;
	}
	if( -f $path )
	{
		setPref( $client, $prf, $path );
		my $msg = ( $prf eq 'matrixfile' ) ? 'PLUGIN_SQUEEZEDSP_CHOSEN_MATRIXFILTER' : 'PLUGIN_SQUEEZEDSP_CHOSEN_RCFILTER';
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
	#amended to load json file
	my $client = shift;
	my $nopath = shift;
	my %presets = ();

	my $types = qr/\.(?:(preset\.json))$/i;
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
					$item =~ s/\.(?:(preset\.json))$//i;
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
# amended to include Q
sub seteqCommand
{
	my $request = shift;
	my $client = $request->client();
	debug( "command: seteq" );
	my $file = getPrefFile( $client );
	my $myConfig = LoadJSONFile ($file);

	if( $request->isNotQuery([[$thistag . '.seteq']]) )
	{
		oops( $client, undef, "seteq not command" );
		$request->setStatusBadDispatch();
		return;
	}

	my $eqband = $request->getParam('band');
	if( !defined($eqband) )
	{
		oops( $client, undef, "seteq, no band!" );
		$request->setStatusBadDispatch();
		return;
	}

	my $bandcount = $myConfig->{Client}->{EQBands};
	
	if( $eqband >= $bandcount )
	{
		oops( $client, undef, "seteq, band $eqband  count $bandcount!" );
		$request->setStatusBadDispatch();
		return;
	}
	
	my $freq = $request->getParam('freq');
	my $gain = $request->getParam('gain');
	my $q = $request->getParam('q');
	my $myBand = 'EQBand_' . $eqband;
	debug( "command: seteq($myBand,$freq,$gain, $q)" );
	
	$myConfig->{Client}->{$myBand}->{freq} = $freq ;
	$myConfig->{Client}->{$myBand}->{gain} = $gain ;
	$myConfig->{Client}->{$myBand}->{q} = $q ;
	SaveJSONFile ($myConfig, $file );
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

	my $file = catdir( $pluginSettingsDataDir, join('_', split(/:/, $key)) . '.preset.json' );
	setPref( $client, 'Preset', $file );
	savePreset( $client, $file );

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
