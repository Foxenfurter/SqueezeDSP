package Plugins::SqueezeDSP::JiveManager;
# ----------------------------------------------------------------------------
# SqueezeDSP	\JiveManager.pm - Used for setting Jive
# ----------------------------------------------------------------------------

use strict;
use base qw(Slim::Web::Settings);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Plugins::SqueezeDSP::Plugin;
use Plugins::SqueezeDSP::Settings;


# ------ main-menu mode ------
=pod remove Jive stuff

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
		$opts{$ERRORKEY} = $client->string( 'PLUGIN_SQUEEZEDSP_RESTART' );
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
	my $bandcount = getPref( $client, 'bands' ) || 2;

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




# ------ Mode: PLUGIN.SqueezeDSP.Presets ------
# Displays menu to load a preset
# Presets are files "xxx.preset.conf" in the plugin's Data folder.
# They are exactly the same format as the "xxx.settings.conf" file used for client settings,
# (but any clientID in the file is ignored)

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


# ------ Mode: PLUGIN.SqueezeDSP.RoomCorrection ------
# Displays menu to select a correction filter.
# Correction filters are any file in the plugin's Data folder with .WAV file extension.
# Of course not all wav files will work properly as filters, but this plugin doesn't know that.



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



# ------ Mode: PLUGIN.SqueezeDSP.Matrix ------
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




# ------ Mode: PLUGIN.SqueezeDSP.SignalGenerator ------
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
					my $genfreq = getPref( $client, 'sigfreq' ) || 1000;
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




# ------ Mode: PLUGIN.SqueezeDSP.Value ------
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

=cut
=pod Jive Menus removed
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
=cut

