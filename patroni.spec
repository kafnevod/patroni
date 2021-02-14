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

%setup_python_module %name

BuildArch: noarch

BuildRequires(pre): rpm-build-python3 

BuildRequires: python3-devel 


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
%python3_install patroni

#set 
#set -x
ls -lR
mkdir -p %buildroot%python3_sitelibdir
cp -r patroni %buildroot%python3_sitelibdir

%pre

%post
%post_service patroni

%preun
%preun_service patroni

%files
%python3_sitelibdir/%name/

%changelog
* Fri Feb 12 2021 Alexey Kostarev <kaf@altlinux.org> 2.0.1-alt1
- 2.0.1



