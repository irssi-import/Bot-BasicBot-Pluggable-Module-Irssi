package Bot::BasicBot::Pluggable::Module::Irssi::Scripts;
our $VERSION = '0.1';
use base qw(Bot::BasicBot::Pluggable::Module);
use strict;
use warnings;
use YAML::Tiny;
use LWP::Simple qw(); # must not override get!
use WWW::Shorten::Simple;

my $gh = WWW::Shorten::Simple->new('GitHub');
my $sck = WWW::Shorten::Simple->new('SCK');


sub help {
    return
"Information about Irssi scripts.

script search <terms>
script info <name>"
}

sub _getdb {
    my $db = LWP::Simple::get('https://raw.githubusercontent.com/irssi/scripts.irssi.org/master/_data/scripts.yaml');
    return unless $db;
    local $@;
    my $ref = eval { YAML::Tiny->read_string($db); };
    if ($@) {
	warn "YAML error $@";
	return;
    }
    $ref->[0];
}

sub said {
    my $self = shift;
    my ($mess, $pri) = @_;

    return unless $pri == 2;
    my $body = $mess->{body};
    return unless $body =~ s/^\#irssi: \s //ix || lc $mess->{channel} eq '#irssi';
    my $readdress = $mess->{channel} ne 'msg' && $body =~ s/\s+@\s+(\S+)[.]?\s*$// ? $1 : '';

    if ($body =~ /^(?: script \s+ (?<type1> search | info ) | (?<type2> find ) \s+ script ) \s+ (?<query> .* )/xi) {
	my $query = $+{query};
	my $type = $+{type1} || $+{type2};
	my $info = lc $type eq 'info';
	my $ref = _getdb() || return;
	my @val = split ' ', $query;
	my @matches;
	my $script = $query;
	$script =~ s/\.pl$//;
	if ($info) {
	    @matches = grep { lc $_->{filename} eq lc "${script}.pl" } @$ref;
	} else {
	    for my $script (sort { $b->{modified} cmp $a->{modified} } @$ref) {
		my @str;
		for my $ent (qw(filename name description authors)) {
		    push @str, $script->{$ent} if defined $script->{$ent};
		};
		my $str = join ' ', @str;
		my $match = 1;
		for my $v (@val) {
		    if ('-' eq (substr $v, 0, 1) && -1 == index $str, (substr $v, 1) ) {
			next;
		    } elsif (-1 != index $str, $v) {
			next;
		    } else {
			$match = 0;
			last;
		    }
		}
		if ($match) {
		    push @matches, $script;
		}
	    }
	}
	if (@matches) {
	    my ($match) = grep { lc $_->{filename} eq lc "${script}.pl" } @matches; # exact
	    $match = $matches[0] unless $match;
	    my %m1 = %$match;
	    my $fn = $m1{filename} =~ s/\.pl$//r;
	    my $str1 = "\cB$fn\cB $m1{description} v$m1{version} \cO".(length $m1{authors} ? "($m1{authors}) " : "")."- ";
	    for my $v (split ' ', $query) {
		$str1 =~ s/(\Q$v\E)/\c_$1\c_/gi
		    unless $v =~ /^-/;
	    }
	    my $mod = $m1{modified} =~ s/ .*//r;
	    $str1 =~ s/\cO/from \cC14$mod\cC /;
	    my $v_info = '';
	    if (my $gh = $self->bot->module('GitHub')) {
		my $proj = "ailin-nemui/scripts.irssi.org"; # $gh->project_for_channel('#irssi');
		my $ng = $proj ? $gh->ng($proj) : undef;
		if ($ng) {
		    my $ua = $ng->ua;
		    $ua->default_header(Accept => 'application/vnd.github.squirrel-girl-preview');
		    my $iss = $ng->issue;
		    my $start = 2;
		    my @comm = $iss->comments($start);
		RST: while (1) {
			for my $c (@comm) {
			    if ($c->{body} =~ /\A## \Q$fn\E[._]pl$/m) {
				if ($c->{reactions}{total_count}) {
				    my $votes = 1+ $c->{reactions}{'+1'} - $c->{reactions}{'-1'};
				    my $hearts = $c->{reactions}{heart};
				    if ($votes > 0) {
					$v_info = $votes . ($hearts >= $votes ? "\x{1f49c}" : "\x{1f31f}");
				    } else {
					$v_info = $votes . ($hearts >= $votes ? "\x{1f494}" : "\x{2744}");
				    }
				}
				last RST;
			    } elsif ($c->{body} =~ /\A#(\d+)\Z/) {
				@comm = $iss->comments($1);
				next RST;
			    }
			}
			last;
		    }
		}
	    }
	    $str1 .= "$v_info  " if length $v_info;
	    $info = "\cC7o\cC $str1"
		.$gh->shorten("https://github.com/irssi/scripts.irssi.org/blob/master/scripts/$m1{filename}")
		.(@matches > 1 ? " and \cB".(@matches-1)."\cB more: " . $sck->shorten("https://scripts.irssi.org/#q=".$query) : "");
	    if ($readdress) {
		my %hash = %$mess;
		$hash{who} = $readdress;
		$hash{address} = 1;
		$self->reply(\%hash, $info);
		return 1;
	    }
	    return $info;
	} else {
	    return "\cC4..\cC no script found";
	}
    }
}

1;
