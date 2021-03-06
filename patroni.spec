%define patroni_user    postgres
%define patroni_group   postgres
%define patroni_confdir %_sysconfdir/%name
%define patroni_home %patroni_confdir

Name: patroni
Version: 2.0.1
Release: alt1

Summary: Patroni is a template to create high-availability Postgres Cluster
License: GPLv2+
Group: Databases

URL: https://patroni.readthedocs.io/en/latest/
Source: %name-%version.tar
Source1: config.yml.in
Source2: dcs.yml
Source3: %name.init
Source4: %name.service
Source5: %{name}@.service
Source6: usr_bin_patroni_aws.py
Source7: usr_bin_patronictl.py
Source8: usr_bin_patroni_patroni.py
Source9: usr_bin_patroni_wale_restore.py


BuildArch: noarch

BuildRequires(pre): rpm-build-python3 

BuildRequires: python3-devel python3-module-six python3-module-psycopg2 python3-module-flake8


%description
Patroni is a template for you to create your own customized,
high-availability solution using Python and - for maximum accessibility -
a distributed configuration store like ZooKeeper, etcd, Consul or Kubernetes.
Database engineers, DBAs, DevOps engineers, and SREs who are looking to quickly
deploy HA PostgreSQL in the datacenter-or anywhere else-will hopefully
find it useful.

We call Patroni a 'template' because it is far from being a one-size-fits-all or
plug-and-play replication system.
It will have its own caveats. Use wisely. There are many ways to run
high availability with PostgreSQL; for a list, see the PostgreSQL Documentation.

%package tools
Summary: A collection of tools included with Python 3
Group: Databases
# No real need in python-base in this package
%filter_from_requires /^python-base/d

%description tools
This package contains several tools included with Python 3

%prep
%setup -n %name-%version


%build
%python3_build


%install
%python3_install 
install -p -D -m 0644 %SOURCE1 %buildroot%patroni_confdir/%name.cfg
install -p -D -m 0644 %SOURCE2 %buildroot%patroni_confdir/%name.cfg
install -D -m 0755 %SOURCE3 %buildroot%_initrddir/patroni
install -p -D -m 0644 %SOURCE4 %buildroot%_unitdir/%name.service
install -p -D -m 0644 %SOURCE5 %buildroot%_unitdir/%{name}@.service
install -p -D -m 0755 %SOURCE6 %buildroot%_bindir/aws
install -p -D -m 0755 %SOURCE7 %buildroot%_bindir/patronictl
install -p -D -m 0755 %SOURCE8 %buildroot%_bindir/patroni_patroni
install -p -D -m 0755 %SOURCE9 %buildroot%_bindir/atroni_wale_restore

%pre

%post
%post_service patroni

%preun
%preun_service patroni

%files
%python3_sitelibdir/%name/
%python3_sitelibdir/*egg-info
%patroni_confdir/*
%_bindir/*
%_unitdir/*
%_initrddir/*

%changelog
* Fri Feb 12 2021 Alexey Kostarev <kaf@altlinux.org> 2.0.1-alt1
- 2.0.1



