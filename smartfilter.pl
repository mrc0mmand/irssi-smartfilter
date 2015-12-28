use strict;
use warnings;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.4";

%IRSSI = (
	authors     => 'Christian Brassat, Niall Bunting and Walter Hop',
	contact     => 'irssi-smartfilter@spam.lifeforms.nl',
	name        => 'smartfilter.pl',
	description => 'Improved smart filter for join, part, quit, nick messages',
	license     => 'BSD',
	url         => 'https://github.com/lifeforms/irssi-smartfilter',
	changed     => '2015-12-28',
);

# Associative array of nick => last active unixtime
our $lastmsg = {};
our $garbagetime = 1;

# Do checks after receving a channel event.
# - If the originating nick is not active, ignore the signal.
# - If nick is active, propagate the signal and display the event message.
#   Keep the nick marked as active, so we will not miss a re-join after a PART
#   or QUIT, a second nick change, etc.
sub checkactive {
	my ($nick, $altnick, $channel) = @_;
	my $ignored_chans = Irssi::settings_get_str('smartfilter_ignored_chans');
	my @ignored_chans_array = split /\s+/, $ignored_chans;

	# Skip filtering if current channel is in 'smartfilter_ignored_chans'
	if (defined $channel && grep(/$channel/, @ignored_chans_array)) {
		return;
	}

	my $isfirst = !exists $lastmsg->{$nick};

	if (!$isfirst && $lastmsg->{$nick} <= time() - Irssi::settings_get_int('smartfilter_delay')) {
		delete $lastmsg->{$nick};
		Irssi::signal_stop();
	} else {
		$lastmsg->{$nick} = time();
		if ($altnick) {
			$lastmsg->{$altnick} = time();
		}

		if ($isfirst) {
			Irssi::signal_stop();
		}
	}

	# Run the garbage collection every interval.
	if ($garbagetime <= time() - (Irssi::settings_get_int('smartfilter_delay') * Irssi::settings_get_int('smartfilter_garbage_multiplier') )) {
		garbagecollect();
		$garbagetime = time();
	}
}

# Implements garbage collection.
sub garbagecollect{
	foreach my $key (keys %$lastmsg) {
		if ($lastmsg->{$key} <= time() - Irssi::settings_get_int('smartfilter_delay')) {
			delete $lastmsg->{$key}
		}
	}
}

# JOIN or PART received.
sub smartfilter_chan {
	my ($server, $channel, $nick, $address) = @_;
	&checkactive($nick, undef, $channel);
};

# QUIT received.
sub smartfilter_quit {
	my ($channel, $nick, $address, $reason) = @_;
	&checkactive($nick, undef, $channel);
};

# NICK change received.
sub smartfilter_nick {
	my ($server, $newnick, $nick, $address) = @_;

	if (Irssi::settings_get_bool('smartfilter_filter_nick')) {
		&checkactive($nick, $newnick, undef);
	}
};

# Channel message received. Mark the nick as active.
sub log {
	my ($server, $msg, $nick, $address, $target) = @_;
	$lastmsg->{$nick} = time();
}

Irssi::signal_add('message public', 'log');
Irssi::signal_add('message join', 'smartfilter_chan');
Irssi::signal_add('message part', 'smartfilter_chan');
Irssi::signal_add('message quit', 'smartfilter_quit');
Irssi::signal_add('message nick', 'smartfilter_nick');

Irssi::settings_add_int('smartfilter', 'smartfilter_garbage_multiplier', 4);
Irssi::settings_add_int('smartfilter', 'smartfilter_delay', 1200);
Irssi::settings_add_str('smartfilter', 'smartfilter_ignored_chans', '');
Irssi::settings_add_bool('smartfilter', 'smartfilter_filter_nick', 1);
