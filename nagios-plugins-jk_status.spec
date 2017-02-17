# spec file for package check_jk_status.pl

%define lname check_jk_status

Name:          nagios-plugins-jk_status
Summary:       Nagios Plugins - check_jk_status.pl
Version:       1.0.0
Url:           http://github.com/lbetz/check_jk_status
License:       GPL-3.0
Group:         System/Monitoring
Source0:       %{lname}-%{version}.tar.gz
Provides:      nagios-plugins-jk_status = %{version}-%{release}
Obsoletes:     nagios-plugins-jk_status < %{version}-%{release}
Requires:      perl(Monitoring::Plugin)
Requires:      perl(LWP::UserAgent)
Requires:      perl(XML::Simple)
Requires:      perl(Data::Dumper)

%if 0%{?suse}
Release:       1
BuildRequires: nagios-rpm-macros
BuildRoot:     %{_tmppath}/%{name}-%{version}-build
%endif

%if 0%{?fedora} || 0%{?rhel} || 0%{?centos}
Release:       1%{?dist}
Requires:      nagios-common
%endif

%if 0%{?fedora} >= 16 || 0%{?rhel} >= 7 || 0%{?centos} >= 7
Requires:      perl(LWP::Protocol::https)
%endif

%description
Checks against the apache mod_jk status site.

%prep
%setup -q -n %{lname}-%{version}

%install
%{__mkdir_p} %{buildroot}/%{_libdir}/nagios/plugins
%{__install} -m755 check_jk_status.pl %{buildroot}/%{_libdir}/nagios/plugins/

%clean
rm -rf %buildroot

%files -n nagios-plugins-jk_status
%defattr(-,root,root)
# avoid build dependecy of nagios - own the dirs
%if 0%{?suse_version}
%dir %{_libdir}/nagios
%dir %{_libdir}/nagios/plugins
%endif
%{_libdir}/nagios/plugins/check_jk_status.pl

%changelog
* Fri Feb 17 2017 Lennart Betz <lennart.betz@netways.de>
- initial setup
