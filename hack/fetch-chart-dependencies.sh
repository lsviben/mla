#!/usr/bin/env bash

# Copyright 2021 The Kubermatic Kubernetes Platform contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

### This script fetches dependencies for a chart, based on the lock file
### contained within the charts' directory. The script iterates over all charts.

set -euo pipefail

# make sure we use yq version 4.x, sometimes known as yq4
if `which yq4`; then
  YQ=yq4
else
  yq --version | grep "version 4" >/dev/null || (echo "yq version 3 not supported, exiting..."; exit 1)
  YQ=yq
fi

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
REALDIR="$(cd "$(dirname $(readlink -f "${BASH_SOURCE[0]}"))" && pwd)"
source ${REALDIR}/lib.sh

cd ${BASEDIR}
charts=$(find charts/ -name Chart.yaml | sort)

[ -n "$charts" ] && while read -r chartYAML; do
  dirname="$(dirname $(echo "$chartYAML"))"
  chartname=$($YQ eval .name "$chartYAML" )
  echodate "Fetching dependencies for ${chartname}..."

  i=0
  for url in $($YQ eval .dependencies "$chartYAML" --tojson | jq -r 'try .[] | .repository'); do
    i=$((i + 1))
    helm repo add ${chartname}-dep-${i} ${url}
  done

  helm dependency build "${dirname}"

  echodate "Cleaning up dependencies repositories..."
  while [[ $i -gt 0 ]]; do
    helm repo remove ${chartname}-dep-${i}
    i=$((i - 1))
  done
done <<< "$charts"
