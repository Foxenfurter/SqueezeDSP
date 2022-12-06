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
	#	Initial version
	#
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
use Plugins::SqueezeDSP::DspManager;

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
my $revision = "0.0.04";
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

my $confBegin = "SqueezeDSP#begin";
my $confEnd = "SqueezeDSP#end";


my $log = Slim::Utils::Log->addLogCategory({ 'category' => 'plugin.' . $thistag, 'defaultLevel' => 'WARN', 'description'  => $thisapp });

my $prefs = preferences('plugin.' . $thistag);



# the usual convolver controlled by this plugin is called SqueezeDSP - this is
# the command inserted in custom-convert.conf
#

my $convolver = "SqueezeDSP";
my $configPath = "";
#use the revision number from the config file
my $myconfigrevision = get_config_revision();
	



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

#the items below should be locked somewhere
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
Plugins::SqueezeDSP::DspManager->setmyRevision($revision);

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

sub getpluginSettingsDataDir
{
	return $pluginSettingsDataDir;
}

sub getthistag
{
	return $thistag;
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
	Slim::Control::Request::addDispatch([$thistag . '.topmenu'],                             [1, 1, 1, \&topmenuCommand]);		# top menu for Jive
	Slim::Control::Request::addDispatch([$thistag . '.settingsmenu', '_index', '_quantity'], [1, 1, 1, \&settingsmenuCommand]);	# settings sub-menu for Jive
	Slim::Control::Request::addDispatch([$thistag . '.ambimenu', '_index', '_quantity'],     [1, 1, 1, \&ambimenuCommand]);		# amb settings sub-menu for Jive

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
	my $appConfig = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/", 'SqueezeDSP.dll.config');
	my $soxbinary = Slim::Utils::Misc::findbin('sox');
	amendPluginConfig($appConfig, 'soxExe', $soxbinary);
	
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
=pod
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
	
	# For SlimServer 6.5 and later: conf file is "custom-convert.conf" in the plugin's folder.
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

	#All this crap is related to moving a config location


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


# --prefs were here
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
# ------ main-menu mode ------

=pod Take a chance and disable these
sub getMainMenuOverlays
{
	my $client = shift;
	defaultPrefs( $client );

	my %over = ();
	if( $fatalError )
	{
		$over{$ERRORKEY} = "";
	}
	elsif( $needUpgrade==1 )
	{
		$over{$ERRORKEY} = "";
	}
	else
	{
		my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' );
		if( $bandcount<2 ) { $bandcount=2; }
		if( $bandcount>90 ) { $bandcount=90; }
		for( my $b = 0; $b < $bandcount; $b++ )
		{
			$over{$b} = valuelabel( $client, $b, Plugins::SqueezeDSP::DspManager->getPref( $client, 'b' . $b . 'value' ) );
		}

		if( currentFilter( $client ) ne '-' )
		{
			$over{'91.' . $FLATNESSKEY} = valuelabel( $client, $FLATNESSKEY, Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $FLATNESSKEY . 'value' ) );
		}

		$over{'92.' . $QUIETNESSKEY} = valuelabel( $client, $QUIETNESSKEY, Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $QUIETNESSKEY . 'value' ) );
		$over{'93.' . $BALANCEKEY}   = valuelabel( $client, $BALANCEKEY, Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $BALANCEKEY . 'value' ) );
		$over{'94.' . $WIDTHKEY}     = valuelabel( $client, $WIDTHKEY, Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $WIDTHKEY . 'value' ) );
		$over{'95.' . $SETTINGSKEY}  = "";
		$over{'96.' . $PRESETSKEY}   = "";
	}
	return %over;
}
=cut
=pod
sub getMainMenuChoices
{
	my $client = shift;
	Plugins::SqueezeDSP::DspManager->defaultPrefs( $client );

	my %opts = ();
	if( $fatalError )
	{
		$opts{$ERRORKEY} = "Error: " . $fatalError;
	}
	elsif( $needUpgrade==1 )
	{
		$opts{$ERRORKEY} = $client->string( 'PLUGIN_SQUEEZEDSP_RESTART' );
	}
	else
	{
		my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' );
		if( $bandcount<2 ) { $bandcount=2; }
		if( $bandcount>90 ) { $bandcount=90; }
		for( my $b = 0; $b < $bandcount; $b++ )
		{
			$opts{$b} = freqlabel( $client, $b );
		}

		if( currentFilter( $client ) ne '-' )
		{
			$opts{'91.' . $FLATNESSKEY} = $client->string( 'PLUGIN_SQUEEZEDSP_FLATNESS' );
		}

		$opts{'92.' . $QUIETNESSKEY} = $client->string( 'PLUGIN_SQUEEZEDSP_QUIETNESS' );
		$opts{'93.' . $BALANCEKEY}   = $client->string( 'PLUGIN_SQUEEZEDSP_BALANCE' );
		$opts{'94.' . $WIDTHKEY}     = $client->string( 'PLUGIN_SQUEEZEDSP_WIDTH' );
		$opts{'95.' . $SETTINGSKEY}  = $client->string( 'PLUGIN_SQUEEZEDSP_SETTINGS' );
		$opts{'96.' . $PRESETSKEY}   = $client->string( 'PLUGIN_SQUEEZEDSP_PRESETS' );
	}
	return %opts;
}
=pod


sub setMode
{
	my $class  = shift;
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	# Create the main menu choice list

	my %opts = getMainMenuChoices( $client );
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;

	my %over = getMainMenuOverlays( $client );
	my @overlays = map $over{$_}, @choicev;

	my $valu = Plugins::SqueezeDSP::DspManager->getPref( $client, 'mainmenu' ) || @choicev[0];

	# Use INPUT.List to display the main menu
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_LINE1',
		'stringHeader' => 1,
		'headerAddCount' => 1,
		'listRef' => \@choices,
		'stringExternRef' => 1,
		'valueRef' => \$valu,
		'parentMode' => Slim::Buttons::Common::mode( $client ),
		'overlayRef' => sub
		{
			my $listIndex = $client->modeParam('listIndex');
			my $menuOver = $overlays[$listIndex];
			if( $client->linesPerScreen() == 1 )
			{
				return ( undef, $menuOver . $client->symbols('rightarrow') );
			}
			return ( $menuOver, $client->symbols('rightarrow') );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );

			my $listIndex = $client->modeParam('listIndex');
			my $menuItem = $choices[$listIndex];
			my $menuValu = keyval($choicev[$listIndex]);

			# For convenience, remember whereabouts on the main menu we were
			setPref( $client, 'mainmenu', $menuItem );

			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			} 
			elsif( $exittype eq 'RIGHT' )
			{
				if( $menuValu eq $ERRORKEY )
				{
					$client->bumpRight();
				}
				elsif( $menuValu eq $PRESETSKEY )
				{
					# Push into presets mode (no params)
					Slim::Buttons::Common::pushModeLeft( $client, $modePresets );
				}
				elsif( $menuValu eq $SETTINGSKEY )
				{
					# Push into eq-settings mode (no params)
					Slim::Buttons::Common::pushModeLeft( $client, $modeSettings );
				}
				else
				{
					# Push into adjust mode for the selected EQ band (or quietness, flatness, width)
					Slim::Buttons::Common::pushModeLeft( $client, $modeAdjust, { itemName => $menuItem, item => $menuValu } );
				}
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.List', \%params );
}

sub jiveTopMenu
{
	my $client = shift;
	my $request = shift;

	if( defined $request )
	{
		my $item = $request->getParam('menuitem_id');
		if( defined $item )
		{
			return jiveTopMenuDispatch( $client, $request, $item );
		}
	}

	# Main menu for Jive exactly follows the main menu for the remote control
	# (adjust the various bands; settings; etc)

	debug( "jiveTopMenu" );

	my %opts = getMainMenuChoices( $client );
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;

	my %over = getMainMenuOverlays( $client );
	my @overlays = map $over{$_}, @choicev;

	my @menuItems = ();
        for (my $listIndex=0; $listIndex<scalar(@choices); $listIndex++)
	{
		my $menuItem = $choices[$listIndex];
		my $menuValu = keyval($choicev[$listIndex]);

		debug( $menuValu . "=" . $menuItem );

		my $k = $menuItem;
		$k =~ s/\.\.\.//;
		push @menuItems, {
			text => $menuItem,
#			window => { 'text' => $k, 'icon-id' => 'plugins/SqueezeDSP/SqueezeDSP.png', 'titleStyle' => 'artists' },
			id => $thistag . $menuValu,
			weight => ($listIndex + 1) * 10,
#			node => $thistag,
			actions => {
				go => {
					player => 0,
					cmd => [$thistag . '.topmenu'],
					params => {
						'menuitem_id' => "$menuValu",
					},
				},
			},
		};
	}
	return @menuItems;
}
=cut
=pod

sub jiveTopMenuDispatch
{
	my $client = shift;
	my $request = shift;
	my $menuValu = shift;
	debug( "jiveTopMenuDispatch $menuValu" );
	if( $menuValu eq $ERRORKEY )
	{
		return ();
	}
	elsif( $menuValu eq $PRESETSKEY )
	{
		# Push into presets mode (no params)
		return jivePresetsMenu( $client, $request );
	}
	elsif( $menuValu eq $SETTINGSKEY )
	{
		# Push into eq-settings mode (no params)
		return jiveSettingsMenu( $client, $request );
	}
	else
	{
		# Push into adjust mode for the selected EQ band (or quietness, flatness, width)
		return jiveAdjustMenu( $client, $request, $menuValu );
	}
}

sub jiveClearTopMenu
{
	my $client = shift;

	debug( "jiveClearTopMenu" );

	my %opts = getMainMenuChoices( $client );
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;

	my @menuItems = ();
        for (my $listIndex=0; $listIndex<scalar(@choices); $listIndex++)
	{
		my $menuItem = $choices[$listIndex];
		my $menuValu = keyval($choicev[$listIndex]);

		debug( $menuValu . "=" . $menuItem );

		# delete old menuitem if it exists, so we get a clean menu
		Slim::Control::Jive::deleteMenuItem( $thistag . $menuValu, $client );
	}
}


# ------ Mode: PLUGIN.SqueezeDSP.Settings ------
# Display the setttings menu


sub getSettingsOptions
{
	my $addAmbi = shift;

	my %opts = ();
	$opts{'-e-'} = 'PLUGIN_SQUEEZEDSP_EQUALIZER';
	$opts{'-r-'} = 'PLUGIN_SQUEEZEDSP_ROOMCORR';
	$opts{'-x-'} = 'PLUGIN_SQUEEZEDSP_MATRIX';
	$opts{$SKEWKEY} = 'PLUGIN_SQUEEZEDSP_SKEW';
#	$opts{$DEPTHKEY} = 'PLUGIN_SQUEEZEDSP_DEPTH';
	$opts{'-y-'} = 'PLUGIN_SQUEEZEDSP_SIGGEN';

	if( $addAmbi )
	{
		$opts{'-z-'} = 'PLUGIN_SQUEEZEDSP_AMBI_DECODE';
	}

	return %opts;
}

sub setSettingsMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	my %opts = getSettingsOptions();
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;

	my $menuopt = Plugins::SqueezeDSP::DspManager->getPref( $client, 'settingsmenu' ) || '-e-';
	for my $k (@choicev)
	{
		if( keyval( $k ) eq $menuopt )
		{
			$menuopt = $k;
			last;
		}
	}

	# Use INPUT.List to display the choices
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_CHOOSE_SETTINGS',
		'stringHeader' => 1,
		'listRef' => \@choicev,
		'externRef' => \@choices,
		'valueRef' => \$menuopt,
		'stringExternRef' => 1,
		'headerAddCount' => 1,
		'parentMode' => Slim::Buttons::Common::mode( $client ),
		'overlayRef' => sub
		{
			return ( undef, $client->symbols('rightarrow') );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );

			# For convenience, remember whereabouts on the menu we were
			setPref( $client, 'settingsmenu', keyval($menuopt) );

			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			} 
			elsif( $exittype eq 'RIGHT' )
			{
				my $opt = keyval($menuopt);
				if( $opt eq '-e-' )
				{
					# Push into equalization-settings mode (no params)
					Slim::Buttons::Common::pushModeLeft( $client, $modeEqualization );
				}
				elsif( $opt eq '-r-' )
				{
					# Push into room-correction-settings mode (no params)
					Slim::Buttons::Common::pushModeLeft( $client, $modeRoomCorr );
				}
				elsif( $opt eq '-x-' )
				{
					# Push into matrix-settings mode (no params)
					Slim::Buttons::Common::pushModeLeft( $client, $modeMatrix );
				}
				elsif( $opt eq '-y-' )
				{
					# Push into signal-generator-settings mode (no params)
					Slim::Buttons::Common::pushModeLeft( $client, $modeSigGen );
				}
				elsif( $opt eq '-z-' )
				{
					# Push into Ambisonic-settings mode (no params)
					Slim::Buttons::Common::pushModeLeft( $client, $modeAmbisonic );
				}
				else
				{
					# Push into adjust mode (for skew, depth)
					my $listIndex = $client->modeParam('listIndex');
					Slim::Buttons::Common::pushModeLeft( $client, $modeAdjust, { itemName => $client->string( $choices[$listIndex] ), item => $choicev[$listIndex] } );
				}
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.List', \%params );
}

sub jiveSettingsMenu
{
	my $client = shift;
	my $request = shift;

	if( defined $request )
	{
		my $item = $request->getParam('setting_id');
		if( defined $item )
		{
			return jiveSettingsMenuDispatch( $client, $request, $item );
		}
	}

	debug( "jiveSettingsMenu" );
	my %opts = getSettingsOptions(1);
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;

	my @menuItems = ();
        for (my $listIndex=0; $listIndex<scalar(@choicev); $listIndex++)
	{
		my $menuItem = $client->string( $choices[$listIndex] );
		my $menuValu = $choicev[$listIndex];

		debug( $menuValu . "=" . $menuItem );

		my $k = $menuItem;
		$k =~ s/\.\.\.//;
		push @menuItems, {
			text => $menuItem,
			window => { text => $k },
			id => $thistag . 'set' . $listIndex,
			weight => ($listIndex + 1) * 10,
			actions => {
				go => {
					player => 0,
					cmd => [$thistag . '.settingsmenu'],
					params => {
						'setting_id' => "$menuValu",
					},
				},
			},
		};
	}
	return @menuItems;
}

sub jiveSettingsMenuDispatch
{
	my $client = shift;
	my $request = shift;
	my $menuopt = shift;
	debug( "jiveSettingsMenuDispatch " . $menuopt );

	my $opt = keyval($menuopt);
	if( $opt eq '-e-' )
	{
		# Push into equalization-settings mode (no params)
		return jiveEqualizationMenu( $client, $request );
	}
	elsif( $opt eq '-r-' )
	{
		# Push into room-correction-settings mode (no params)
		return jiveRoomCorrMenu( $client, $request );
	}
	elsif( $opt eq '-x-' )
	{
		# Push into matrix-settings mode (no params)
		return jiveMatrixMenu( $client, $request );
	}
	elsif( $opt eq '-y-' )
	{
		# Push into signal-generator-settings mode (no params)
		return jiveSigGenMenu( $client, $request );
	}
	elsif( $opt eq '-z-' )
	{
		# Push into Ambisonic-settings mode (no params)
		return jiveAmbiMenu( $client, $request );
	}
	else
	{
		# Push into adjust mode (for skew, depth)
		return jiveAdjustMenu( $client, $request, $menuopt );
	}
}


Slim::Buttons::Common::addMode( $modeSettings, \%noFunctions, \&setSettingsMode );




# ------ Mode: PLUGIN.SqueezeDSP.Ambisonic ------
# Display the Ambisonic setttings menu


sub getAmbiOptions
{
	my %opts = ();
	$opts{'01.UHJ'} = 'PLUGIN_SQUEEZEDSP_AMBI_UHJ';
	$opts{'02.Blumlein'} = 'PLUGIN_SQUEEZEDSP_AMBI_BLUMLEIN';
	$opts{'03.Crossed'} = 'PLUGIN_SQUEEZEDSP_AMBI_CARDIOID';
#	$opts{'04.Crossed+jW'} = 'PLUGIN_SQUEEZEDSP_AMBI_CARDIOID_PLUSJW';
	$opts{$AMBANGLEKEY} = 'PLUGIN_SQUEEZEDSP_AMBI_CARDIOID_ANGLE';
	$opts{$AMBDIRECTKEY} = 'PLUGIN_SQUEEZEDSP_AMBI_CARDIOID_DIRECT';
#	$opts{$AMBJWKEY} = 'PLUGIN_SQUEEZEDSP_AMBI_CARDIOID_JW';
	$opts{$AMBROTATEZKEY} = 'PLUGIN_SQUEEZEDSP_AMBI_ROTATION_Z';
	$opts{$AMBROTATEYKEY} = 'PLUGIN_SQUEEZEDSP_AMBI_ROTATION_Y';
	$opts{$AMBROTATEXKEY} = 'PLUGIN_SQUEEZEDSP_AMBI_ROTATION_X';

	return %opts;
}

sub setAmbiMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	my %opts = getAmbiOptions();
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;

	my $menuopt = Plugins::SqueezeDSP::DspManager->getPref( $client, 'ambimenu' ) || 'UHJ';
	for my $k (@choicev)
	{
		if( keyval( $k ) eq $menuopt )
		{
			$menuopt = $k;
			last;
		}
	}

	# Use INPUT.List to display the choices
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_AMBI_CHOOSE_SETTINGS',
		'stringHeader' => 1,
		'listRef' => \@choicev,
		'externRef' => \@choices,
		'valueRef' => \$menuopt,
		'stringExternRef' => 1,
		'headerAddCount' => 1,
		'parentMode' => Slim::Buttons::Common::mode( $client ),
		'overlayRef' => sub
		{
			return ( undef, $client->symbols('rightarrow') );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );

			# For convenience, remember whereabouts on the menu we were
			setPref( $client, 'settingsmenu', keyval($menuopt) );

			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			} 
			elsif( $exittype eq 'RIGHT' )
			{
				my $opt = keyval($menuopt);
				if( ( $opt eq $AMBANGLEKEY ) || ( $opt eq $AMBDIRECTKEY ) || ( $opt eq $AMBJWKEY ) || ( $opt eq $AMBROTATEZKEY ) || ( $opt eq $AMBROTATEYKEY ) || ( $opt eq $AMBROTATEXKEY ) )
				{
					# Push into adjust mode (for angle, directivity, etc)
					my $listIndex = $client->modeParam('listIndex');
					Slim::Buttons::Common::pushModeLeft( $client, $modeAdjust, { itemName => $choices[$listIndex], item => $choicev[$listIndex] } );
				}
				else
				{
					# Set decode type
					debug( "ambtype: " . $opt );
					setPref( $client, 'ambtype', $opt );
					$client->update();
					$client->bumpRight();
				}			
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.List', \%params );
}

sub jiveAmbiMenu
{
	my $client = shift;
	my $request = shift;

	if( defined $request )
	{
		my $item = $request->getParam('ambisetting_id');
		if( defined $item )
		{
			return jiveAmbiMenuDispatch( $client, $request, $item );
		}
	}

	debug( "jiveAmbiMenu" );
	my %opts = getAmbiOptions();
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;

	my $opt = Plugins::SqueezeDSP::DspManager->getPref( $client, "ambtype" );

	my @menuItems = ();
        for (my $listIndex=0; $listIndex<scalar(@choicev); $listIndex++)
	{
		my $menuItem = $client->string( $choices[$listIndex] );
		my $menuValu = $choicev[$listIndex];

		debug( keyval($menuValu) . "=" . $menuItem );

		my $k = $menuItem;
		$k =~ s/\.\.\.//;
		if( ( $menuValu eq $AMBANGLEKEY ) || ( $menuValu eq $AMBDIRECTKEY ) || ( $menuValu eq $AMBJWKEY ) || ( $menuValu eq $AMBROTATEZKEY ) || ( $menuValu eq $AMBROTATEYKEY ) || ( $menuValu eq $AMBROTATEXKEY ) )
		{
			push @menuItems, {
				text => $menuItem,
				window => { text => $k },
				id => $thistag . 'amb' . $listIndex,
				weight => ($listIndex + 1) * 10,
				actions => {
					go => {
						player => 0,
						cmd => [$thistag . '.ambimenu'],
						params => {
							'ambisetting_id' => "$menuValu",
						},
					},
				},
			};
		}
		else
		{
			push @menuItems, {
				text => $menuItem,
				radio => (keyval($menuValu) eq $opt) + 0,
				id => $thistag . 'amb' . $listIndex,
				weight => ($listIndex + 1) * 10,
				actions => {
					do => {
						player => 0,
						cmd => [$thistag . '.setval'],
						params => {
							'key' => "Amb",
							'val' => keyval($menuValu),
						},
					},
				},
			};
		}
	}
	return @menuItems;
}

sub jiveAmbiMenuDispatch
{
	my $client = shift;
	my $request = shift;
	my $menuopt = shift;
	debug( "jiveAmbiMenuDispatch " . $menuopt );

	my $opt = keyval($menuopt);

	# Push into adjust mode (for angle, directivity, etc)
	return jiveAdjustMenu( $client, $request, $menuopt );
}


Slim::Buttons::Common::addMode( $modeAmbisonic, \%noFunctions, \&setAmbiMode );


# ------ Mode: PLUGIN.SqueezeDSP.Equalization ------
# Choose how many channels of equalization to use


sub getEqualizationOptions
{
	my $more = shift;
	my %opts = ();
	$opts{"02"} = 'PLUGIN_SQUEEZEDSP_2BAND';
	$opts{"03"} = 'PLUGIN_SQUEEZEDSP_3BAND';
	$opts{"05"} = 'PLUGIN_SQUEEZEDSP_5BAND';
	$opts{"09"} = 'PLUGIN_SQUEEZEDSP_9BAND';
	if( $more )
	{
		$opts{"15"} = 'PLUGIN_SQUEEZEDSP_15BAND';
		$opts{"31"} = 'PLUGIN_SQUEEZEDSP_31BAND';
	}
	return %opts;
}
 
sub setEqualizationMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	my %opts = getEqualizationOptions();
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;
	my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' ) || 2;

	# Use INPUT.List to display the list of band choices
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_CHOOSE_EQSETTINGS',
		'stringHeader' => 1,
		'listRef' => \@choicev,
		'externRef' => \@choices,
		'stringExternRef' => 1,
		'valueRef' => \$bandcount,
		'headerAddCount' => 1,
		'parentMode' => Slim::Buttons::Common::mode( $client ),
		'overlayRef' => sub
		{
			my ( $client, $value ) = @_;
			return ( undef, Slim::Buttons::Common::checkBoxOverlay( $client, ($value+0) eq Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' ) ) );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );

			# For convenience, remember whereabouts on the menu we were
			# setPref( $client, 'equalizationmenu', $bandcount + 0 );

			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			} 
			elsif( $exittype eq 'RIGHT' )
			{
				# Update the pref setting, then refresh display, but stay in this mode
				setBandCount( $client, $bandcount );
				$client->update();
				$client->bumpRight();
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.List', \%params );
}


sub jiveEqualizationMenu
{
	my $client = shift;
	my $request = shift;

	debug( "jiveEqualizationMenu" );
	my %opts = getEqualizationOptions(1);
	my @choicev = sort { uc($a) cmp uc($b) } keys %opts;
	my @choices = map $opts{$_}, @choicev;
	my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' ) || 2;

	my @menuItems = ();
        for (my $listIndex=0; $listIndex<scalar(@choicev); $listIndex++)
	{
		my $menuItem = $choices[$listIndex];
		my $menuValu = $choicev[$listIndex];

		debug( $menuValu . "=" . $menuItem );

		push @menuItems, {
			text => $client->string( $menuItem ),
			radio => ( ($menuValu+0) eq $bandcount ) + 0,
			id => $thistag . 'eq' . $listIndex,
			weight => ($listIndex + 1) * 10,
			actions => {
				do => {
					player => 0,
					cmd => [$thistag . '.setval'],
					params => {
						'key' => "Bands",
						'val' => $menuValu + 0,
					},
				},
			},
		};
	}
	return @menuItems;
}

Slim::Buttons::Common::addMode( $modeEqualization, \%noFunctions, \&setEqualizationMode );




# ------ Mode: PLUGIN.SqueezeDSP.Adjust ------
# Displays bar for editing one band of equalization

sub setAdjustMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	# item param is band number (e.g. 0 = bass), L for quietness, or F for flatness
	my $item = $client->modeParam('item');

	my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' );
	my $itemName;			# user-visible name of this band ('bass', '440 Hz' etc). already client-stringified
	my $prefValuKey;
	my $prefFreqKey;
	my $valu;			# the level (dB) for this band
	my $freq;			# the center frequency for this band (if applicable)
	if( $item =~ /^-?\d/ )
	{
		# EQ bands
		$itemName = freqlabel( $client, $item ) || $client->modeParam('itemName');
		$prefValuKey = 'b' . $item . 'value';
		$prefFreqKey = 'b' . $item . 'freq';
		$valu = Plugins::SqueezeDSP::DspManager->getPref( $client, $prefValuKey );
		$freq = Plugins::SqueezeDSP::DspManager->getPref( $client, $prefFreqKey ) || defaultFreq( $client, $item, $bandcount );
	}
	else
	{
		# Other stuff
		$itemName = $client->modeParam('itemName');
		$prefValuKey = 'band' . $item . 'value';
		$valu = Plugins::SqueezeDSP::DspManager->getPref( $client, $prefValuKey );
	}

#  if( $item eq $FLATNESSKEY )
#  {
#    $valu = 10 unless ($valu =~ /^-?\d*\./);
#  }
#  else
#  {
#    $valu = 0 unless ($valu =~ /^-?\d*\./);
#  }

	my $min = -12;
	my $max = 12;
	my $increment = 0.1;
	if( ($item eq $QUIETNESSKEY) || ($item eq $FLATNESSKEY) )
	{
		$min = 0;
		$max = 10;
		$increment = 1;
	}
	elsif( ($item eq $SKEWKEY) || ($item eq $DEPTHKEY) )
	{
		$increment = 1;
	}
	elsif( ($item eq $BALANCEKEY) || ($item eq $WIDTHKEY) )
	{
		$min = -9;
		$max = 9;
	}
	elsif( ($item eq $AMBANGLEKEY) )
	{
		$min = 45;
		$max = 150;
		$increment = 5;
	}
	elsif( ($item eq $AMBDIRECTKEY) )
	{
		$min = 0;
		$max = 1;
	}
	elsif( ($item eq $AMBJWKEY) )
	{
		$min = 0;
		$max = 1;
		$increment = 0.05;
	}
	elsif( ($item eq $AMBROTATEZKEY) || ($item eq $AMBROTATEYKEY) || ($item eq $AMBROTATEXKEY) )
	{
		$min = -180;
		$max = 180;
		$increment = 1;
	}

	# Round the value before we start, in case of weird float artifacts
	$valu = round( $valu, $increment );

	# use INPUT.Bar for editing the value, +/- 12dB unless overridden
	my %params =
	(
		# Bar has a bug where negative values' header display value is off by one, so make our own header
		'header' => sub
		{
			return valuelabel( $client, $item, $valu );
		},
		'overlayRef' => sub
		{
			if( $client->linesPerScreen() == 1 )
			{
				return ( undef, $itemName );
			}
			return ( $itemName, undef );
		},
		'stringHeader' => 1,
		'valueRef' => \$valu,
		'min' => $min,
		'max' => $max,
		'increment' => $increment,
		'smoothing' => 1,
		'onChange' => sub
		{
			# Change the value immediately, not on exit...
			$valu = round( $valu, $increment );
			setPref( $client, $prefValuKey, $valu );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );
			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			}
			elsif( $exittype eq 'RIGHT' )
			{
				if( $item =~ /^-?\d/ )
				{
					# push into adjust-band-frequency mode.
					# the min & max frequencies are determined by the adjacent bands (so we can't run over them)!
					my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' );
					my $min = 10;
					if( $item > 0 ) { $min = int( Plugins::SqueezeDSP::DspManager->getPref( $client, 'b' . ($item-1). 'freq' ) || defaultFreq( $client, ($item-1), $bandcount ) ) + 5; }
					my $max = 22000;
					if( $item < $bandcount-1 ) { $max = int( Plugins::SqueezeDSP::DspManager->getPref( $client, 'b' . ($item+1). 'freq' ) || defaultFreq( $client, ($item+1), $bandcount ) ) - 5; }
					debug( $item . " of " . $bandcount . ", min " . $min . ", max " . $max );
					Slim::Buttons::Common::pushModeLeft( $client, $modeValue, { 
						'header' => $client->string( 'PLUGIN_SQUEEZEDSP_BANDCENTER' ),
						'suffix' => ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_HERTZ' ),
						'min' => $min,
						'max' => $max,
						'increment' => 1,
						'valueRef' => \$freq,
						'parentMode' => Slim::Buttons::Common::mode($client),
						'onChange' => sub
						{
							# Change the value immediately, not on exit...
							setPref( $client, 'b' . $item . 'freq', $freq );
							$itemName = freqlabel( $client, $item ) || $client->string( $client->modeParam('itemName') );
						},
					 } );
				}
				else
				{
					$client->bumpRight();
				}
			}
			else
			{
				return;
			}
		}
	);
	Slim::Buttons::Common::pushModeLeft( $client, 'INPUT.Bar', \%params );
}
=cut
sub round
{
	my ( $valu, $increment ) = @_;
	my $val2 = ($valu + 0) / $increment;
	$val2 = int($val2 + .5 * ($val2 <=> 0));
	return $val2 * $increment;
}
=pod
sub jiveAdjustMenu
{
	my $client = shift;
	my $request = shift;
	my $item = shift;

	debug( "jiveAdjustMenu" );

	my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' );
	my $prefValuKey;
	my $prefFreqKey;
	my $valu;			# the level (dB) for this band
	my $freq;			# the center frequency for this band (if applicable)
	if( $item =~ /^-?\d/ )
	{
		# EQ bands
		$prefValuKey = 'b' . $item . 'value';
		$prefFreqKey = 'b' . $item . 'freq';
		$valu = Plugins::SqueezeDSP::DspManager->getPref( $client, $prefValuKey );
		$freq = Plugins::SqueezeDSP::DspManager->getPref( $client, $prefFreqKey ) || defaultFreq( $client, $item, $bandcount );
	}
	else
	{
		# Other stuff
		$prefValuKey = 'band' . $item . 'value';
		$valu = Plugins::SqueezeDSP::DspManager->getPref( $client, $prefValuKey );
	}

	my $min = -12;
	my $max = 12;
	my $increment = 0.1;
	if( ($item eq $QUIETNESSKEY) || ($item eq $FLATNESSKEY) )
	{
		$min = 0;
		$max = 10;
		$increment = 1;
	}
	elsif( ($item eq $SKEWKEY) || ($item eq $DEPTHKEY) )
	{
		$increment = 1;
	}
	elsif( ($item eq $BALANCEKEY) || ($item eq $WIDTHKEY) )
	{
		$min = -9;
		$max = 9;
	}
	elsif( ($item eq $AMBANGLEKEY) )
	{
		$min = 45;
		$max = 150;
		$increment = 5;
	}
	elsif( ($item eq $AMBDIRECTKEY) )
	{
		$min = 0;
		$max = 1;
	}
	elsif( ($item eq $AMBJWKEY) )
	{
		$min = 0;
		$max = 1;
		$increment = 0.05;
	}
	elsif( ($item eq $AMBROTATEZKEY) || ($item eq $AMBROTATEYKEY) || ($item eq $AMBROTATEXKEY) )
	{
		$min = -180;
		$max = 180;
		$increment = 1;
	}

	# For now: radio buttons,
	# 4 points either side of the current value (because Jive has 9 items on its menus without scrolling).
	# TBD later, an input.BAR-type thing please!

	my $max4 = $valu + (4 * $increment);
	my $start;
	if( $max4 < $max )
	{
		my $min4 = $valu - (4 * $increment);
		$start = ( $min4 < $min ) ? $min : $min4;
	}
	else
	{
		my $max8 = $max - (8 * $increment);
		$start = ( $max8 < $min ) ? $min : $max8;
	}

	debug( "min $min max $max value $valu start $start" );

	my @menuItems = ();
	for( my $i=$start, my $n=0; $n<9; $i+=$increment, $n++ )
	{
		my $v = round( $i, $increment );
		last if( $v > $max );
		push @menuItems, {
			text => valuelabel( $client, $item, $v ),
			radio => ( $v == round( $valu, $increment ) ) + 0,
			id => $thistag . 'adj' . $n,
			weight => ($n + 1) * 10,
			actions => {
				do => {
					# setval($item) parameter is value
					player => 0,
					cmd => [$thistag . '.setval'],
					params => {
						'key' => $prefValuKey,
						'val' => $v,
					},
				},
			},
		};
	}
	return @menuItems;
}

Slim::Buttons::Common::addMode( $modeAdjust, \%noFunctions, \&setAdjustMode );

=cut


# ------ Mode: PLUGIN.SqueezeDSP.Presets ------
# Displays menu to load a preset
# Presets are files "xxx.preset.conf" in the plugin's Data folder.
# They are exactly the same format as the "xxx.settings.conf" file used for client settings,
# (but any clientID in the file is ignored)


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
=pod
sub setPresetsMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	initPresetsChoices( $client );

	my $preset = currentPreset($client); # $presetsMenuValues[0];

	# Use INPUT.List to display the menu
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_CHOOSE_PRESET',
		'stringHeader' => 1,
		'headerAddCount' => 1,
		'listRef' => \@presetsMenuValues,
		'externRef' => \@presetsMenuChoices,
		'valueRef' => \$preset,
		'parentMode' => Slim::Buttons::Common::mode( $client ),
		'overlayRef' => sub
		{
			return ( undef, $client->symbols('rightarrow') );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );

			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			} 
			elsif( $exittype eq 'RIGHT' )
			{
				if( $preset eq '-' )
				{
					# Input a filename and save current settings
					savePreset( $client );
				}
				else
				{
					# Load this preset and return
					my $listIndex = $client->modeParam('listIndex');
					my $desc = $presetsMenuChoices[$listIndex];
					my $path = $presetsMenuValues[$listIndex];
					loadPrefs( $client, $path, $desc );
					Slim::Buttons::Common::popMode( $client );
				}
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.List', \%params );
}

sub currentPreset
{
	my $client = shift;
	return Plugins::SqueezeDSP::DspManager->getPref( $client, 'preset' ) || '-';
}

sub savePreset
{
	my $client = shift;

	# Use Input.TEXT to get filename.
	# Restrict filenames to alphanum and a few choice punctuation... not fullstop, colon, etc...

	my @chars = (
		undef, # placeholder for rightarrrow
		'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
		'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
		'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
		' ', '-', '_',
		'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
		);

	my @mixed = (
		[' ','0'], 				# 0
		['-','_','1'], 				# 1
		['a','b','c','A','B','C','2'],		# 2
		['d','e','f','D','E','F','3'], 		# 3
		['g','h','i','G','H','I','4'], 		# 4
		['j','k','l','J','K','L','5'], 		# 5
		['m','n','o','M','N','O','6'], 		# 6
		['p','q','r','s','P','Q','R','S','7'], 	# 7
		['t','u','v','T','U','V','8'], 		# 8
		['w','x','y','z','W','X','Y','Z','9'] 	# 9
		);

	my $oldfile = Plugins::SqueezeDSP::DspManager->getPref( $client, 'preset' ); 
	my ( $vol, $dir, $name ) = splitpath( $oldfile );
	$name =~ s/\.(?:(preset\.conf))$//i;
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_SAVEPRESETFILE',
		'stringHeader' => 1,
		'charsRef' => \@chars,
		'numberLetterRef' => \@mixed,
		'valueRef' => \$name,
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );
			if( $exittype eq 'NEXTCHAR' )
			{
				$name =~ s/$client->symbols('rightarrow')//;
				if( length($name)>0 )
				{
					my $file = catdir( $pluginSettingsDataDir, join('_', split(/:/, $name)) . '.preset.conf' );
					setPref( $client, 'preset', $file );
					my $ok = savePrefs( $client, $file );
					Slim::Buttons::Common::popMode( $client );
					$client->pushLeft();
					$client->showBriefly( { line => [ $name, $client->string('PLUGIN_SQUEEZEDSP_PRESET_SAVED') ] } , 2) if $ok;
					# reload the presets list
					initPresetsChoices( $client );
				}
			} 
			elsif( $exittype eq 'BACKSPACE' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			}
			else
			{
				$client->bumpRight();
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.Text', \%params );
	$client->pushLeft();
}

sub jivePresetsMenu
{
	my $client = shift;
	my $request = shift;

	debug( "jivePresetsMenu" );
	initPresetsChoices( $client );
	my $preset = currentPreset($client);

	my @menuItems = ();

        for (my $listIndex=0; $listIndex<scalar(@presetsMenuValues); $listIndex++)
	{
		my $menuItem = $presetsMenuChoices[$listIndex];
		my $menuValu = $presetsMenuValues[$listIndex];

		debug( $menuValu . "=" . $menuItem );

		if( $menuValu eq '-' )
		{
			# This is the "save preset as..." menu item
			push @menuItems, {
				text => $menuItem,
				input => {
					initialText  => '',
					len          => 1,
					allowedChars => Slim::Utils::Strings::string('PLUGIN_SQUEEZEDSP_FILECHARS'),
					help         => {
						           text => Slim::Utils::Strings::string('PLUGIN_SQUEEZEDSP_PRESET_HELP'),
					},
					softbutton1  => Slim::Utils::Strings::string('INSERT'),
					softbutton2  => Slim::Utils::Strings::string('DELETE'),
				},
		                actions => {
					do => {
						# saveas parameter is filename (without .preset.conf)
						player => 0,
						cmd => [$thistag . '.saveas'],
						params => {
							'preset' => '__TAGGEDINPUT__',
						},
					},
				},
				window => {
					text => Slim::Utils::Strings::string('PLUGIN_SQUEEZEDSP_SAVEPRESETFILE'),
				},
			};
		}
		else
		{
			my ( $vol, $dir, $fil ) = splitpath( $menuValu );
			push @menuItems, {
				text => $menuItem,
				radio => 0, # ( $menuValu eq $preset ) + 0, but of the presets aren't "current" really
				actions => {
					do => {
						# setval(preset) parameter is filename (with .preset.conf, without path)
						player => 0,
						cmd => [$thistag . '.setval'],
						params => {
							'key' => "Preset",
							'val' => "$fil",
						},
					},
				},
			};
		}
	}
	return @menuItems;
}

Slim::Buttons::Common::addMode( $modePresets, \%noFunctions, \&setPresetsMode );

=cut
# ------ Mode: PLUGIN.SqueezeDSP.RoomCorrection ------
# Displays menu to select a correction filter.
# Correction filters are any file in the plugin's Data folder with .WAV file extension.
# Of course not all wav files will work properly as filters, but this plugin doesn't know that.


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
	return Plugins::SqueezeDSP::DspManager->getPref( $client, 'filter' ) || '-';
}

=pod More menu
sub setRoomCorrectionMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	my %filters = getFiltersList( $client, $pluginImpulsesDataDir, 0 );
	my @choicev = sort { uc($a) cmp uc($b) } keys %filters;
	my @choices = map $filters{$_}, @choicev;
	my $filter = currentFilter( $client );

	# Use INPUT.List to display the menu
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_CHOOSE_RCFILTER',
		'stringHeader' => 1,
		'headerAddCount' => 1,
		'listRef' => \@choicev,
		'externRef' => \@choices,
		'valueRef' => \$filter,
		'parentMode' => Slim::Buttons::Common::mode( $client ),
		'overlayRef' => sub
		{
			my ( $client, $value ) = @_;
			return ( undef, Slim::Buttons::Common::checkBoxOverlay( $client, $value eq currentFilter( $client ) ) );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );
			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			} 
			elsif( $exittype eq 'RIGHT' )
			{
				# Update the pref setting, then refresh display, but stay in this mode
				setPref( $client, 'filter', $filter );
				$client->update();
				$client->bumpRight();
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.List', \%params );
}

sub jiveRoomCorrMenu
{
	my $client = shift;
	my $request = shift;

	debug( "jiveRoomCorrMenu" );
	my %filters = getFiltersList( $client, $pluginImpulsesDataDir, 1 );
	my @choicev = sort { uc($a) cmp uc($b) } keys %filters;
	my @choices = map $filters{$_}, @choicev;
	my $filter = currentFilter( $client );

	my @menuItems = ();
        for (my $listIndex=0; $listIndex<scalar(@choicev); $listIndex++)
	{
		my $menuItem = $choices[$listIndex];
		my $menuValu = $choicev[$listIndex];

		debug( $menuValu . "=" . $menuItem );

		push @menuItems, {
			text => $menuItem,
			radio => ( ( $menuValu eq $filter ) || ( catdir($pluginImpulsesDataDir, $menuValu) eq $filter ) ) + 0,
			actions => {
				do => {
					player => 0,
					cmd => [$thistag . '.setval'],
					params => {
						'key' => "Filter",
						'val' => "$menuValu",
					},
				},
			},
		};
	}
	return @menuItems;
}

Slim::Buttons::Common::addMode( $modeRoomCorr, \%noFunctions, \&setRoomCorrectionMode );

=cut

# ------ Mode: PLUGIN.SqueezeDSP.Matrix ------
# Displays menu to control stereo image width and cross-feed filters.
# Cross-feed filters are any file in the plugin's Matrix folder with .WAV file extension.
# Of course not all wav files will work properly as filters, but this plugin doesn't know that.


sub currentMatrixFilter
{
	my $client = shift;
	return Plugins::SqueezeDSP::DspManager->getPref( $client, 'matrix' ) || '-';
}
=cut
sub setMatrixMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	my %filters = getFiltersList( $client, $pluginMatrixDataDir, 0 );
	my @choicev = sort { uc($a) cmp uc($b) } keys %filters;
	my @choices = map $filters{$_}, @choicev;
	my $filter = currentMatrixFilter( $client );

	# Use INPUT.List to display the menu
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_CHOOSE_MATRIXFILTER',
		'stringHeader' => 1,
		'headerAddCount' => 1,
		'listRef' => \@choicev,
		'externRef' => \@choices,
		'valueRef' => \$filter,
		'parentMode' => Slim::Buttons::Common::mode( $client ),
		'overlayRef' => sub
		{
			my ( $client, $value ) = @_;
			return ( undef, Slim::Buttons::Common::checkBoxOverlay( $client, $value eq currentMatrixFilter( $client ) ) );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );
			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			} 
			elsif( $exittype eq 'RIGHT' )
			{
				# Update the pref setting, then refresh display, but stay in this mode
				setPref( $client, 'matrix', $filter );
				$client->update();
				$client->bumpRight();
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.List', \%params );
}

sub jiveMatrixMenu
{
	my $client = shift;
	my $request = shift;

	debug( "jiveMatrixMenu" );
	my %filters = getFiltersList( $client, $pluginMatrixDataDir, 1 );
	my @choicev = sort { uc($a) cmp uc($b) } keys %filters;
	my @choices = map $filters{$_}, @choicev;
	my $filter = currentMatrixFilter( $client );

	my @menuItems = ();
        for (my $listIndex=0; $listIndex<scalar(@choicev); $listIndex++)
	{
		my $menuItem = $choices[$listIndex];
		my $menuValu = $choicev[$listIndex];

		debug( $menuValu . "=" . $menuItem );

		push @menuItems, {
			text => $menuItem,
			radio => ( ( $menuValu eq $filter ) || ( catdir($pluginMatrixDataDir, $menuValu) eq $filter ) ) + 0,
			actions => {
				do => {
					player => 0,
					cmd => [$thistag . '.setval'],
					params => {
						'key' => "Matrix",
						'val' => "$menuValu",
					},
				},
			},
		};
	}
	return @menuItems;
}

Slim::Buttons::Common::addMode( $modeMatrix, \%noFunctions, \&setMatrixMode );

=cut


# ------ Mode: PLUGIN.SqueezeDSP.SignalGenerator ------
# Displays menu to control a signal generator.
# Signal-generator mode "None" just plays the music.  Anything else overrides the music with a test signal.

=pod no need for signal generator
sub currentSignalGenerator
{
	my $client = shift;
	return Plugins::SqueezeDSP::DspManager->getPref( $client, 'siggen' ) || 'None';
}

sub getSignalGeneratorOptions
{
	my %opts = ();

	$opts{'01.None'}        = 'PLUGIN_SQUEEZEDSP_SIGGEN_NONE';
	$opts{'02.Ident'}       = 'PLUGIN_SQUEEZEDSP_SIGGEN_IDENT';
	$opts{'03.Sweep'}       = 'PLUGIN_SQUEEZEDSP_SIGGEN_SWEEP';
	$opts{'03.SweepShort'}  = 'PLUGIN_SQUEEZEDSP_SIGGEN_SWEEP_SHORT';
	$opts{'04.SweepEQL'}    = 'PLUGIN_SQUEEZEDSP_SIGGEN_SWEEP_EQ_L';
	$opts{'05.SweepEQR'}    = 'PLUGIN_SQUEEZEDSP_SIGGEN_SWEEP_EQ_R';
	$opts{'06.Pink'}        = 'PLUGIN_SQUEEZEDSP_SIGGEN_PINK';
	$opts{'07.PinkEQ'}      = 'PLUGIN_SQUEEZEDSP_SIGGEN_PINK_EQ';
	$opts{'08.PinkSt'}      = 'PLUGIN_SQUEEZEDSP_SIGGEN_PINK_STEREO';
	$opts{'09.PinkStEQ'}    = 'PLUGIN_SQUEEZEDSP_SIGGEN_PINK_STEREO_EQ';
	$opts{'10.White'}       = 'PLUGIN_SQUEEZEDSP_SIGGEN_WHITE';
	$opts{'11.Sine'}        = 'PLUGIN_SQUEEZEDSP_SIGGEN_SINE';
	$opts{'12.Quad'}        = 'PLUGIN_SQUEEZEDSP_SIGGEN_QUAD';
	$opts{'13.BLSquare'}    = 'PLUGIN_SQUEEZEDSP_SIGGEN_SQUARE';
	$opts{'14.BLTriangle'}  = 'PLUGIN_SQUEEZEDSP_SIGGEN_TRIANGLE';
	$opts{'15.BLSawtooth'}  = 'PLUGIN_SQUEEZEDSP_SIGGEN_SAWTOOTH';
	$opts{'16.Intermodulation'} = 'PLUGIN_SQUEEZEDSP_SIGGEN_IM';
#	$opts{'17.ShapedBurst'} = 'PLUGIN_SQUEEZEDSP_SIGGEN_BURST';

	return %opts;
}

sub setSignalGeneratorMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	my %opts = getSignalGeneratorOptions();
	my @choicev = sort keys %opts;
	my @choices = map $opts{$_}, @choicev;
	my $opt = currentSignalGenerator( $client );
	for my $k (@choicev)
	{
		if( keyval( $k ) eq $opt )
		{
			$opt = $k;
			last;
		}
	}

	# Use INPUT.List to display the menu
	my %params =
	(
		'header' => 'PLUGIN_SQUEEZEDSP_CHOOSE_SIGGEN',
		'stringHeader' => 1,
		'headerAddCount' => 1,
		'listRef' => \@choicev,
		'externRef' => \@choices,
		'stringExternRef' => 1,
		'valueRef' => \$opt,
		'parentMode' => Slim::Buttons::Common::mode( $client ),
		'overlayRef' => sub
		{
			my ( $client, $value ) = @_;
			return ( undef, Slim::Buttons::Common::checkBoxOverlay( $client, keyval($value) eq currentSignalGenerator( $client ) ) );
		},
		'callback' => sub
		{
			my ( $client, $exittype ) = @_;
			$exittype = uc( $exittype );
			if( $exittype eq 'LEFT' )
			{
				Slim::Buttons::Common::popModeRight( $client );
			} 
			elsif( $exittype eq 'RIGHT' )
			{
				# Update the pref setting, then refresh display, but stay in this mode
				my $gentype = keyval($opt);
				setSigGen( $client, $gentype );
				$client->update();
				if( ($gentype eq 'Sine') || ($gentype eq 'Quad') || ($gentype eq 'Square') || ($gentype eq 'BLSquare') ||
				    ($gentype eq 'Triangle') || ($gentype eq 'BLTriangle') || ($gentype eq 'Sawtooth') || ($gentype eq 'BLSawtooth') || ($gentype eq 'ShapedBurst'))
				{
					# Push into adjust-frequency mode for this signal
					my $genfreq = Plugins::SqueezeDSP::DspManager->getPref( $client, 'sigfreq' ) || 1000;
					Slim::Buttons::Common::pushModeLeft( $client, $modeValue, { 
						'header' => $gentype,
						'suffix' => ' ' . $client->string( 'PLUGIN_SQUEEZEDSP_HERTZ' ),
						'min' => 10,
						'max' => 22000,
						'increment' => 1,
						'valueRef' => \$genfreq,
						'parentMode' => Slim::Buttons::Common::mode($client),
						'onChange' => sub
						{
							# Change the value immediately, not on exit...
							setPref( $client, 'sigfreq', $genfreq );
						},
					 } );
				}
				else
				{
					$client->bumpRight();
				}
			}
		}
	);        
	Slim::Buttons::Common::pushMode( $client, 'INPUT.List', \%params );
}

sub jiveSigGenMenu
{
	my $client = shift;
	my $request = shift;

	debug( "jiveSigGenMenu" );
	my %opts = getSignalGeneratorOptions();
	my @choicev = sort keys %opts;
	my @choices = map $opts{$_}, @choicev;
	my $opt = currentSignalGenerator( $client );
	debug( 'current:' . $opt );

	my @menuItems = ();
        for (my $listIndex=0; $listIndex<scalar(@choicev); $listIndex++)
	{
		my $menuItem = $choices[$listIndex];
		my $menuValu = $choicev[$listIndex];

		debug( keyval($menuValu) . "=" . $menuItem );

		push @menuItems, {
			text => $client->string( $menuItem ),
			radio => (keyval($menuValu) eq $opt) + 0,
			id => $thistag . 'sig' . $listIndex,
			weight => ($listIndex + 1) * 10,
			actions => {
				do => {
					player => 0,
					cmd => [$thistag . '.setval'],
					params => {
						'key' => "SigGen",
						'val' => keyval($menuValu),
					},
				},
			},
		};
	}
	return @menuItems;
}

Slim::Buttons::Common::addMode( $modeSigGen, \%noFunctions, \&setSignalGeneratorMode );

=cut


# ------ Mode: PLUGIN.SqueezeDSP.Value ------
# Numeric value chooser
#
# Parameters: header, suffix, min, max, increment, valueRef
=pod
sub setValueMode
{
	my $client = shift;
	my $method = shift;
	if( $method eq 'pop' )
	{
		Slim::Buttons::Common::popMode( $client );
		return;
	}

	# set the scale of the knob
	my $min = $client->modeParam('min') || 10;
	my $max = $client->modeParam('max') || 22000;
	my $valueRef = $client->modeParam('valueRef');
	$client->modeParam('listLen', $max - $min);
	$client->modeParam('listIndex', $$valueRef - $min);
	$client->modeParam('knobFlags', 0);
	$client->modeParam('knobWidth', int($$valueRef/10)+10);
	$client->modeParam('knobHeight', 1);
	$client->modeParam('knobBackgroundForce', 0);
	$client->updateKnob(1);

	$client->lines(\&valueLines);
}

my %valueFunctions = (
	'left' => sub  {
		my $client = shift;
		Slim::Buttons::Common::popModeRight($client);
	},

	'right'=> sub  {
		my $client = shift;
		$client->bumpRight;
	},

	'down' => sub  {
		my $client = shift;
		my $valueRef = $client->modeParam('valueRef');
		my $inc = $client->modeParam('increment') || 1;
		if( Slim::Hardware::IR::holdTime($client) > 0 ) {
			$inc *= Slim::Hardware::IR::repeatCount($client, 200, 10);
		}
		valueSet($client, $$valueRef - $inc);
	},

	'up' => sub  {
		my $client = shift;
		my $valueRef = $client->modeParam('valueRef');
		my $inc = $client->modeParam('increment') || 1;
		if( Slim::Hardware::IR::holdTime($client) > 0 ) {
			$inc *= Slim::Hardware::IR::repeatCount($client, 200, 10);
		}
		valueSet($client, $$valueRef + $inc);
	},

	'knob' => sub {
		my ( $client, $funct, $functarg ) = @_;
		my $min = $client->modeParam('min') || 10;
		valueSet($client, $client->knobPos + $min);
	},

	'passback' => sub {
		my ( $client, $funct, $functarg ) = @_;
		my $parentMode = $client->modeParam('parentMode');
		if( defined($parentMode) ) {
			Slim::Hardware::IR::executeButton($client,$client->lastirbutton,$client->lastirtime,$parentMode);
		}
	},
);
=cut
sub valueSet {
	my $client = shift;
	my $value = shift;
	my $min = $client->modeParam('min') || 10;
	my $max = $client->modeParam('max') || 22000;
	if( $value < $min ) { $value = $min; }
	if( $value > $max ) { $value = $max; }
	my $valueRef = $client->modeParam('valueRef');
	$$valueRef = $value;
	$client->modeParam('listIndex', int($value) - $min);
	$client->modeParam('knobWidth', int($value/10)+10);
	$client->updateKnob(1);
	my $onChange = $client->modeParam('onChange');
	if( ref($onChange) eq 'CODE' ) {
		$onChange->( $client, $$valueRef );
	}
	$client->update();
}

sub valueLines {
	my $client = shift;
	my $valueRef = $client->modeParam('valueRef');
	my $line1 = $client->modeParam('header');
	my $line2 = $$valueRef . $client->modeParam('suffix');
	my $parts = {
		'line'    => [ $line1, $line2 ],
		'overlay' => [ undef, undef ]
	};
	return $parts;
}
=pod
Slim::Buttons::Common::addMode( $modeValue, \%valueFunctions, \&setValueMode );

=cut


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
	my $filt = ( Plugins::SqueezeDSP::DspManager->getPref( $client, 'matrix' ) || '' );
	my ( $vol, $dir, $fil ) = splitpath( $filt );
	$request->addResult("Matrix",    $fil );

	$filt = ( Plugins::SqueezeDSP::DspManager->getPref( $client, 'filter' ) || '' );
	($vol, $dir, $fil) = splitpath( $filt );
	$request->addResult("Filter",    $fil );

	$request->addResult("Amb",        Plugins::SqueezeDSP::DspManager->getPref( $client, 'ambtype' ) );
	$request->addResult("Bands",      Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' ) );
	$request->addResult("Quietness",  Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $QUIETNESSKEY . 'value' ) );
	$request->addResult("Flatness",   Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $FLATNESSKEY . 'value' ) );
	$request->addResult("Width",      Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $WIDTHKEY . 'value' ) );
	$request->addResult("Balance",    Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $BALANCEKEY . 'value' ) );
	$request->addResult("Skew",       Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $SKEWKEY . 'value' ) );
#	$request->addResult("Depth",      Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $DEPTHKEY . 'value' ) );
	$request->addResult("AmbAngle",   Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $AMBANGLEKEY . 'value' ) );
	$request->addResult("AmbDirect",  Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $AMBDIRECTKEY . 'value' ) );
	$request->addResult("AmbjW",      Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $AMBJWKEY . 'value' ) );
	$request->addResult("AmbRotateZ", Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $AMBROTATEZKEY . 'value' ) );
	$request->addResult("AmbRotateY", Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $AMBROTATEYKEY . 'value' ) );
	$request->addResult("AmbRotateX", Plugins::SqueezeDSP::DspManager->getPref( $client, 'band' . $AMBROTATEXKEY . 'value' ) );

	# The current EQ freq/gain values
	my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' );
	my $cnt = 0;
	for( my $n = 0; $n < $bandcount; $n++ )
	{
		my $f = Plugins::SqueezeDSP::DspManager->getPref( $client, 'b' . $n . 'freq' ) || defaultFreq( $client, $n, $bandcount );
		my $v = Plugins::SqueezeDSP::DspManager->getPref( $client, 'b' . $n . 'value' ) || 0;
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

	my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' );
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

		# First clear out the old Jive top menu, since it will change
		jiveClearTopMenu( $client );

		# Set the band count
		setBandCount( $client, $val );

		# ShowBriefly to tell jive users that the band count has been set
		my $line = $client->string('PLUGIN_SQUEEZEDSP_CHOSEN_BANDS');
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );

		# Refresh the Jive main menu
		#my @menuItems = jiveTopMenu( $client );
		#Slim::Control::Jive::registerPluginMenu( \@menuItems, $thistag, $client );
		#Slim::Control::Jive::refreshPluginMenus( $client );
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
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );
	}
	else
	{
		debug( "Can't set, file $path does not exist" );
	}
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


sub setSigGen
{
	my ( $client, $val ) = @_;

	my $prevval = Plugins::SqueezeDSP::DspManager->getPref( $client, 'siggen' );

	# Set the signal generator
	setPref( $client, 'siggen', $val );

	if( $val ne $prevval )
	{
		# rewind to start of track, so the DSP reinitializes
		$client->execute(["playlist", "jump", "+0"]);

		# Special instructions!
		$client->showBriefly( { line => [ "SigGen Changed (TBD)", "Be careful now!" ] } , 2);
	}
}


sub setSigFreq
{
	my ( $client, $val ) = @_;

	# Set the signal generator
	setPref( $client, 'sigfreq', $val );

	# Special instructions!
	$client->showBriefly( { line => [ "SigFreq Changed (TBD)", "Be careful now!" ] } , 2);
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

	my $bandcount = Plugins::SqueezeDSP::DspManager->getPref( $client, 'bands' );
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
	$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );

	$request->setStatusDone();
}


sub topmenuCommand
{
	my $request = shift;
	my $client = $request->client();
	debug( "command: topmenu" );

	if( $request->isNotQuery([[$thistag . '.topmenu']]) )
	{
		my $client = $request->client();
		oops( $client, undef, "topmenu not command" );
		$request->setStatusBadDispatch();
		return;
	}

	my @menuItems = jiveTopMenu( $client, $request );
	debug(Data::Dump::dump(@menuItems));

	my $numitems = scalar(@menuItems);
	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachmenu (@menuItems) {
		$request->setResultLoopHash('item_loop', $cnt, $eachmenu);
		$cnt++;
	}
	
	$request->setStatusDone();
	debug( "topmenu done" );
}



sub settingsmenuCommand
{
	my $request = shift;
	my $client = $request->client();
	debug( "command: settingsmenu" );

	if( $request->isNotQuery([[$thistag . '.settingsmenu']]) )
	{
		my $client = $request->client();
		oops( $client, undef, "settingsmenu not command" );
		$request->setStatusBadDispatch();
		return;
	}

	my @menuItems = jiveSettingsMenu( $client, $request );
	debug(Data::Dump::dump(@menuItems));

	my $numitems = scalar(@menuItems);
	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachmenu (@menuItems) {
		$request->setResultLoopHash('item_loop', $cnt, $eachmenu);
		$cnt++;
	}
	
	$request->setStatusDone();
	debug( "settingsmenu done" );
}


sub ambimenuCommand
{
	my $request = shift;
	my $client = $request->client();
	debug( "command: ambimenu" );

	if( $request->isNotQuery([[$thistag . '.ambimenu']]) )
	{
		my $client = $request->client();
		oops( $client, undef, "ambimenu not command" );
		$request->setStatusBadDispatch();
		return;
	}

	my @menuItems = jiveAmbiMenu( $client, $request );
	debug(Data::Dump::dump(@menuItems));

	my $numitems = scalar(@menuItems);
	$request->addResult("count", $numitems);
	$request->addResult("offset", 0);
	my $cnt = 0;
	for my $eachmenu (@menuItems) {
		$request->setResultLoopHash('item_loop', $cnt, $eachmenu);
		$cnt++;
	}
	
	$request->setStatusDone();
	debug( "ambimenu done" );
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
=pod removed support for pre 7.3 server
=cut
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


=pod remove old squeeze versions pre 7.3
=cut
=pod templat definition moved into separate file
=cut

# added aac entry (jb)
# deleted aap entry (jb)
# replaced alc entry (jb)
# added mp4 entry (jb)
# added spt (spotty) (jb)

1;
