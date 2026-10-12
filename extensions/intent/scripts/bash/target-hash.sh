#!/usr/bin/env bash
# Records or checks the hash of a spec's target: its Outcomes and Constraints sections.
# Bash port of ../powershell/target-hash.ps1 (same hash, same JSON, same exit codes).
#
#   target-hash.sh [--spec FILE] --record   write target_hash into the spec's frontmatter
#   target-hash.sh [--spec FILE] --check    exit 1 when the recorded hash differs (0 otherwise)
#
# The hash is SHA-256 over "## outcomes\n" + N(Outcomes) + "\n## constraints\n" + N(Constraints), N being
# the section's lines up to the next level-two heading, HTML comments removed, LF line endings, trailing
# whitespace trimmed, blank lines dropped. Errors: "ERROR: …" on stderr, exit 3. Needs perl (ships with git).
exec perl -x "$0" "$@"
#!perl
use strict;
use warnings;
use utf8;
use Encode qw(decode encode);
use Digest::SHA qw(sha256_hex);
use JSON::PP ();

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

sub fail { print STDERR "ERROR: $_[0]\n"; exit 3 }

sub json_str {
    my ($s) = @_;
    return 'null' unless defined $s;
    $s =~ s/(["\\])/\\$1/g;
    $s =~ s/\n/\\n/g; $s =~ s/\r/\\r/g; $s =~ s/\t/\\t/g;
    $s =~ s/([\x00-\x1f])/sprintf('\\u%04x', ord $1)/ge;
    return "\"$s\"";
}

my ($spec, $mode);
while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg eq '--spec' || $arg eq '-Spec') { $spec = shift @ARGV // fail('--spec needs a file.') }
    elsif ($arg eq '--record' || $arg eq '-Record') { $mode = 'record' }
    elsif ($arg eq '--check' || $arg eq '-Check') { $mode = 'check' }
    else { fail("unknown argument: $arg (use --spec FILE and --record or --check).") }
}
fail('pass --record or --check.') unless $mode;

if (!defined $spec) {
    my $feature = '.specify/feature.json';
    fail('no --spec given and no .specify/feature.json here.') unless -f $feature;
    open my $fh, '<:raw', $feature or fail("cannot read $feature");
    local $/; my $json = JSON::PP->new->utf8->decode(<$fh>);
    $spec = "$json->{feature_directory}/spec.md";
}
fail("spec not found: $spec") unless -f $spec;

open my $in, '<:raw', $spec or fail("cannot read $spec");
my $raw = do { local $/; <$in> };
close $in;
$raw =~ s/\A\xEF\xBB\xBF//;    # .NET ReadAllText drops a byte order mark
my $text = decode('UTF-8', $raw);
(my $lf = $text) =~ s/\r\n/\n/g;

sub section {
    my ($name, $optional) = @_;
    if ($lf =~ /^##[ \t]+\Q$name\E[ \t]*\n(.*?)(?=^##[ \t]|\z)/ims) {
        (my $body = $1) =~ s/<!--.*?-->//gs;
        my @lines = grep { $_ ne '' } map { s/\s+\z//r } split /\n/, $body, -1;
        return join "\n", @lines;
    }
    return '' if $optional;
    fail("the spec has no '## $name' section.");
}

my $canonical = "## outcomes\n" . section('Outcomes') . "\n## constraints\n" . section('Constraints', 1);
my $hash = sha256_hex(encode('UTF-8', $canonical));

$text =~ /\A---\r?\n(.*?\r?\n)---\r?\n/s or fail('the spec has no frontmatter block.');
my ($block, $block_start) = ($1, $-[1]);
my ($stored, $stored_at);
if ($block =~ /^target_hash:[ \t]*([0-9a-f]{64})[ \t]*\r?$/m) { ($stored, $stored_at) = ($1, $-[1]) }

if ($mode eq 'record') {
    my $newline = index($text, "\r\n") >= 0 ? "\r\n" : "\n";
    my $new_block = defined $stored ? substr($block, 0, $stored_at) . $hash . substr($block, $stored_at + 64) : "${block}target_hash: $hash$newline";
    my $updated = substr($text, 0, $block_start) . $new_block . substr($text, $block_start + length $block);
    open my $out, '>:raw', $spec or fail("cannot write $spec");
    print {$out} encode('UTF-8', $updated);
    close $out;
    print '{"HASH":' . json_str($hash) . ',"RECORDED":true,"SPEC":' . json_str($spec) . "}\n";
    exit 0;
}

my $status = !defined $stored ? 'unrecorded' : $stored eq $hash ? 'match' : 'changed';
print '{"STATUS":' . json_str($status) . ',"STORED":' . json_str($stored) . ',"COMPUTED":' . json_str($hash) . ',"SPEC":' . json_str($spec) . "}\n";
exit($status eq 'changed' ? 1 : 0);
