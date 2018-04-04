#!/bin/sh

# JVM installed
JAVA_BIN=/opt/mqm/java/jre64/jre/bin/java

echo "#### Using Java Virtual Machine :"
echo $($JAVA_BIN -version)

$JAVA_BIN -jar $(dirname $0)/CMDRunner.jar --tool PerfMonAgent "$@"
