################################
#An auto-url shortener/expander for Irssi
#
#Zach Walton, 3/3/10
################################

use vars qw($VERSION %IRSSI);
use Irssi qw(command_bind);
use HTTP::Request;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Response;
use HTML::LinkExtor;

my $VERSION = '1.00';
my %IRSSI =
(
	authors	=> 'Zach Walton',
	contact	=> 'zacwalt@gmail.com',
	name		=> 'bitssi',
	description	=> 'An auto-url shortener/expander for Irssi',
	license	=> 'GPL'
);

sub parse {
	if (!Irssi::settings_get_str('bitssi_login') || !Irssi::settings_get_str('bitssi_api_key') || (Irssi::settings_get_str('bitssi_mode') eq "nothing")) { return; }
	my ($data, $x, $y) = @_;
	if ($data=~/(.*?)(s|e)?(https?\:\/\/.+?)(,.*?|\s.*?|\.\s.*?)?$/s) {
		if (Irssi::settings_get_str('bitssi_mode') eq "shorten") {
			$data = $1.shorten($3).$4;
		}
		elsif (Irssi::settings_get_str('bitssi_mode') eq "expand") {
			$data = $1.expand($3).$4;
		}
		elsif (Irssi::settings_get_str('bitssi_mode') eq "manual") {
			if ($2 eq 's' || $2 eq 'e') {
				$data=$1.manual($2,$3).$4;
			}
		}
		$_[0]=$data;
		Irssi::signal_continue(@_);
	}
}

sub inc_parse {
       if (!Irssi::settings_get_str('bitssi_login') || !Irssi::settings_get_str('bitssi_api_key') || (Irssi::settings_get_str('bitssi_mode') eq "nothing")) { return; }
        my ($x, $data, $y) = @_;
        if ($data=~/(.*?)(s|e)?(https?\:\/\/.+?)(,.*?|\s.*?|\.\s.*?)?$/s) {
                if (Irssi::settings_get_str('bitssi_mode') eq "shorten") {
                        $data = $1.shorten($3).$4;
                }
                elsif (Irssi::settings_get_str('bitssi_mode') eq "expand") {
                        $data = $1.expand($3).$4;
                }
                elsif (Irssi::settings_get_str('bitssi_mode') eq "manual") {
                        if ($2 eq 's' || $2 eq 'e') {
                                $data=$1.manual($2,$3).$4;
                        }
                }
                $_[1]=$data;
                Irssi::signal_continue(@_);
        }
}

sub shorten {
	 if ((!Irssi::settings_get_str("bitssi_login")) || (!Irssi::settings_get_str("bitssi_api_key"))) {
                Irssi::active_win->print("You must set a bit.ly username and API key to use this feature.  Type /bitssi_help for a list of commands.", MSGLEVEL_CRAP);
		return;
        }
	my $long_url =$_[0];
	$long_url=~s/&/%26/g; $long_url=~s/\?/%3F/g;
	my $url="http://api.bit.ly/shorten?version=2.0.1&longUrl=".$long_url."&login=".Irssi::settings_get_str('bitssi_login')."&apiKey=".Irssi::settings_get_str('bitssi_api_key');
	my $request = get($url);
	$request =~ /(http\:\/\/bit\.ly.+?)\"/s;
	my $short_url=$1;
	return $short_url;
}

sub expand {
	if ((!Irssi::settings_get_str("bitssi_login")) || (!Irssi::settings_get_str("bitssi_api_key"))) {
		Irssi::active_win->print("You must set a bit.ly username and API key to use this feature.  Type /bitssi_help for a list of commands.", MSGLEVEL_CRAP);
		return;
	}
	my $url="http://api.bit.ly/expand?version=2.0.1&shortUrl=".$_[0]."&login=".Irssi::settings_get_str('bitssi_login')."&apiKey=".Irssi::settings_get_str('bitssi_api_key');
	my $request = get($url);
	print $request;
	if ($request =~ /(https?\:\/\/.+?)\"/) {
		my $long_url=$1;
		return $long_url;
	}
	else {
		return "URL doesn't exist!";
	}
}

sub manual {
	if ($_[0] eq 's') {
		return shorten($_[1]);
	}
	elsif ($_[0] eq 'e') {
		return expand($_[1]);
	}
}

sub command_shorten {
	Irssi::active_win()->print(shorten($_[0]), MSGLEVEL_CRAP);	
}

sub command_expand {
	Irssi::active_win()->print(expand($_[0]), MSGLEVEL_CRAP);
}

sub set_login {
	Irssi::settings_set_str("bitssi_login",$_[0]);
	Irssi::active_win()->print("Bit.ly login set to ".$_[0], MSGLEVEL_CRAP);
}

sub set_api {
	Irssi::settings_set_str("bitssi_api_key",$_[0]);
	Irssi::active_win()->print("Bit.ly API key set to ".$_[0], MSGLEVEL_CRAP);
}

sub mode {
	if ($_[0] eq "shorten" || $_[0] eq "expand" || $_[0] eq "nothing" || $_[0] eq "manual")  {
		Irssi::settings_set_str("bitssi_mode", $_[0]);
		Irssi::active_win()->print("Mode set to ".$_[0], MSGLEVEL_CRAP);
	}
	else {
		Irssi::active_win()->print("Invalid mode!\n\nValid modes are:\n     shorten: shortens URLs\n     expand: expands URLs\n     manual: manual shortening/expansion only.\n             Type 's' or 'e' before http to shorten or expand.\n     nothing: does nothing", MSGLEVEL_CRAP);
	}
}

sub help() {
	Irssi::active_win()->print("%rMost of these commands will not work until you register an API account at bit.ly.%n\n\nCommands:\n     /set_bitssi_login - Sets the login name for bit.ly\n     /set_api_key - Sets the API key for bit.ly\n     /expand - Expands a given bit.ly URL\n     /shorten - Shortens a given URL\n     /bitssi_mode - Sets link behavior (shorten, expand, or nothing)\n     For further help, see http://zachwalton.com/bitssi.html", MSGLEVEL_CRAP);
}

sub print_welcome() {
	Irssi::active_win()->print("Welcome to Bitssi!\n\nTo get started, you'll need to sign up for an API account at bit.ly.  Sign up and view your API key here: http://bit.ly/account/your_api_key\n\nAfterward, type /bitssi_help for a list of commands.", MSGLEVEL_CRAP);
}

print_welcome();

Irssi::settings_add_str("misc", "bitssi_mode", "shorten");
Irssi::settings_add_str("misc", "bitssi_login", "");
Irssi::settings_add_str("misc", "bitssi_api_key", "");
Irssi::signal_add_first("send command", "parse");
Irssi::signal_add_first("message public", "inc_parse");
Irssi::signal_add_first("message private", "inc_parse");
command_bind shorten          => \&command_shorten;
command_bind expand           => \&command_expand;
command_bind bitssi_mode      => \&mode;
command_bind bitssi_help      => \&help;
command_bind set_bitssi_login => \&set_login;
command_bind set_api_key      => \&set_api;

