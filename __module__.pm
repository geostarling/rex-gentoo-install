package Rex::Gentoo::Install;

use Rex -base;
use Term::ANSIColor;

desc 'Install base Gentoo host system';

include qw/
Rex::Disk::Layout
/;

task 'bootstrap_env', sub {

    account "install",
    ensure         => "present",
    password       => 'welcome1';

};

sub optional {
  my ( $command, $question ) = @_;

  print colored(['bold blue'], "$question [No]\n");
  print colored(['bold yellow'], "[Yy]es/[Nn]o: ");
  while  ( <STDIN> ) {
    if ( /[Yy]es/ ) {
      $command->();
      last;
    } elsif ( /[Nn]o/ ) {
      say "Skipping...";
      last;
    } else {
      print "Sorry, response '" . $_ =~ s/\s+$//r . "' was not understood. \n";
      print colored(['bold yellow'], '[Yy]es/[Nn]o: ');
    }
  }
}

task 'setup', sub {
  optional \&Rex::Disk::Layout::setup_partitions, "Do you want to setup partitions?" ;
  optional \&Rex::Disk::Layout::setup_filesystems, "Do you want to setup filesystems?" ;

  Rex::Disk::Layout::mount_filesystems { mount_root => '/mnt/gentoo' };
  Rex::Disk::Layout::swapon();

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
