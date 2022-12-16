package Bot::BasicBot::Pluggable::Module::Irssi::Scripts;
our $VERSION = '0.1';
use base qw(Bot::BasicBot::Pluggable::Module);
use strict;
use warnings;
use YAML::Tiny;
use LWP::Simple qw(); # must not override get!
# trick cloudflare
$LWP::Simple::ua->agent('curl/7.52.1');
#use WWW::Shorten::Simple;
use Data::Dumper;
use URI::Escape;
use Bot::BasicBot::Pluggable::MiscUtils qw(util_dehi);
use AkariLinkShortener;

my $als = AkariLinkShortener->new;
#my $gh = WWW::Shorten::Simple->new('GitHub');  # broken as of 2022/01/11


sub help {
    return
"Information about Irssi scripts. Usage: script search <terms>, script info <name>"
}

sub _getdb {
    warn 'loading script db';
    my $db = LWP::Simple::get('https://scripts.irssi.org/scripts.yml');
    return unless $db;
    local $@;
    my $ref = eval { YAML::Tiny->read_string($db); };
    if ($@) {
	warn "YAML error $@";
	return;
    }
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Useqq = 1;
    local $Data::Dumper::Varname = '';
    local $Data::Dumper::Quotekeys = '';
    local $Data::Dumper::Sparseseen = 1;
    for my $script (@{$ref->[0]}) {
	for my $ent (qw(filename name description authors)) {
	    if (defined $script->{$ent} && ref $script->{$ent}) {
		$script->{$ent} = Dumper($script->{$ent});
	    }
	}
    }
    $ref->[0];
}

sub said {
    my $self = shift;
    my ($mess, $pri) = @_;

    return unless $pri == 2;
    my $body = $mess->{body};
    return unless $body =~ s/^\#irssi: \s //ix || $body =~ s/^irssi:://i || lc $mess->{channel} eq '#irssi';
    my $readdress = $mess->{channel} ne 'msg' && $body =~ s/\s+@\s+(\S+)[.]?\s*$// ? $1 : '';

    if ($body =~ /^(?: script \s+ (?<type1> search | info ) | (?<type2> find ) \s+ script ) \s+ (?<query> .* )/xi) {
	my $query = $+{query};
	my $type = $+{type1} || $+{type2};
	my $info = lc $type eq 'info';
	my $ref = _getdb() || return;
	my @val = split ' ', lc $query;
	my @matches;
	my $script = $query;
	$script =~ s/\.pl$//;
	if ($info) {
	    @matches = map { +{ s => $_, w => 1 } } grep { lc $_->{filename} eq lc "${script}.pl" } @$ref;
	} else {
	    for my $script (sort { $b->{modified} cmp $a->{modified} } @$ref) {
		my @str;
		for my $ent (qw(filename name description authors)) {
		    push @str, lc $script->{$ent} if defined $script->{$ent};
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
		    my $w = 1;
		    for my $v (@val) {
			next if '-' eq substr $v, 0, 1;
			my $i = @str;
			for my $s (@str) {
			    if (-1 != index $s, $v) {
				$w += $i;
			    }
			}
			$i--;
		    }
		    push @matches, +{ s => $script, w => $w };
		}
	    }
	}
	if (@matches) {
	    my ($match) = grep { lc $_->{s}{filename} eq lc "${script}.pl" } @matches; # exact
	    $match = (sort { $b->{w} <=> $a->{w} } @matches)[0] unless $match;
	    my %m1 = %{ $match->{s} };
	    my $fn = $m1{filename} =~ s/\.pl$//r;
	    warn "found match: $fn";
	    my $str1 = "\cB$fn\cB $m1{description} v$m1{version} \cO".(length $m1{authors} ? "(" . ($m1{authors} =~ s/([^ \t,;:])([^ \t,;:]+)/$1\cB\cB$2/gr) . ") " : "")."- ";
	    for my $v (split ' ', $query) {
		$str1 =~ s/(\Q$v\E)/\c_$1\c_/gi
		    unless $v =~ /^-/;
	    }
	    my $mod = $m1{modified} =~ s/ .*//r;
	    $str1 =~ s/\cO/from \cC14$mod\cC /;
	    my $v_info = '';
	    my $v_db = LWP::Simple::get('https://ailin-nemui.github.io/irssi-script-votes/votes.yml');
	    my $v_ref = do {
		local $@;
		my $ref = eval { YAML::Tiny->read_string($v_db); };
		if ($@) {
		    warn "YAML error $@";
		    undef
		} else {
		    $ref->[0]
		}
	    };
	    my $votes = $v_ref->{ $m1{filename} };
	    if ($votes->{v}) {
		$v_info = $votes->{v} . ( $votes->{h} ? "\x{1f49c}" : "\x{1f31f}" );
	    }
# 	    if (my $gh = $self->bot->module('GitHub')) {
# 		my $proj = "ailin-nemui/scripts.irssi.org"; # $gh->project_for_channel('#irssi');
# 		my $ng = $proj ? $gh->ng($proj) : undef;
# 		if ($ng) {
# 		    my $ua = $ng->ua;
# 		    # patch into Net/GitHub/V3/Issues.pm
# 		    # my %__methods = (
# 		    #    comments => { url => "/repos/%s/%s/issues/%s/comments", preview => "squirrel-girl-preview" },
# #		    $ua->default_header(Accept => 'application/vnd.github.squirrel-girl-preview');
# 		    my $iss = $ng->issue;
# 		    my $start = 2;
# 		    my @comm = $iss->comments($start);
# 		RST: while (1) {
# 			for my $c (@comm) {
# 			    $c->{body} =~ s/\r\n/\n/g;
# 			    if ($c->{body} =~ /\A## \Q$fn\E[._]pl$/m || $c->{body} =~ /\A\Q$fn\E[._]pl\n---\n/m) {
# #				use Data::Dumper ; warn Dumper $c; # "$c->{reactions}{total_count} $c->{body}";
# 				if ($c->{reactions}{total_count}) {
# 				    my $votes = 1+ $c->{reactions}{'+1'} - $c->{reactions}{'-1'};
# 				    my $hearts = $c->{reactions}{heart};
# 				    if ($votes > 0) {
# 					$v_info = ($votes > 1 ? $votes-1 : "") . ($hearts >= $votes ? "\x{1f49c}" : "\x{1f31f}");
# 				    } else {
# 					$v_info = ($votes > 1 ? $votes-1 : "") . ($hearts >= $votes ? "\x{1f494}" : "\x{2744}");
# 				    }
# 				}
# 				last RST;
# 			    } elsif ($c->{body} =~ /\A#(\d+)\Z/) {
# 				@comm = $iss->comments($1);
# 				next RST;
# 			    }
# 			}
# 			last;
# 		    }
# 		}
# 	    }
	    $str1 .= "$v_info  " if length $v_info;
	    $info = "\cC7o\cC $str1"
		.$als->shorten("https://github.com/irssi/scripts.irssi.org/blob/master/scripts/$m1{filename}")
		.(@matches > 1 ? " and \cB".(@matches-1)."\cB more: " . $als->shorten("https://scripts.irssi.org/#q=".uri_escape_utf8($query)) : "");
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
