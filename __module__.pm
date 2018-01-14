package Rex::Gentoo::Install;

use Rex -base;
use Rex::Template::TT;
use Rex::Gentoo::Utils;

desc 'Install base Gentoo host system';

include qw/
Rex::Disk::Layout
Rex::Gentoo::Host
Rex::Gentoo::Kernel
Rex::Gentoo::Networking
Rex::Bootloader::Syslinux
/;

task 'install_from_livecd', sub {
  $DB::single = 1;
  Rex::Gentoo::Utils::optional(\&Rex::Disk::Layout::setup_partitions, "Do you want to setup partitions?");
  Rex::Gentoo::Utils::optional(\&Rex::Disk::Layout::setup_filesystems, "Do you want to setup filesystems?");

  Rex::Disk::Layout::mount_filesystems { mount_root => '/mnt/gentoo' };
  Rex::Disk::Layout::swapon();

  install_stage_tarball();
  install_base_system();
};

task 'install_stage_tarball', sub {
  my $stage_tarball_url = param_lookup "stage_tarball_url", ();
  my $stage_tarball = param_lookup "stage_tarball", ();

  run "Download stage tarball",
    command => "wget -O /mnt/gentoo/$stage_tarball $stage_tarball_url",
  creates => "/mnt/gentoo/$stage_tarball";

  # TODO verify PGP signature
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
    Rex::Gentoo::Host::setup_portage();

    # sync portage tree and profile list
    update_package_db;

    # setup the gentoo profile
    Rex::Gentoo::Host::setup_profile();

    # update all installed packages (@world) to their latest versions
    Rex::Gentoo::Utils::optional sub { update_system }, 'Do you want to update @world packages?';

    Rex::Gentoo::Host::setup_timezone();
    Rex::Gentoo::Host::setup_locales();
    Rex::Gentoo::Host::setup_kernel();

    Rex::Disk::Layout::setup_fstab("automount" => FALSE);

    Rex::Gentoo::Host::setup_hostname();
    Rex::Gentoo::Host::setup_hosts();

    Rex::Gentoo::Networking::setup();

    install_core_services();

    Rex::Gentoo::Utils::optional(\&Rex::Bootloader::Syslinux::install_bootloader, "Do you want to install bootloader?");
    Rex::Bootloader::Syslinux::setup();

    Rex::Gentoo::Host::setup_ssh_keys(user => 'root');

  };
  run "umount -l /mnt/gentoo/dev{/shm,/pts,}";
  run "umount -R /mnt/gentoo";
  Rex::Gentoo::Utils::optional(sub { run "reboot"; }, "Installation completed successfuly. Reboot now?");

};

task 'install_core_services', sub {
  my $pkgs = param_lookup 'core_packages', [];
  my $svcs = param_lookup 'core_services', [];
  foreach my $pkg (keys %$pkgs) {
    pkg $pkg, ensure  => "present";
  }
  foreach my $svc (keys %$svcs) {
    service $svc, ensure => "started";
  }
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
