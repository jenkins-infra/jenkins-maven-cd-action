#!/bin/bash
set -euxo pipefail
if [ $GITHUB_EVENT_NAME = check_run ]
then
    gh api /repos/$GITHUB_REPOSITORY/releases | jq -e -r '[ .[] | select(.draft == true and .name == "next")] | max_by(.id).body' | egrep "$INTERESTING_CATEGORIES"
fi
export MAVEN_OPTS=-Djansi.force=true
mvn -B -V -s $GITHUB_ACTION_PATH/settings.xml -ntp -Dstyle.color=always -Dset.changelist -DaltDeploymentRepository=maven.jenkins-ci.org::default::https://repo.jenkins-ci.org/releases/ -Pquick-build -P\!consume-incrementals clean deploy
version=$(mvn -B -ntp -Dset.changelist -Dexpression=project.version -q -DforceStdout help:evaluate)
# Create the annotated git tag - https://docs.github.com/en/rest/git/tags#create-a-tag-object
gh api -F tag=$version -F message=$version -F object=$GITHUB_SHA -F type=commit /repos/$GITHUB_REPOSITORY/git/tag
# Create the git reference associated to the annotated git tag - https://docs.github.com/en/rest/git/refs#create-a-reference
gh api -F ref=refs/tags/$version -F sha=$GITHUB_SHA /repos/$GITHUB_REPOSITORY/git/refs
# Publish the GitHub draft release and associate it with the git tag - https://docs.github.com/en/rest/releases/releases#update-a-release
release=$(gh api /repos/$GITHUB_REPOSITORY/releases | jq -e -r '[ .[] | select(.draft == true and .name == "next").id] | max')
gh api -X PATCH -F draft=false -F name=$version -F tag_name=$version /repos/$GITHUB_REPOSITORY/releases/$release
