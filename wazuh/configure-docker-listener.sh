#!/bin/bash

CONTAINERS=( $(pct list | grep running | awk '{print $1}') )
WAZUH_MANAGER_CONTAINER=107

for CONTAINER in ${CONTAINERS[@]}
do
    has_agent=$(pct exec $CONTAINER -- test -d /var/ossec && echo "yes" || echo "no")
    has_docker=$(pct exec $CONTAINER -- docker --version &> /dev/null && echo "yes" || echo "no")
    if [[ $has_agent == "yes" && $CONTAINER != $WAZUH_MANAGER_CONTAINER && $has_docker == "yes" ]]; then

        echo "# Configuring $CONTAINER -----------------------------------------------------------------------------------"
        echo "# Has docker: $has_docker"
        echo "# Has wazuh agent: $has_agent"
        sleep 1

        echo "# [$CONTAINER] - Installing Python and pip..."
        pct exec $CONTAINER -- apt update
        pct exec $CONTAINER -- apt install python3 -y
        pct exec $CONTAINER -- apt install python3-pip -y

        has_docker_module=$(pct exec $CONTAINER -- pip show docker &>/dev/null && echo "yes" || echo "no")
        echo "Has docker module installed: $has_docker_module"

        if [[ $has_docker_module == "no" ]]; then
            echo "# [$CONTAINER] - Installing python docker module..."
            pct exec $CONTAINER -- pip3 install docker==4.2.0 --break-system-packages
        else
            echo "# [$CONTAINER] - Python docker module already installed"
            sleep 1
        fi

        echo "# [$CONTAINER] - Enabling the Wazuh agent to receive remote commands from the Wazuh server..."

        remote_command_enabled=$(pct exec $CONTAINER -- cat /var/ossec/etc/local_internal_options.conf 2>/dev/null | grep logcollector.remote_commands >/dev/null && echo "yes" || echo "no>        echo "Has remote command enabled: $remote_command_enabled"

        if [[ $remote_command_enabled == "no" ]]; then
            echo "echo 'logcollector.remote_commands=1' >> /var/ossec/etc/local_internal_options.conf" | pct enter $CONTAINER
        else
            echo "# [$CONTAINER] - Remote command already enabled"
            sleep 1
        fi

        echo "# [$CONTAINER] - Restarting the agent..."
        pct exec $CONTAINER -- systemctl restart wazuh-agent
    fi
done


