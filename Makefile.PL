use ExtUtils::MakeMaker;
WriteMakefile(
    NAME      => 'git-sync-world',
    VERSION   => '1.00',
    ABSTRACT  => 'Sync the world to this git checkout',
    AUTHOR    => 'William Schroeder <wschroeder@gmail.com>',
    EXE_FILES => ['bin/git-sync-world'],
    MAN3PODS  => {},
    PM        => {},
    PREREQ_PM => {
        'Cwd'          => 0,
        'File::Path'   => 0,
        'File::Temp'   => 0,
        'FindBin'      => 0,
        'Getopt::Long' => 0,
        'IO::File'     => 0,
        'IPC::Open3'   => 0,
        'Pod::Usage'   => 0,
        'Test::More'   => 0,
        'strict'       => 0,
        'warnings'     => 0,
    },
);
