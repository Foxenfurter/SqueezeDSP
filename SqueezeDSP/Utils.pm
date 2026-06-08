package Plugins::SqueezeDSP::Utils;
use strict;
use File::Spec::Functions qw(:ALL);
use File::Path;
use File::Copy;
use JSON::XS;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Cache;

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
my $cache = Slim::Utils::Cache->new();

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
	$request->addResult('album_id',        $currentGain->{album_id})   if defined $currentGain->{album_id};

    # Determine whether the current track is in album sequence with either its
    # neighbour in the playlist. trackAlbumMatch() checks whether the track at
    # the given offset (+1 next, -1 previous) is adjacent on the same album.
    # The || means: if either comparison returns true, album_match is true.
    # trackAlbumMatch() handles edge cases internally (first/last track,
    # playlist wrap-around, repeat mode) so no extra logic is needed here.
	my $albumMatch = 0;
    if (defined $currentGain->{album_gain}) {
        # Check whether the current track is in album sequence with either neighbour.
        # || means: true if either the previous (-1) or next (+1) track matches.
        # trackAlbumMatch() handles edge cases (first/last track, repeat mode) internally.
        $albumMatch = Slim::Player::ReplayGain->trackAlbumMatch($client, -1)
                   || Slim::Player::ReplayGain->trackAlbumMatch($client,  1);
    }

    $request->addResult('album_match', $albumMatch ? 1 : 0);

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
			$request->addResult('next_album_id',   $nextGain->{album_id})    if defined $nextGain->{album_id};
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

    $url = $url->url() if ref $url;

    my %data = (url => $url);

	if ($track->remote) {
		my $handler = Slim::Player::ProtocolHandlers->handlerForURL($url);
		my $meta;

		# Always fetch metadata - needed for album ID regardless of whether
		# trackGain() succeeds
		if ($handler && $handler->can('getMetadataFor')) {
			$meta = $handler->getMetadataFor($client, $url);
		}

		if ($handler && $handler->can('trackGain')) {
			$data{track_gain} = $handler->trackGain($client, $url);
		}

		# Fall back to metadata for track gain/peak if not provided directly
		unless (defined $data{track_gain}) {
			$data{track_gain} = $meta->{replay_gain} if $meta;
			$data{track_peak} = $meta->{replay_peak} if $meta;
		}

		my $albumId = $meta ? $meta->{albumId} : undef;
		debug("_getTrackGainDataFromTrack: albumId=" . ($albumId // 'undef') . " meta keys=" . ($meta ? join(',', keys %$meta) : 'no meta'));
		if ($albumId) {
			$data{album_id} = "qobuz:album:$albumId";

			my $album = Slim::Schema->single('Album', { extid => "qobuz:album:$albumId" });
			debug("schema lookup: " . ($album ? "found, gain=" . ($album->replay_gain() // 'undef') : "not found"));

			if ($album && defined $album->replay_gain()) {
				$data{album_gain} = $album->replay_gain();
				$data{album_peak} = $album->replay_peak();
			}
			# cache fallback - gain is min(track_gains), not a true album tag
			unless (defined $data{album_gain}) {
				eval {
					require Plugins::Qobuz::API::Common;
					my $qobuzCache = Plugins::Qobuz::API::Common->getCache();
					my $cached = $qobuzCache->get('album_with_tracks_' . $albumId)
							|| $qobuzCache->get('albumInfo_' . $albumId);
					if ($cached && ref $cached && defined $cached->{replay_gain}) {
						$data{album_gain} = $cached->{replay_gain};
						$data{album_peak} = $cached->{replay_peak};
					}
				};
				debug("Qobuz cache eval error: $@") if $@;
			}
		}

    } else {
        $data{track_gain} = $track->replay_gain();
        $data{track_peak} = $track->replay_peak();

        my $album = $track->album();
        if ($album && $album->can('replay_gain')) {
            $data{album_gain} = $album->replay_gain();
            $data{album_peak} = $album->replay_peak();
            # *** NEW: expose album identifier for local tracks too ***
            $data{album_id}   = 'local:album:' . $album->id();
        }
    }

    return \%data;
}



1;