#!/usr/bin/env bash
#------------------------------------------------------------------
# script: ./namespace_setup.sh
#
# description: This script sets up a new network namespace
#
#
#------------------------------------------------------------------

# shellcheck enable=add-default-case
# shellcheck enable=quote-safe-variables
# shellcheck enable=require-variable-braces
# shellcheck enable=avoid-nullary-conditions
# shellcheck enable=require-double-brackets
# shellcheck enable=check-extra-masked-returns
# shellcheck enable=check-set-e-suppressed

# shellcheck disable=SC1091
# shellcheck disable=SC1090

if [[ -n "${DEBUG}" ]]; then
        set -x # DEBUGGING MODE
fi

if [[ -n "${VERBOSE}" ]]; then
        set -v # VERBOSE MODE
fi

if [[ -n "${SYNTAX_CHECK}" ]]; then
        set -n # CHECK SYNTAX WITHOUT RUNNING THE SCRIPT
fi

set -u
set -e

_PROGRAM_NAME="$(basename "${0}")"
PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/:/usr/local/sbin/"
IFS="
 "

###############################################################
# SETTINGS
###############################################################
NAMESPACE_NAME="my_namespace"
VETH_MAIN="veth0"
VETH_NS="veth1"
IP_ADDRESS_MAIN="192.168.1.1"
IP_ADDRESS_NS="192.168.1.110"
NETWORK_CIDR="10.0.0.0/24"
MAIN_INTERFACE="wlp2s0"
DNS_SERVER="8.8.8.8"
COMMAND="bash"
#COMMAND="openvpn --config mralians1.ovpn"
###############################################################

if [[ $(id -u) -ne 0 ]];then
    printf "Cannot possibly work without effective root\n" >&2
    exit 1
fi

#export DISPLAY=:0.0

if ip netns list | grep -q "\<${NAMESPACE_NAME}\>";then
    printf "Netns "${NAMESPACE_NAME}" exists. Do you want to delete this namespace? [Y/n] "
    read answer
    answer="${answer:-"Y"}"
    if [[ ${answer} == "Y" ]];then
        ip netns del "${NAMESPACE_NAME}"
    else
        exit 0
    fi
fi


ip netns add "${NAMESPACE_NAME}"

if ip link show "${VETH_MAIN}" >/dev/null 2>&1;then
    ip link del "${VETH_MAIN}"
fi

ip link add "${VETH_MAIN}" type veth peer name "${VETH_NS}"

ip link set "${VETH_NS}" netns "${NAMESPACE_NAME}"

ip addr add "${IP_ADDRESS_MAIN}/24" dev "${VETH_MAIN}"
ip netns exec "${NAMESPACE_NAME}" ip addr add "${IP_ADDRESS_NS}/24" dev "${VETH_NS}"

ip link set "${VETH_MAIN}" up
ip netns exec "${NAMESPACE_NAME}" ip link set "${VETH_NS}" up

ip route add "${NETWORK_CIDR}" via "${IP_ADDRESS_MAIN}" dev "${VETH_MAIN}"
ip netns exec "${NAMESPACE_NAME}" ip route add default via "${IP_ADDRESS_MAIN}" dev "${VETH_NS}"

echo "1" > /proc/sys/net/ipv4/ip_forward

iptables -t nat -A POSTROUTING -s "${IP_ADDRESS_NS}/24" -o "${MAIN_INTERFACE}" -j MASQUERADE

mkdir -p /etc/netns/"${NAMESPACE_NAME}"
echo "nameserver "${DNS_SERVER}"" > /etc/netns/"$NAMESPACE_NAME"/resolv.conf

ip netns exec "${NAMESPACE_NAME}" "${COMMAND}"
