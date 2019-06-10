#!/bin/bash
set -e
eval "$(jq -r '@sh "AMI_IMAGE_NAME=\(.ami_image_name) VERSION_REGEX=\(.version_regex)"')"

## The kubernetes versions supported by EKS are determined from the list
## of available worker node AMI images.  Given a regular expression and
## the name of an AMI image (obtained from the 'aws_ami' data source),
## parse the version from the image name.
the_version=""
if [[ $AMI_IMAGE_NAME =~ $VERSION_REGEX ]]; then
    ## Image name matched the regular expression; Capture the version
    ## from the name to be used when creating/updating the cluster.
    the_version=${BASH_REMATCH[1]}
fi
jq -n --arg cluster_version "$the_version" '{cluster_version:($cluster_version)}'