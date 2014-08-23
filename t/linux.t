#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use IPC::Open3 qw(open3);
use IO::File;
use Test::More ($^O eq 'MSWin32' ? (skip_all => 'This test will not run in Windows') : ());
use Cwd qw(chdir);

# ----------------------------------------------------------------------------
# We are going to play with our current directory, so... Let's just safely
# restore it in the end.
# ----------------------------------------------------------------------------
BEGIN {
    our $__original_path = $ENV{PWD};
    our $world_dir       = tempdir(CLEANUP => 0, UNLINK => 0);
    our $git_dir         = tempdir(CLEANUP => 0, UNLINK => 0);
};
END {
    our ($__original_path, $world_dir, $git_dir);
    chdir($__original_path);

    # File::Temp isn't perfect, so we are handling cleanup ourselves.
    for my $tmpdir ($world_dir, $git_dir) {
        if ($tmpdir && -d $tmpdir) {
            rmtree($tmpdir);
        }
    }
};


# ----------------------------------------------------------------------------
# Prepare some state and constants
# ----------------------------------------------------------------------------
local $ENV{PATH} = "$Bin/../bin:$ENV{PATH}";
my $exe = 'git-sync-world';

our ($world_dir, $git_dir);
chdir($git_dir);

sub make_file {
    my $file_name = shift;
    my $fh;
    open($fh, '>', $file_name) || die "Could not write to $file_name: $!";
    $fh->print('test') || die "Could not print to $file_name";
    $fh->close();
}

sub quiet_system {
    my ($stdin, $stdout, $stderr);
    waitpid open3($stdin, $stdout, $stderr, @_), 0;
    return $?;
}

sub run_sync {
    quiet_system("$exe " . join(' ', @_));
}


# ----------------------------------------------------------------------------
# TESTS
# ----------------------------------------------------------------------------
subtest development_basics => sub {
    isnt(run_sync(), 0, 'No git repo');

    quiet_system('git init');
    isnt(run_sync(), 0, "git repo has no commits");

    make_file('useless.txt');
    quiet_system('git add useless.txt');
    quiet_system('git commit -am "useless.txt"');
    isnt(run_sync(), 0, "No expectation of support for $exe");

    quiet_system('mkdir git-sync-world');
    isnt(run_sync(), 0, 'git-sync-world directory exists but lacks get-change-id');

    system("echo 'git-sync-world-test-$$' > git-sync-world/get-change-id");
    isnt(run_sync(), 0, 'get-change-id cannot be executed');

    chmod 0700, 'git-sync-world/get-change-id';
    isnt(run_sync(), 0, 'get-change-id returns an error code');

    system("echo 'echo fake-id' > git-sync-world/get-change-id");
    isnt(run_sync(), 0, 'get-change-id does not return a git ID');

    system("echo 'git rev-parse HEAD' > git-sync-world/get-change-id");
    is(run_sync(), 0, 'Nothing to do.  No problem.');

    # Set ourselves to "first change" mode
    system("echo 'echo' > git-sync-world/get-change-id");
    chmod 0700, 'git-sync-world/get-change-id';
    quiet_system("git add git-sync-world/get-change-id");
    quiet_system('git commit --amend -m "Basics"');

    sub test_required_files {
        my @files = @_;
        for my $file (@files) {
            system("echo 'git-sync-world-test-$$' > git-sync-world/$file");
            chmod 0700, "git-sync-world/$file";
            quiet_system("git add git-sync-world/$file");
        }
        quiet_system('git commit --amend -m "Basics"');
        isnt(run_sync(), 0, "Incomplete system: " . join(', ', @files));
        run_sync('--abort');
        for my $file (@files) {
            quiet_system("git rm git-sync-world/$file");
        }
        quiet_system('git commit --amend -m "Basics"');
    }

    test_required_files(qw( commit ));
    test_required_files(qw( verify-commit ));
    test_required_files(qw( rollback ));
    test_required_files(qw( verify-rollback ));
    test_required_files(qw( commit verify-commit ));
    test_required_files(qw( commit rollback ));
    test_required_files(qw( commit verify-rollback ));
    test_required_files(qw( verify-commit rollback ));
    test_required_files(qw( verify-rollback rollback ));
    test_required_files(qw( set-change-id commit ));
    test_required_files(qw( set-change-id verify-commit ));
    test_required_files(qw( set-change-id verify-rollback ));
    test_required_files(qw( set-change-id rollback ));
    test_required_files(qw( set-change-id commit verify-commit ));
    test_required_files(qw( set-change-id commit verify-rollback ));
    test_required_files(qw( set-change-id commit rollback ));
    test_required_files(qw( set-change-id verify-commit rollback ));
    test_required_files(qw( set-change-id verify-rollback rollback ));

    for my $file (qw( commit verify-commit verify-rollback set-change-id )) {
        system("echo 'git-sync-world-test-$$' > git-sync-world/$file");
        quiet_system("git add git-sync-world/$file");
    }
    system("echo 'echo \"rollback $$\"' > git-sync-world/rollback");
    quiet_system("git add git-sync-world/rollback");
    quiet_system('git commit --amend -m "Basics"');

    isnt(run_sync(), 0, "commit is not executable");
    run_sync('--abort');

    chmod 0700, "git-sync-world/commit";
    quiet_system('git commit --amend -am "Basics"');
    isnt(run_sync(), 0, "set-change-id is not executable");
    run_sync('--abort');

    chmod 0700, "git-sync-world/set-change-id";
    quiet_system('git commit --amend -am "Basics"');
    isnt(run_sync(), 0, "verify-commit is not executable");
    run_sync('--abort');

    chmod 0700, "git-sync-world/verify-commit";
    quiet_system('git commit --amend -am "Basics"');
    isnt(run_sync(), 0, "rollback is not executable");
    run_sync('--abort');

    chmod 0700, 'git-sync-world/rollback';
    isnt(run_sync(), 0, "verify-rollback is not executable");
    run_sync('--abort');

    chmod 0700, 'git-sync-world/verify-rollback';
    quiet_system('git commit --amend -am "Basics"');
    isnt(run_sync(), 0, "commit returned an error code");
    run_sync('--abort');

    system("echo 'echo \"commit $$\"' > git-sync-world/commit");
    quiet_system('git commit --amend -am "Basics"');
    isnt(run_sync(), 0, "set-change-id returned an error code");
    run_sync('--abort');

    system("echo 'echo \"set-change-id $$\"' > git-sync-world/set-change-id");
    quiet_system('git commit --amend -am "Basics"');
    isnt(run_sync(), 0, "verify-commit returned an error code");
    run_sync('--abort');

    system("echo 'echo \"verify-commit $$\"' > git-sync-world/verify-commit");
    quiet_system('git commit --amend -am "Basics"');
    is(run_sync(), 0, 'Commit process was a virtual success');
};

subtest 'first_change_is_committed' => sub {
    is(quiet_system('git-sync-world/rollback'), 0, 'Rollback current changes');
    is(run_sync(), 0, 'Freshly virtually committed');
};

subtest 'first_real_change' => sub {
    # First make sure verify fails on its own
    system("echo 'ls $world_dir/foo.txt > /dev/null' > git-sync-world/verify-commit");
    system("echo 'rm -f $world_dir/foo.txt' > git-sync-world/rollback");
    isnt(run_sync(), 0, 'Reject dirty repo');

    is(quiet_system('git commit -am "Incomplete commit, needs commit"'), 0, 'Incomplete commit, needs commit');
    isnt(run_sync(), 0, 'We have new changes, but verify-commit fails.');
    run_sync('--abort');

    # Now make a change
    system("echo \"echo test > $world_dir/foo.txt\" > git-sync-world/commit");
    is(quiet_system('git commit --amend -am "First upgrade"'), 0, 'git commit for first upgrade worked');
    system("echo 'echo \$1 > $world_dir/version' > git-sync-world/set-change-id");
    system("echo 'echo' > git-sync-world/get-change-id");
    is(quiet_system('git add .'), 0, 'Added ID changes');
    is(quiet_system('git commit --amend -m "First upgrade"'), 0, 'Amended the commit');
    is(run_sync(), 0, 'Upgrade happened?');
    ok(-e "$world_dir/foo.txt", 'Upgrade happened!');
};

sub make_change_no_commit {
    my $name = shift;
    system("echo \"echo test > $world_dir/$name.txt\" > git-sync-world/commit");
    system("echo 'ls $world_dir/$name.txt 2>&1 > /dev/null' > git-sync-world/verify-commit");
    system("echo 'rm -f $world_dir/$name.txt' 2>&1 > git-sync-world/rollback");
    system("echo '! ls $world_dir/$name.txt 2>&1 > /dev/null' > git-sync-world/verify-rollback");
}

sub make_change {
    my $name = shift;
    make_change_no_commit($name);
    is(quiet_system("git commit -am '$name'"), 0, "Added change: $name");
}

subtest 'three_linear_changes' => sub {
    # Now we don't need to fake an older ID.  We are live!  So let's make a
    # few changes.  And we shouldn't forget that we are beyond our first
    # version.
    system("echo 'cat $world_dir/version' > git-sync-world/get-change-id");
    for my $change (qw(bar baz quux)) {
        make_change($change);
        is(run_sync(), 0, "Upgrade to $change happened?");
        ok(-e "$world_dir/$change.txt", "Upgrade to $change happened!");
    }
};

subtest 'branch_behind_two_linear_changes' => sub {
    # Now we go back two commits, make a new branch, add one change, and
    # validate baz and quux are missing while alt.txt, foo.txt, and bar.txt
    # exist
    is(quiet_system('git checkout HEAD^^'), 0, 'Move back two revisions');
    is(quiet_system('git checkout -b new_direction'), 0, 'Create a new branch');
    make_change('alt');
    is(run_sync(), 0, "Upgrade to alt happened?");
    ok(-e "$world_dir/foo.txt", 'new_direction has foo.txt');
    ok(-e "$world_dir/bar.txt", 'new_direction has bar.txt');
    ok(! -e "$world_dir/baz.txt", 'new_direction does not have baz.txt');
    ok(! -e "$world_dir/quux.txt", 'new_direction does not have quux.txt');
    ok(-e "$world_dir/alt.txt", 'new_direction has alt.txt');
};

subtest 'return_to_master' => sub {
    is(quiet_system('git checkout master'), 0, 'git checkout master');
    is(run_sync(), 0, "Upgrade to master happened?");
    ok(-e "$world_dir/foo.txt", 'master has foo.txt');
    ok(-e "$world_dir/bar.txt", 'master has bar.txt');
    ok(-e "$world_dir/baz.txt", 'master has baz.txt');
    ok(-e "$world_dir/quux.txt", 'master has quux.txt');
    ok(! -e "$world_dir/alt.txt", 'master does not have alt.txt');
};

subtest 'go_backwards_one_revision' => sub {
    is(quiet_system('git checkout master^'), 0, 'Move one revision behind master');
    is(run_sync(), 0, "Upgrade to master^ happened?");
    ok(-e "$world_dir/foo.txt", 'master^ has foo.txt');
    ok(-e "$world_dir/bar.txt", 'master^ has bar.txt');
    ok(-e "$world_dir/baz.txt", 'master^ has baz.txt');
    ok(! -e "$world_dir/quux.txt", 'master^ does not have quux.txt');
    ok(! -e "$world_dir/alt.txt", 'master^ does not have alt.txt');
};

subtest 'last_stop_at_master' => sub {
    is(quiet_system('git checkout master'), 0, 'git checkout master');
    is(run_sync(), 0, "Upgrade to last master happened?");
    ok(-e "$world_dir/foo.txt", 'last master has foo.txt');
    ok(-e "$world_dir/bar.txt", 'last master has bar.txt');
    ok(-e "$world_dir/baz.txt", 'last master has baz.txt');
    ok(-e "$world_dir/quux.txt", 'last master has quux.txt');
    ok(! -e "$world_dir/alt.txt", 'last master does not have alt.txt');
};

subtest 'test_continue' => sub {
    system("echo ls fake-dir > git-sync-world/commit");
    is(quiet_system("git commit -am bad-commit"), 0, "Added change: fake-dir");
    isnt(run_sync(), 0, "Bad commit");
    is(quiet_system("git checkout master"), 0, 'Connected HEAD to master');
    make_change_no_commit('dragon');
    is(quiet_system("git commit --amend -am 'dragon'"), 0, "Added change: dragon");
    is(system("git rev-parse HEAD > .git/git-sync-world/commit"), 0, 'Updated the commit log');
    is(quiet_system('git checkout $(git rev-parse HEAD)'), 0, 'Detach HEAD');
    is(run_sync('--continue'), 0, 'Continued');
    ok(-e "$world_dir/foo.txt", 'last master has foo.txt');
    ok(-e "$world_dir/bar.txt", 'last master has bar.txt');
    ok(-e "$world_dir/baz.txt", 'last master has baz.txt');
    ok(-e "$world_dir/quux.txt", 'last master has quux.txt');
    ok(! -e "$world_dir/alt.txt", 'last master does not have alt.txt');
    ok(-e "$world_dir/dragon.txt", 'last master has dragon.txt');
    ok(! -e "$world_dir/unicorn.txt", 'last master does not have unicorn.txt');
};

subtest 'test_skip' => sub {
    system("echo ls fake-dir > git-sync-world/commit");
    is(quiet_system("git commit -am bad-commit"), 0, "Added change: fake-dir");
    make_change('unicorn');

    isnt(run_sync(), 0, "Found bad commit");
    is(run_sync('--skip'), 0, 'Skipped');
    ok(-e "$world_dir/foo.txt", 'last master has foo.txt');
    ok(-e "$world_dir/bar.txt", 'last master has bar.txt');
    ok(-e "$world_dir/baz.txt", 'last master has baz.txt');
    ok(-e "$world_dir/quux.txt", 'last master has quux.txt');
    ok(! -e "$world_dir/alt.txt", 'last master does not have alt.txt');
    ok(-e "$world_dir/dragon.txt", 'last master has dragon.txt');
    ok(-e "$world_dir/unicorn.txt", 'last master has unicorn.txt');

    is(quiet_system('git checkout master^^^^'), 0, 'Move several revisions behind master');
    is(run_sync(), 0, "Upgrade to master^^^^ happened?");
    ok(-e "$world_dir/foo.txt", 'master^^^^ has foo.txt');
    ok(-e "$world_dir/bar.txt", 'master^^^^ has bar.txt');
    ok(-e "$world_dir/baz.txt", 'master^^^^ has baz.txt');
    ok(! -e "$world_dir/quux.txt", 'master^^^^ does not have quux.txt');
    ok(! -e "$world_dir/alt.txt", 'master^^^^ does not have alt.txt');
};

done_testing;

