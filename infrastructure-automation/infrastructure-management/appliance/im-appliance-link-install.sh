#
# © Copyright IBM Corp. 2020, 2023
# SPDX-License-Identifier: Apache2.0
#
#!/bin/bash

# version="1.0"
#
# ARG_OPTIONAL_SINGLE([all],[a],[Do all configurations: deployement, service, route creation, zen configurations],[false])
# ARG_OPTIONAL_SINGLE([containers],[c],[create deployment, service routes for all containers],[false])
# ARG_OPTIONAL_SINGLE([zen],[z],[configure zen],[false])
# ARG_HELP([Script configures Cost and Analysis / Energy functionality for CloudPak])

die()
{
    local _ret="${2:-1}"
    test "${_PRINT_HELP:-no}" = yes && print_help >&2
    echo "$1" >&2
    exit "${_ret}"
}


begins_with_short_option()
{
    local first_option all_short_options='aczuh'
    first_option="${1:0:1}"
    test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - OPTIONALS
#_arg_all="false"
#_arg_containers="false"
#_arg_zen="false"


print_help()
{
    printf '\t%s\n' " "
    printf '%s\n' "This script configures Infrastructure Automation - Infrastructure Management Appliance link."
    printf '%s\n' "***** You must must login to the oc client******"
    printf '%s\n' "***** Run script as sudo or root ******"
    printf '\t%s\n' " "
    printf 'Usage: %s [-i|--i <arg>] [-u|--uninstall] [-h|--help]\n' "$0"
    printf '\t%s\n' "-i, --install: Install Infrastructure Management Appliance, Usage im-appliance-link-install.sh -i <https://Infrastructure Management appliance host or ip>"
    printf '\t%s\n' "-u, --uninstall: Remove Infrastructure Management configuration from CloudPak , Usage im-appliance-link-install.sh -u "
    printf '\t%s\n' "-h, --help: Prints help"
}

parse_commandline()
{
    while test $# -gt 0
    do
        _key="$1"
        case "$_key" in
            -i|--install)
                test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_install="$2"
                shift
            ;;
            --install=*)
              test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_install="$2"
                shift
            ;;
            -i*)
              test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_install="$2"
                shift
             ;;
            -u|--uninstall)
                #test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
                _arg_uninstall="true"
                shift
            ;;
            --uninstall=*)
                _arg_uninstall="true"
            ;;
            -u*)
                _arg_uninstall="true"
            ;;
            -h|--help)
                print_help
                exit 0
            ;;
            -h*)
                print_help
                exit 0
            ;;
            *)
                _PRINT_HELP=yes die "FATAL ERROR: Got an unexpected argument '$1'" 1
            ;;
        esac
        shift
    done
}

parse_commandline "$@"

check_oc_installed() {
    echo "Checking if oc is installed..."
    command -v oc >/dev/null 2>&1 || {
        echo >&2 "OC client is not installed... Aborting."
        exit 1
    }
    echo "OS client is installed"
}

update_permissions_for_templates(){
    chmod 755 -R *
}

oc_crud_yamls_in_directory(){
    command="apply"

    if [ -n "$_arg_uninstall" ]; then
        command="delete"
        echo "Uninstalling  $directory" 2>&1 | tee -a install.log
        echo "Uninstall yaml files in $directory directory"
        oc $command -f $directory 2>&1 | tee -a install.log
        #allow certian resources to have time to clear.
        sleep 30
    else
        echo "Installing  $directory" 2>&1 | tee -a install.log
        echo "Install yaml files in $directory directory"
        oc $command -f $directory -o yaml 2>&1 | tee -a install.log
    fi
    
    echo "Finished yaml execution"
}


find_zen_namespace(){
    #find namespace of deployment zen-core
    zen_namespace=`oc get deployments --all-namespaces | grep "zen-core" | head -n1 | awk '{print $1;}'`
    if [ -n "$zen_namespace" ]; then
        echo "Using Zen namespace: $zen_namespace"
        export zen_namespace="$zen_namespace"
    else
        echo ""
        echo "Source environment file: infra-automation.env"
        . infra-automation.env
    fi
}

setup(){
    export im_url="$_arg_install"
    check_oc_installed
    update_permissions_for_templates
    find_zen_namespace
    rm -rf install.log
    if [ -n "$_arg_uninstall" ]; then
      _uninstall="true"
    else 
      _install="true"
      create_yml_files
    fi
}

create_yml_files() {

    if [ -n "$_arg_uninstall" ]; then
      return
    fi    
   ###############Menu####################
    echo " "
    echo "Creating navigation menu"
    ./nav_template/automate.sh > ./nav/automate.yml
    chmod -R 775 ./nav 
}


############### Start script execution ###################

 #source environment variables       
   if [ -n "$_arg_uninstall" ] ||  [ -n "$_arg_install" ]; then
    setup
    declare -a arr=("nav")    
    for directory in "${arr[@]}"
    do
        echo "---------------------"
        echo "Preparing execution of yaml in $directory"
        oc_crud_yamls_in_directory
    done
   exit 0
   fi
    echo ""
    echo "-----------------------"
    echo "Missing an argument (-i or -u). Please view help:"
    echo "-----------------------"
    print_help
