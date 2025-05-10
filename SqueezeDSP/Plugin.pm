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
	#
	0.1.21	Fox: Performance improvements to binary following profile runs test in 60% of time
	0.1.20	Fox: New Binary - using golang
	0.1.11	Fox: New Binary experimental sopport for MacOS arm 64 native
	0.1.10	Fox: Initialises log file, added better error handling where it is not created as this was causing failures, added better error handling for JSON reads that were failing
	0.1.09	Fox: Cleaned up code for updating the preset for a player, so that it won't keep updating for Smart TVs that run polling processes. Added cleanup for preset files deleted bands.
	0.1.08	Fox: Amended templates for Spotty and prettified the JSON settings at last
	0.1.07	Fox: Amended mechanism for deriving the settings folder by passing it from the plugin script to the binary via the config file. This should enable MacOs install to work
	0.1.06	Fox: Revised Binary, impulse loaded and resampled via SoX with no temp file used, SoX resampler was more accurate than new internal one.
				Convolver code for Impulses revised to use Externl FFT.Calculation as this seems more accurate
				A number of code tweaks, suggested for improving speed. Mainly optimising loops.
				Corrected an issue with Low Pass filter, which generated rubbish when approaching Nyquist frequency.
				Added Loudness fine-tuning and Width processing, and this needed amendments to UI and Perl Script	
	0.1.05	Fox: New Binary no longer using SoX wrapped but internal library instead. Amending this code to automatically update binaries
	0.1.04	Fox: Code added in to remove native conversion and competing flac conversions so that SqueezeDSP is the default
				 this code was reworked from C3P0 plugin.
	0.1.01	Fox: Added in logging interface, new call will read SqueezeDSP log file.
	0.1.00	Fox: Binary update PLugin update to version number
	0.0.98	Fox: New EQ Bands now appearing in correct place, wth no weird defaults
			New players now have default JSON files created properly
	0.0.97	Fox: Adding and deleting a frequency band working predictably off a simple default
	0.0.95	Fox: Commented out references to CamillaDSP, using sox instead. Added fallback default for EQ frequency
	0.0.92	Fox: Fixed Case sensitive filenames on Linux
	0.0.91	Fox: Cleaning up for installation
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
#use XML::Simple;
#use JSON;
#use JSON::XS::VersionOneAndTwo;
use JSON::XS;
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
my $revision = "0.1.21";
my $binversion = "0_2_01";
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
my $logfile = "";
my $prefs = preferences('plugin.' . $thistag);

# these sort alphabetically
my $BALANCEKEY = 'B';   # balance (left/right amplitude alignment)
my $DELAYKEY = 'S';      # skew    (left/right time alignment, under "settings")
my $LOUDNESSKEY = 'L';


my $SETTINGSKEY = "-s-";
my $PRESETSKEY = "-p-";
my $ERRORKEY = "-";

# the usual convolver controlled by this plugin is called SqueezeDSP - this is
# the command inserted in custom-convert.conf
#

my $convolver = "SqueezeDSP";
my $configPath = "";
#use the revision number from the config file
my $myconfigrevision = get_config_revision();
	



my %noFunctions = ();  # const
my $needUpgrade = 0;
my $fatalError;
my $pluginDataDir;            # <appdata>\squeezedsp
my $pluginSettingsDataDir;    # <appdata>\squeezedsp\Settings     used for settings and presets
my $pluginImpulsesDataDir;    # <appdata>\squeezedsp\Impulses     used for room correction impulse filters
my $pluginMatrixDataDir;      # <appdata>\squeezedsp\Matrix       used for cross-feed matrix impulse filters
#no measurements made

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
		if ($os->{'osArch'} =~ /arm64/) {
			return qw(/publishOSX-arm64/SqueezeDSP);
		} 
		return qw(/publishOSX-x64/SqueezeDSP);
		
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
	Slim::Control::Request::addDispatch([$thistag . '.logsummary'],                          [1, 1, 0, \&logsummaryQuery]);		# read log for current player

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
	
	# On linux we need the settings directory to be writable by SqueezeDSP binary
	

	$pluginImpulsesDataDir = catdir( $pluginDataDir, 'Impulses' );
	mkdir( $pluginImpulsesDataDir );

	$pluginMatrixDataDir = catdir( $pluginDataDir, 'MatrixImpulses' );
	mkdir( $pluginMatrixDataDir );

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
		# This is to make it easier to copy impulse across, not needed on windowsa
		chmod(0777, $pluginImpulsesDataDir);
		
		chmod(0777, $pluginTempDataDir);
	}		
	if (!-e $exec) {
		$log->warn("$exec not executable");
		#return;
	}
	#derive standard binary path
	$bin = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/", $convolver . $binExtension);
	$binversion	=catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/",$binversion);
	debug('standard binary path: ' . $bin);
	# copy correct binary into bin folder unless it already exists
	#unless (-e $bin) {
	# if we have a new binary the root binary directory should contain a file named after the binversion
	# we check for this file and then do a copy and delete the file.
	if (-e $binversion) {	
		debug('copying binary' . $exec );
		copy( $exec , $bin)  or die "copy failed: $!";
		
		#we know only windows has an extension, now set the binary
		if ( $binExtension == "") {
				debug('executable not having \'x\' permission, correcting');
				chmod (0555, $bin);

				
		}
		#now remove the file
		unlink $binversion;
	}
	
	#do any cleanup
	housekeeping();
	#do any app config settings, simplifies handover to SqueezeDSP app
	my $appConfig = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/", 'SqueezeDSP_config.json');
	# add settings folder, MacOS is inconsistent hence we need to pass the value
	amendPluginConfig($appConfig, 'pluginDataFolder', $pluginDataDir);
	# add the other folders in to avoid ambiguity
	amendPluginConfig($appConfig, 'settingsDataFolder', $pluginSettingsDataDir);
	amendPluginConfig($appConfig, 'impulseDataFolder', $pluginImpulsesDataDir);
	amendPluginConfig($appConfig, 'tempDataFolder', $pluginTempDataDir);
	
	

	my $soxbinary = Slim::Utils::Misc::findbin('sox');
	#needs updating to amend json...
	amendPluginConfig($appConfig, 'soxExe', $soxbinary);
	# find folder for log file

	$logfile = catdir(Slim::Utils::OSDetect::dirsFor('log'), "squeezedsp.log");
	# create the log file if it does not exists
if (! -e $logfile) {  # Check if the file exists
    open my $fh, '>', $logfile or die "Could not create log file: $!";
    close $fh; # Important to close the file handle after creation
    debug ( 'Log file created: ' . $logfile)  ;
} else {
    debug ('Log file already exists: ' . $logfile)  ;
}

	amendPluginConfig($appConfig, 'logFile',$logfile);


# new works for the first time a client /  server is connected this session or for brand new clients
		Slim::Control::Request::subscribe(
		\&clientEvent,
		[['client'],['new']]
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

sub LoadJSONFileOld
{
	my $myinputJSONfile = shift;
	debug( "SqueezeDSP Loading JSON File : " . $myinputJSONfile  );
	my $txt = do {                             			# do block to read file into variable
		local $/;                              			# slurp entire file
		open my $fh, "<", $myinputJSONfile or die $!;  	# open for reading
		<$fh>;                                 			# read and return file content
		
	};
	#my $myoutputData = from_json($txt);
	my $myoutputData = decode_json($txt);
	#print Dumper $myoutputData;
	
	return ($myoutputData);
	
}

sub LoadJSONFile {
    my $myinputJSONfile = shift;
    debug( "SqueezeDSP Loading JSON File : " . $myinputJSONfile  );

    my $txt;
	my $myoutputData;
    eval {
        local $/;                              			# slurp entire file
        open my $fh, "<", $myinputJSONfile or die $!;  	# open for reading
        $txt = <$fh>;                                 			# read and return file content
    };
    if ($@) {
        debug("Error reading JSON file: $myinputJSONfile. $@");
        return undef;
    }

    eval {
        $myoutputData = decode_json($txt);
    };
    if ($@) {
        debug("Error decoding JSON: $myinputJSONfile. $@");
        return undef;
    }

    return ($myoutputData);
}

sub SaveJSONFile
{
	my $myinputData = shift;
	my $myoutputJSONfile = shift;
	
	open my $fh, ">",$myoutputJSONfile;
	#print $fh encode_json($myinputData);
	#above works, but we want nice formatting - so, which unfortunately is not installed on LMS
	print $fh  JSON::XS->new->utf8->pretty->encode($myinputData);
	
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

}


sub _inspectProfile{
	my $profile=shift;
	
	my $inputtype;
	my $outputtype;
	my $clienttype;
	my $clientid;;
	
	if ($profile =~ /^(\S+)\-+(\S+)\-+(\S+)\-+(\S+)$/) {

		$inputtype  = $1;
		$outputtype = $2;
		$clienttype = $3;
		$clientid   = lc($4);
		
		return ($inputtype, $outputtype, $clienttype, $clientid);	
	}
	return (undef,undef,undef,undef);
}


sub _getEnabledPlayers{
	my @clientList= Slim::Player::Client::clients();
	my %enabled=();
	
	for my $client (@clientList){
		
			
			$enabled{$client->id()} = 1;
	}
	return \%enabled;
}

sub removeNativeConversion{
    my $self = shift;
    my $client = shift || undef;
    my $conv    = Slim::Player::TranscodingHelper::Conversions();
	my $caps    = \%Slim::Player::TranscodingHelper::capabilities;
    my %players = %{_getEnabledPlayers()};
    
    my %out=();

    for my $profile (sort keys %$conv){
    
        my ($inputtype, $outputtype, $clienttype, $clientid) = _inspectProfile($profile);

        if ($client ){
            
            if (!($clientid eq '*') && !($client->id() eq $clientid)) {next}
            if (!($clienttype eq '*') && !($client->model() eq $clienttype)) {next}
        }
        
        my $command = $conv->{$profile};

		my $enabled = Slim::Player::TranscodingHelper::enabledFormat($profile);

		#delete native commands
		if ( $enabled == 1 && $clienttype  eq "*" && $command eq "-"){
				debug ( "delete native command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid, enabled $enabled, command $command ") ;
				delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
				delete $Slim::Player::TranscodingHelper::capabilities{ $profile };

		}
		#delete generic flac commands
		if ( $enabled == 1 &&  $clientid  eq "*" && $outputtype eq "flc"){
				debug ( "delete flac command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid, enabled $enabled, command $command ") ;
				delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
				delete $Slim::Player::TranscodingHelper::capabilities{ $profile };

		}


    }
}



sub initConfiguration
{

	# called when a client first appears
	# (not on plugin init, because we need the client ID)
	#
	my $client = shift;
	debug( "client " . $client->id() ." name " . $client->name ." initializing" );



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
	 sleep 1; # Wait for 1 second - been issues with the check for configpath not working and then getting stuck in a loop
	debug ( "Config Path: " . $configPath) ;  # Print the path

if ( ! -e $configPath ) { # Check if the file or directory exists at all
    debug ( "Error:" .  $configPath . " does not exist." );
}
if ( ! -f $configPath ) {
    debug ( "Error: " . $configPath ." is not a regular file." ); # More specific
}

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
		
	upgradePrefs(  $PRE_0_9_21, @foundClients );
	removeNativeConversion();
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
	
	#restart will trigger a re-write so re-set need upgrade to off.
	$needUpgrade = 0;
	debug( "Reload Conversion Tables" );
	my $myRestart = Slim::Player::TranscodingHelper::loadConversionTables();
	#need to do this again as we have just loaaded the conversion tables again, which add back in native formats
	removeNativeConversion();
	# see if doing this twice eliminates the duplicates - NB it doesn't
	
}


# ------ web interface ------

sub webPages
{
	my $class = shift;
	
		
	
	if( Slim::Utils::PluginManager->isEnabled("Plugins::SqueezeDSP::Plugin") )
	{
		Slim::Web::Pages->addPageFunction("plugins/SqueezeDSP/index.html", \&handleWebIndex);
		Slim::Web::Pages->addPageLinks("plugins", { $class->getDisplayName => 'plugins/SqueezeDSP/index.html' });
		
		
		#Slim::Web::Pages->addPageLinks("icons",   { $class->getDisplayName => '/plugins/SqueezeDSP/images/SqueezeDSP_svg.png' });
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
		elsif  ( $prefName eq  "Loudness.listening_level" ) { $returnval =  $myConfig->{Client}->{Loudness}->{listening_level}  ;}
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
	# only use this for more complicated settings
		if     ( $prefName eq "Delay.delay" ) {		$myConfig->{Client}->{Delay}->{delay} = $prefValue ;		}
		elsif  ( $prefName eq  "Loudness.enabled" ) {	$myConfig->{Client}->{Loudness}->{enabled} = $prefValue ;	}		
		elsif  ( $prefName eq  "Loudness.listening_level" ) {$myConfig->{Client}->{Loudness}->{listening_level} = $prefValue ;	}
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
	$myConfig->{Client}->{Width} = $doc->{Client}->{Width} ;
	$myConfig->{Client}->{Delay}->{delay} = $doc->{Client}->{Delay}->{delay} ;
	$myConfig->{Client}->{Delay}->{units} = $doc->{Client}->{Delay}->{units} ;
	$myConfig->{Client}->{EQBands} = $doc->{Client}->{EQBands};
	$myConfig->{Client}->{Loudness}->{enabled} = $doc->{Client}->{Loudness}->{enabled} ;
	$myConfig->{Client}->{Loudness}->{listening_level} = $doc->{Client}->{Loudness}->{listening_level} ;			
	
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


sub setBandCount
{
	#tries to map old eq values to current equailzer when band count changes
	#only going to do the deletion for now
	
	# not sure remapping values is relevant any more.
	my $client = shift;
	my $bandcount = shift;
	$bandcount = int( $bandcount );
	# 0 is an allowable value
	#return if( $bandcount<2 );
	
	# get doc from JSON file

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
		#nb bandcount is number of bands where band numbering starts at 0
		for( my $n=0; $n<$bandcount; $n++ )
		{
			
			# copy values and if they are blank we will use defaults	
			$myBand = 'EQBand_' . $n;
			
			my $oldf = $myConfig->{Client}->{$myBand}->{freq};
			my $oldv = $myConfig->{Client}->{$myBand}->{gain};
			my $oldq = $myConfig->{Client}->{$myBand}->{q};
			
			debug( "Adding Band" . $myBand );
			#debug( "closest to $f is $oldf (=$oldv)" );
			# now that we can amend frequence we want the actual old value as saved
			

			$myConfig->{Client}->{$myBand}->{freq} =  $oldf || 60  ;
			$myConfig->{Client}->{$myBand}->{gain} = $oldv || 0 ;
			$myConfig->{Client}->{$myBand}->{q} = $oldq || 1.41 ;
		}

		# Delete any unused prefs
		if ( $prevcount > $bandcount )
		{
			for( my $n=$bandcount; $n<=$prevcount; $n++ )
			{
				$myBand = 'EQBand_' . $n;
				debug( "Delete Band" . $myBand );
				delete $myConfig->{Client}->{$myBand};

			}
		}
	}
	$myConfig->{Client}->{EQBands} = $bandcount;

	#Cleanup - there was a bug in the previous version that left a lot of blank bands undeleted.
# Find the maximum 'n' in EQ_Band_n

my $max_n = 0;
my $myBand = "";
foreach my $key (keys %{$myConfig->{Client}}) {
    if ($key =~ /^EQBand_(\d+)$/) { 
        my $n = $1; 
        $max_n = $n if $n > $max_n; 
    }
}

# Delete any unused prefs
if ( $max_n  > $bandcount ) {
    for( my $n = $bandcount; $n <= $max_n; $n++ ) { 
        $myBand = 'EQBand_' . $n;
        debug( "Delete Band" . $myBand );
        delete $myConfig->{Client}->{$myBand};
    }
}

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
	$p = 'Width';          		setPref( $client, $p, 0 )  	unless defined ( getPref( $client, $p ))	;           
	$p = 'Loudness.enabled'; 	setPref( $client, $p, 0 )   unless defined ( getPref( $client, $p ))	;    
	$p = 'Loudness.listening_level'; 	setPref( $client, $p, 70 )   unless defined ( getPref( $client, $p ))	;    
	$p = 'Preamp'; 			    setPref( $client, $p, -5 ) unless defined ( getPref( $client, $p ))	;
	$p = 'Delay.delay';  	    setPref( $client, $p, 0 )  	unless defined ( getPref( $client, $p ))	;  
	$p = 'Highpass.enabled';    setPref( $client,$p, 0 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Highpass.freq';       setPref( $client,$p, 30 ) 	unless defined ( getPref( $client, $p ))	; 
	$p = 'Highpass.q';      	setPref( $client,$p, 1 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Highshelf.enabled';   setPref( $client,$p, 0 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Highshelf.freq';      setPref( $client,$p, 8000 ) unless defined ( getPref( $client, $p ))	; 
	$p = 'Highshelf.gain';      setPref( $client,$p, 1 ) 	unless defined ( getPref( $client, $p )	); 
	$p = 'Highshelf.slope';   	setPref( $client, $p,0.3 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowpass.enabled';     setPref( $client,$p, 0 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowpass.freq';        setPref( $client,$p, 20000 ) unless defined ( getPref( $client, $p ))	;  
	$p = 'Lowpass.q';   		setPref( $client, $p,1 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowshelf.enabled';    setPref( $client,$p, 0 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowshelf.freq';       setPref( $client, $p,300 ) 	unless defined ( getPref( $client, $p ))	;  
	$p = 'Lowshelf.gain';       setPref( $client,$p, 2 ) 	unless defined ( getPref( $client, $p ))	;   
	$p = 'Lowshelf.slope';   	setPref( $client, $p, 0.3 ) 	unless defined ( getPref( $client, $p ))	;   

	
}

sub upgradePrefs
{
	# Going to run this each time the server starts and update revision number for each active client
	# 
	my ( $PRE_0_9_21, @clientIDs ) = @_;
	
	#return if ( $prevrev eq $revision ) && !$PRE_0_9_21;
	
	foreach my $clientID ( @clientIDs )
	{
		debug( "client " . $clientID );
		my $client = Slim::Player::Client::getClient( $clientID );
# Check IMMEDIATELY after getClient()
    unless (defined($client)) 
		{  # Or if (not defined $client) {
        print "Error: Could not get client object for ID: " . $clientID;
        next; # Skip to the next client ID
    	}	
		# Check the current and previous installed versions of the plugin,
		# in case we need to upgrade the prefs store (for this client)
		#
		my $myJSONFile = getPrefFile( $client );
		
		# debug( "client " . $client->id() ." previous version " . $prevrev );
		#create a player json file with default settings.

		#my $myJSONFile = getPrefFile( $client );
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
		debug ( $clientID . " Config File " . $myJSONFile . " loaded" );
		my $prevrev = $myConfig->{Client}->{Version};
		# my $prevrev = $prefs->client($client)->get( 'Version' ) || '0.0.0.0';
		
	
		#Now touch the version numbers	
		if( defined( $client ) )
		{
			if ( $prevrev eq $revision )
			{
				debug ( "upgrade from " . $prevrev . " not required " )	;
			}
		
			else   
			{
				debug( "upgrade from " . $prevrev . " to " . $revision );
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
	$request->addResult("Width",     $myConfig->{Client}->{Width} );
	$request->addResult("Delay.delay", $myConfig->{Client}->{Delay}->{delay} );
	$request->addResult("Delay.units", $myConfig->{Client}->{Delay}->{units} );
	#problematics
	$request->addResult("Loudness.enabled", $myConfig->{Client}->{Loudness}->{enabled} );
	$request->addResult("Loudness.listening_level", $myConfig->{Client}->{Loudness}->{listening_level} );
	
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
	
	$request->addResult("Last_preset", $myConfig->{Client}->{Last_preset});
		# The current EQ freq/gain values
	my $myBand = "";
	my $cnt = 0;
	for( my $n = 0; $n < $bandcount; $n++ )
	{
		$myBand = 'EQBand_' . $n;
		my $f = $myConfig->{Client}->{$myBand}->{freq} || 60;
		my $v = $myConfig->{Client}->{$myBand}->{gain} || 0;
		my $q = $myConfig->{Client}->{$myBand}->{q} || 1.41;
		# Ithink there is only 4 slots available in the result loop so concatenating gain and Q; will split on the client
		$request->addResultLoop( 'EQ_loop', $cnt, $f, $v . '|' . $q );
		$cnt++;
	}

	$request->setStatusDone();
}


sub logsummaryQuery
{
	#Get the last 5 log entries and return them
	my $request = shift;
	my $client = $request->client();
	my $clientID = $client->id() ;
	my $tracklimit = 10;
	debug( "query: logsummary" );

	if( $request->isNotQuery([[$thistag . '.logsummary']]) )
	{
		$request->setStatusBadDispatch();
		return;
	}
    
	my $startline = '';
	my $trackcount = 0;
	my @reportlines ;
	my @startvalues ;

	#$myfile = 'C:\ProgramData\Squeezebox\Logs\squeezedsp.log';
	#$myfile =~ s#\\#/#g;
	debug( "Opening log file " . $logfile . " for "  . $clientID   );
	 # Check if the file exists BEFORE attempting to open it
    if (! -e $logfile) {
        debug("Log file does not exist: $logfile"); # Log the event
        $request->addResult("trackcount", 0); # Report zero tracks
        $request->setStatusDone();
        return; # Return immediately with an empty dataset
    }

	open(FILE, "<$logfile") or
 	die("Could not open log file. $!\n");
	while(<FILE>) {
		
 		my($line) = $_;
 		chomp($line);
		
	 	if (index($line, '=>') != -1 && index($line, $clientID) != -1 ) {
			 #copy Line but only use it if the output is complete
		 	$startline = $line;
			#debug( "Log Start" . $line );
	 	}
 
	 	if (index($line, 'peak') != -1 && index($line, $clientID) != -1 ) {
			my @endvalues = split(' ', $line);
			#check that a number of samples have actually been played
			if ($endvalues[3] != 0 ) {
				@startvalues = split(' ', $startline);
				#debug( "Log End" . $line );
			
				my %reportrow = (
					date    => $startvalues[0],
					time 	=> $startvalues[1],
					playerid => $startvalues[2],
					inputrate => $startvalues[3],
					outputrate	=> $startvalues[6],
					preamp 	=> $startvalues[10],	
					peakdBfs => $endvalues[13],
					);

			push @reportlines, \%reportrow;   # What's this?
			$trackcount++;
			}
		} 
    
	}
	#We don't need the file any more so close it
	close(FILE);
	# Only going to display info relating to last $tracklimit tracks
	#debug( "TrackCount found is: " . $trackcount );
	if ( $trackcount > $tracklimit )
	{
		$trackcount = $tracklimit
	}
	my $length = scalar @reportlines;
	my $firstline = $length - $trackcount;
	my $lastline = $length - 1 ;
	#we always want tracks 1 up to 5 
	my $trackpos = 1;
	for ( my $i = $firstline  ; $i <= $lastline ; $i++ ) {
		#debug( "Log Processing Line : " . $i );

		my $reportrow = $reportlines[$i];
		$request->addResult("date_$trackpos" , $reportrow -> {date}) ;
		$request->addResult("time_$trackpos" , $reportrow -> {time}) ;
		$request->addResult("playerid_$trackpos" , $reportrow -> {playerid}) ;
		$request->addResult("inputrate_$trackpos" , $reportrow -> {inputrate}) ;
		$request->addResult("outputrate_$trackpos" , $reportrow -> {outputrate}) ;
		$request->addResult("preamp_$trackpos" , $reportrow -> {preamp}) ;
		$request->addResult("peakdBfs_$trackpos" , $reportrow -> {peakdBfs}) ;

		$trackpos++;

	}
	#debug( "TrackCount reported is: " . $trackcount );

	$request->addResult("trackcount" , $trackcount) ;
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
