#!/usr/bin/env bash

set -e

(which istioctl &>/dev/null) || (echo '* missing istioctl; ensure that Istio is installed and `istioctl` is available on your PATH. More info: https://istio.io/docs/tasks/installing-istio.html' && exit 1)

ISTIO_PATH="$(cd "$(dirname "$(which istioctl)")/.." && pwd)"

istioctl-kube-inject() {
    # Several hacky things here...
    # kube-inject doesn't currently support StatefulSet, so we hack output to
    # Deployment and then turn it back into StatefulSet
    # and add back the service name that is strips
    # Lastly, if we're not a StatefulSet we strip the trailing --- as there's a bug
    # in istioctl where it adds this delimeter even if it doesn't convert JSON to YAML,
    # thus causing the JSON to be invalid

    # Most of this can be removed when this PR is merged: https://github.com/istio/pilot/pull/896/files

    if grep -q '"kind":\s*"StatefulSet"' "$1"; then
        service_name="$(cat "$1" | sed -n 's/".*serviceName"\s*:\s*"\([^"]*\)".*,/\1/p' | sed 's/^ *//;s/ *$//')"

        cat "$1" |
        sed 's/"kind": "StatefulSet"/"kind": "Deployment"/' |
        "$ISTIO_PATH/bin/istioctl" kube-inject -f - |
        sed 's/kind: Deployment/kind: StatefulSet/' |
        sed "s/^spec:$/spec:\n  serviceName: $service_name/" |
        sed 's/status: {}//' |
        sed 's/strategy: {}//'
    else
        cat "$1" |
        "$ISTIO_PATH/bin/istioctl" kube-inject -f - |
        sed 's/---$//'
    fi
}

if [ "$1" != "" ]; then
    istioctl-kube-inject "$1"
fi