package Plugins::SqueezeDSP::Plugin;
=pod version history
	# ----------------------------------------------------------------------------
	# SqueezeDSP\Plugin.pm - a SlimServer plugin.
	# Makes a remote-control user interface, and writes settings files, which
	# provide parameters for operation of a convolution and filter engine.
	#
	# This file is licensed to you under the terms below.  If you received other
	# files as part of a package containing this file, each might have different
	# license terms.  If you do not accept the terms, do not use the software.
	#
	# Copyright (c) 2006-2012 by Hugh Pyle, inguzaudio.com, and contributors.
	#
	# Permission is hereby granted, free of charge, to any person obtaining a
	# copy of this software and associated documentation files (the "Software"),
	# to deal in the Software without restriction, including without limitation
	# the rights to use, copy, modify, merge, publish, distribute, sublicense,
	# and/or sell copies of the Software, and to permit persons to whom the
	# Software is furnished to do so, subject to the following conditions:
	#
	# The above copyright notice and this permission notice shall be included in
	# all copies or substantial portions of the Software.
	#
	# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
	# IN THE SOFTWARE.
	# ----------------------------------------------------------------------------
	#
	# todo (TBD):
	# 	web html5, ditch silverlight
	# 	web silverlight animated "loading" thing
	# 	web "extra text" on values (flat, etc)
	# 	jive EQ adjust frequency (later, when we have a bar... radiobuttons would be too clunky)
	# 	jive SigGen adjust frequency (ditto)
	# 	jive titlebar icon?
	# 	anything else marked TBD
	#
	#
	# Revision history:
	# 0.9.47			Amended Flac Conv to allow seek -
	#					split templates into separate versioned file; updates are now based off this.
	# 0.9.46
	# JF 2022-11		Remove real old code, relating to 9_2_1 versions and earlier.
	#					Removed settings for server pre 7.3
	#					changed plugin location for settings to be in plugin prefs folder
	#					copy application binary to plugin path	
	#					changed location of binary so that is auto-detected 
	#					added code for setting executable status to binary if not windows
	#					fixed issues with generating custom.conf - no more additional white lines
	#					fixed issue where re-boot required on regeneration of custom.conf
	
						
	# JF 2020-03		Removed references to Silverlight - and added in new SL freed stuff
	# JB's edits
	# 20181212			added aac, mp4 filetypes
	# 					corrected alc filetype to work with later versions of LMS
	# 					deleted aap entry - replaced with aac entry
	# 					added spt entry for Spotty (spotify plugin)
	# 					changed FLAC compression levels to 0 (were 5)
	# 					(very little lost in size but 0 takes significantly less time to encode)
	#
	# 20170805			Warning: Using a hash as a reference is deprecated at 3138
	# 					L3138 $request->addResultLoop( 'Points_loop', $cnt, $ff, %h->{$ff} );
	# 					changed %h->{$ff} to $h{$ff}
	#
	# High Pyle's revisions start here
	# 0.9.33   20120101   encode with flac -5, CPU is cheap now
	#          20110601   Merge contrib from do0g
	# 0.9.30   20090105   SqueezeCenter 7.3 support
	#                     add UHJ filetype
	#                     remove SHN support
	#                     add seek (for WAV and similar)
	# 0.9.29   20081130   SqueezeCenter 7.2.1 support
	#                     fix amb RotateZ serialization
	# 0.9.28   20080412   SqueezeCenter version
	#                     add CLI
	#                     add Jive UI
	#                     add web/silverlight UI
	#                     add ambisonic UI stuff
	#                     balance, width to 9dB; all incr 0.1dB
	#                     lists sort case insensitively
	#                     add sweep(short)
	#                     add .aap (http://wiki.slimdevices.com/index.cgi?AACplus)
	#                     fix 'save preset'
	#                     fix flatness 0 written as 10
	#                     restart track immediately when changing test-signal type
	# 0.9.27   20070930   no change
	# 0.9.25   20070916   add stereo pink noise test signals
	#                     better save-presets default (patch from Toby)
	#                     add -wavo for all FLAC transcodes, mostly for spdif
	# 0.9.24   20070812   add -wav for [alac]
	#                     Register the .amb type properly (6.5)
	# 0.9.23   20070625   Fix large-size Adjust menu
	#                     Add current-values to menus
	#                     Add .amb support (Ambisonics B-format)
	# 0.9.22   20070514   Fix compatibility with SlimServer 6.3.1 (again)
	#                     Fix bad savePrefs bug
	# 0.9.21   20070506   Sweep-with-EQ: separate versions for left and right
	#                     move convert.conf to plugin dir for easier uninstall
	#                     adjustable frequency centers for each EQ band
	#                     fix the HASH(...) bug when loading from empty xml
	#                     more robustness when loading presets/settings
	#                     report cause of fatal errors when upgrading etc
	# 0.9.20   20070422   remove non-band-limited signal generator functions
	# 0.9.18   20070314   skew +/-25 samples, increase from 12
	#                     signal generator: EQ'd versions, channel ident
	#                     signal generator: editable frequency
	# 0.9.16   20070311   Fix compatibility with SlimServer 6.3.1
	# 0.9.15   20070310   Add signal-generator mode
	#                     Put the source formatting back
	#                     Miscellaneous tweaks
	# 0.9.13   20070113   Fix & test the APE, Ogg and MusePack file types
	# 0.9.12   20070113   Add linux support (debian, redhat)
	# 0.9.11   20070101   Nice graphical button overlay
	#                     Don't show the Flatness menu unless a room-correction
	#                       filter has been selected (it's a no-op)
	#                     Add matrix/width controls
	#                     Add balance/skew controls
	#                     Move equalizer type onto its own submenu
	#                     Better defaults for first-time use
	#                     Source formatting: fewer tabs
	# 0.9.10   20061106   Fix non-44100 bitrates (SlimServer 6.5 or greater
	#                       only), otherwise they play too fast or too slow
	#                     Fix the AIFF filetype
	#                     Fix the ALC (apple lossless) filetype
	# 0.9.9    20060930   Use the $RATE$ flag to pass thru samplerate for 6.5
	#                       and above
	#                     Fix the WAV source type (for arbitrary wav files)
	#                     Fix for mov123 (big-endian output)
	# 0.9.8    20060811   Send WAV not FLAC to softsqueeze and SB1 clients
	#                     Make menus' last-used-position stickier
	# 0.9.7    20060730   Add 'flatness' control
	# 0.9.6    20060716   Transcode to FLAC24 to avoid losing any dynamic range
	# 0.9.5    20060603   Beta release under MIT-style free software license
	#
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
my $revision = "0.9.47";
use vars qw($VERSION);
$VERSION = $revision;

# Names and name-related constants...
#
my $thistag = "inguzeq";
my $thisapp = "InguzEQ";
my $binary;
my $settingstag = "InguzEQSettings";
my $confBegin = "inguzeq#begin";
my $confEnd = "inguzeq#end";
my $modeAdjust       = "PLUGIN.InguzEQ.Adjust";
my $modeValue        = "PLUGIN.InguzEQ.Value";
my $modePresets      = "PLUGIN.InguzEQ.Presets";
my $modeSettings     = "PLUGIN.InguzEQ.Settings";
my $modeEqualization = "PLUGIN.InguzEQ.Equalization";
my $modeRoomCorr     = "PLUGIN.InguzEQ.RoomCorrection";
my $modeMatrix       = "PLUGIN.InguzEQ.Matrix";
my $modeSigGen       = "PLUGIN.InguzEQ.SignalGenerator";
my $modeAmbisonic    = "PLUGIN.InguzEQ.Ambisonic";

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

# the usual convolver controlled by this plugin is called InguzDSP - this is
# the command inserted in custom-convert.conf
#
my $convolver = "InguzDSP";
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
my $pluginDataDir;            # <appdata>\inguzeq
my $pluginSettingsDataDir;    # <appdata>\inguzeq\Settings     used for settings and presets
my $pluginImpulsesDataDir;    # <appdata>\inguzeq\Impulses     used for room correction impulse filters
my $pluginMatrixDataDir;      # <appdata>\inguzeq\Matrix       used for cross-feed matrix impulse filters
my $pluginMeasurementDataDir; # <appdata>\inguzeq\Measurement  used for measurement sweeps and noise samples
my $pluginTempDataDir;        # <appdata>\inguzeq\Temp         used for any temporary stuff
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
	my $labl = ' ' . $client->string( 'PLUGIN_INGUZEQ_DECIBELS' );
	my $sign = ( $valu > 0 ) ? '+' : '';
	my $extra = ( $valu == 0 ) ? ' ' . $client->string( 'PLUGIN_INGUZEQ_EQ_FLAT' ) : '';
	if( $item eq $QUIETNESSKEY )
	{
		$sign = '';
		$labl = '';
		$extra = ( $valu == 0 ) ? ' ' . $client->string( 'PLUGIN_INGUZEQ_QUIETNESS_OFF' ) : '';
	}
	elsif( $item eq $FLATNESSKEY )
	{
		$sign = '';
		$labl = '';
		$extra = ( $valu == 10 ) ? ' ' . $client->string( 'PLUGIN_INGUZEQ_FLATNESS_FLAT' ) : '';
	}
	elsif( ($item eq $SKEWKEY) || ($item eq $DEPTHKEY) )
	{
		$labl = ' ' . $client->string( 'PLUGIN_INGUZEQ_SAMPLES' );
		$extra = '';
	}
	elsif( ($item eq $AMBANGLEKEY) || ($item eq $AMBROTATEZKEY) || ($item eq $AMBROTATEYKEY) || ($item eq $AMBROTATEXKEY) )
	{
		$sign = '';
		$labl = ' ' . $client->string( 'PLUGIN_INGUZEQ_DEGREES' );
		$extra = '';
	}
	elsif( $item eq $AMBDIRECTKEY )
	{
		$sign = '';
		$labl = '';
		# hypercardioid is 0.3333 (1/3)
		# supercardioid is 0.5773 (sqrt3/3)
		if( $valu==0 )    { $extra = ' ' . $client->string( 'PLUGIN_INGUZEQ_AMBI_DIRECT_FIGURE8' ); }
		if( $valu==0.33 ) { $extra = ' ' . $client->string( 'PLUGIN_INGUZEQ_AMBI_DIRECT_HYPERCARDIOID' ); }
		if( $valu==0.58 ) { $extra = ' ' . $client->string( 'PLUGIN_INGUZEQ_AMBI_DIRECT_SUPERCARDIOID' ); }
		if( $valu==1 )    { $extra = ' ' . $client->string( 'PLUGIN_INGUZEQ_AMBI_DIRECT_CARDIOID' ); }
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
			my @v = ( 'PLUGIN_INGUZEQ_BASS', 'PLUGIN_INGUZEQ_TREBLE' );
			$labl = $client->string( $v[$item] );
		}
		elsif( $bandcount==3 )
		{
			my @v = ( 'PLUGIN_INGUZEQ_BASS', 'PLUGIN_INGUZEQ_MID', 'PLUGIN_INGUZEQ_TREBLE' );
			$labl = $client->string( $v[$item] );
		}
		else
		{
			if( $freq > 1000 )
			{
				$labl = ( int( $freq / 100 ) / 10 ) . ' ' . $client->string( 'PLUGIN_INGUZEQ_KILOHERTZ' );
			}
			else
			{
				$labl = int( $freq ) . ' ' . $client->string( 'PLUGIN_INGUZEQ_HERTZ' );
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
			return qw(/publishLinux-x64/InguzDSP );
		}
		if ($os->{'binArch'} =~ /i386/) {
			return qw(/publishLinux-x86/InguzDSP);
		}
		if ($os->{'osArch'} =~ /aarch64/) {
			return qw(/publishlinux-arm64/InguzDSP) ;
		}
		if ($os->{'binArch'} =~ /armhf/) {
			return qw( /publishlinux-arm/InguzDSP );
		}
		if ($os->{'binArch'} =~ /arm/) {
			return qw( /publishlinux-arm/InguzDSP );
		}
		
		# fallback to offering all linux options for case when architecture detection does not work
		return qw( /publishLinux-x86/InguzDSP );
	}
	
	if ($os->{'os'} eq 'Unix') {
	
		if ($os->{'osName'} =~ /freebsd/) {
			return qw( /publishLinux-x64/InguzDSP );
		}
		
	}	
	
	if ($os->{'os'} eq 'Darwin') {
		return qw(/publishOsx-x64/InguzDSP );
	}
		
	if ($os->{'os'} eq 'Windows') {
		return qw(\publishWin32\InguzDSP.exe);
	}	
	
}



# ------ slimserver delegates and initialization ------

sub getFunctions
{
	return \%noFunctions;
}

sub getDisplayName
{
	return 'PLUGIN_INGUZEQ_DISPLAYNAME';
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
=begin mhereger suggested changing this to a folder installed on the plugin path.

	 
	 if(Slim::Utils::OSDetect::OS() eq 'win')
	 {
		# # Application data lives in a folder under \Documents and Settings\All Users\Application Data\
		# # (plugin may not always have write access to \Program Files\SqueezeCenter\Plugins\)
		 $appdata = Win32::GetFolderPath(0x0023); # 0x0023 is Win32::CSIDL_COMMON_APPDATA, but on linux that breaks for some reason
	 }
	 else
	 {
		# # debian, redhat, and everything else
		 $appdata = '/usr/share';
		# #$appdata = '/usr/local/slimserver/prefs';
	 }
=cut	

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
	#do any app config settings, simplifies handover to Inguz app
	my $appConfig = catdir(Slim::Utils::PluginManager->allPlugins->{$thisapp}->{'basedir'}, 'Bin',"/", 'InguzDSP.dll.config');
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

	if( Slim::Utils::PluginManager->isEnabled("Plugins::InguzEQ::Plugin") )
	{
		Slim::Web::Pages->addPageFunction("plugins/InguzEQ/index.html", \&handleWebIndex);
		Slim::Web::Pages->addPageFunction("plugins/InguzEQ/inguz.png", \&handleWebStatic);
		Slim::Web::Pages->addPageLinks("plugins", { $class->getDisplayName => 'plugins/InguzEQ/index.html' });
		Slim::Web::Pages->addPageLinks("icons",   { $class->getDisplayName => 'plugins/InguzEQ/inguz.png' });
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
		return Slim::Web::HTTP::filltemplatefile('plugins/InguzEQ/index.html', $params);
		#We now no longer need to flash the restart message, because the table is reloaded automatically	
		# Very first thing: check the config and prefs.
		#if( $needUpgrade==1 )
		#{
	#		return Slim::Web::HTTP::filltemplatefile('plugins/InguzEQ/restart.html', $params);
	#	}
	#	else
	#	{
	#		return Slim::Web::HTTP::filltemplatefile('plugins/InguzEQ/index.html', $params);
	#	}
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
	return catdir( $pluginSettingsDataDir, join('_', split(/:/, $client->id())) . '.settings.conf' );
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

	my $line = $client->string('PLUGIN_INGUZEQ_PRESET_LOADED');
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
		return( "Type=\"Ident\" L=\"" . $client->string('PLUGIN_INGUZEQ_SIGGEN_IDENT_L') . "\" R=\"" . $client->string('PLUGIN_INGUZEQ_SIGGEN_IDENT_R') . "\"" ); 
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

# ------ main-menu mode ------


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
		my $bandcount = getPref( $client, 'bands' );
		if( $bandcount<2 ) { $bandcount=2; }
		if( $bandcount>90 ) { $bandcount=90; }
		for( my $b = 0; $b < $bandcount; $b++ )
		{
			$over{$b} = valuelabel( $client, $b, getPref( $client, 'b' . $b . 'value' ) );
		}

		if( currentFilter( $client ) ne '-' )
		{
			$over{'91.' . $FLATNESSKEY} = valuelabel( $client, $FLATNESSKEY, getPref( $client, 'band' . $FLATNESSKEY . 'value' ) );
		}

		$over{'92.' . $QUIETNESSKEY} = valuelabel( $client, $QUIETNESSKEY, getPref( $client, 'band' . $QUIETNESSKEY . 'value' ) );
		$over{'93.' . $BALANCEKEY}   = valuelabel( $client, $BALANCEKEY, getPref( $client, 'band' . $BALANCEKEY . 'value' ) );
		$over{'94.' . $WIDTHKEY}     = valuelabel( $client, $WIDTHKEY, getPref( $client, 'band' . $WIDTHKEY . 'value' ) );
		$over{'95.' . $SETTINGSKEY}  = "";
		$over{'96.' . $PRESETSKEY}   = "";
	}
	return %over;
}


sub getMainMenuChoices
{
	my $client = shift;
	defaultPrefs( $client );

	my %opts = ();
	if( $fatalError )
	{
		$opts{$ERRORKEY} = "Error: " . $fatalError;
	}
	elsif( $needUpgrade==1 )
	{
		$opts{$ERRORKEY} = $client->string( 'PLUGIN_INGUZEQ_RESTART' );
	}
	else
	{
		my $bandcount = getPref( $client, 'bands' );
		if( $bandcount<2 ) { $bandcount=2; }
		if( $bandcount>90 ) { $bandcount=90; }
		for( my $b = 0; $b < $bandcount; $b++ )
		{
			$opts{$b} = freqlabel( $client, $b );
		}

		if( currentFilter( $client ) ne '-' )
		{
			$opts{'91.' . $FLATNESSKEY} = $client->string( 'PLUGIN_INGUZEQ_FLATNESS' );
		}

		$opts{'92.' . $QUIETNESSKEY} = $client->string( 'PLUGIN_INGUZEQ_QUIETNESS' );
		$opts{'93.' . $BALANCEKEY}   = $client->string( 'PLUGIN_INGUZEQ_BALANCE' );
		$opts{'94.' . $WIDTHKEY}     = $client->string( 'PLUGIN_INGUZEQ_WIDTH' );
		$opts{'95.' . $SETTINGSKEY}  = $client->string( 'PLUGIN_INGUZEQ_SETTINGS' );
		$opts{'96.' . $PRESETSKEY}   = $client->string( 'PLUGIN_INGUZEQ_PRESETS' );
	}
	return %opts;
}


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

	my $valu = getPref( $client, 'mainmenu' ) || @choicev[0];

	# Use INPUT.List to display the main menu
	my %params =
	(
		'header' => 'PLUGIN_INGUZEQ_LINE1',
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
#			window => { 'text' => $k, 'icon-id' => 'plugins/InguzEQ/inguz.png', 'titleStyle' => 'artists' },
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


# ------ Mode: PLUGIN.InguzEQ.Settings ------
# Display the setttings menu


sub getSettingsOptions
{
	my $addAmbi = shift;

	my %opts = ();
	$opts{'-e-'} = 'PLUGIN_INGUZEQ_EQUALIZER';
	$opts{'-r-'} = 'PLUGIN_INGUZEQ_ROOMCORR';
	$opts{'-x-'} = 'PLUGIN_INGUZEQ_MATRIX';
	$opts{$SKEWKEY} = 'PLUGIN_INGUZEQ_SKEW';
#	$opts{$DEPTHKEY} = 'PLUGIN_INGUZEQ_DEPTH';
	$opts{'-y-'} = 'PLUGIN_INGUZEQ_SIGGEN';

	if( $addAmbi )
	{
		$opts{'-z-'} = 'PLUGIN_INGUZEQ_AMBI_DECODE';
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

	my $menuopt = getPref( $client, 'settingsmenu' ) || '-e-';
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
		'header' => 'PLUGIN_INGUZEQ_CHOOSE_SETTINGS',
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




# ------ Mode: PLUGIN.InguzEQ.Ambisonic ------
# Display the Ambisonic setttings menu


sub getAmbiOptions
{
	my %opts = ();
	$opts{'01.UHJ'} = 'PLUGIN_INGUZEQ_AMBI_UHJ';
	$opts{'02.Blumlein'} = 'PLUGIN_INGUZEQ_AMBI_BLUMLEIN';
	$opts{'03.Crossed'} = 'PLUGIN_INGUZEQ_AMBI_CARDIOID';
#	$opts{'04.Crossed+jW'} = 'PLUGIN_INGUZEQ_AMBI_CARDIOID_PLUSJW';
	$opts{$AMBANGLEKEY} = 'PLUGIN_INGUZEQ_AMBI_CARDIOID_ANGLE';
	$opts{$AMBDIRECTKEY} = 'PLUGIN_INGUZEQ_AMBI_CARDIOID_DIRECT';
#	$opts{$AMBJWKEY} = 'PLUGIN_INGUZEQ_AMBI_CARDIOID_JW';
	$opts{$AMBROTATEZKEY} = 'PLUGIN_INGUZEQ_AMBI_ROTATION_Z';
	$opts{$AMBROTATEYKEY} = 'PLUGIN_INGUZEQ_AMBI_ROTATION_Y';
	$opts{$AMBROTATEXKEY} = 'PLUGIN_INGUZEQ_AMBI_ROTATION_X';

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

	my $menuopt = getPref( $client, 'ambimenu' ) || 'UHJ';
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
		'header' => 'PLUGIN_INGUZEQ_AMBI_CHOOSE_SETTINGS',
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

	my $opt = getPref( $client, "ambtype" );

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


# ------ Mode: PLUGIN.InguzEQ.Equalization ------
# Choose how many channels of equalization to use


sub getEqualizationOptions
{
	my $more = shift;
	my %opts = ();
	$opts{"02"} = 'PLUGIN_INGUZEQ_2BAND';
	$opts{"03"} = 'PLUGIN_INGUZEQ_3BAND';
	$opts{"05"} = 'PLUGIN_INGUZEQ_5BAND';
	$opts{"09"} = 'PLUGIN_INGUZEQ_9BAND';
	if( $more )
	{
		$opts{"15"} = 'PLUGIN_INGUZEQ_15BAND';
		$opts{"31"} = 'PLUGIN_INGUZEQ_31BAND';
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
	my $bandcount = getPref( $client, 'bands' ) || 2;

	# Use INPUT.List to display the list of band choices
	my %params =
	(
		'header' => 'PLUGIN_INGUZEQ_CHOOSE_EQSETTINGS',
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
			return ( undef, Slim::Buttons::Common::checkBoxOverlay( $client, ($value+0) eq getPref( $client, 'bands' ) ) );
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
	my $bandcount = getPref( $client, 'bands' ) || 2;

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



# ------ Mode: PLUGIN.InguzEQ.Adjust ------
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

	my $bandcount = getPref( $client, 'bands' );
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
		$valu = getPref( $client, $prefValuKey );
		$freq = getPref( $client, $prefFreqKey ) || defaultFreq( $client, $item, $bandcount );
	}
	else
	{
		# Other stuff
		$itemName = $client->modeParam('itemName');
		$prefValuKey = 'band' . $item . 'value';
		$valu = getPref( $client, $prefValuKey );
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
					my $bandcount = getPref( $client, 'bands' );
					my $min = 10;
					if( $item > 0 ) { $min = int( getPref( $client, 'b' . ($item-1). 'freq' ) || defaultFreq( $client, ($item-1), $bandcount ) ) + 5; }
					my $max = 22000;
					if( $item < $bandcount-1 ) { $max = int( getPref( $client, 'b' . ($item+1). 'freq' ) || defaultFreq( $client, ($item+1), $bandcount ) ) - 5; }
					debug( $item . " of " . $bandcount . ", min " . $min . ", max " . $max );
					Slim::Buttons::Common::pushModeLeft( $client, $modeValue, { 
						'header' => $client->string( 'PLUGIN_INGUZEQ_BANDCENTER' ),
						'suffix' => ' ' . $client->string( 'PLUGIN_INGUZEQ_HERTZ' ),
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

sub round
{
	my ( $valu, $increment ) = @_;
	my $val2 = ($valu + 0) / $increment;
	$val2 = int($val2 + .5 * ($val2 <=> 0));
	return $val2 * $increment;
}

sub jiveAdjustMenu
{
	my $client = shift;
	my $request = shift;
	my $item = shift;

	debug( "jiveAdjustMenu" );

	my $bandcount = getPref( $client, 'bands' );
	my $prefValuKey;
	my $prefFreqKey;
	my $valu;			# the level (dB) for this band
	my $freq;			# the center frequency for this band (if applicable)
	if( $item =~ /^-?\d/ )
	{
		# EQ bands
		$prefValuKey = 'b' . $item . 'value';
		$prefFreqKey = 'b' . $item . 'freq';
		$valu = getPref( $client, $prefValuKey );
		$freq = getPref( $client, $prefFreqKey ) || defaultFreq( $client, $item, $bandcount );
	}
	else
	{
		# Other stuff
		$prefValuKey = 'band' . $item . 'value';
		$valu = getPref( $client, $prefValuKey );
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




# ------ Mode: PLUGIN.InguzEQ.Presets ------
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
	my %presets = ( '-' => $client->string('PLUGIN_INGUZEQ_SAVEPRESETAS') );
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
		'header' => 'PLUGIN_INGUZEQ_CHOOSE_PRESET',
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
	return getPref( $client, 'preset' ) || '-';
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

	my $oldfile = getPref( $client, 'preset' ); 
	my ( $vol, $dir, $name ) = splitpath( $oldfile );
	$name =~ s/\.(?:(preset\.conf))$//i;
	my %params =
	(
		'header' => 'PLUGIN_INGUZEQ_SAVEPRESETFILE',
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
					$client->showBriefly( { line => [ $name, $client->string('PLUGIN_INGUZEQ_PRESET_SAVED') ] } , 2) if $ok;
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
					allowedChars => Slim::Utils::Strings::string('PLUGIN_INGUZEQ_FILECHARS'),
					help         => {
						           text => Slim::Utils::Strings::string('PLUGIN_INGUZEQ_PRESET_HELP'),
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
					text => Slim::Utils::Strings::string('PLUGIN_INGUZEQ_SAVEPRESETFILE'),
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


# ------ Mode: PLUGIN.InguzEQ.RoomCorrection ------
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
	my %impulses = ( '-' => $client->string('PLUGIN_INGUZEQ_FILTERNONE') );
	my %more = getFiltersListNoNone( $client, $folder, $nopath );
	@impulses{keys %more} = values %more;
	return %impulses;
}

sub currentFilter
{
	my $client = shift;
	return getPref( $client, 'filter' ) || '-';
}

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
		'header' => 'PLUGIN_INGUZEQ_CHOOSE_RCFILTER',
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



# ------ Mode: PLUGIN.InguzEQ.Matrix ------
# Displays menu to control stereo image width and cross-feed filters.
# Cross-feed filters are any file in the plugin's Matrix folder with .WAV file extension.
# Of course not all wav files will work properly as filters, but this plugin doesn't know that.


sub currentMatrixFilter
{
	my $client = shift;
	return getPref( $client, 'matrix' ) || '-';
}

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
		'header' => 'PLUGIN_INGUZEQ_CHOOSE_MATRIXFILTER',
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




# ------ Mode: PLUGIN.InguzEQ.SignalGenerator ------
# Displays menu to control a signal generator.
# Signal-generator mode "None" just plays the music.  Anything else overrides the music with a test signal.


sub currentSignalGenerator
{
	my $client = shift;
	return getPref( $client, 'siggen' ) || 'None';
}

sub getSignalGeneratorOptions
{
	my %opts = ();

	$opts{'01.None'}        = 'PLUGIN_INGUZEQ_SIGGEN_NONE';
	$opts{'02.Ident'}       = 'PLUGIN_INGUZEQ_SIGGEN_IDENT';
	$opts{'03.Sweep'}       = 'PLUGIN_INGUZEQ_SIGGEN_SWEEP';
	$opts{'03.SweepShort'}  = 'PLUGIN_INGUZEQ_SIGGEN_SWEEP_SHORT';
	$opts{'04.SweepEQL'}    = 'PLUGIN_INGUZEQ_SIGGEN_SWEEP_EQ_L';
	$opts{'05.SweepEQR'}    = 'PLUGIN_INGUZEQ_SIGGEN_SWEEP_EQ_R';
	$opts{'06.Pink'}        = 'PLUGIN_INGUZEQ_SIGGEN_PINK';
	$opts{'07.PinkEQ'}      = 'PLUGIN_INGUZEQ_SIGGEN_PINK_EQ';
	$opts{'08.PinkSt'}      = 'PLUGIN_INGUZEQ_SIGGEN_PINK_STEREO';
	$opts{'09.PinkStEQ'}    = 'PLUGIN_INGUZEQ_SIGGEN_PINK_STEREO_EQ';
	$opts{'10.White'}       = 'PLUGIN_INGUZEQ_SIGGEN_WHITE';
	$opts{'11.Sine'}        = 'PLUGIN_INGUZEQ_SIGGEN_SINE';
	$opts{'12.Quad'}        = 'PLUGIN_INGUZEQ_SIGGEN_QUAD';
	$opts{'13.BLSquare'}    = 'PLUGIN_INGUZEQ_SIGGEN_SQUARE';
	$opts{'14.BLTriangle'}  = 'PLUGIN_INGUZEQ_SIGGEN_TRIANGLE';
	$opts{'15.BLSawtooth'}  = 'PLUGIN_INGUZEQ_SIGGEN_SAWTOOTH';
	$opts{'16.Intermodulation'} = 'PLUGIN_INGUZEQ_SIGGEN_IM';
#	$opts{'17.ShapedBurst'} = 'PLUGIN_INGUZEQ_SIGGEN_BURST';

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
		'header' => 'PLUGIN_INGUZEQ_CHOOSE_SIGGEN',
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
					my $genfreq = getPref( $client, 'sigfreq' ) || 1000;
					Slim::Buttons::Common::pushModeLeft( $client, $modeValue, { 
						'header' => $gentype,
						'suffix' => ' ' . $client->string( 'PLUGIN_INGUZEQ_HERTZ' ),
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




# ------ Mode: PLUGIN.InguzEQ.Value ------
# Numeric value chooser
#
# Parameters: header, suffix, min, max, increment, valueRef

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

Slim::Buttons::Common::addMode( $modeValue, \%valueFunctions, \&setValueMode );




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

		# First clear out the old Jive top menu, since it will change
		jiveClearTopMenu( $client );

		# Set the band count
		setBandCount( $client, $val );

		# ShowBriefly to tell jive users that the band count has been set
		my $line = $client->string('PLUGIN_INGUZEQ_CHOSEN_BANDS');
		$client->showBriefly( { 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 } );

		# Refresh the Jive main menu
		my @menuItems = jiveTopMenu( $client );
		Slim::Control::Jive::registerPluginMenu( \@menuItems, $thistag, $client );
		Slim::Control::Jive::refreshPluginMenus( $client );
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

		my $line = $client->string('PLUGIN_INGUZEQ_CHOSEN_VALUE');
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
		my $msg = ( $prf eq 'matrix' ) ? 'PLUGIN_INGUZEQ_CHOSEN_MATRIXFILTERNONE' : 'PLUGIN_INGUZEQ_CHOSEN_RCFILTERNONE';
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
		my $msg = ( $prf eq 'matrix' ) ? 'PLUGIN_INGUZEQ_CHOSEN_MATRIXFILTER' : 'PLUGIN_INGUZEQ_CHOSEN_RCFILTER';
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

	my $prevval = getPref( $client, 'siggen' );

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

	my $line = $client->string('PLUGIN_INGUZEQ_PRESET_SAVED');
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
