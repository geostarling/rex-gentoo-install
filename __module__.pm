package Rex::Gentoo::Install;

use Rex -base;
use Term::ANSIColor;

desc 'Install base Gentoo host system';



task 'bootstrap_env', sub {

    account "install",
    ensure         => "present",
    password       => 'welcome1';

};

sub setup_disk_layout {

    print colored(['bold green'], 'Do you want to perform disk repartitioning? [No]\n');
    my $choice;
    while (<>) {
        print colored(['bold yellow'], '[Yy]es/[Nn]o\n');
        switch ($_) {
            case /[Yy]es/ {
                Rex::Disk::Layout::setup();
            }
            case /[Nn]o/ {
                print ('Skipping...');
            }
            else {
                print "Sorry, response '$_' not understood. \n"
                    print colored(['bold yellow'], '[Yy]es/[Nn]o\n');
            }
        }
    }
}

task 'setup', sub {

    setup_disk_layout();




};

1;

=pod

=head1 NAME

$::module_name - {{ SHORT DESCRIPTION }}

=head1 DESCRIPTION

{{ LONG DESCRIPTION }}

=head1 USAGE

{{ USAGE DESCRIPTION }}

 include qw/Rex::Gentoo::Install/;

 task yourtask => sub {
    Rex::Gentoo::Install::example();
 };

=head1 TASKS

=over 4

=item example

This is an example Task. This task just output's the uptime of the system.

=back

=cut
