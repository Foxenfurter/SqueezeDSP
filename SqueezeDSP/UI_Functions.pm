package Plugins::SqueezeDSP::UI_Functions;
use strict;
use JSON::XS;
use MIME::Base64;
use File::Copy;
use File::Spec::Functions qw(catdir catfile);  # ADD THIS IMPORT

sub filtersQuery {
    my $request = shift;
    my $client = $request->client();
    Plugins::SqueezeDSP::Utils::debug("query: filters");

    if($request->isNotQuery([[ $Plugins::SqueezeDSP::Plugin::thistag . '.filters' ]])) {
        $request->setStatusBadDispatch();
        return;
    }
	# return "Filter_loop" with list of the available filters
	# and "Preset_loop" with list of the available presets
	# (only their short names, not full paths)
    my %filters = getFiltersListNoNone($client, $Plugins::SqueezeDSP::Plugin::pluginImpulsesDataDir, 0);
    my $cnt = 0;
    foreach my $ff(sort { uc($a) cmp uc($b) } keys %filters) {
        $request->addResultLoop('FIRWavFile_loop', $cnt, 0, $ff);
        $cnt++;
    }

    my %presets = getPresetsListNoNone($client, 0);
    $cnt = 0;
    foreach my $ff(sort { uc($a) cmp uc($b) } keys %presets) {
        $request->addResultLoop('Preset_loop', $cnt, 0, $ff);
        $cnt++;
    }

    $request->setStatusDone();
}

sub logsummaryQuery {
    my $request = shift;
    my $client = $request->client();
    my $clientID = $client->id();
    my $tracklimit = 10;
    Plugins::SqueezeDSP::Utils::debug("query: logsummary");

    if($request->isNotQuery([[ $Plugins::SqueezeDSP::Plugin::thistag . '.logsummary' ]])) {
        $request->setStatusBadDispatch();
        return;
    }
    
    my $startline = '';
    my $trackcount = 0;
    my @reportlines;
    my @startvalues;

    Plugins::SqueezeDSP::Utils::debug("Opening log file " . $Plugins::SqueezeDSP::Plugin::logfile . " for " . $clientID);
    if (! -e $Plugins::SqueezeDSP::Plugin::logfile) {
        Plugins::SqueezeDSP::Utils::debug("Log file does not exist: $Plugins::SqueezeDSP::Plugin::logfile");
        $request->addResult("trackcount", 0);
        $request->setStatusDone();
        return;
    }

    open(FILE, "<$Plugins::SqueezeDSP::Plugin::logfile") or die("Could not open log file. $!\n");
    while(<FILE>) {
        my($line) = $_;
        chomp($line);
        if (index($line, '=>') != -1 && index($line, $clientID) != -1) {
            $startline = $line;
        }
        if (index($line, 'peak') != -1 && index($line, $clientID) != -1) {
            my @endvalues = split(' ', $line);
            if ($endvalues[3] != 0) {
                @startvalues = split(' ', $startline);
                my %reportrow = (
                    date    => $startvalues[0],
                    time    => $startvalues[1],
                    playerid => $startvalues[2],
                    inputrate => $startvalues[3],
                    outputrate    => $startvalues[6],
                    preamp     => $startvalues[10],    
                    peakdBfs => $endvalues[13],
                );
                push @reportlines, \%reportrow;
                $trackcount++;
            }
        } 
    }
    close(FILE);
    
    if($trackcount > $tracklimit) {
        $trackcount = $tracklimit;
    }
    my $length = scalar @reportlines;
    my $firstline = $length - $trackcount;
    my $lastline = $length - 1;
    my $trackpos = 1;
    for (my $i = $firstline; $i <= $lastline; $i++) {
        my $reportrow = $reportlines[$i];
        $request->addResult("date_$trackpos", $reportrow->{date});
        $request->addResult("time_$trackpos", $reportrow->{time});
        $request->addResult("playerid_$trackpos", $reportrow->{playerid});
        $request->addResult("inputrate_$trackpos", $reportrow->{inputrate});
        $request->addResult("outputrate_$trackpos", $reportrow->{outputrate});
        $request->addResult("preamp_$trackpos", $reportrow->{preamp});
        $request->addResult("peakdBfs_$trackpos", $reportrow->{peakdBfs});
        $trackpos++;
    }

    $request->addResult("trackcount", $trackcount);
    $request->setStatusDone();
}

sub importwavCommand {
    my $request = shift;
    my $client = $request->client();
    Plugins::SqueezeDSP::Utils::debug("importwavCommand ENTERED");

    if($request->isNotQuery([[ $Plugins::SqueezeDSP::Plugin::thistag . '.importwav' ]])) {
        $request->setStatusBadDispatch();
        return;
    }

    my $filename = $request->getParam('_p0') || 'audio.wav';
    my $base64   = $request->getParam('_p1');
    Plugins::SqueezeDSP::Utils::debug("Raw filename: " . $filename);

    unless ($base64) {
        $request->setStatusBadParams("Missing audio data");
        return;
    }

    # Security-focused sanitization
    # 1. Remove path components
    $filename =~ s/.*[\\\/]//g;
    
    # 2. Remove unsafe characters (keep alphanumeric, dots, dashes, underscores)
    $filename =~ s/[^\w\.\-]//g;
    
    # 3. Ensure we have a .wav extension
    $filename =~ s/\.wav$//i;
    $filename .= ".wav";
    
    # 4. Handle empty filename case
    $filename = "audio_import.wav" if $filename eq ".wav";
    Plugins::SqueezeDSP::Utils::debug("Sanitized filename: $filename");
    Plugins::SqueezeDSP::Utils::debug("Base64 length: " . length($base64));
    # Configure save path
    my $filepath = catfile($Plugins::SqueezeDSP::Plugin::pluginImpulsesDataDir, $filename);
 # Save file    
    if (open(my $fh, '>', $filepath)) {
        binmode $fh;
        print $fh decode_base64($base64);
        close $fh;
        Plugins::SqueezeDSP::Utils::debug("Saved WAV file: $filepath");
        $request->addResult('_success', 1);
        $request->setStatusDone();
    } else {
        Plugins::SqueezeDSP::Utils::debug("Save failed: $!");
        $request->setStatusBadParams("Couldn't write file: $!");
    }
}

sub saveallCommand {
    my $request = shift;
    my $client = $request->client();
    Plugins::SqueezeDSP::Utils::debug("Saving settings");
    if($request->isNotQuery([[ $Plugins::SqueezeDSP::Plugin::thistag . '.saveall' ]])) {
        Plugins::SqueezeDSP::Utils::oops($client, undef, "saveall not command");
        $request->setStatusBadDispatch();
        return;
    }

    my $json = $request->getParam('val') or return $request->setStatusBadParams("No data");
    my $data = eval { decode_json($json) };
    if ($@) {
        Plugins::SqueezeDSP::Utils::debug("JSON decode failed: $@");
        return $request->setStatusBadParams("Invalid JSON");
    }
    my $myJSONFile = Plugins::SqueezeDSP::Utils::getPrefFile($client);
    Plugins::SqueezeDSP::Utils::debug("Saving settings to: $myJSONFile");
    Plugins::SqueezeDSP::Utils::debug("JSON length: " . length($json));
    Plugins::SqueezeDSP::Utils::SaveJSONFile($data, $myJSONFile);
    $request->setStatusDone();

     # Force DSP reload by seeking (if player available)
    return unless $client;

    # Use controller-based methods for reliable position/duration - FIXED
    my $controller = $client->controller();
    return unless $controller;
    # Get current song and track
    my $song = $controller->playingSong();
    return unless $song;
    my $current_track = $song->track();
    return unless $current_track;
     # Define included protocols
    my @included_protocols = qw(file http https smb nfs afp tidal spotify deezer qobuz);
    # Define excluded file extensions
    my @excluded_extensions = qw(wma wmal wmap);
    # Get track URL
    my $current_url = $current_track->url;
    my $source = '';
    my $extension = '';
    # Extract protocol and extension
    if ($current_url) {
        ($source) = $current_url =~ m{^(\w+):};
        $source = lc($source) if defined $source;
        ($extension) = $current_url =~ /\.([a-z0-9]+)$/i;
        $extension = lc($extension) if defined $extension;
    }
     # Check if protocol is allowed
    my $is_allowed_protocol = 0;
    if ($source) {
        $is_allowed_protocol = grep { $_ eq $source } @included_protocols;
    }
    # Skip if not an allowed protocol
    unless ($is_allowed_protocol) {
        Plugins::SqueezeDSP::Utils::debug("Skipping seek for non-included protocol: $source");
        return;
    }
    
    if ($extension && grep { $_ eq $extension } @excluded_extensions) {
        Plugins::SqueezeDSP::Utils::debug("Skipping seek for excluded extension: $extension");
        return;
    }
    
    # Get player state using controller methods - FIXED UNITS
    my $was_playing = $client->isPlaying();
    my $current_position = $controller->playingSongElapsed();
    my $track_duration = $controller->playingSongDuration();
    # Validate seek conditions
    return unless defined $current_position && defined $track_duration;
    return if $track_duration <= 0;
    
    # Calculate new position (0.5s forward)
    my $seek_amount = 0.5;
    my $new_position = $current_position + $seek_amount;
    
    # Only seek if we're not at/near end of track
    if ($new_position < $track_duration - 0.1) {
        if ($was_playing) {
            $client->execute(['time', $new_position]);
        } else {
            $client->execute(['pause', 0]);
            $client->execute(['time', $new_position]);
            $client->execute(['pause', 1]);
        }
        Plugins::SqueezeDSP::Utils::debug("DSP reload triggered: " . ($was_playing ? "Playing" : "Paused") . " track advanced to $new_position");
    } else {
        Plugins::SqueezeDSP::Utils::debug("Skipping seek near end of track (position: $current_position, duration: $track_duration sec)");
    }
}

# Set a value for a specific key - contains some deprecated code
sub setvalCommand {
    my $request = shift;
    my $client = $request->client();
    Plugins::SqueezeDSP::Utils::debug("command: setval");

    if($request->isNotQuery([[ $Plugins::SqueezeDSP::Plugin::thistag . '.setval' ]])) {
        Plugins::SqueezeDSP::Utils::oops($client, undef, "setval not command");
        $request->setStatusBadDispatch();
        return;
    }

    my $key = $request->getParam('key');
    if(!$key) {
        Plugins::SqueezeDSP::Utils::oops($client, undef, "setval, no key!");
        $request->setStatusBadDispatch();
        return;
    }

    my $val = $request->getParam('val');
    Plugins::SqueezeDSP::Utils::debug("command: setval($key,$val)");
    # Check this command is OK - not validating for now as it will fail anyway and too much change
    my $bandcount = Plugins::SqueezeDSP::Utils::getPref($client, 'EQBands');
    if($key eq 'EQBands') {
        Plugins::SqueezeDSP::Utils::setBandCount($client, $val);
        my $line = $client->string('PLUGIN_SQUEEZEDSP_CHOSEN_BANDS');
        $client->showBriefly({ 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 });
    } elsif($key eq 'FIRWavFile' || $key eq 'MatrixFile') {
        setFilterValue($client, $key, $val);
    } elsif($key eq 'Preset') {
        loadPresetFile($client, $val);
    } else {
        Plugins::SqueezeDSP::Utils::setPref($client, $key, $val);
        my $line = $client->string('PLUGIN_SQUEEZEDSP_CHOSEN_VALUE');
        $client->showBriefly({ 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 1 });
    }
    $request->setStatusDone();
}

sub setFilterValue {
    my ($client, $prf, $val) = @_;
    my $path;
    if($val eq '-' || $val eq '') {
        Plugins::SqueezeDSP::Utils::setPref($client, $prf, $val);
        my $msg = ($prf eq 'matrixfile') ? 'PLUGIN_SQUEEZEDSP_CHOSEN_MATRIXFILTERNONE' : 'PLUGIN_SQUEEZEDSP_CHOSEN_RCFILTERNONE';
        my $line = $client->string($msg);
        $client->showBriefly({ 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 });
        return;
    }
    if($prf eq 'MatrixFile') {
        $path = catdir($Plugins::SqueezeDSP::Plugin::pluginMatrixDataDir, $val);
    } else {
        $path = catdir($Plugins::SqueezeDSP::Plugin::pluginImpulsesDataDir, $val);
    }
    if(-f $path) {
        Plugins::SqueezeDSP::Utils::setPref($client, $prf, $path);
        my $msg = ($prf eq 'matrixfile') ? 'PLUGIN_SQUEEZEDSP_CHOSEN_MATRIXFILTER' : 'PLUGIN_SQUEEZEDSP_CHOSEN_RCFILTER';
        my $line = $client->string($msg);
        $client->showBriefly({ 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 });
    } else {
        Plugins::SqueezeDSP::Utils::debug("Can't set, file $path does not exist");
    }
}

sub saveasCommand {
    my $request = shift;
    my $client = $request->client();
    Plugins::SqueezeDSP::Utils::debug("command: saveas");

    if($request->isNotQuery([[ $Plugins::SqueezeDSP::Plugin::thistag . '.saveas' ]])) {
        Plugins::SqueezeDSP::Utils::oops($client, undef, "saveas not command");
        $request->setStatusBadDispatch();
        return;
    }

    my $key = $request->getParam('preset');
    if(!$key) {
        Plugins::SqueezeDSP::Utils::oops($client, undef, "saveas, no preset name!");
        $request->setStatusBadDispatch();
        return;
    }

    Plugins::SqueezeDSP::Utils::debug("command: saveas($key)");
    my $file = catdir($Plugins::SqueezeDSP::Plugin::pluginSettingsDataDir, join('_', split(/:/, $key)) . '.preset.json');
    Plugins::SqueezeDSP::Utils::setPref($client, 'Preset', $file);
    Plugins::SqueezeDSP::Utils::savePreset($client, $file);
    my $line = $client->string('PLUGIN_SQUEEZEDSP_PRESET_SAVED');
    $client->showBriefly({ 'line' => [ undef, $line ], 'jive' => { 'type' => 'popupinfo', text => [ $line ] }, }, { 'duration' => 2 });
    $request->setStatusDone();
}

sub readClientSettings {
    my $request = shift;
    my $client = $request->client();
    Plugins::SqueezeDSP::Utils::debug("query: readClientSettings");
    my $myJSONFile = Plugins::SqueezeDSP::Utils::getPrefFile($client);
    Plugins::SqueezeDSP::Utils::debug("Reading preset file: $myJSONFile");
    
    if (open(my $fh, '<', $myJSONFile)) {
        local $/;
        my $jsonContent = <$fh>;
        close $fh;
        $request->addResult('json', $jsonContent);
        $request->addResult('clientName', $client->name);
        $request->addResult('revision', $Plugins::SqueezeDSP::Plugin::revision);
        $request->setStatusDone();
    } else {
        my $error = "Couldn't read $myJSONFile: $!";
        Plugins::SqueezeDSP::Utils::debug("ERROR: $error");
        $request->setStatusBadParams($error);
    }
}

sub readPresetSettings {
    my $request = shift;
    my $client = $request->client();
    my $presetFileName = $request->getParam('presetFileName');
    Plugins::SqueezeDSP::Utils::debug("query: readPresetSettings");
    my $myJSONFile = Plugins::SqueezeDSP::Utils::getPrefFile($client);
    Plugins::SqueezeDSP::Utils::debug("Copying preset: $presetFileName to $myJSONFile");
    
    unless (copy($presetFileName, $myJSONFile)) {
        my $error = "Copy failed: $presetFileName → $myJSONFile: $!";
        Plugins::SqueezeDSP::Utils::debug("ERROR: $error");
        $request->setStatusBadParams($error);
        return;
    }
    
    my $settings = {};
    if (open(my $fh, '<', $myJSONFile)) {
        local $/;
        my $jsonContent = <$fh>;
        close $fh;
        $settings = decode_json($jsonContent);
        $request->addResult('json', $jsonContent);
        $request->addResult('clientName', $client->name);
        $request->addResult('revision', $Plugins::SqueezeDSP::Plugin::revision);
        $request->setStatusDone();
    } else {
        my $error = "Couldn't read $myJSONFile after copy: $!";
        Plugins::SqueezeDSP::Utils::debug("ERROR: $error");
        $request->setStatusBadParams($error);
    }
    return $settings;
}

sub getFiltersListNoNone {
    my ($client, $folder, $nopath) = @_;
    my %impulses = ();
    my $types = qr/\.(?:(wav))$/i;
    opendir(DIR, $folder) or do { return %impulses; };
    for my $item (readdir(DIR)) {
        my $itemPath = $item;
        my $fullPath = catdir($folder, $item);
        if(-f $fullPath) {
            if($item =~ $types) {
                $item =~ s/\.(?:(wav))$//i;
                $impulses{$nopath ? $itemPath : $fullPath} = $item;
            }
        }
    }
    closedir(DIR);
    return %impulses;
}

sub getFiltersList {
    my ($client, $folder, $nopath) = @_;
    my %impulses = ( '-' => $client->string('PLUGIN_SQUEEZEDSP_FILTERNONE') );
    my %more = getFiltersListNoNone($client, $folder, $nopath);
    @impulses{keys %more} = values %more;
    return %impulses;
}

sub getPresetsListNoNone {
    my ($client, $nopath) = @_;
    my %presets = ();
    my $types = qr/\.(?:(preset\.json))$/i;
    if(opendir(DIR, $Plugins::SqueezeDSP::Plugin::pluginSettingsDataDir)) {
        for my $item (readdir(DIR)) {
            my $itemPath = $item;
            my $fullPath = catdir($Plugins::SqueezeDSP::Plugin::pluginSettingsDataDir, $item);
            if(-f $fullPath) {
                if($item =~ $types) {
                    $item =~ s/\.(?:(preset\.json))$//i;
                    $presets{$nopath ? $itemPath : $fullPath} = $item;
                }
            }
        }
        closedir(DIR);
    }
    return %presets;
}

sub getPresetsList {
    my ($client, $nopath) = @_;
    my %presets = ( '-' => $client->string('PLUGIN_SQUEEZEDSP_SAVEPRESETAS') );
    my %more = getPresetsListNoNone($client, $nopath);
    @presets{keys %more} = values %more;
    return %presets;
}

sub loadPresetFile {
    my ($client, $val) = @_;
    my $path = catdir($Plugins::SqueezeDSP::Plugin::pluginSettingsDataDir, $val);
    if(-f $path) {
        Plugins::SqueezeDSP::Utils::loadPrefs($client, $path, undef);
    } else {
        Plugins::SqueezeDSP::Utils::debug("Can't set, file $path does not exist");
    }
}

1;