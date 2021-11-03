package Bot::BasicBot::Pluggable::Module::Irssi::Help;
our $VERSION = '0.1';
use base qw(Bot::BasicBot::Pluggable::Module);
use strict;
use warnings;
use YAML::Tiny;
use LWP::Simple qw(); # must not override get!
use WWW::Shorten::Simple;
use AkariLinkShortener;

my $sck = AkariLinkShortener->new;

sub help {
    return
"Help from Irssi. Usage: help <command>, help <command> <subcommand>, syntax <command>"
}

# ack --cc SYNTAX | perl -aln -E' @F = split ":"; @G = split " ", $F[3]; $cmd{ $F[0] }{ $G[0] } = 1; END { for (sort keys %cmd) { print "'"'"'$_'"'"' => [qw( " . (join " ", sort keys %{$cmd{$_}}) . " )]," } }  '

my %synfiles = (
'src/core/chat-commands.c' => [qw( CONNECT DISCONNECT FOREACH MSG QUIT SERVER )],
'src/core/commands.c' => [qw( CD EVAL )],
'src/core/rawlog.c' => [qw( RAWLOG )],
'src/core/servers-reconnect.c' => [qw( RECONNECT RMRECONNS )],
'src/core/session.c' => [qw( UPGRADE )],
'src/fe-common/core/fe-channels.c' => [qw( CHANNEL CYCLE JOIN NAMES )],
'src/fe-common/core/fe-core-commands.c' => [qw( BEEP CAT ECHO UPTIME VERSION )],
'src/fe-common/core/fe-exec.c' => [qw( EXEC )],
'src/fe-common/core/fe-help.c' => [qw( HELP )],
'src/fe-common/core/fe-ignore.c' => [qw( IGNORE UNIGNORE )],
'src/fe-common/core/fe-log.c' => [qw( LOG WINDOW )],
'src/fe-common/core/fe-modules.c' => [qw( LOAD UNLOAD )],
'src/fe-common/core/fe-queries.c' => [qw( QUERY UNQUERY )],
'src/fe-common/core/fe-recode.c' => [qw( RECODE )],
'src/fe-common/core/fe-server.c' => [qw( SERVER )],
'src/fe-common/core/fe-settings.c' => [qw( ALIAS RELOAD SAVE SET TOGGLE UNALIAS )],
'src/fe-common/core/completion.c' => [qw( COMPLETION )],
'src/fe-common/core/hilight-text.c' => [qw( DEHILIGHT HILIGHT )],
'src/fe-common/core/keyboard.c' => [qw( BIND )],
'src/fe-common/core/themes.c' => [qw( FORMAT )],
'src/fe-common/core/window-commands.c' => [qw( FOREACH LAYOUT WINDOW )],
'src/fe-common/irc/fe-irc-commands.c' => [qw( ACTION BAN ME SETHOST TS VER )],
'src/fe-common/irc/fe-irc-server.c' => [qw( SERVER )],
'src/fe-common/irc/fe-ircnet.c' => [qw( NETWORK )],
'src/fe-common/irc/fe-netsplit.c' => [qw( NETSPLIT )],
'src/fe-text/lastlog.c' => [qw( LASTLOG )],
'src/fe-text/mainwindows.c' => [qw( WINDOW )],
'src/fe-text/statusbar-config.c' => [qw( STATUSBAR )],
'src/fe-text/textbuffer-commands.c' => [qw( CLEAR SCROLLBACK )],
'src/irc/core/bans.c' => [qw( BAN UNBAN )],
'src/irc/core/irc-commands.c' => [qw( ACCEPT ADMIN AWAY CTCP DIE HASH INFO INVITE ISON KICK KICKBAN KILL KNOCK KNOCKOUT LINKS LIST LUSERS MAP MOTD NCTCP NICK NOTICE OPER PART PING QUOTE REHASH RESTART SCONNECT SERVER SERVLIST SILENCE SQUERY SQUIT STATS TIME TOPIC TRACE UNSILENCE USERHOST VERSION WAIT WALL WALLOPS WHO WHOIS WHOWAS )],
'src/irc/core/modes.c' => [qw( DEOP DEVOICE MODE OP VOICE )],
'src/irc/dcc/dcc-chat.c' => [qw( DCC MIRCDCC )],
'src/irc/dcc/dcc-get.c' => [qw( DCC )],
'src/irc/dcc/dcc-resume.c' => [qw( DCC )],
'src/irc/dcc/dcc-server.c' => [qw( DCC )],
'src/irc/dcc/dcc.c' => [qw( DCC )],
'src/irc/notifylist/notify-commands.c' => [qw( NOTIFY UNNOTIFY )],
'src/irc/proxy/proxy.c' => [qw( IRSSIPROXY )],
);

#our local @colors;
sub _to_ic {
    my ($cc, $cg, $type, $on) = @_;
    my $col = @$cg >= 3 ? $cg->[$type] :
	@$cg == 2 && $type > 0 ? $cg->[$type - 1] :
	@$cg == 1 && $type == 1 ? $cg->[0] :
        '';
    my $str = '';
    if ($col =~ s/[*]//) {
	$str .= "\cB";
    }
    if ($col =~ s/[_]//) {
	$str .= "\c_";
    }
    if (length $col) {
	if ($on) {
	    push @$cc, $col;
	}
	else {
	    pop @$cc;
	    $col = @$cc ? $cc->[-1] : '';
	}
	$str = "\cC$col$str";
    }
    $str;
}
sub _popcol {
    my ($cc, $text) = @_;
    my $col = @$cc ? $cc->[-1] : '';
    @$cc ? "$text\cC$col" : $text;
}

sub _add_syn_colors {
    my $text = shift;
    my $cc = pop // [];
    my $cgroup = shift // [];
    my @next_level = @_;
    $text =~ s{
		  (,?\s*|\|) |
		  (< .*? >) |
		  ((?<!^) [[] (?: [^][]++ | (?R) )* []]) |
		  ([^][\s,|><]+)
	  }{
#	      defined $1 ? _popcol($cc, $1) :
	      defined $1 ? $1 :
		  length $2 ? _to_ic($cc,$cgroup,1,1).$2._to_ic($cc,$cgroup,1,0) :
		  length $3 ? _to_ic($cc,$cgroup,2,1)._add_syn_colors($3, @next_level, [@$cc])._to_ic($cc,$cgroup,2,0) :
		  length $4 ? _to_ic($cc,$cgroup,0,1).$4._to_ic($cc,$cgroup,0,0) : ""
	  }gexr;
}


sub said {
    my $self = shift;
    my ($mess, $pri) = @_;

    return unless $pri == 2;

    my $body = $mess->{body};
    return unless $body =~ s/^\#irssi: \s //ix || lc $mess->{channel} eq '#irssi' || $body =~ /^irssi::/i;
    my $readdress = $mess->{channel} ne 'msg' && $body =~ s/\s+@\s+(\S+)[.]?\s*$// ? $1 : '';

    #return unless $mess->{address};

    my $synre = qr/syn(?:tax)?/i;
    my $syntax_pre;

    my %rep = ( '|' => '', ':' => ' ', '#' => '', '%' => '%', '_' => "\c_", '9' => "\cB" );
    if ($body =~ /^($synre (?: \s+ \d+ )?) \s+ ( .*? )( \s+ \d+ )? \s* $/xi) {
	$body = "help $2 $1" . ($3 ? " $3" : "");
	$syntax_pre = 1;
    }

    if ($body =~ /^(?:\/|irssi::)?help \s+ (?<expr> .* )/xi) {
	my @words = split ' ', $+{expr};
	my $info;

	my $syn_idx;
	if (@words >= 3 && $words[-2] =~ /^$synre$/i && $words[-1] =~ /^\d+$/) {
	    $syn_idx = pop @words;
	}

	if ($words[-1] =~ /^$synre$/i) {
	    # look up syntax
	    my @files = grep { grep { $_ eq uc $words[0] } @{$synfiles{$_}} } sort keys %synfiles;
	    my $expr = join "\\s+", map { "(?:\\S*?\\|)?\Q$_\E(?:\\|\\S*?)?" } @words[0..($#words-1)];
	    my @match;
	    for my $file (@files) {
		my $res = LWP::Simple::get("https://github.com/irssi/irssi/raw/master/$file");
		if ($res) {
		    push @match, grep {
			/^$expr(?:\s+.*?)?$/i
		    } map {
			s/\s/ /g; s/\s{3,}/ /g; $_
		    } map {
			my ($word) = /^(\S+)/;
			(split /^\s+(?=\Q$word\E\s)/m, $_)
		    } $res =~ m{ ^ \s* /[*] \s* SYNTAX: \s* (.*?) \s* [*]/ \s* $ }gimsx ;
		} else {
		    warn "no response for $file";
		}
	    }
	    if (@match == 1) {
		$info = "@match";
	    } elsif (@match) {
		my %match0;
		my (%non_uniq, %non_uniq_c);
		pop @words; # 'syntax'

		$non_uniq{"\U@words"}++;
		for (@match) {
		    my $orig = $_;
		    s/\s[-[<].*//;
		    $non_uniq{$_}++;
		    push @{$match0{"\U$_"}}, $orig;
		}
		for (@match) {
		    if ($non_uniq{$_} > 1) {
			$_ .= "\cB" . ($syntax_pre ? ' ' : ' syntax ') . ++$non_uniq_c{$_} . "\cB";
		    }
		}
		my $ar = $match0{"\U@words"} // [];
		if ($syn_idx && $ar->[$syn_idx-1]) {
		    @match = $ar->[$syn_idx-1];
		}
		$info = +(join ", ", @match);
	    }

	    if ($info) {
		$info = _add_syn_colors($info, ["*", "*05", "10"], ["09", "14"], ["*", "13", "13"], ["14"], []);

		$info .= " .. " . $sck->shorten("https://ailin-nemui.github.io/irssi/documentation/help/\L$words[0].html");
	    }
	}
	elsif (@words > 1 && ('set' eq lc $words[0] || 'setting' eq lc $words[0])) {
	    # look up setting
	    my $res = LWP::Simple::get("https://ailin-nemui.github.io/irssi/_sources/documentation/settings.md.txt");
	    my @info;
	    my $soon = 0;
	    my $val;
	    for my $line (split "\n", $res) {
		if ($line =~ /^\(\Q$words[1]\E\)=/i) {
		    $soon = 1;
		}
		elsif ($soon == 1 && $line =~ /^(?:` (.*) `|`(.*)` \*\*`(.*)`\*\*)$/) {
		    $val = defined $1 ? $1 : "$2 = $3";
		    $soon++;
		}
		elsif ($soon && $line =~ /^[: ]/) {
		    next if $line =~ /^:?\s+$/;
		    next if $line =~ /^:?\s+!/;
		    next if $line =~ /^:?\s+```/;
		    push @info, ($line =~ /^[: ] (.*)/);
		}
		elsif (@info) {
		    last;
		}
	    }
	    if ($val && @words > 2 && ($words[2] eq '=' || $words[2] eq '?')) {
		unshift @info, $val;
		splice @words, 2, 1;
	    }
	    if (@words > 2) {
		my $expr = join "\\s+", map { quotemeta } @words[2..$#words];
		@info = grep /\b$expr\b/i, @info;
	    }
	    s/`//g for @info;
	    s/\\\\/\\/g for @info;
	    if (@info) {
		my $sep =($info[0] =~ s/^\Q$words[1]\E\s+=(\s+|\s*$)//i) ? '' : ':';
		my $clr = !$sep && !length $info[0] ? '-clear ' : '';
		my $setting_anchor = lc $words[1];
		$setting_anchor =~ s/_/-/g;
		$info = "/set $clr\cB\L$words[1]\E\cB$sep $info[0] " . (@info > 1 ? " ... " : "")
		    . " .. " . $sck->shorten("https://ailin-nemui.github.io/irssi/documentation/settings.html#$setting_anchor");
	    }
	}
	else {
	    # look up detailed help
	    my $cmd = $words[0];
	    $cmd =~ s/\W//g;
	    my $res = LWP::Simple::get("https://github.com/irssi/irssi/raw/master/docs/help/in/\L$cmd.in");
	    if ($res) {
		if (@words == 1 || (@words == 2 && $words[1] =~ /^desc(?:ription)?$/i )) {
		    # description
		    my $soon;
		    my @info;
		    for my $line (split /\n/, $res) {
			local $_ = $line;
			if (/^%9Description:/) { $soon = 1; }
			elsif ($soon) {
			    if (@info && (/^\s*$/ || /^\S/) ) {
				last;
			    }
			    elsif (/^\s+(\S.*)$/) {
				push @info, $1;
			    }
			}
		    }
		    s{%(.)}{$rep{$1} // '%'.$1}ge for @info;
		    @info = '(No description found)'
			unless @info;
		    $info = "\U\cB$cmd:\cB\E @info .. " . $sck->shorten("https://ailin-nemui.github.io/irssi/documentation/help/\L$cmd.html");
			#if @info;
		}
		else {
		    my $expr = join "\\s+", map { quotemeta } @words[1..$#words];
		    my @info;
		    for my $line (split /\n/, $res) {
			local $_ = $line;
			if (/^\s+($expr(?::|\s)\s)\s*(.*)$/i) {
			    push @info, "\cB$1\cB" . $2;
			}
			elsif (@info) {
			    if (/^\s{8}\s+(\S.*)$/) {
				push @info, $1;
			    }
			    else {
				last;
			    }
			}
		    }
		    s{%(.)}{$rep{$1} // '%'.$1}ge for @info;
		    $info = "\[\U$cmd\E\] @info .. " . $sck->shorten("https://ailin-nemui.github.io/irssi/documentation/help/\L$cmd.html")
			if @info;
		}
	    }
	}
	if ($info) {
	    if ($readdress) {
		my %hash = %$mess;
		$hash{who} = $readdress;
		$hash{address} = 1;
		$self->reply(\%hash, $info);
		return 1;
	    }
	    return $info;
	} else {
	    warn "no info for @words";
	    return # "\cC4..\cC not found";
	}
    }
}
