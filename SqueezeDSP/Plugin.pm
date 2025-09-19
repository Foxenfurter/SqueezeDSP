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
    0.1.31	Fox: Revised Binary, fixed gapless playback by caching latest player filter and fixed issue with 24 bit aiff file not being read correctly
	0.1.30	Fox: Revised behaviour so that player settings are created on the UI and saved here rather than managed here. This simlifies design and communication between the UI and the binary.

	0.1.28	Fox: Found issue where there is only a PEQ filter, then the checks for FIR filter cause early termination.
	0.1.27	Fox: Found issue where there is no filter of any kind, end of processing tail handler fails and closes prematurely.
	0.1.26	Fox: Found issue where there is no filter of any kind. Output runs but with zero gain.
	0.1.25	Fox: Binary using sox for resampling, now that I have figured out the highest quality settings. Normaliser is based off FFT peak, as more accurate - code cleaned
				Transcoder, fixing issue with alc where the parameter order affects whether transcoding works. 
	0.1.24	Fox: Fixed issue with cleanup vs REW filters being wrong, now detects where impulse peak is at start of the file and trims accordingly
				Extended length of PEQ filter, likely inaudible but should be more effective
				Amended mp3 transcoder so that it works with talkSport. (lame now outputs wav rather than raw)
	0.1.23	Fox: Changes to binary, Bug fixes - Disable Low/High Pass amd :ow/High Shelf filters no longer build filters
				Loudness filter working
				width filter gain neutral, before gain was super-boosted
				FIR Filters are now trimmed to the point where level is -70 dBFS with a margin and windowing.
				Fixed Minor issue with convolver when merging fir and PEQ filters
				This seems to fix the Housecurve filter issue and results in smaller filters that are just as effective

	0.1.22	Fox: Major bug fixes to binary, including:
				Wav Reader now handles PCM and AIF correctly as well as detecting end of data section for WAV files, this stope early termination
				Fixed issue with Wav Reader, reading only frame samples rather than the intended block loading of 1/5 second this fixed issue with stuttering
				Fixed issue with Convolver setting signal length = impulse length. This could cause choking on large impulses as buffers were emptied
				Reduced buffer sizes for GO Channel processing as no longer needed, reduces memory footprint
				
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
use FindBin qw($Bin);
use Slim::Utils::Log;
use Slim::Utils::Prefs;

# ======== START: VARIABLE DECLARATIONS ========
# Package-level declarations (at the top, before any subs)
our (
    $log,                # Log object
    $prefs,              # Preferences object
    $thisapp,            # Application name
    $pluginDataDir,      # Main plugin directory
    $pluginSettingsDataDir, # Settings directory
    $pluginImpulsesDataDir, # Impulses directory
    $pluginMatrixDataDir,   # Matrix directory
    $pluginTempDataDir,     # Temp directory
    $convolver,          # Convolver name
    $logfile,            # Log file path
    $fatalError,         # Fatal error message
    $needUpgrade,        # Upgrade flag
    $doneJiveInit,       # Jive init flag
    $configPath,         # Config path
    $thistag,            # Plugin tag
    $myconfigrevision,   # Config revision
    $binversion          # Binary version
);

# Revision number
my $revision = "0.1.31";
$binversion = "0_2_10";
use vars qw($VERSION);
$VERSION = $revision;

# Names and name-related constants...
$thistag = "squeezedsp";
$thisapp = "SqueezeDSP";
my $binary;
my $settingstag = "SqueezeDSPSettings";
my $confBegin = "SqueezeDSP#begin";
my $confEnd = "SqueezeDSP#end";
my $modeAdjust       = "PLUGIN.SqueezeDSP.Adjust";
my $modeValue        = "PLUGIN.SqueezeDSP.Value";
my $modePresets      = "PLUGIN.SqueezeDSP.Presets";
my $modeSettings     = "PLUGIN.SqueezeDSP.Settings";
my $modeEqualization = "PLUGIN.SqueezeDSP.Equalization";
my $modeRoomCorr     = "PLUGIN.SqueezeDSP.RoomCorrection";
my $modeMatrix       = "PLUGIN.SqueezeDSP.Matrix";

our %noFunctions = ();
$needUpgrade = 0;
$fatalError = undef;
$doneJiveInit = 0;
# ======== END: VARIABLE DECLARATIONS ========

# Load submodules
use Plugins::SqueezeDSP::Settings;
use Plugins::SqueezeDSP::TemplateConfig;
use Plugins::SqueezeDSP::Configuration;
use Plugins::SqueezeDSP::UI_Functions;
use Plugins::SqueezeDSP::Utils;
use Plugins::SqueezeDSP::Binary;

sub initPlugin {
    my $class = shift;
    $class->SUPER::initPlugin( @_ );

    # ======== START: VARIABLE INITIALIZATION ========
    # Initialize log and preferences
    $log = Slim::Utils::Log->addLogCategory({ 
        'category' => 'plugin.' . $thistag, 
        'defaultLevel' => 'WARN', 
        'description'  => $thisapp 
    });
    $prefs = preferences('plugin.' . $thistag);
    
    # Initialize directories
    my $appdata = Slim::Utils::Prefs::dir();
    $pluginDataDir = catdir($appdata, $thisapp);
    mkdir($pluginDataDir);
    $pluginSettingsDataDir = catdir($pluginDataDir, 'Settings');
    mkdir($pluginSettingsDataDir);
    $pluginImpulsesDataDir = catdir($pluginDataDir, 'Impulses');
    mkdir($pluginImpulsesDataDir);
    $pluginMatrixDataDir = catdir($pluginDataDir, 'MatrixImpulses');
    mkdir($pluginMatrixDataDir);
    $pluginTempDataDir = catdir($pluginDataDir, 'Temp');
    mkdir($pluginTempDataDir);
    
    # Other initializations
    $convolver = "SqueezeDSP";
    $logfile = catdir(Slim::Utils::OSDetect::dirsFor('log'), "squeezedsp.log");
    $myconfigrevision = Plugins::SqueezeDSP::TemplateConfig::get_config_revision();
    # ======== END: VARIABLE INITIALIZATION ========

    Plugins::SqueezeDSP::Utils::debug("plugin " . $revision . " enabled");

    # Register json/CLI functions
    Slim::Control::Request::addDispatch([$thistag . '.filters'], [1, 1, 0, \&Plugins::SqueezeDSP::UI_Functions::filtersQuery]);
    Slim::Control::Request::addDispatch([$thistag . '.saveas'], [1, 1, 1, \&Plugins::SqueezeDSP::UI_Functions::saveasCommand]);
    Slim::Control::Request::addDispatch([$thistag . '.logsummary'], [1, 1, 0, \&Plugins::SqueezeDSP::UI_Functions::logsummaryQuery]);
    Slim::Control::Request::addDispatch([$thistag . '.saveall'], [1, 1, 1, \&Plugins::SqueezeDSP::UI_Functions::saveallCommand]);
    Slim::Control::Request::addDispatch([$thistag . '.readclientSettings'], [1, 1, 1, \&Plugins::SqueezeDSP::UI_Functions::readClientSettings]);
    Slim::Control::Request::addDispatch([$thistag . '.readpresetSettings'], [1, 1, 1, \&Plugins::SqueezeDSP::UI_Functions::readPresetSettings]);
    Slim::Control::Request::addDispatch([$thistag . '.importwav'], [1, 1, 1, \&Plugins::SqueezeDSP::UI_Functions::importwavCommand]);

    # Binary setup and housekeeping
    Plugins::SqueezeDSP::Binary::setup_binary($class);
    Plugins::SqueezeDSP::Binary::housekeeping();
    Plugins::SqueezeDSP::Configuration::removeNativeConversion();
    
    # Event subscription
    Slim::Control::Request::subscribe(\&clientEvent, [['client'],['new']]);
}

sub shutdown {
    Slim::Control::Request::unsubscribe(\&clientEvent);
}

sub clientEvent {
    my $request = shift;
    my $client  = $request->client();
    return unless defined $client;
    
    Plugins::SqueezeDSP::Configuration::initConfiguration($client);
    
    if (!$doneJiveInit) {
        my $node = {
            id => $thistag,
            text => Slim::Utils::Strings::string(getDisplayName()),
            weight => 5,
            node => 'extras',
        };
        Slim::Control::Jive::registerPluginNode($node);
        Plugins::SqueezeDSP::Utils::debug($thistag . " node registered");
        $doneJiveInit = 1;
    }
}

sub webPages {
    my $class = shift;
    if (Slim::Utils::PluginManager->isEnabled("Plugins::SqueezeDSP::Plugin")) {
        Slim::Web::Pages->addPageFunction("plugins/SqueezeDSP/index.html", \&handleWebIndex);
        Slim::Web::Pages->addPageLinks("plugins", { $class->getDisplayName => 'plugins/SqueezeDSP/index.html' });
    } else {
        Slim::Web::Pages->addPageLinks("plugins", { $class->getDisplayName => undef });
        Slim::Web::Pages->addPageLinks("icons", { $class->getDisplayName => undef });
    }
}

sub handleWebIndex {
    my ($client, $params) = @_;
    return Slim::Web::HTTP::filltemplatefile('plugins/SqueezeDSP/index.html', $params) if $client;
}

sub getFunctions { return \%noFunctions; }
sub getDisplayName { return 'PLUGIN_SQUEEZEDSP_DISPLAYNAME'; }
sub enabled { return 1; }
sub getpluginVersion { return $revision; }

1;