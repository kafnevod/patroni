%define patroni_user    postgres
%define patroni_group   postgres
%define patroni_confdir %_sysconfdir/%name
%define patroni_home %patroni_confdir

Name: patroni
Version: 2.0.1
Release: alt1

Summary: Patroni is a template for you to create your own customized, high-availability solution using Python and - for maximum accessibility - a distributed configuration store like ZooKeeper, etcd, Consul or Kubernetes
License: GPLv2+
Group: System/Servers

URL: https://patroni.readthedocs.io/en/latest/
Source: %name-%version.tar
Source1: config.yml.in
Source2: dcs.yml
Source3: %name.init
Source4: %name.service
Source5: %{name}@.service
# Source6: usr


BuildArch: noarch

# BuildRequires: python-devel

BuildRequires: python3 python3-module-psycopg2 python3-module-yaml 

%description
Patroni is a template for you to create your own customized, high-availability solution using Python and - 
for maximum accessibility - a distributed configuration store like ZooKeeper, etcd, Consul or Kubernetes. 
Database engineers, DBAs, DevOps engineers, and SREs who are looking to quickly deploy HA PostgreSQL in the datacenter-or anywhere else-will hopefully find it useful.

We call Patroni a “template” because it is far from being a one-size-fits-all or plug-and-play replication system. 
It will have its own caveats. Use wisely. There are many ways to run high availability with PostgreSQL; for a list, see the PostgreSQL Documentation.


%prep
%setup -n %name-%version

%build
%python3_build


%install
%python3_install
# install -p -D -m 0644 %name %buildrootpython_sitelibdir/%name

install -p -D -m 0644 %SOURCE1 %buildroot%patroni_confdir/%name.cfg
install -p -D -m 0644 %SOURCE2 %buildroot%patroni_confdir/%name.cfg
install -D -m 0755 %SOURCE3 %buildroot%_initrddir/patroni
install -p -D -m 0644 %SOURCE4 %buildroot%_unitdir/%name.service
install -p -D -m 0644 %SOURCE5 %buildroot%_unitdir/%{name}@.service
install -d -D -m 0755 %SOURCE6 %buildroot%_bindir 

%pre

%post
%post_service patroni

%preun
%preun_service patroni

%files
%doc CHANGELOG LICENSE README ROADMAP doc/architecture.txt doc/configuration.txt doc/intro.txt doc/management.txt doc/proxy-protocol.txt examples/*.cfg
%dir %patroni_confdir
%config(noreplace) %patroni_confdir/config.yml.in
%config(noreplace) %patroni_confdir/dcs.yml
%_initrddir/%name
%_unitdir/%name.service
%_unitdir/%{name}@.service
%_bindir/usr/
%_bindir/*
%_man1dir/*

%changelog
* Fri Feb 12 2021 Alexey Kostarev <kaf@altlinux.org> 2.0.1-alt1
- 2.0.1



