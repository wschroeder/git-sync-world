#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

isnt($^O, 'MSWin32', 'There is no present plan to support Windows directly.  This project requires cygwin or a *nix variant.');
done_testing;

