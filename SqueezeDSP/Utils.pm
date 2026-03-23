package Plugins::SqueezeDSP::Utils;
use strict;
use File::Spec::Functions qw(:ALL);
use File::Path;
use File::Copy;
use JSON::XS;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Player::Source;
use Slim::Player::Playlist;
use Slim::Player::ProtocolHandlers;
use Slim::Schema;
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

sub _trackGainQuery {
    my $request = shift;
    my $client  = $request->client();
	
	debug("_trackGainQuery called for player: " . ($client ? $client->id() : 'unknown'));
    unless ($client) {
        $request->setStatusBadParams();
        return;
    }

    my $song = $client->streamingSong();
    unless ($song) {
        $request->addResult('error', 'no_song');
        $request->setStatusDone();
        return;
    }

    # current track
    my $currentGain = _getTrackGainData($client, $song);
    $request->addResult('url',             $currentGain->{url})        if defined $currentGain->{url};
    $request->addResult('track_gain',      $currentGain->{track_gain}) if defined $currentGain->{track_gain};
    $request->addResult('track_peak',      $currentGain->{track_peak}) if defined $currentGain->{track_peak};
    $request->addResult('album_gain',      $currentGain->{album_gain}) if defined $currentGain->{album_gain};
    $request->addResult('album_peak',      $currentGain->{album_peak}) if defined $currentGain->{album_peak};

    # next track
	my $nextIndex = Slim::Player::Source::streamingSongIndex($client) + 1;
	my $nextURL   = Slim::Player::Playlist::track($client, $nextIndex);

	# track() returns an object for remote tracks - extract url string
	if (ref $nextURL) {
		$nextURL = $nextURL->url();
	}

    if ($nextURL) {
        my $nextTrack = Slim::Schema->objectForUrl({ 'url' => $nextURL, 'create' => 1, 'readTags' => 1 });
        if ($nextTrack) {
            my $nextGain = _getTrackGainDataFromTrack($client, $nextTrack, $nextURL);
            $request->addResult('next_url',        $nextGain->{url})        if defined $nextGain->{url};
            $request->addResult('next_track_gain', $nextGain->{track_gain}) if defined $nextGain->{track_gain};
            $request->addResult('next_track_peak', $nextGain->{track_peak}) if defined $nextGain->{track_peak};
            $request->addResult('next_album_gain', $nextGain->{album_gain}) if defined $nextGain->{album_gain};
            $request->addResult('next_album_peak', $nextGain->{album_peak}) if defined $nextGain->{album_peak};
        }
    }

    $request->setStatusDone();
}

sub _getTrackGainData {
    my ($client, $song) = @_;
    my $track = $song->currentTrack();
    return {} unless $track;
    return _getTrackGainDataFromTrack($client, $track, $track->url);
}

sub _getTrackGainDataFromTrack {
    my ($client, $track, $url) = @_;

	# ensure url is a plain string not an object
    $url = $url->url() if ref $url;

    my %data = (url => $url);

if ($track->remote) {
    my $handler = Slim::Player::ProtocolHandlers->handlerForURL($url);

    if ($handler && $handler->can('trackGain')) {
        $data{track_gain} = $handler->trackGain($client, $url);
    }

    unless (defined $data{track_gain}) {
        if ($handler && $handler->can('getMetadataFor')) {
            my $meta = $handler->getMetadataFor($client, $url);
            $data{track_gain} = $meta->{replay_gain};
            $data{track_peak} = $meta->{replay_peak};

            # if still nothing log available keys for diagnosis
			unless (defined $data{track_gain}) {
				debug("[$url] no gain found in metadata, available keys: " . 
					join(', ', sort keys %$meta));
			}
        }
    }
} else {
        $data{track_gain} = $track->replay_gain();
        $data{track_peak} = $track->replay_peak();

        my $album = $track->album();
        if ($album && $album->can('replay_gain')) {
            $data{album_gain} = $album->replay_gain();
            $data{album_peak} = $album->replay_peak();
        }
    }

    return \%data;
}



1;