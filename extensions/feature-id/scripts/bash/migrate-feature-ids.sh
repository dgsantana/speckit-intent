#!/usr/bin/env bash
# Renames legacy sequential spec directories (NNN-slug) to <yyyyMMdd>-<hash>-<slug> and rewrites every
# reference to them in tracked text files. Bash port of ../powershell/migrate-feature-ids.ps1; the rules,
# the mapping file and the report are the same, so either script can migrate a branch the other started.
#
#   migrate-feature-ids.sh [--apply] [--json] [--allow-dirty] [--keep PATTERN]... [--foreign REGEX]
#
# Dry run by default. `.specify/feature-id-migration.json` is the authoritative mapping: commit it so every
# branch gets identical names. A legacy name absent from it takes its date from `git log --all`. --keep
# patterns (PowerShell -like wildcards over forward-slash paths) replace the default list
# CHANGELOG*, */CHANGELOG*, */history/*, history/*. See the PowerShell script's help for the full rationale.
exec perl -x -I"$(dirname "$0")" "$0" "$@"
#!perl
use strict;
use warnings;
use utf8;
use Encode qw(decode encode);
use JSON::PP ();
use FeatureIdLib qw(find_project_root spec_directories slug slug_hash feature_id_info resolve_free_hash json_encode);

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
@ARGV = map { decode('UTF-8', $_) } @ARGV;

my ($apply, $json, $allow_dirty, $foreign, @keep) = (0, 0, 0, undef);
while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg =~ /^(--apply|-Apply)$/) { $apply = 1 }
    elsif ($arg =~ /^(--json|-Json)$/) { $json = 1 }
    elsif ($arg =~ /^(--allow-dirty|-AllowDirty)$/) { $allow_dirty = 1 }
    elsif ($arg =~ /^(--foreign|-Foreign)$/) { $foreign = shift @ARGV }
    elsif ($arg =~ /^(--keep|-Keep)$/) { push @keep, split /,/, shift @ARGV }
    else { fail("unknown argument: $arg") }
}
@keep = ('CHANGELOG*', '*/CHANGELOG*', '*/history/*', 'history/*') unless @keep;

sub fail { print STDERR "ERROR: $_[0]\n"; print STDERR "  $_\n" for @_[1 .. $#_]; exit 1 }
sub git {
    open my $pipe, '-|', 'git', @_ or return ();
    my @out = <$pipe>;
    close $pipe;
    chomp @out;
    return map { decode('UTF-8', $_) } @out;
}

my $root = find_project_root() // fail('not inside a Spec Kit project (no .specify directory found).');
chdir $root or fail("cannot enter $root");
fail('no specs/ directory in this tree.') unless -d 'specs';

my $mapping_relative = '.specify/feature-id-migration.json';
my %mapping;
if (-e $mapping_relative) {
    open my $fh, '<:raw', $mapping_relative or fail("cannot read $mapping_relative");
    my $loaded = JSON::PP->new->utf8->decode(do { local $/; <$fh> } =~ s/^\xEF\xBB\xBF//r);
    %mapping = map { $_ => "$loaded->{$_}" } keys %$loaded;
}

# A rename plus a repository-wide rewrite over unrelated uncommitted work would become one diff nobody can review.
my @dirty = grep { !/^\?\? / } git(qw(status --porcelain -- .));
if ($apply && @dirty && !$allow_dirty) {
    fail('working tree has tracked modifications. Commit or stash them first so the migration is its own diff, or pass --allow-dirty:', @dirty);
}
printf STDERR "WARNING: applying over %d tracked modification(s); the migration will not be a separate diff.\n", scalar @dirty if $apply && @dirty;

# Oldest commit on any ref that added the spec's spec.md, else that touched its directory.
sub spec_add_date {
    my ($name) = @_;
    for my $args (["--diff-filter=A", "--", "specs/$name/spec.md"], ["--", "specs/$name"]) {
        my @dates = grep { $_ ne '' } git('log', '--all', '--format=%ad', '--date=format:%Y%m%d', @$args);
        return $dates[-1] if @dates;
    }
    return undef;
}

my @features = map { feature_id_info($_) } spec_directories('specs');
my @unknown = grep { $_->{Kind} eq 'unknown' } @features;
fail('spec directories match neither naming rule; resolve them by hand before migrating:', map { "specs/$_->{Name}" } @unknown) if @unknown;

# Hashes already in use, so a legacy slug that prefix-collides with a dated one widens instead of clashing.
my %taken = map { $_->{Slug} => $_->{Hash} } grep { $_->{Kind} eq 'modern' } @features;
my @plan;
for my $feature (sort { lc $a->{Name} cmp lc $b->{Name} } grep { $_->{Kind} eq 'legacy' } @features) {
    if (exists $mapping{ $feature->{Name} }) {
        my $new = $mapping{ $feature->{Name} };
        my $info = feature_id_info($new);
        fail("mapping entry '$feature->{Name}' -> '$new' is not a valid feature ID.") if $info->{Kind} ne 'modern';
        my $expected = slug_hash($info->{Slug}, length $info->{Hash});
        fail("mapping entry '$new' has a hash that does not match its slug (expected $expected). Refusing to propagate a hand-edited mapping.")
            if $expected ne $info->{Hash};
        $taken{ $info->{Slug} } = $info->{Hash};
        push @plan, { Old => $feature->{Name}, New => $new, Source => 'mapping' };
        next;
    }
    my $slug = eval { slug($feature->{Slug}) } // fail($@ =~ s/\n$//r);
    my $hash = resolve_free_hash($slug, \%taken);
    $taken{$slug} = $hash;
    my $date = $feature->{Date} // spec_add_date($feature->{Name})
        // fail("no allocation date for specs/$feature->{Name} in git history, and no mapping entry. Add one to $mapping_relative rather than letting the clock decide, or the name will differ per machine.");
    push @plan, { Old => $feature->{Name}, New => "$date-$hash-$slug", Source => 'derived' };
}

# Two legacy directories with one slug, or a target slug a dated directory already holds, need a person.
my %by_slug = map { lc $_->{Slug} => ["specs/$_->{Name}"] } grep { $_->{Kind} eq 'modern' } @features;
push @{ $by_slug{ lc feature_id_info($_->{New})->{Slug} } }, "specs/$_->{Old}" for @plan;
my @collisions = grep { @{ $by_slug{$_} } > 1 } sort keys %by_slug;
fail('these directories hold the same feature name; merge or rename them by hand, then run again. Nothing was changed.',
    map { "$_: " . join(', ', @{ $by_slug{$_} }) } @collisions) if @collisions;

if (!@plan) {
    my $message = 'No legacy spec directories found; nothing to migrate.';
    print $json ? json_encode([[OK => JSON::PP::true], [RENAMES => { list => [] }], [FILES => { list => [] }], [MESSAGE => $message]]) . "\n" : "$message\n";
    exit 0;
}

my %binary = map { $_ => 1 } qw(.png .jpg .jpeg .gif .bmp .ico .webp .pdf .zip .gz .br .7z .dll .exe .pdb .so .dylib
    .woff .woff2 .ttf .otf .eot .wasm .sqlite .db .bin .tif .tiff .onnx .snk .glb .b3dm .pnts .las .laz .ply .terrain
    .terraindb .imagerydb .gpkg .uasset .umap);

# PowerShell -like: * any run, ? one character, [set], backtick escapes; whole string, ignoring case.
sub like_regex {
    my ($pattern) = @_;
    my $re = '';
    while ($pattern =~ /\G(?:`(.)|(\*)|(\?)|(\[[^\]]*\])|(.))/gcs) {
        $re .= defined $1 ? quotemeta $1 : defined $2 ? '.*' : defined $3 ? '.' : defined $4 ? $4 : quotemeta $5;
    }
    return qr/^$re$/si;
}
my @keep_res = map { like_regex($_) } @keep;
sub kept { my ($path) = @_; return scalar grep { $path =~ $_ } @keep_res }

# The mapping records the rename; installed preset and extension files belong to the tools.
my @candidates = grep { $_ ne '' && $_ ne $mapping_relative && !m{^\.specify/(extensions|presets)/} }
    map { decode('UTF-8', $_) } split /\0/, do { open my $pipe, '-|', 'git', 'ls-files', '-z' or fail('git ls-files failed'); local $/; <$pipe> // '' };
push @candidates, '.specify/feature.json' unless grep { $_ eq '.specify/feature.json' } @candidates;

# Whole directory-name tokens only: `007-auth` must not match inside `007-auth-tokens`.
my %token = map { $_->{Old} => qr/(?<![A-Za-z0-9_-])\Q$_->{Old}\E(?![A-Za-z0-9_-])/ } @plan;

# Short references `specs/021` mean the one legacy directory numbered 021; shared numbers, prose and lines
# matching --foreign are listed for a person instead.
my %by_number;
for my $item (@plan) { push @{ $by_number{$1} }, $item if $item->{Old} =~ /^(\d{3})-/ }
my %short = map { $_ => { Pattern => qr/(?<![A-Za-z0-9_.\/\\-])(specs[\\\/])($_)(?![A-Za-z0-9_-])/, New => $by_number{$_}[0]{New} } }
    grep { @{ $by_number{$_} } == 1 } keys %by_number;
my $numbers = join '|', sort keys %by_number;
my $leftover = %by_number ? qr/(?<![A-Za-z0-9_-])spec(?:ification)?s?[\\\/ ]+(?:$numbers)(?![0-9A-Za-z_-])/i : undef;
my $foreign_re = defined $foreign && $foreign ne '' ? qr/$foreign/ : undef;
my $window = 24;
my $missing = qr/(?<![A-Za-z0-9_-])specs[\\\/](?<name>\d{3}-[A-Za-z0-9][A-Za-z0-9-]*)/;
my %local_names = map { $_->{Name} => 1 } @features;

sub foreign_before {
    my ($line, $index) = @_;
    return 0 unless $foreign_re && $index >= 0;
    my $start = $index - $window < 0 ? 0 : $index - $window;
    return substr($line, $start, $index - $start) =~ $foreign_re ? 1 : 0;
}

my (@edits, @kept, @not_utf8, @unresolved, @foreign_refs);
for my $relative (@candidates) {
    my ($extension) = $relative =~ m{(\.[^./]*)$};
    next if defined $extension && $binary{ lc $extension };
    next unless -f $relative;

    # Rewrite UTF-8 only, keeping a byte order mark where there was one.
    open my $fh, '<:raw', $relative or next;
    my $bytes = do { local $/; <$fh> } // '';
    close $fh;
    my $bom = $bytes =~ s/^\xEF\xBB\xBF//;
    my $content = eval { decode('UTF-8', $bytes, Encode::FB_CROAK | Encode::LEAVE_SRC) };
    if (!defined $content) {
        push @not_utf8, $relative if grep { index($bytes, $_->{Old}) >= 0 } @plan;
        next;
    }
    my $updated = $content;
    my @hits;
    for my $item (@plan) {
        my $count = () = $updated =~ /$token{ $item->{Old} }/g;
        next unless $count;
        $updated =~ s/$token{ $item->{Old} }/$item->{New}/g;
        push @hits, "$item->{Old} x$count";
    }
    if (%short) {
        my %short_hits;
        my @lines = split /\n/, $updated, -1;
        for my $line (@lines) {
            for my $number (keys %short) {
                my $s = $short{$number};
                # A reference is another repository's only when --foreign matches just before its `specs/`.
                $line =~ s{$s->{Pattern}}{
                    foreign_before($line, $-[1]) ? "$1$2" : do { $short_hits{$number}++; "$1$s->{New}" }
                }ge;
            }
        }
        $updated = join "\n", @lines;
        push @hits, "specs/$_ x$short_hits{$_}" for sort keys %short_hits;
    }

    if (kept($relative)) {
        push @kept, $relative if @hits;
        next;
    }

    # What is left for a person: after --foreign it is FOREIGN, anything else UNRESOLVED.
    my @lines = split /\n/, $updated, -1;
    for my $i (0 .. $#lines) {
        my $line = $lines[$i];
        my @found;
        if ($leftover) { while ($line =~ /$leftover/g) { push @found, $-[0] } }
        while ($line =~ /$missing/g) { push @found, $-[0] unless $local_names{ $+{name} } }
        next unless @found;
        my $entry = [[FILE => $relative], [LINE => { number => $i + 1 }], [TEXT => $line =~ s/^\s+|\s+$//gr]];
        if (grep { !foreign_before($line, $_) } @found) { push @unresolved, $entry } else { push @foreign_refs, $entry }
    }
    next unless @hits;

    push @edits, [[FILE => $relative], [REPLACEMENTS => { list => \@hits }]];
    if ($apply) {
        open my $out, '>:raw', $relative or fail("cannot write $relative");
        print $out ($bom ? "\xEF\xBB\xBF" : ''), encode('UTF-8', $updated);
        close $out;
    }
}

if ($apply) {
    for my $item (@plan) {
        system('git', 'mv', '--', "specs/$item->{Old}", "specs/$item->{New}") == 0 or fail("git mv failed for specs/$item->{Old}");
        $mapping{ $item->{Old} } = $item->{New};
    }
    open my $out, '>:raw', $mapping_relative or fail("cannot write $mapping_relative");
    print $out encode('UTF-8', json_encode([map { [$_ => $mapping{$_}] } sort { lc $a cmp lc $b } keys %mapping]) . "\n");
    close $out;
}

my @renames = map { [[FROM => "specs/$_->{Old}"], [TO => "specs/$_->{New}"], [SOURCE => $_->{Source}]] } @plan;
if ($json) {
    print json_encode([
        [OK => JSON::PP::true], [APPLIED => $apply ? JSON::PP::true : JSON::PP::false], [MAPPING => $mapping_relative],
        [RENAMES => { list => \@renames }], [FILES => { list => \@edits }], [KEPT => { list => \@kept }],
        [NOT_UTF8 => { list => \@not_utf8 }], [UNRESOLVED => { list => \@unresolved }], [FOREIGN => { list => \@foreign_refs }],
    ]), "\n";
    exit 0;
}
print $apply ? "Applied:\n" : "Dry run (use --apply):\n";
print "  specs/$_->{Old}  ->  specs/$_->{New}   [$_->{Source}]\n" for @plan;
printf "\nFiles rewritten: %d\n", scalar @edits;
print "  $_->[0][1]  [" . join('; ', @{ $_->[1][1]{list} }) . "]\n" for @edits;
my $entry_line = sub { "  $_[0][0][1]:$_[0][1][1]  $_[0][2][1]\n" };
if (@kept) { printf "\nFiles left with old names (--keep): %d\n", scalar @kept; print "  $_\n" for @kept }
if (@foreign_refs) {
    printf "\nReferences to another repository's specs (--foreign), left as they are: %d\n", scalar @foreign_refs;
    print $entry_line->($_) for @foreign_refs;
}
if (@unresolved) {
    printf "\nReferences to legacy numbers left as they are; fix by hand: %d\n", scalar @unresolved;
    print $entry_line->($_) for @unresolved;
}
if (@not_utf8) {
    printf "\nFiles not rewritten because they are not UTF-8; update their references by hand: %d\n", scalar @not_utf8;
    print "  $_\n" for @not_utf8;
}
print "\nThen: commit the renames and the mapping together, and run new-feature-id.sh --verify.\n";
