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
    my $upgradeReason = '';
    my @origLines;
    my @clientIDs = sort map { $_->id() } Slim::Player::Client::clients();
    my @foundClients;
    my $PRE_0_9_21 = 0;
    my $tryMoveConfig = 0;
    
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
    } else {
        Plugins::SqueezeDSP::Utils::debug ("Config Not found, new one created" );
        $upgradeReason = "New configuration" unless $Plugins::SqueezeDSP::Plugin::needUpgrade;
        $Plugins::SqueezeDSP::Plugin::needUpgrade = 1;
        @foundClients = @clientIDs;
    }
        
    upgradePrefs( $PRE_0_9_21, @foundClients );
    removeNativeConversion();
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
    $Plugins::SqueezeDSP::Plugin::needUpgrade = 0;
    Plugins::SqueezeDSP::Utils::debug( "Reload Conversion Tables" );
    Slim::Player::TranscodingHelper::loadConversionTables();
    removeNativeConversion();
}

# Going to run this each time the server starts and update revision number for each active client
sub upgradePrefs
{
	# Going to run this each time the server starts and update revision number for each active client
	# 
	my ( $PRE_0_9_21, @clientIDs ) = @_;
	$Plugins::SqueezeDSP::Plugin::revision;
	#return if ( $prevrev eq $revision ) && !$PRE_0_9_21;
	
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

# remove native conversion for FLAC24 and WAV16
sub removeNativeConversion {
    my $conv = Slim::Player::TranscodingHelper::Conversions();
    my %players = %{Plugins::SqueezeDSP::Utils::_getEnabledPlayers()};
    for my $profile (sort keys %$conv) {
        my ($inputtype, $outputtype, $clienttype, $clientid) = Plugins::SqueezeDSP::Utils::_inspectProfile($profile);
        my $command = $conv->{$profile};
        my $enabled = Slim::Player::TranscodingHelper::enabledFormat($profile);
        if ($enabled == 1 && $clienttype eq "*" && $command eq "-") {
            Plugins::SqueezeDSP::Utils::debug("delete native command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid, enabled $enabled, command $command");
            delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
            delete $Slim::Player::TranscodingHelper::capabilities{ $profile };
        }
        if ($enabled == 1 && $clientid eq "*" && $outputtype eq "flc") {
            Plugins::SqueezeDSP::Utils::debug("delete flac command - input: $inputtype, output $outputtype, clienttype $clienttype, clientid $clientid, enabled $enabled, command $command");
            delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
            delete $Slim::Player::TranscodingHelper::capabilities{ $profile };
        }
    }
}

1;