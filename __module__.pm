package Rex::Gentoo::Install;

use Rex -base;
use Rex::Template::TT;

use Term::ANSIColor;

desc 'Install base Gentoo host system';

include qw/
Rex::Disk::Layout
/;

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

task 'install', sub {
  optional \&Rex::Disk::Layout::setup_partitions, "Do you want to setup partitions?" ;
  optional \&Rex::Disk::Layout::setup_filesystems, "Do you want to setup filesystems?" ;

  Rex::Disk::Layout::mount_filesystems { mount_root => '/mnt/gentoo' };
  Rex::Disk::Layout::swapon();

  install_stage_tarball();
};

task 'install_stage_tarball', sub {
  my $stage_tarball_url = param_lookup "stage_tarball_url", ();
  my $stage_tarball = param_lookup "stage_tarball", ();
  run "Download stage tarball",
    command => "wget -O /mnt/gentoo/$stage_tarball $stage_tarball_url",
    creates => "/mnt/gentoo/$stage_tarball";
  # TODO verify hash and signature
  extract "/mnt/gentoo/$stage_tarball", to => "/mnt/gentoo";
    file "/mnt/gentoo/$stage_tarball", ensure => "absent";
};

task 'install_base_system', sub {

  my $root_ssh_key = param_lookup "root_ssh_key";

  # for installation we use resolv.conf from installation medium
  cp("/etc/resolv.conf", "/mnt/gentoo/etc/");

  # mount proc and sys filesystems, rebind /dev
  run "mount -t proc /proc /mnt/gentoo/proc";
  run "mount --rbind /sys /mnt/gentoo/sys";
  run "mount --make-rslave /mnt/gentoo/sys";
  run "mount --rbind /dev /mnt/gentoo/dev";
  run "mount --make-rslave /mnt/gentoo/dev";

  chroot "/mnt/gentoo", sub {
    $DB::single = 1;
    # setup make.conf
    setup_portage();

    _eselect("profile", "portage_profile", "default/linux/amd64/13.0");

    # sync portage tree
    update_package_db;

    # update all installed packages (@world) to their latest versions
    update_system;

    setup_timezone();

    setup_locales();

    setup_kernel();

    Rex::Disk::Layout::install_fstab "automount" => false;

    Rex::Gentoo::Networking::setup();

    install_core_services();

    Rex::Bootloader::Syslinux::install();

    setup_ssh_keys user => 'root';

  };
  run "umount -l /mnt/gentoo/dev{/shm,/pts,}";
  run "umount -R /mnt/gentoo";
  optional { run "reboot"; }, "Installation completed successfuly. Reboot now?";

};

task 'setup_ssh_keys', sub {
  my $params = shift;
  my $users = param_lookup 'users', [];
  if ( exists $params->{user} ) {
    $users = \grep { $_->{name} == $params->{user} } @$users;
  }
  foreach $user (@$users) {
    my $keys = $user->{ssh_keys};
    foreach $key (@{$user->{ssh_keys}}) {
      my $comment = $key->{comment};
      append_or_amend_line "~/.ssh/authorized_keys",
        line  => $key->{key} . " " . $comment,
        regexp => qr{^ssh-rsa [^ ]+ $comment$};
    }
  }
};

task 'install_core_services', sub {
  my $pkgs = param_lookup 'core_packages', [];
  my $svcs = param_lookup 'core_services', [];
  foreach $pkg (@$pkgs) {
    pkg $pkg, ensure  => "present";
  }
  foreach $svc (@$svcs) {
    service $svc, ensure => "started";
  }
};

task 'setup_portage', sub {
  file "/etc/portage/make.conf",
    content => template("templates/make.conf.tt");
};

task 'setup_timezone', sub {
  file '/etc/timezone',
    content => param_lookup('timezone', 'Etc/UTC'),
    on_change => sub { run 'emerge --config sys-libs/timezone-data'; };
};

task 'setup_locales', sub {
  file '/etc/locale.gen',
    content => join("\n", @{param_lookup('locales', ['en_US.UTF-8 UTF-8'])}),
    on_change => sub { run 'locale-gen'; };

  _eselect("locale", "system_locale", "en_US.utf8");
};

task 'setup_kernel', sub {
  $DB::single = 1;
  optional \&Rex::Gentoo::Kernel::setup_kernel, "Do you want to (re)compile the kernel?" ;
};


task 'setup_users', sub {
  my $users = param_lookup 'users', [];
  foreach $user (@$users) {
    if ($user->{name} != 'root') {
      account $user->{name},
        ensure         => "present",
        comment        => 'User Account',
        groups         => $user->{groups},
        password       => $user->{password},
        crypt_password => $user->{crypt_password};
    }
    setup_ssh_keys user => $user->{name};
  }
};

sub _eselect {
  my ( $module, $param_name, $default_target ) = @_;
  my $desired_target = param_lookup $param_name, $default_target;
  my @available_targets = run "eselect --brief $module list";
  my $targets_count = scalar @available_targets;
  my ( $target_index ) = grep { @available_targets[$_] eq $desired_target } 0..$targets_count;

  # NOTE: targets are numbered from 1
  run "eselect $module set " . ($target_index + 1);
}


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
