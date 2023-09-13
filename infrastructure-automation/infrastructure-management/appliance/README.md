# IM Appliance Link Installer
<!-- © Copyright IBM Corp. 2020, 2023 -->

Configures Infrastructure Management (IM) appliance navigation links in Infrastructure Automation.
The result will be an Automation folder and IM link with a user supplied server URL.

## Prerequisites

 1.  Sudo or Root access
 2.  OC Client install and authenticated

## Install

 1. Clone this repository. 
 2. Chmod 755 -R *

## Important Files: 
 im-appliance-link-install.sh - script to used for execution 
 install.log - installation log
 
 ## How to get help
 
Execute ./im-appliance-link-install.sh  -h (help). the following options will be displayed
 
```
Usage: ./im-appliance-link-install.sh [-i|--install <arg>] [-u|--uninstall] [-h|--help]
	-i, --install: Install Infrastructure Management Applicance, Usage im-appliance-link-install -i <https://Infrastructure Management appliance host or ip>
	-u, --uninstall: Remove Infrastructure Management configuration from CloudPak , Usage im-appliance-link-install.sh -u 
	-h, --help: Prints help
```


## How to Install:
```
im-appliance-link-install.sh -i https://appliance_host_name.com
```

## How to Uninstall:
```
im-appliance-link-install.sh  -u
```

