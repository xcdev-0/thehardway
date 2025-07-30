#!/usr/bin/env bash


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/scripts

CPMEM="2048M"
WNMEM="2048M"

specs=/tmp/vm-specs
cat <<EOF > $specs
controlplane01,2,${CPMEM},10G
controlplane02,2,${CPMEM},5G
loadbalancer,1,512M,5G
node01,2,${WNMEM},5G
node02,2,${WNMEM},5G
EOF

hostentries=/tmp/hostentries

[ -f $hostentries ] && rm -f $hostentries

for spec in $(cat $specs)
do
    node=$(cut -d ',' -f 1 <<< $spec)
    ip=$(multipass info $node --format json | jq -r 'first( .info[] | .ipv4[0] )')
    echo "$ip $node" >> $hostentries
done

for spec in $(cat $specs); do
    name=$(echo ${spec} | cut -d ',' -f 1)
    printf "executing node %s\n" "${name}"


    multipass transfer $hostentries $name:/tmp/

    multipass transfer $SCRIPT_DIR/01-setup-hosts.sh $name:/tmp/
    multipass exec $name -- chmod +x /tmp/01-setup-hosts.sh
    multipass exec $name -- /tmp/01-setup-hosts.sh

done


