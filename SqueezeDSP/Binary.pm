package Plugins::SqueezeDSP::Binary;
use strict;
use File::Copy;
use File::Spec::Functions qw(:ALL);
use Plugins::SqueezeDSP::Plugin qw($log $thisapp $pluginDataDir $pluginSettingsDataDir 
                                   $pluginImpulsesDataDir $pluginMatrixDataDir $pluginTempDataDir);

sub binaries {
    my $os = Slim::Utils::OSDetect::details();
    if ($os->{'os'} eq 'Linux') {
        if ($os->{'osArch'} =~ /x86_64/) {
            return qw(/publishLinux-x64/SqueezeDSP);
        }
        if ($os->{'binArch'} =~ /i386/) {
            return qw(/publishLinux-x86/SqueezeDSP);
        }
        if ($os->{'osArch'} =~ /aarch64/) {
            return qw(/publishlinux-arm64/SqueezeDSP);
        }
        if ($os->{'binArch'} =~ /armhf/) {
            return qw(/publishlinux-arm/SqueezeDSP);
        }
        if ($os->{'binArch'} =~ /arm/) {
            return qw(/publishlinux-arm/SqueezeDSP);
        }
        return qw(/publishLinux-x86/SqueezeDSP);
    }
    if ($os->{'os'} eq 'Unix') {
        if ($os->{'osName'} =~ /freebsd/) {
            return qw(/publishLinux-x64/SqueezeDSP);
        }
    }
    if ($os->{'os'} eq 'Darwin') {
        if ($os->{'osArch'} =~ /arm64/) {
            return qw(/publishOSX-arm64/SqueezeDSP);
        }
        return qw(/publishOSX-x64/SqueezeDSP);
    }
    if ($os->{'os'} eq 'Windows') {
        return qw(\publishWin64\SqueezeDSP.exe);
    }
}

sub setup_binary {
    my $class = shift;
    #my $bin = $class->binaries();
    my $bin = binaries();
    Plugins::SqueezeDSP::Utils::debug("Fox plugin path: " . $bin . " binary");
    my $exec = catdir(Slim::Utils::PluginManager->allPlugins->{$Plugins::SqueezeDSP::Plugin::thisapp}->{'basedir'}, 'Bin', $bin);
    Plugins::SqueezeDSP::Utils::debug("Fox plugin path: " . $exec . " exec");
    my $binExtension = ".exe";
    if (Slim::Utils::OSDetect::details()->{'os'} ne 'Windows') {
        $binExtension = "";
        chmod(0777, $Plugins::SqueezeDSP::Plugin::pluginImpulsesDataDir);
        chmod(0777, $Plugins::SqueezeDSP::Plugin::pluginTempDataDir);
    }
    if (!-e $exec) {
        $Plugins::SqueezeDSP::Plugin::log->warn("$exec not executable");
    }
    my $binpath = catdir(Slim::Utils::PluginManager->allPlugins->{$Plugins::SqueezeDSP::Plugin::thisapp}->{'basedir'}, 'Bin', "/", $Plugins::SqueezeDSP::Plugin::convolver . $binExtension);
    my $binversion_path = catdir(Slim::Utils::PluginManager->allPlugins->{$Plugins::SqueezeDSP::Plugin::thisapp}->{'basedir'}, 'Bin', "/", $Plugins::SqueezeDSP::Plugin::binversion);
    Plugins::SqueezeDSP::Utils::debug('standard binary path: ' . $binpath);
    if (-e $binversion_path) {
        Plugins::SqueezeDSP::Utils::debug('copying binary' . $exec);
        copy($exec, $binpath) or die "copy failed: $!";
        if ($binExtension eq "") {
            Plugins::SqueezeDSP::Utils::debug('executable not having \'x\' permission, correcting');
            chmod(0555, $binpath);
        }
        unlink $binversion_path;
        housekeeping();
    }
    my $appConfig = catdir(Slim::Utils::PluginManager->allPlugins->{$Plugins::SqueezeDSP::Plugin::thisapp}->{'basedir'}, 'Bin', "/", 'SqueezeDSP_config.json');
    amendPluginConfig($appConfig, 'pluginDataFolder', $Plugins::SqueezeDSP::Plugin::pluginDataDir);
    amendPluginConfig($appConfig, 'settingsDataFolder', $Plugins::SqueezeDSP::Plugin::pluginSettingsDataDir);
    amendPluginConfig($appConfig, 'impulseDataFolder', $Plugins::SqueezeDSP::Plugin::pluginImpulsesDataDir);
    amendPluginConfig($appConfig, 'tempDataFolder', $Plugins::SqueezeDSP::Plugin::pluginTempDataDir);
    my $soxbinary = Slim::Utils::Misc::findbin('sox');
    amendPluginConfig($appConfig, 'soxExe', $soxbinary);
    $Plugins::SqueezeDSP::Plugin::logfile = catdir(Slim::Utils::OSDetect::dirsFor('log'), "squeezedsp.log");
    if (! -e $Plugins::SqueezeDSP::Plugin::logfile) {
        open my $fh, '>', $Plugins::SqueezeDSP::Plugin::logfile or die "Could not create log file: $!";
        close $fh;
        Plugins::SqueezeDSP::Utils::debug('Log file created: ' . $Plugins::SqueezeDSP::Plugin::logfile);
    } else {
        Plugins::SqueezeDSP::Utils::debug('Log file already exists: ' . $Plugins::SqueezeDSP::Plugin::logfile);
    }
    amendPluginConfig($appConfig, 'logFile', $Plugins::SqueezeDSP::Plugin::logfile);
}

sub housekeeping {
    unlink glob catdir($Plugins::SqueezeDSP::Plugin::pluginTempDataDir, "/", '*.filter');
    unlink glob catdir($Plugins::SqueezeDSP::Plugin::pluginTempDataDir, "/", '*.filter.wav');
    unlink glob catdir($Plugins::SqueezeDSP::Plugin::pluginTempDataDir, "/", '*.wav');
    unlink grep { !/\current.json/ } glob catdir($Plugins::SqueezeDSP::Plugin::pluginTempDataDir, "/", '*.json');
}

sub amendPluginConfig {
    my ($myJSONFile, $myKey, $myValue) = @_;
    Plugins::SqueezeDSP::Utils::debug('Fox amend file: ' . $myJSONFile . ' for key =' . $myKey . ' value= ' . $myValue);
    my $myConfig =  Plugins::SqueezeDSP::Utils::LoadJSONFile($myJSONFile);
    $myConfig->{settings}->{$myKey} = $myValue;
    Plugins::SqueezeDSP::Utils::SaveJSONFile($myConfig, $myJSONFile);
}

1;