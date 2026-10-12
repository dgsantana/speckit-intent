package FeatureIdLib;
# Shared slug and hash rules for feature IDs <yyyyMMdd>-<hash>-<slug>.
# Perl port of ../powershell/feature-id-lib.ps1, used by new-feature-id.sh and migrate-feature-ids.sh so the
# PowerShell `-match` ignores case, so the ID patterns do too.
# two cannot disagree. Any change here must keep the PowerShell and bash results identical (tests/parity).
use strict;
use warnings;
use utf8;
use Encode qw(encode);
use Digest::SHA qw(sha1_hex);
use Unicode::Normalize qw(NFD);
use Cwd qw(getcwd);
use File::Spec;
use Exporter 'import';

our @EXPORT_OK = qw(find_project_root spec_directories slug slug_hash feature_id_info canonical_slug resolve_free_hash json_encode);

our $MODERN = qr/^(?<date>\d{8})-(?<hash>[0-9a-f]{7,})-(?<slug>[a-z0-9]+(?:-[a-z0-9]+)*)$/i;
our $LEGACY = qr/^(?<num>\d{3})-(?<slug>.+)$/si;
our $TIMESTAMP = qr/^(?<date>\d{8})-\d{6}-(?<slug>.+)$/si;

# Nearest directory holding .specify, searching upward from the current directory.
sub find_project_root {
    my $dir = getcwd();
    while (1) {
        return $dir if -d File::Spec->catdir($dir, '.specify');
        my $parent = File::Spec->catdir($dir, File::Spec->updir);
        $parent = Cwd::abs_path($parent);
        return undef if !defined $parent || $parent eq $dir;
        $dir = $parent;
    }
}

# Names of the directories under $specs, as Get-ChildItem -Directory lists them (hidden ones left out).
sub spec_directories {
    my ($specs) = @_;
    return () unless -d $specs;
    opendir my $dh, $specs or return ();
    my @names = sort grep { !/^\./ && -d "$specs/$_" } readdir $dh;
    closedir $dh;
    return map { Encode::decode('UTF-8', $_) } @names;
}

# Accents decomposed and dropped, ASCII alphanumerics kept, runs of anything else as '-', at most 48
# characters cut on a word boundary. Dies when nothing usable is left.
sub slug {
    my ($text) = @_;
    my $stripped = NFD($text);
    $stripped =~ s/\p{Mn}//g;
    my $slug = lc $stripped;
    $slug =~ s/[^a-z0-9]+/-/g;
    $slug =~ s/^-+|-+$//g;
    die "'$text' contains no characters usable in a feature slug.\n" if $slug eq '';
    if (length $slug > 48) {
        $slug = substr $slug, 0, 48;
        my $last_dash = rindex $slug, '-';
        $slug = substr $slug, 0, $last_dash if $last_dash >= 12;
        $slug =~ s/^-+|-+$//g;
    }
    return $slug;
}

# SHA-1 of the slug's UTF-8 bytes, first $length hex characters.
sub slug_hash {
    my ($slug, $length) = @_;
    return substr sha1_hex(encode('UTF-8', $slug)), 0, $length;
}

sub feature_id_info {
    my ($name) = @_;
    return { Name => $name, Kind => 'modern', Date => $+{date}, Hash => $+{hash}, Slug => $+{slug} } if $name =~ $MODERN;
    return { Name => $name, Kind => 'legacy', Date => $+{date}, Hash => undef, Slug => $+{slug} } if $name =~ $TIMESTAMP;
    return { Name => $name, Kind => 'legacy', Date => undef, Hash => undef, Slug => $+{slug} } if $name =~ $LEGACY;
    return { Name => $name, Kind => 'unknown', Date => undef, Hash => undef, Slug => undef };
}

sub canonical_slug {
    my ($feature) = @_;
    return $feature->{Slug} if $feature->{Kind} eq 'modern';
    my $slug = eval { slug($feature->{Slug}) };
    return defined $slug ? $slug : $feature->{Slug};
}

# Shortest hash prefix for $slug that no different slug already holds ($taken: slug → hash).
sub resolve_free_hash {
    my ($slug, $taken, $start) = @_;
    $taken ||= {};
    for (my $length = $start || 7; $length <= 40; $length += 2) {
        my $candidate = slug_hash($slug, $length);
        my $clash = grep { $_ ne $slug && defined $taken->{$_} && $taken->{$_} ne '' && index($taken->{$_}, $candidate) == 0 } keys %$taken;
        return $candidate unless $clash;
    }
    die "Could not find a free hash prefix for slug '$slug'. Inspect specs/ by hand.\n";
}

# Pretty JSON like PowerShell 7 ConvertTo-Json (2-space indent, "key": value), keys in the order given:
# objects are array refs of [key, value] pairs, lists are { list => [...] }, numbers are { number => N }.
sub json_encode {
    my ($value, $indent) = @_;
    $indent //= 0;
    my $pad = '  ' x ($indent + 1);
    my $end = '  ' x $indent;
    if (!defined $value) { return 'null' }
    if (ref $value eq 'JSON::PP::Boolean') { return $value ? 'true' : 'false' }
    if (ref $value eq 'HASH' && exists $value->{number}) { return 0 + $value->{number} }
    if (ref $value eq 'HASH' && exists $value->{list}) {
        my @items = @{ $value->{list} };
        return '[]' unless @items;
        return "[\n" . join(",\n", map { $pad . json_encode($_, $indent + 1) } @items) . "\n$end]";
    }
    if (ref $value eq 'ARRAY') {
        return '{}' unless @$value;
        return "{\n" . join(",\n", map { $pad . _str($_->[0]) . ': ' . json_encode($_->[1], $indent + 1) } @$value) . "\n$end}";
    }
    return _str($value);
}

sub _str {
    my ($s) = @_;
    $s =~ s/(["\\])/\\$1/g;
    $s =~ s/\n/\\n/g; $s =~ s/\r/\\r/g; $s =~ s/\t/\\t/g;
    $s =~ s/([\x00-\x1f])/sprintf('\\u%04x', ord $1)/ge;
    return "\"$s\"";
}

1;
