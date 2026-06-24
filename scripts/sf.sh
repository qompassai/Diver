#!/usr/bin/env bash

# sf.sh
# Qompass AI Diver Salesforce CLI Script
# ----------------------------------------
# Reference: https://developer.salesforce.com/docs/platform/salesforce-cli-reference/guide/cli_reference.html
set -euo pipefail
sf plugins install \
  @cristiand391/sf-plugin-fzf-cmp \
  @dx-cli-toolbox/sfdx-toolbox-package-utils \
  @jayree/sfdx-plugin-manifest \
  @jayree/sfdx-plugin-org \
  @jayree/sfdx-plugin-prettier \
  @jayree/sfdx-plugin-source \
  @salesforce/plugin-agent \
  @salesforce/plugin-apex \
  @salesforce/plugin-api \
  @salesforce/plugin-auth \
  @salesforce/plugin-code-analyzer \
  @salesforce/plugin-community \
  @salesforce/plugin-custom-metadata \
  @salesforce/plugin-data \
  @salesforce/plugin-deploy-retrieve \
  @salesforce/plugin-dev \
  @salesforce/plugin-devops-center \
  @salesforce/plugin-flow \
  @salesforce/plugin-info \
  @salesforce/plugin-lightning-dev \
  @salesforce/plugin-limits \
  @salesforce/plugin-marketplace \
  @salesforce/plugin-org \
  @salesforce/plugin-packaging \
  @salesforce/plugin-schema \
  @salesforce/plugin-settings \
  @salesforce/plugin-signups \
  @salesforce/plugin-sobject \
  @salesforce/plugin-templates \
  @salesforce/plugin-ui-bundle-dev \
  @salesforce/plugin-user \
  @salesforce/sfdx-plugin-lwc-test \
  aura-helper-sfdx \
  heat-sfdx-cli \
  kc-sf-plugin \
  lightning-flow-scanner \
  mo-dx-plugin \
  sfdmu \
  sfdx-browserforce-plugin \
  sfdx-git-delta \
  sfdx-git-packager \
  sfdx-hardis \
  sfdx-plugin-source-read \
  sfdx-plugin-update-notifier \
  shane-sfdx-plugins \
  texei-sfdx-plugin
