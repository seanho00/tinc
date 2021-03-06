#! /system/bin/sh
## /data/local/udhcpc-script.sh
## udhcpc -s <script>
## https://udhcp.busybox.net/README.udhcpc
## key vars: interface ip subnet mask broadcast router dns domain

# Set vars
pri=5500
tid=150
chain="out_dns"
nat="iptables -t nat"

# Subroutines

setIP() {
  echo "Setting IP address $ip on $interface"
  eval $(ipcalc -ns $ip/$mask) # set NETWORK
  ip ad add $ip/$mask dev $interface
  ip ro add $NETWORK dev $interface table $tid
}

clearRouting() {
  ip ru del pri $pri lookup $tid 2>&-
  ip ro flush table $tid
}

setGateway() {
  echo "Setting default gateway to $1"
  ip ru add pri $pri lookup $tid
  ip ro add default via $1 dev $interface table $tid
}

clearDNS() {
  $nat -D OUTPUT -j $chain 2>&-
}

redirDNS() {
  echo "Redirecting DNS traffic to $1"
  rule="--dport 53 -j DNAT --to $1"

  $nat -N $chain 2>&-
  $nat -F $chain
  $nat -A $chain -p udp $rule
  $nat -A $chain -p tcp $rule
  $nat -C OUTPUT -j $chain 2>&- || \
  $nat -I OUTPUT -j $chain
}

# Main actions

[ -n "$1" ] || {
  echo "Error: should be called from udhcpc"
  exit 1
}

case "$1" in
 deconfig)
  echo "Deconfig interface: $interface"
  ip link set $interface up
  clearDNS
  clearRouting
  ;;

 bound)
  echo "Bind interface: $interface $ip"
  setIP
  setGateway $router
  redirDNS $dns
  ;;

 renew)
  echo "Renew lease: $interface $ip"
  setGateway $router
  redirDNS $dns
  ;;
esac

exit 0
