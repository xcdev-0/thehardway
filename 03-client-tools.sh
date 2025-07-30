#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd )/scripts




host="controlplane01"

multipass transfer $SCRIPT_DIR/03-setup-cloud.sh $host:/tmp/
multipass exec $host -- chmod +x /tmp/03-setup-cloud.sh
multipass exec $host -- /tmp/03-setup-cloud.sh






