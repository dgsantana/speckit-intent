#!/usr/bin/env bash
# Allocates or audits a Spec Kit feature directory ID <yyyyMMdd>-<hash>-<slug>.
# Bash port of ../powershell/new-feature-id.ps1 (same IDs, same JSON, same exit codes).
#
#   new-feature-id.sh --name "Short name" [--date yyyyMMdd] [--hash-length 7..40] [--text]
#   new-feature-id.sh --verify [--text]
#
# The hash is derived from the slug here (FeatureIdLib.pm), never written by hand or by a model. Re-running
# with the same name returns the same ID; an existing directory is reported rather than duplicated.
exec perl -x -I"$(dirname "$0")" "$0" "$@"
#!perl
use strict;
use warnings;
use utf8;
use Encode qw(decode);
use POSIX qw(strftime);
use JSON::PP ();
use FeatureIdLib qw(find_project_root spec_directories slug slug_hash feature_id_info canonical_slug resolve_free_hash json_encode);

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
@ARGV = map { decode('UTF-8', $_) } @ARGV;

my ($name, $date, $verify, $json) = (undef, undef, 0, 1);
my $hash_length = 7;
while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg eq '--name' || $arg eq '-Name') { $name = shift @ARGV }
    elsif ($arg eq '--date' || $arg eq '-Date') { $date = shift @ARGV }
    elsif ($arg eq '--hash-length' || $arg eq '-HashLength') { $hash_length = shift @ARGV }
    elsif ($arg eq '--verify' || $arg eq '-Verify') { $verify = 1 }
    elsif ($arg eq '--json') { $json = 1 }
    elsif ($arg eq '--text') { $json = 0 }
    elsif (!defined $name && $arg !~ /^-/) { $name = $arg }
    else { print STDERR "ERROR: unknown argument: $arg\n"; exit 1 }
}
if (!$verify && (!defined $name || $name eq '')) { print STDERR "ERROR: --name is required (or --verify).\n"; exit 1 }
if (defined $date && $date !~ /^\d{8}$/) { print STDERR "ERROR: --date must be yyyyMMdd.\n"; exit 1 }
if ($hash_length !~ /^\d+$/ || $hash_length < 7 || $hash_length > 40) { print STDERR "ERROR: --hash-length must be 7..40.\n"; exit 1 }

my $root = find_project_root();
if (!defined $root) { print STDERR "ERROR: not inside a Spec Kit project (no .specify directory found).\n"; exit 1 }
my $specs = "$root/specs";

sub existing { return map { feature_id_info($_) } spec_directories($specs) }

if ($verify) {
    my @features = existing();
    my %count;
    $count{ canonical_slug($_) }++ for grep { $_->{Kind} ne 'unknown' } @features;
    my $duplicate = 'DUPLICATE: another directory holds this slug';
    my (@failures, @report);
    for my $f (@features) {
        my $status;
        if ($f->{Kind} eq 'legacy') { $status = $count{ canonical_slug($f) } > 1 ? $duplicate : 'legacy' }
        elsif ($f->{Kind} eq 'modern') {
            my $expected = slug_hash($f->{Slug}, length $f->{Hash});
            $status = $expected ne $f->{Hash} ? "MISMATCH: expected $expected" : $count{ $f->{Slug} } > 1 ? $duplicate : 'ok';
        }
        else { $status = 'UNRECOGNISED: neither <yyyyMMdd>-<hash>-<slug> nor legacy NNN-<slug> or <yyyyMMdd>-<HHmmss>-<slug>' }
        push @failures, $f->{Name} unless $status eq 'ok' || $status eq 'legacy';
        push @report, [[FEATURE_DIRECTORY => "specs/$f->{Name}"], [KIND => $f->{Kind}], [STATUS => $status]];
    }
    if ($json) {
        print json_encode([[OK => @failures ? JSON::PP::false : JSON::PP::true], [FAILURES => { list => \@failures }], [FEATURES => { list => \@report }]]), "\n";
    } else {
        printf "%-60s %-8s %s\n", 'FEATURE_DIRECTORY', 'KIND', 'STATUS';
        printf "%-60s %-8s %s\n", map { $_->[1] } @$_ for @report;
    }
    exit(@failures ? 1 : 0);
}

my $slug = eval { slug($name) };
if (!defined $slug) { print STDERR "ERROR: $@"; exit 1 }
$date //= strftime('%Y%m%d', localtime);
my @existing = existing();

my ($same) = grep { $_->{Kind} ne 'unknown' && canonical_slug($_) eq $slug } @existing;
my $result;
if ($same) {
    $result = [[FEATURE_ID => $same->{Name}], [SLUG => $same->{Slug}], [HASH => $same->{Hash}], [DATE => $same->{Date}],
               [FEATURE_DIRECTORY => "specs/$same->{Name}"], [EXISTING => JSON::PP::true]];
} else {
    my %taken = map { $_->{Slug} => $_->{Hash} } grep { $_->{Kind} eq 'modern' } @existing;
    my $hash = eval { resolve_free_hash($slug, \%taken, $hash_length) };
    if (!defined $hash) { print STDERR "ERROR: $@"; exit 1 }
    my $id = "$date-$hash-$slug";
    $result = [[FEATURE_ID => $id], [SLUG => $slug], [HASH => $hash], [DATE => $date], [FEATURE_DIRECTORY => "specs/$id"], [EXISTING => JSON::PP::false]];
}
if ($json) { print json_encode($result), "\n" }
else { print "$_->[0]=" . (ref $_->[1] ? ($_->[1] ? 'True' : 'False') : $_->[1] // '') . "\n" for @$result }
