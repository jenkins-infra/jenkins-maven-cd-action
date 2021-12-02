#!/bin/bash
set -euxo pipefail
if [ $GITHUB_EVENT_NAME = check_run ]
then
    gh api /repos/$GITHUB_REPOSITORY/releases | jq -e -r '.[] | select(.draft == true and .name == "next") | .body' | egrep "$INTERESTING_CATEGORIES"
fi
export MAVEN_OPTS=-Djansi.force=true
if fgrep -sq changelist.format .mvn/maven.config
then # JEP-229
    mvn -B -V -s $GITHUB_ACTION_PATH/settings.xml -ntp -Dstyle.color=always -Dset.changelist -DaltDeploymentRepository=maven.jenkins-ci.org::default::https://repo.jenkins-ci.org/releases/ -Pquick-build -P\!consume-incrementals clean deploy
    version=$(mvn -B -ntp -Dset.changelist -Dexpression=project.version -q -DforceStdout help:evaluate)
    gh api -F ref=refs/tags/$version -F sha=$GITHUB_SHA /repos/$GITHUB_REPOSITORY/git/refs
else # MRP
    git config --global user.email cd@jenkins.io
    git config --global user.name jenkins-maven-cd-action
    git config --global url.https://github.com/.insteadOf git@github.com:
    git config -l # TODO debugging
    mvn -B -V -s $GITHUB_ACTION_PATH/settings.xml -ntp -Dstyle.color=always -P\!consume-incrementals -Darguments='-Pquick-build -ntp' validate release:prepare release:perform
    git checkout HEAD^ # tagged version, rather than prepare for next development version
    version=$(mvn -B -ntp -Dexpression=project.version -q -DforceStdout help:evaluate)
fi
release=$(gh api /repos/$GITHUB_REPOSITORY/releases | jq -e -r '.[] | select(.draft == true and .name == "next") | .id')
gh api -X PATCH -F draft=false -F name=$version -F tag_name=$version /repos/$GITHUB_REPOSITORY/releases/$release
