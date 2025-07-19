package Plugins::SqueezeDSP::Utils;
use strict;
use File::Spec::Functions qw(:ALL);
use File::Path;
use JSON::XS;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
# Access Plugin's variables


my $log = $Plugins::SqueezeDSP::Plugin::log;
my $thisapp = $Plugins::SqueezeDSP::Plugin::thisapp;
my $pluginDataDir = $Plugins::SqueezeDSP::Plugin::pluginDataDir;
my $pluginSettingsDataDir = $Plugins::SqueezeDSP::Plugin::pluginSettingsDataDir;
my $pluginImpulsesDataDir = $Plugins::SqueezeDSP::Plugin::pluginImpulsesDataDir;
my $pluginMatrixDataDir = $Plugins::SqueezeDSP::Plugin::pluginMatrixDataDir;
my $pluginTempDataDir = $Plugins::SqueezeDSP::Plugin::pluginTempDataDir;
my $prefs = $Plugins::SqueezeDSP::Plugin::prefs;

sub keyval {
    my $k = shift;
    $k =~ s/^[\d]*\.//;
    return $k;
}

sub debug {
    my $txt = shift;
    $Plugins::SqueezeDSP::Plugin::log->info($thisapp . ": " . $txt . "\n");
}

sub oops {
    my ($client, $desc, $message) = @_;
    $Plugins::SqueezeDSP::Plugin::log->warn("oops: " . $desc . ' - ' . $message);
    #$client->showBriefly({ line => [ $desc, $message ] }, 2);
    
}

sub fatal {
    my ($client, $desc, $message) = @_;
    $Plugins::SqueezeDSP::Plugin::log->error("fatal: " . $desc . ' - ' . $message);
    #$client->showBriefly({ line => [ $desc, $message ] }, 2);
    $Plugins::SqueezeDSP::Plugin::fatalError = $message;
}

sub newConfigPath {
    my @rootdirs = Slim::Utils::PluginManager->dirsFor($Plugins::SqueezeDSP::Plugin::thisapp, 'enabled');
    for my $d (@rootdirs) {
        if($d =~ m/$Plugins::SqueezeDSP::Plugin::thisapp/i) {
            my $cp = catdir($d, 'custom-convert.conf');
            debug("New CP:" . $cp);
            return $cp;
        }
    }
    fatal("can't find directory with custom-convert.conf");
    return;
}

sub _inspectProfile {
    my $profile = shift;
    my $inputtype;
    my $outputtype;
    my $clienttype;
    my $clientid;
    if($profile =~ /^(\S+)\-+(\S+)\-+(\S+)\-+(\S+)$/) {
        $inputtype  = $1;
        $outputtype = $2;
        $clienttype = $3;
        $clientid   = lc($4);
        return ($inputtype, $outputtype, $clienttype, $clientid);
    }
    return (undef, undef, undef, undef);
}

sub _getEnabledPlayers {
    my @clientList = Slim::Player::Client::clients();
    my %enabled = ();
    for my $client (@clientList) {
        $enabled{$client->id()} = 1;
    }
    return \%enabled;
}

sub getPrefFile {
    my $client = shift;
    my $settingsDir = $Plugins::SqueezeDSP::Plugin::pluginSettingsDataDir;
    my $file = catdir( $settingsDir, join('_', split(/:/, $client->id())) . ".settings.json");
    return $file;
}

sub setPref {
    my ($client, $prefName, $prefValue) = @_;
    my $file = getPrefFile($client);
    my $myConfig = LoadJSONFile($file);
    debug("setPref " . $prefName . "=" . $prefValue);
    $myConfig->{Client}->{$prefName} = $prefValue;
    SaveJSONFile($myConfig, $file);
}

sub delPref {
    my ($client, $prefName) = @_;
    $prefs->client($client)->remove($prefName) if $prefs->client($client)->exists($prefName);
}

#much easier to simply copy the existing config to the preset location.
sub savePreset {
    my ($client, $myPresetFile) = @_;
    my $SourceFile = getPrefFile($client);
    copy($SourceFile, $myPresetFile) or do { 
        oops($client, undef, "Preferences could not be saved to $myPresetFile.");
        return 0;
    };
}

#write to JSON file
#amended so that it will only save to a selected preset file
#the client specific file should be dynamic and is now the source for this call.
sub savePrefs {
    my ($myinputData, $myoutputJSONfile) = @_;
    open my $fh, ">", $myoutputJSONfile;
    print $fh JSON::XS->new->utf8->pretty->encode($myinputData);
    close $fh;
    return;
}

sub LoadJSONFile {
    my $myinputJSONfile = shift;
    debug("SqueezeDSP Loading JSON File : " . $myinputJSONfile);
    my $txt;
    my $myoutputData;
    eval {
        local $/;
        open my $fh, "<", $myinputJSONfile or die $!;
        $txt = <$fh>;
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

sub SaveJSONFile {
    my ($myinputData, $myoutputJSONfile) = @_;
    open my $fh, ">", $myoutputJSONfile;
    print $fh JSON::XS->new->utf8->pretty->encode($myinputData);
    close $fh;
    return;
}

1;