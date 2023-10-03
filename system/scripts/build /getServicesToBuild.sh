#!/bin/bash

# this script is used to parse pipeline input and generate a list of services to build for the next stage.
# it handles a list of modules or a special case "all" to build.
# the format expected is a comma separated list <module>@<branch> to build.

# the script will use the service catalog to determine modules to be built.

input=$INPUT

## create a hardcoded list of services to handle harnesscore@<branch>
IFS="," read -ra HARNESSCORE <<< "ci-manager,ng-manager,platform-service,sto-manager,migrator,batch-processing,manager,access-control,ce-nextgen,template-service,pipeline-service,event-server,change-data-capture,srm-service,verification-service,bootstrap"

## example input:  harnesscore@develop,access-manager@IE-1234
#remove outside braces and Services: from input, $services is now just a list
parseList=${input#*\{}
parseList=${parseList%\}}
parseList=${parseList#Services:}


## setup file paths
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
HARNESS_PL_INFRA_DIR="$SCRIPTPATH/../../.."
SERVICE_CATALOG="$HARNESS_PL_INFRA_DIR/system/service-catalog.yaml"

serviceList=()
IFS=',' read -ra buildArray <<< "$parseList"

# buildArray is a bash array of values from $input
for build in ${buildArray[@]}; do
  # grab branch from inputs strings, <build>@<branch>
  branch=${build#*@}

  # add services to be built to our serviceList
  case $build in
    all*)
        ## use yq to find all services from servicecatalog
        ## add each service found to serviceList
        services=$(yq 'keys | .[]' $SERVICE_CATALOG | tr '\n' ' ')
        serviceArray="${services[*]}"
        for service in $serviceArray; do
          branch=$(yq e ".${service}.defaultBranch" $SERVICE_CATALOG)
          serviceList+=($service@$branch)
        done
        ;;
    *harnesscore*)
      for b in ${HARNESSCORE[@]}; do
        serviceList+=($b@$branch)
      done
      ;;
    *)
      ## look in servicecatalog for "service" (aka module) using yq (ex: platform@develop)
      ## if a list is found, add those services to the serviceList
      module=${build%%@*}
      services=$(yq eval "with_entries(select(.value.module | .[] | contains(\"$module\"))) | keys | .[]" $SERVICE_CATALOG | tr '\n' ' ')
      if [ ! -z "$services" ]; then
        serviceArray="${services[*]}"
        for service in $serviceArray; do
          serviceList+=($service@$branch)
        done
      else
        serviceList+=($build)
      fi
      ;;
    esac
done

# generate comma separated list of servcies to build for next step in pipeline
services=$(IFS=','; echo "${serviceList[*]}")
echo $services
