#!/bin/bash

## Print usage message and exit
usage()
{
    echo "Usage: ${0} checkApi|checkNodes <endpoint> <auth token> [<timeout seconds> <interval seconds>]" >&2
    exit 1
}

## Cluster's API server endpoint is not accessible immediately upon
## completion of the 'eks_cluster' resource creation.  Repeatedly
## attempt to access the endpoint until success or timeout occurs.
checkApiServer()
{
    elapsedTime=0
    status=503
    authHeader="Authorization: Bearer ${AUTHTOKEN}"
    while [ ${elapsedTime} -lt ${TIMEOUT} ]; do
        status=$(curl --connect-timeout 2 -o /dev/null -s -w "%{http_code}\n" ${ENDPOINT} --header "${authHeader}" --insecure)
        if [ "${status}" == "200" ]; then
            echo "Cluster is accessible at ${ENDPOINT}"
            elapsedTime=${TIMEOUT}
        else
            echo "Cluster not yet accessible; Waiting for next attempt..."
            sleep ${INTERVAL}
            elapsedTime=$((elapsedTime+${INTERVAL}))
        fi
    done
    if [ "${status}" != "200" ]; then
        echo "Warning: Unable to access cluster at ${ENDPOINT} within allotted time"
        exit 1
    fi
}

## Convert given text to lower case after removing leading and trailing quotes
trimAndLower()
{
    text=$(echo ${1} | sed -e 's/^"//' -e 's/"$//' | tr '[:upper:]' '[:lower:]')
    echo ${text}
}

## After enabling the worker nodes within the cluster, they are not immediately
## ready for use.  Repeatedly check the status of the nodes until all are ready
## or timeout occurs.
checkNodesReady()
{
    elapsedTime=0
    readyCount=0
    readyState=1
    authHeader="Authorization: Bearer ${AUTHTOKEN}"
    while [ ${elapsedTime} -lt ${TIMEOUT} ]; do
        nodeCount=0
        nodeJson=$(curl ${ENDPOINT}/api/v1/nodes --header "${authHeader}" --insecure)
        if [ ! -z "${nodeJson}" ]; then
            ## Determine whether all nodes are in a ready state
            nodeCount=$(echo ${nodeJson} | jq '.items' | jq length)
            if [ ${nodeCount} -gt 0 ]; then
                ## Parse and examine details for each node
                readyCount=0
                nodeIndex=0
                while [ ${nodeIndex} -lt ${nodeCount} ]; do
                    nodeName=$(echo ${nodeJson} | jq ".items[${nodeIndex}].metadata.name")
                    echo "Checking ready status for node ${nodeName}..."

                    conditionsCount=$(echo ${nodeJson} | jq ".items[${nodeIndex}].status.conditions" | jq length)
                    conditionsIndex=0
                    while [ ${conditionsIndex} -lt ${conditionsCount} ]; do
                        ## Find and examine the 'Ready' condition for the node
                        conditionType=$(echo ${nodeJson}   | jq ".items[${nodeIndex}].status.conditions[${conditionsIndex}].type")
                        conditionStatus=$(echo ${nodeJson} | jq ".items[${nodeIndex}].status.conditions[${conditionsIndex}].status")

                        theType=$(trimAndLower ${conditionType})
                        theStatus=$(trimAndLower ${conditionStatus})
                        if [ "${theType}" == 'ready' ]; then
                            if [ "${theStatus}" == 'true' ]; then
                                echo "Node ${nodeName} is in a Ready state"
                                readyCount=$((readyCount+1))
                            else
                                echo "Node ${nodeName} is not yet ready"
                            fi
                        fi

                        conditionsIndex=$((conditionsIndex+1))
                    done
                    nodeIndex=$((nodeIndex+1))
                done
                if [ ${readyCount} -eq ${nodeCount} ]; then
                    readyState=0
                fi
            else
                echo "Node details not found in retrieved data"
            fi
        else
            echo "Node data is not available"
        fi

        if [ ${readyState} -eq 0 ]; then
            echo "All nodes are ready"
            elapsedTime=${TIMEOUT}
        else
            echo "Of ${nodeCount} nodes, ${readyCount} are ready; Waiting for next status check..."
            sleep ${INTERVAL}
            elapsedTime=$((elapsedTime+${INTERVAL}))
        fi
    done
    if [ ${readyState} -ne 0 ]; then
        echo "Warning: Not all nodes are ready within allotted time"
        exit 1
    fi
}


## Process input parameters
CHECK=$1
ENDPOINT=$2
AUTHTOKEN=$3
if [ ! -z "${AUTHTOKEN}" ]; then
    AUTHTOKEN=$(echo ${AUTHTOKEN} | base64 -d)
fi
TIMEOUT=600
if [ "$#" -gt 3 ]; then
    TIMEOUT=$4
fi
INTERVAL=10
if [ "$#" -gt 4 ]; then
    INTERVAL=$5
fi
if [ -z "${CHECK}"  -o  -z "${ENDPOINT}"  -o  -z "${AUTHTOKEN}" ]; then
    usage
fi


## Perform requested check
if [ "${CHECK}" == "checkApi" ]; then
    checkApiServer
elif [ "${CHECK}" == "checkNodes" ]; then
    checkNodesReady
else
    usage
fi
