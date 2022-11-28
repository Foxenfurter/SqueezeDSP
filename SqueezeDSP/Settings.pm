package Plugins::S::Settings;
# ----------------------------------------------------------------------------
# SqueezeDSP	\Settings.pm - player settings for SqueezeDSP plugin
# ----------------------------------------------------------------------------

use strict;
use base qw(Slim::Web::Settings);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Plugins::SqueezeDSP::Plugin;

my $thistag = "inguzeq";
my $thisapp = "InguzEQ";

my $log = logger('plugin.' . $thistag);
my $prefs = preferences('plugin.' . $thistag);
my $plugin;

sub new
{
	my $class = shift;
	$plugin   = shift;
	$class->SUPER::new;
}

sub name
{
    return 'PLUGIN_INGUZEQ_DISPLAYNAME';
}

sub needsClient
{
	return 1;
}

sub page
{
    return 'plugins/SqueezeDSP/settings/basic.html';
}


sub handler
{
	my ($class, $client, $params) = @_;
        return $class->SUPER::handler($client, $params);
}

$prefs->init({ "enabled" => 1, });

1;

__END__
