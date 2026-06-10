package Plugins::SqueezeDSP::Configuration;
use strict;
use File::Spec::Functions qw(:ALL);
use Slim::Player::TranscodingHelper;
#use Plugins::SqueezeDSP::Utils;

# ------ configuration helpers ------
sub initConfiguration {
    my $client = shift;
    Plugins::SqueezeDSP::Utils::debug( "client " . $client->id() ." name " . $client->name ." initializing" );

    $Plugins::SqueezeDSP::Plugin::fatalError = undef;
    my @clientIDs = sort map { $_->id() } Slim::Player::Client::clients();

    upgradePrefs( @clientIDs );
	#Now done once when server is ready, not here:
    removeNativeConversion();
}

sub initConfigurationOld {
    my $client = shift;
    Plugins::SqueezeDSP::Utils::debug( "client " . $client->id() ." name " . $client->name ." initializing" );

    $Plugins::SqueezeDSP::Plugin::fatalError = undef;
    my $upgradeReason = '';
    my @origLines;
    my @clientIDs = sort map { $_->id() } Slim::Player::Client::clients();
    my @foundClients;

    @origLines = ();
    $Plugins::SqueezeDSP::Plugin::configPath = Plugins::SqueezeDSP::Utils::newConfigPath();
    sleep 1;
    Plugins::SqueezeDSP::Utils::debug ( "Config Path: " . $Plugins::SqueezeDSP::Plugin::configPath);

    if( -f $Plugins::SqueezeDSP::Plugin::configPath ) {
        open( CONFIG, "$Plugins::SqueezeDSP::Plugin::configPath" ) || do {
            Plugins::SqueezeDSP::Utils::fatal( $client, undef, "Can't read from $Plugins::SqueezeDSP::Plugin::configPath" );
            return 0;
        };
        @origLines = <CONFIG>;
        close( CONFIG );

        # Check for corruption: empty file or missing begin marker
        my $hasBeginMarker = grep( /#$Plugins::SqueezeDSP::Plugin::confBegin#rev:/i, @origLines );
        if( !@origLines || !$hasBeginMarker ) {
            Plugins::SqueezeDSP::Utils::debug( "Config file missing or corrupt, will rebuild fresh" );
            $upgradeReason = "Config file missing or corrupt" unless $Plugins::SqueezeDSP::Plugin::needUpgrade;
            $Plugins::SqueezeDSP::Plugin::needUpgrade = 1;
            @foundClients = @clientIDs;   # Include all current clients
            @origLines = ();              # Discard old contents
        } else {
            my @revs = split /\./, $Plugins::SqueezeDSP::Plugin::myconfigrevision;
            for( @origLines ) {
                if( m/#$Plugins::SqueezeDSP::Plugin::confBegin#rev\:(.*)#client\:(.*)#/i ) {
                    my @test = split /\./, $1;
                    for my $ver ( @revs ) {
                        my $vert = shift( @test ) || 0;
                        next if $vert == $ver;
                        Plugins::SqueezeDSP::Utils::debug ("Template version higher than config: " . $ver . " - " . $vert );
                        $upgradeReason = "Previous version $1 less than my $Plugins::SqueezeDSP::Plugin::myconfigrevision ($vert less than $ver)" unless $Plugins::SqueezeDSP::Plugin::needUpgrade;
                        $Plugins::SqueezeDSP::Plugin::needUpgrade = 1;
                        last;
                    }
                    push( @foundClients, $2 );
                }
            }
            unless( $Plugins::SqueezeDSP::Plugin::needUpgrade ) {
                for my $c (@clientIDs) {
                    my $ok = 0;
                    for my $cc (@foundClients) {
                        if( $c eq $cc ) {
                            $ok = 1;
                            last;
                        }
                    }
                    unless( $ok ) {
                        $upgradeReason = "Client $c was not yet registered" unless $Plugins::SqueezeDSP::Plugin::needUpgrade;
                        $Plugins::SqueezeDSP::Plugin::needUpgrade = 1;
                        Plugins::SqueezeDSP::Utils::debug ("Client $c was not yet registered" );
                        push( @foundClients, $c );
                        last;
                    }
                }
            }
        }
    } else {
        Plugins::SqueezeDSP::Utils::debug ("Config Not found, new one created" );
        $upgradeReason = "New configuration" unless $Plugins::SqueezeDSP::Plugin::needUpgrade;
        $Plugins::SqueezeDSP::Plugin::needUpgrade = 1;
        @foundClients = @clientIDs;
    }

    upgradePrefs( @foundClients );
	#Now done once when server is ready, not here:
    #removeNativeConversion();
    return unless $Plugins::SqueezeDSP::Plugin::needUpgrade;

    Plugins::SqueezeDSP::Utils::debug( "Need to rewrite " . $Plugins::SqueezeDSP::Plugin::configPath . " (" .$upgradeReason . ")" );
    open( OUT, ">$Plugins::SqueezeDSP::Plugin::configPath" ) || do {
        Plugins::SqueezeDSP::Utils::fatal( $client, undef, "Can't write to $Plugins::SqueezeDSP::Plugin::configPath" );
        return;
    };

    my $now = localtime;
    print OUT "# Modified by $Plugins::SqueezeDSP::Plugin::thisapp, $now: $upgradeReason\n";
    foreach ( @origLines ) {
        print OUT if m/# Modified by $Plugins::SqueezeDSP::Plugin::thisapp/i;
    }
    print OUT "\n";

    foreach my $clientID ( @foundClients ) {
        print OUT "# #$Plugins::SqueezeDSP::Plugin::confBegin#rev:$Plugins::SqueezeDSP::Plugin::myconfigrevision#client:$clientID# ***** BEGIN AUTOMATICALLY GENERATED SECTION - DO NOT EDIT ****\n";
        my $n = template( $clientID );
        print OUT $n;
        print OUT "\n";
        print OUT "# #$Plugins::SqueezeDSP::Plugin::confEnd#client:$clientID# ***** END AUTOMATICALLY GENERATED SECTION - DO NOT EDIT *****\n";
        print OUT "\n";
    }

    close( OUT );

    # Verify that the file was written successfully and is non‑empty
    if( -s $Plugins::SqueezeDSP::Plugin::configPath == 0 ) {
        Plugins::SqueezeDSP::Utils::fatal( $client, undef, "Config file written but appears empty!" );
        return;
    }

    # Optionally set permissions so the file can be manually edited
    chmod 0666, $Plugins::SqueezeDSP::Plugin::configPath;   # or 0644 for owner‑only write

    $Plugins::SqueezeDSP::Plugin::needUpgrade = 0;
    Plugins::SqueezeDSP::Utils::debug( "Reload Conversion Tables" );
    Slim::Player::TranscodingHelper::loadConversionTables();
    #removeNativeConversion();
}

# Going to run this each time the server starts and update revision number for each active client
sub upgradePrefs
{
	# Going to run this each time the server starts and update revision number for each active client
	# 
	my (  @clientIDs ) = @_;
	$Plugins::SqueezeDSP::Plugin::revision;
		
	foreach my $clientID ( @clientIDs )
	{
		Plugins::SqueezeDSP::Utils::debug( "client " . $clientID );
		my $client = Slim::Player::Client::getClient( $clientID );
# Check IMMEDIATELY after getClient()
    unless (defined($client)) 
		{  # Or if (not defined $client) {
        print "Error: Could not get client object for ID: " . $clientID;
        next; # Skip to the next client ID
    	}	
		# Check the current and previous installed versions of the plugin,
		# in case we need to upgrade the prefs store (for this client)
		
		my $myJSONFile = Plugins::SqueezeDSP::Utils::getPrefFile( $client );
		
		unless( -f $myJSONFile )
		{
			#create default file if it does not exist
			Plugins::SqueezeDSP::Utils::debug( $client,  "Player Config File $myJSONFile not found. Creating" );
			#need to create file first
			my $myDefault = my $myDefault = {
				Client     => { Bypass => "1" },
				ClientName => "",
				Revision   => 0
			};
			Plugins::SqueezeDSP::Utils::SaveJSONFile ($myDefault, $myJSONFile );
			#Plugins::SqueezeDSP::Utils::defaultPrefs( $client );
		}

		my $myConfig = Plugins::SqueezeDSP::Utils::LoadJSONFile ($myJSONFile);
		Plugins::SqueezeDSP::Utils::debug ( $clientID . " Config File " . $myJSONFile . " loaded" );
		my $prevrev = $myConfig->{Client}->{Version};
	
		#Now touch the version numbers	
		if( defined( $client ) )
		{
			if ( $prevrev eq $Plugins::SqueezeDSP::Plugin::revision )
			{
				Plugins::SqueezeDSP::Utils::debug ( "upgrade from " . $prevrev . " not required " )	;
			}
		
			else   
			{
				Plugins::SqueezeDSP::Utils::debug( "upgrade from " . $prevrev . " to " . $Plugins::SqueezeDSP::Plugin::revision );
				Plugins::SqueezeDSP::Utils::setPref( $client, "Version", $Plugins::SqueezeDSP::Plugin::revision );
			
			}
		}
	}
}


# find the appropriate template depending on client type
sub template {
    my $clientID = shift;
    my $client = Slim::Player::Client::getClient($clientID);
    my $template;
    if(!defined($client)) {
        Plugins::SqueezeDSP::Utils::debug("template? client $clientID not defined!");
        $template = Plugins::SqueezeDSP::TemplateConfig::template_FLAC24();
    } elsif(Slim::Player::Client::contentTypeSupported($client, 'flc') && ($client->model() ne "softsqueeze")) {
        Plugins::SqueezeDSP::Utils::debug("client $clientID is " . $client->model() . ", using FLAC24");
        $template = Plugins::SqueezeDSP::TemplateConfig::template_FLAC24();
    } else {
        Plugins::SqueezeDSP::Utils::debug("client $clientID is " . $client->model() . ", using WAV16");
        $template = Plugins::SqueezeDSP::TemplateConfig::template_WAV16();
    }

    my $pipeout;
    my $pipenul;
    if(Slim::Utils::OSDetect::OS() eq 'win') {
        $pipeout = '#PIPE#';
        $pipenul = '';
    } else {
        $pipeout = '/dev/fd/4';
        $pipenul = '4>&1 1>/dev/null';
    }

    $template =~ s/\$CONVAPP\$/$Plugins::SqueezeDSP::Plugin::convolver/g;
    $template =~ s/\$CLIENTID\$/$clientID/g;
    $template =~ s/\$PIPEOUT\$/$pipeout/g;
    $template =~ s/\$PIPENUL\$/$pipenul/g;
    return $template;
}

# Need to do this as a two step process, remove the generics at startup using this routine
# then remove the player specific entries once the player starts. 
sub cleanupConversionTables {
    # 1. Clear and reload
    %Slim::Player::TranscodingHelper::commandTable = ();
    %Slim::Player::TranscodingHelper::capabilities = ();
    Plugins::SqueezeDSP::Utils::debug("Conversion tables cleared.");
    Slim::Player::TranscodingHelper::loadConversionTables();
    Plugins::SqueezeDSP::Utils::debug("Default LMS rules reloaded.");
	
	# ------------------------------------------------------------
    # Step 1:Remove any Native conversions
    # ------------------------------------------------------------
    
	my $conv = Slim::Player::TranscodingHelper::Conversions();
    my %players = %{Plugins::SqueezeDSP::Utils::_getEnabledPlayers()};
    for my $profile (sort keys %$conv) {
        my ($inputtype, $outputtype, $clienttype, $clientid) = Plugins::SqueezeDSP::Utils::_inspectProfile($profile);
        my $command = $conv->{$profile};
        
        if ($command eq "-") {
            Plugins::SqueezeDSP::Utils::debug("delete native command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid,  command $command");
            delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
            delete $Slim::Player::TranscodingHelper::capabilities{ $profile };
        }
	}


    my $conv      = Slim::Player::TranscodingHelper::Conversions();
    my $convolver = $Plugins::SqueezeDSP::Plugin::convolver;
    my $prefs     = Slim::Utils::Prefs::preferences('server');

    Plugins::SqueezeDSP::Utils::debug("cleanupConversionTables: " . scalar(keys %$conv) . " profiles found.");

    my %caps = %Slim::Player::TranscodingHelper::capabilities;

    # ------------------------------------------------------------
    # Step 2: Build copy table with stripped profile and normalized command
    # ------------------------------------------------------------
    my @entries;
    for my $profile (keys %$conv) {
        my $command = $conv->{$profile};

        # Strip priority suffix from profile (e.g., -1, -00, -01, -2)
        my $stripped_profile = $profile;
        $stripped_profile =~ s/-\d+$//;        # remove trailing -1, -00, -2
        $stripped_profile =~ s/-\*-\d+$//;     # handle patterns like -*-1 -> -*

        my $base_cmd = _normalize_command($command);
        my $dedup_key = "$stripped_profile||$base_cmd";   # composite key

        push @entries, {
            profile         => $profile,
            stripped_profile=> $stripped_profile,
            command         => $command,
            cap             => $caps{$profile} // {},
            base_cmd        => $base_cmd,
            dedup_key       => $dedup_key,
            disabled        => 0,
        };
    }

    # ------------------------------------------------------------
    # Step 3: Deduplicate by composite key – keep last occurrence
    # ------------------------------------------------------------
    @entries = sort { $a->{dedup_key} cmp $b->{dedup_key} } @entries;

    my $i = 0;
    while ($i < $#entries) {
        if ($entries[$i]{dedup_key} eq $entries[$i+1]{dedup_key}) {
            splice(@entries, $i, 1);   # remove current
        } else {
            $i++;
        }
    }
    Plugins::SqueezeDSP::Utils::debug("After deduplication: " . scalar(@entries) . " entries.");

    # ------------------------------------------------------------
    # Step 4: Flag disabled = any entry without SqueezeDSP in its command
    # ------------------------------------------------------------
    for my $e (@entries) {
        if (index($e->{command}, $convolver) == -1) {
            $e->{disabled} = 1;
        }
    }

    # ------------------------------------------------------------
    # Step 5: Clear live tables again
    # ------------------------------------------------------------
    %Slim::Player::TranscodingHelper::commandTable = ();
    %Slim::Player::TranscodingHelper::capabilities = ();

    # ------------------------------------------------------------
    # Step 6: Insert ONLY enabled (disabled=0) entries
    # ------------------------------------------------------------
	dumpWorkingCopy(\@entries, $convolver);
    my @disabled_profiles;
    for my $e (@entries) {
        if ($e->{disabled}) {
            push @disabled_profiles, $e->{profile};
            #Plugins::SqueezeDSP::Utils::debug("Omitting (disabled): $e->{profile}");
        } else {
            $Slim::Player::TranscodingHelper::commandTable{$e->{profile}} = $e->{command};
            $Slim::Player::TranscodingHelper::capabilities{$e->{profile}} = $e->{cap};
            #Plugins::SqueezeDSP::Utils::debug("Inserting enabled: $e->{profile}");
        }
    }

    $prefs->set('disabledformats', \@disabled_profiles);

    Plugins::SqueezeDSP::Utils::debug("cleanupConversionTables complete. Inserted " .
        (scalar(@entries) - scalar(@disabled_profiles)) . " enabled rules, omitted " .
        scalar(@disabled_profiles) . " disabled rules.");
}

# ------------------------------------------------------------
# Helper: aggressive normalization (already defined)
# ------------------------------------------------------------
sub _normalize_command {
    my ($cmd) = @_;
    my $norm = $cmd;
    $norm =~ s/\s+-priority\s+\d+\s*/ /g;
    $norm =~ s/\s+-threads\s+\d+\s*/ /g;
    $norm =~ s/\s+-p\d+\s*/ /g;
    $norm =~ s/\s+--threads=\d+\s*/ /g;
    $norm =~ s|/usr/bin/||g;
    $norm =~ s|/bin/||g;
    $norm =~ s|/usr/local/bin/||g;
    $norm =~ s|/opt/local/bin/||g;
    $norm =~ s/--(\w+)=\S+/--$1/g;   # strip values from --key=value
    $norm =~ s/\s+\d+\s+/ /g;
    $norm =~ s/\s+/ /g;
    $norm =~ s/^\s+|\s+$//g;
    return $norm;
}

sub dumpWorkingCopy {
    my ($entries, $convolver) = @_;
    Plugins::SqueezeDSP::Utils::debug("========== WORKING COPY AFTER DEDUP & FLAGGING ==========");
    foreach my $e (sort { $a->{base_cmd} cmp $b->{base_cmd} } @$entries) {
        my $status = $e->{disabled} ? "DISABLED" : "ENABLED";
        Plugins::SqueezeDSP::Utils::debug("$status: $e->{profile}");
        Plugins::SqueezeDSP::Utils::debug("  base_cmd: $e->{base_cmd}");
        Plugins::SqueezeDSP::Utils::debug("  command: $e->{command}");
        if ($e->{command} =~ /\Q$convolver\E/) {
            Plugins::SqueezeDSP::Utils::debug("  contains $convolver: YES");
        } else {
            Plugins::SqueezeDSP::Utils::debug("  contains $convolver: NO");
        }
    }
    Plugins::SqueezeDSP::Utils::debug("=================================================================");
}


# removes entries added for the specific player that has just started
# real belt and braces stuff.
sub removeNativeConversion {
    my $conv = Slim::Player::TranscodingHelper::Conversions();
    my %players = %{Plugins::SqueezeDSP::Utils::_getEnabledPlayers()};
    for my $profile (sort keys %$conv) {
        my ($inputtype, $outputtype, $clienttype, $clientid) = Plugins::SqueezeDSP::Utils::_inspectProfile($profile);
        my $command = $conv->{$profile};
        my $enabled = Slim::Player::TranscodingHelper::enabledFormat($profile);
        #if ($enabled == 1 && $clienttype eq "*" && $command eq "-") {
		#disable all native passthrough rules
		(my $trimmed = $command) =~ s/^\s+|\s+$//g;
		#any native passthrough rule 
		if ($enabled == 1 &&  $trimmed eq "-") {
            Plugins::SqueezeDSP::Utils::debug("delete - command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid, enabled $enabled, command $command");
            delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
            delete $Slim::Player::TranscodingHelper::capabilities{ $profile };
        }
		if ($enabled == 1 && $clientid eq "*" && $command eq "native") {
            Plugins::SqueezeDSP::Utils::debug("delete native command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid, enabled $enabled, command $command");
            delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
            delete $Slim::Player::TranscodingHelper::capabilities{ $profile };
        }
		# disable any rule that is not outputting flc or mp3
		if ($enabled == 1 && $outputtype ne "flc" && $outputtype ne "mp3" ) {
            Plugins::SqueezeDSP::Utils::debug("delete other non mp3/flc command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid, enabled $enabled, command $command");
            delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
            delete $Slim::Player::TranscodingHelper::capabilities{ $profile };
        }

		## remove competing flac and mp3 rules
        if ($enabled == 2 && $clientid eq "*" && ( $outputtype eq "flc" || $outputtype eq "mp3") ) {
            Plugins::SqueezeDSP::Utils::debug("delete flac command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid, enabled $enabled, command $command");
            delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
            delete $Slim::Player::TranscodingHelper::capabilities{ $profile };
        }
    }
	Plugins::SqueezeDSP::Utils::debug("removeNativeConversion complete.");
}

1;