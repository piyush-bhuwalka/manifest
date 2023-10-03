#!/bin/bash

# Input parameters
SERVICE_NAME="$1"   # Service name
COMMIT_SHA="$2"     # Commit SHA
RELEASE_TYPE="$3"   # Release Type -> MINOR/PATCH
BRANCH_NAME="$4"

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

HARNESS_PLUGIN_INFRA_DIR=$SCRIPTPATH
for (( i=0; i<2; ++i)); do
  HARNESS_PLUGIN_INFRA_DIR=$(dirname $HARNESS_PLUGIN_INFRA_DIR)
done

echo "HARNESS_PLUGIN_INFRA_DIR is : $HARNESS_PLUGIN_INFRA_DIR"
HARNESS_PLUGIN_SYSTEM_DIR=${HARNESS_PLUGIN_INFRA_DIR}

# Defaults to the latest commit SHA
if [[ -z $COMMIT_SHA ]]; then
  COMMIT_SHA=$(git rev-parse HEAD)
fi

# Get the latest tag for the service
LATEST_TAG=$(git tag -l | grep -E "^${SERVICE_NAME}/v[0-9]+\.[0-9]+\.[0-9]+" | sort -V | tail -n 1 2>/dev/null)
echo "LATEST_TAG is: $LATEST_TAG"
if [[ -z $LATEST_TAG ]]; then
  echo "No tag found, will create new tag"
fi

if [ "$RELEASE_TYPE" == "PATCH" ]; then
  echo "BRANCH_NAME is $BRANCH_NAME"
  LATEST_TAG="$(echo "${BRANCH_NAME}" | awk -F'_' '{print $2}')"
  LATEST_TAG=$(echo "$LATEST_TAG" | cut -d. -f1-2)
  LATEST_TAG=$(git tag -l | grep -E "^${SERVICE_NAME}/v${LATEST_TAG}+\.[0-9]+" | sort -V | tail -n 1 2>/dev/null)
  echo "LATEST_TAG for hotfix is $LATEST_TAG"
fi 

NEW_VERSION=""
#Parse the version from the latest tag and increment accordingly
if [ -n "$LATEST_TAG" ]; then
  # Extract the version from the tag (format: servicename_1.0.0)
    VERSION="${LATEST_TAG##*/v}"
    echo "VERSION is $VERSION"
    if [ "$RELEASE_TYPE" == "MINOR" ]; then
        # Normal release: Increment the MINOR version by 1
        NEW_VERSION=$($HARNESS_PLUGIN_SYSTEM_DIR/utils/increment_version.sh -m ${VERSION})
        echo "NEW_VERSION is $NEW_VERSION"
    elif [ "$RELEASE_TYPE" == "PATCH" ]; then
        # Hotfix: Increment the PATCH version by 1
        NEW_VERSION=$($HARNESS_PLUGIN_SYSTEM_DIR/utils/increment_version.sh -p ${VERSION})
    else
        echo "do nothing"
        exit 1
    fi

else
    # If no tag exists for the service, start with version 1.0.0
    NEW_VERSION="1.0.0"
fi

echo "NEW_VERSION is $NEW_VERSION"
# Create the git tag
export NEW_TAG="${SERVICE_NAME}/v${NEW_VERSION}"
git tag -a "$NEW_TAG" "$COMMIT_SHA" -m "Release $NEW_VERSION"
# Push the tag
git push origin "$NEW_TAG"

# Fork a release branch from the tag (replace '.' with '-') only for MINOR Release
if [ "$RELEASE_TYPE" == "MINOR" ]; then
  export BRANCH_NAME="release/${SERVICE_NAME}_${NEW_VERSION}"
  git checkout -b "$BRANCH_NAME" "$NEW_TAG"
  git push origin "$BRANCH_NAME"
  echo "Release Branch: $BRANCH_NAME"
fi

# Output the new tag
echo "New Tag: $NEW_TAG"
