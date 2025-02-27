#!/bin/bash

# Make sure JENKINS_URL, JENKINS_AGENT_NAME, JENKINS_AGENT_SECRET are set
if [ -z "$JENKINS_URL" ] || [ -z "$JENKINS_AGENT_NAME" ] || [ -z "$JENKINS_AGENT_SECRET" ]; then
    echo "ERROR: JENKINS_URL, JENKINS_AGENT_NAME, JENKINS_AGENT_SECRET must be set."
    sleep 15
    exit 1
fi

# 1. Download the matching agent.jar from the master
cd /root/.jenkins
wget -O agent.jar "${JENKINS_URL}jnlpJars/agent.jar"

# 2. Start the inbound agent
exec java -jar agent.jar -url "${JENKINS_URL}" -secret ${JENKINS_AGENT_SECRET} -name "${JENKINS_AGENT_NAME}" -webSocket -workDir "/root/.jenkins"