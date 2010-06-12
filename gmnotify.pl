
## A nick hilight/PM notification and response script		
##								
## See http://github.com/zach-walton/gmnotify for example config file
##
## Parts of this script are modified from sumeet's goobtown.pl	
## and drano's notify.io script.				
##								
## zorachus, 6/7/10						


use vars qw($VERSION %IRSSI);
use Irssi qw(command_bind);
use Email::Send;
use Email::Send::Gmail;
use Email::Simple;
use Email::Simple::Creator;
use Net::IMAP::Simple::SSL;

my $VERSION = '1.1';
my %IRSSI =	(
	authors	=> 'Zach Walton',
	contact	=> 'zacwalt@gmail.com',
	name		=> 'gmnotify',
	description	=> 'A nick hilight/PM notification script.  As far as I know, the only one that supports responding via email.',
	license	=> 'GPL'
);


## Irssi environment variables:									
## (change with /set variable_name)								
##	gmnotify_poll_rate: 		How often to poll for new emails (IMAP) in seconds.  	
##					Default: 300						
##	gmnotify_active_poll_rate: 	How often to poll for new emails after an email			
##                                 has been sent or received for the next 			
##					gmnotify_poll_rate seconds.  Default: 60		
##	gmnotify_source		Gmail address to send from (blank by default!)		
##	gmnotify_password		Password for gmnotify_source (blank by default!)
##	gmnotify_dest			Gmail address to send to (blank by default!)	
##	gmnotify_folder		The IMAP folder (or Gmail label) to poll for response	
##					emails.  Add this folder to the gmnotify_source address 
##					and set up filters appropriately.			
##					Default: irssi_notifications				


sub sig_print_text($$$) {
	my ($destination, $text, $stripped) = @_;
	my $server = $destination->{server};
        my ($hilight) = Irssi::parse_special('$;');
	return unless $server->{usermode_away} eq 1;
	$text =~ s/(.*)$hilight(.*)($server->{nick})(.*)/$3$4/;
	if ($destination->{level} & MSGLEVEL_HILIGHT) {
		send_message(
			"Nick Highlight in ".$destination->{target},
			$stripped,
			"Nick Highlight in ".$destination->{target}.
			":\n\n<".$hilight."> ".$text."\n-----\n|Server:".
			$server->{tag}."|Channel:".$destination->{target}.
			"|User:".$hilight."|"
		);
	}
}

sub sig_message_private($$$$) {
	return unless (Irssi::settings_get_int('screen_away_status') eq 0);
	my ($server, $data, $nick, $address) = @_;
	return unless $server->{usermode_away} eq 1;
	send_message(
		"Private Message from ".$nick,
		"Private Message from".$nick, 
		"Private Message from ".$nick.
		":\n\n<$nick> $data\n-----\n|Server:".
		$server->{tag}."|Channel:Private|User:$nick|"
	);
}

sub send_message($$$) {
	short_timer(0);
	my($title,$text,$content)=@_;
	my $email = Email::Simple->create(
		header => [
			From    => Irssi::settings_get_str('gmnotify_source'),
			To      => Irssi::settings_get_str('gmnotify_dest'),
			Subject => $title,
		],
		body => $content,
	);
	my $sender = Email::Send->new({   
		mailer      => 'Gmail',
		mailer_args => [
			username => Irssi::settings_get_str('gmnotify_source'),
			password => Irssi::settings_get_str('gmnotify_password'),
		]
	});
	eval { $sender->send($email) };
	die "Error sending email: $@" if $@;
}

sub poll {
	my $imap = Net::IMAP::Simple::SSL->new('imap.gmail.com');
	$imap->login(Irssi::settings_get_str('gmnotify_source'), Irssi::settings_get_str('gmnotify_password')) or return; #sometimes, polling too often causes this to fail.  die() would kill the script too often
	$number_of_messages = $imap->select(Irssi::settings_get_str('gmnotify_folder'));
	foreach $msg (1..$number_of_messages) {	
		if (!defined($imap->seen($msg))) {
			short_timer(0);
			$lines = $imap->get($msg);
			$imap->delete($msg);
			post_response(@$lines);
		}
	}
	$imap->quit(); #initialize object every time in case the account is changed
	timer();
}

sub post_response($) {
	my @lines = @_;
	my ($server,$channel,$user,$message) = strip($lines);
	if (!defined($user) || !defined($message) || !defined($server) || !defined($channel)) { return; }
	if ($channel eq "Private") {
		my $irssi_server = Irssi::server_find_tag($server);
		if (!defined($irssi_server)) { return; }
		$irssi_server->send_message($user, "$message [from email]", 1);
		Irssi::print("Private message sent to \%W$user\%n on \%W$server\%n: $message [from email]", MSGLEVEL_CLIENTNOTICES);
	}
	else {
		my $irssi_server = Irssi::server_find_tag($server);
		if (!defined($irssi_server)) { return; }
		$irssi_server->send_message($channel, "$user: $message [from email]", 0);
		Irssi::print("Message sent to \%W$channel\%n on \%W$server\%n: $user: $message", MSGLEVEL_CLIENTNOTICES);
	}
	return;
}

sub strip {
	my $lines=$_[0];
	$lines =~ /Server\:(.+?)\|Channel\:(.+?)\|User\:(.+?)\|/;
	my $server=$1;
	my $channel=$2;
	my $user=$3;
	$lines =~ /Content-Type\:\stext\/plain;.+?\n.+?\n(.+?)On.+?\w{3}.+?\d{2}/s;
	my $message=$1;
	$message =~ s/[\n\r]//sg;
	return ($server,$channel,$user,$message);
}

sub timer {
	if (defined($timer_name)) {
		Irssi::timeout_remove($timer_name);
	}
	$timer_name=Irssi::timeout_add(Irssi::settings_get_int('gmnotify_poll_rate')*1000, 'poll', Irssi::settings_get_str('gmnotify_folder'));
}

sub short_timer($) {
	my $reset=$_[0];
	if ($reset eq 1) {
		Irssi::settings_set_int('gmnotify_poll_rate', $long_poll_rate);
		if (defined($short_timer)) {
			Irssi::timeout_remove($short_timer);
		}
		return;
	}
	$long_poll_rate=Irssi::settings_get_int('gmnotify_poll_rate');
	Irssi::settings_set_int('gmnotify_poll_rate',Irssi::settings_get_int('gmnotify_active_poll_rate'));
	if (defined($timer_name)) {
		Irssi::timeout_remove($timer_name);
	}
	$timer_name=Irssi::timeout_add(Irssi::settings_get_int('gmnotify_poll_rate')*1000, 'poll', Irssi::settings_get_str('gmnotify_folder'));
	if (defined($short_timer)) {
		Irssi::timeout_remove($short_timer);
	}
	$short_timer=Irssi::timeout_add($long_poll_rate*1000,'short_timer', '1');
}

sub load_conf {
	my $exists = open(GMCONF, "<gmnotify.conf");
	if (!$exists) {
		print "Error opening configuration file!  See example configuration at http://github.com/zach-walton/gmnotify.  Exiting.";
		exit(1);
	}
	my $i=0;
	while ($line = <GMCONF>) {
		$i++;
		if (($line !~ /^#/) and ($line !~ /^\n/)) {
			chomp($line);
			$line =~ /(\S+?)\:\s+?(.+)/;
			my $name = $1; my $value = $2;
			if ($name eq "SourceEmail") {
				Irssi::settings_set_str('gmnotify_source', $value);
			}
			elsif ($name eq "SourcePassword") { 
				Irssi::settings_set_str('gmnotify_password', $value); 
			}
			elsif ($name eq "DestEmail") { 
				Irssi::settings_set_str('gmnotify_dest', $value); 
			}
			elsif ($name eq "IMAPPollRate")	{ 
				Irssi::settings_set_int('gmnotify_poll_rate', $value); 
			}
			elsif ($name eq "TempIMAPPollRate") { 
				Irssi::settings_set_int('gmnotify_active_poll_rate', $value); 
			}
			else { 
				die("Error in gmnotify.conf at line $i!  See example conf file at http://github.com/zach-walton/gmnotify");
			}
		}
	}
}

Irssi::signal_add_last('print text', \&sig_print_text);
Irssi::signal_add_last('message private', \&sig_message_private);

Irssi::settings_add_int('misc', 'gmnotify_poll_rate', 0);
Irssi::settings_add_int('misc', 'gmnotify_active_poll_rate', 0); #setting this lower than 60 may cause freezing/crashing!
Irssi::settings_add_str('misc', 'gmnotify_source', '');
Irssi::settings_add_str('misc', 'gmnotify_password', '');
Irssi::settings_add_str('misc', 'gmnotify_dest', '');
Irssi::settings_add_str('misc', 'gmnotify_folder', '');

our $timer_name=undef;
our $short_timer=undef;
our $long_poll_rate=Irssi::settings_get_int('gmnotify_poll_rate');

load_conf();

poll($folder);

