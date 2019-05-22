package Systemd::Util;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Exporter qw(import);
our @EXPORT_OK = qw(systemd_is_running);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Some utility routines related to Systemd',
};

$SPEC{'systemd_is_running'} = {
    v => 1.1,
    summary => 'Check if systemd is running',
    description => <<'_',

Will return payload of 1 if systemd is running, 0 if not running, `undef` if
cannot determine for sure. The result metadata `func.note` will give more
details. The following heuristics are currently used:

1. Check if /sbin/init exists, if it does not the return 0.

2. Check if /sbin/init is a symlink to something with /systemd/ in its name. If
yes, then we return 1. We use <pm:Cwd>'s `realpath()` instead of `readlink()`
here, to handle multiple redirection.

3. Check if /lib/systemd/systemd exists. Return 0 otherwise.

4. Check if /sbin/init is a hardlink to /lib/systemd/systemd by comparing its
inode. Return 1 if it is.

3. Return undef otherwise, since we detect that /lib/systemd/systemd exists
(systemd is installed) but we cannot be sure if it is running or not.

When used as a CLI, this routine will exit 0 if systemd is running, 1 if systemd
is not running, or 99 if cannot determine for sure. To see the more detailed
note, you can run the CLI with `--json` to return the whole enveloped response.

_
};
sub systemd_is_running {
    my %args = @_;

    my $res = [200, "OK", undef, {}];

    {
        my @lst = lstat "/sbin/init";
        unless (@lst) {
            $res->[2] = 0;
            $res->[3]{'func.note'} = 'Cannot stat /sbin/init (does not exist?)';
            last;
        }

        my $realpath;
        if (-l _) {
            require Cwd;
            $realpath = Cwd::realpath("/sbin/init");
            if (!defined $realpath) {
                $res->[2] = undef;
                $res->[3]{'func.note'} = "Cannot check the real path of ".
                    "/sbin/init (permission problem?)";
                last;
            } elsif ($realpath =~ /systemd/) {
                $res->[2] = 1;
                $res->[3]{'func.note'} = "/sbin/init is a symlink to ".
                    "$realpath (contains 'systemd')";
                last;
            }
        } else {
            $realpath = "/sbin/init";
        }

        my @sts = stat "/lib/systemd/systemd";
        unless (@sts) {
            $res->[2] = 0;
            $res->[3]{'func.note'} = "Cannot stat/find /lib/systemd/systemd, ".
                "assuming there is no systemd installed";
            last;
        }

        my @st = stat $realpath;
        unless (@st) {
            $res->[2] = undef;
            $res->[3]{'func.note'} = "Cannot stat $realpath ".
                "(permission problem?)";
            last;
        }

        if ($st[1] == $sts[1]) {
            $res->[2] = 1;
            $res->[3]{'func.note'} = "/sbin/init is a hardlink to ".
                "/lib/systemd/systemd";
            last;
        }

        $res->[2] = undef;
        $res->[3]{'func.note'} = "/lib/systemd/systemd is installed, ".
            "but we don't see /sbin/init linked to systemd";
    }

    $res->[3]{'cmdline.result'} = '';
    $res->[3]{'cmdline.exit_code'} = !defined($res->[2]) ? 99 :
        $res->[2] ? 0 : 1;

    $res;
}

1;
# ABSTRACT:

=cut
