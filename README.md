# GitLab Job Artifacts Cleaner

Bash script to delete your GitLab job artifacts

## Pre-requisite

- [jq](https://stedolan.github.io/jq/download/)
- GitLab token that has the `api` scope

## How to Use

1. Clone the repo
2. Run `export GITLAB_TOKEN=<paste your token here>`
3. Run `./cleaner.sh -p <project path e.g. group1/project1> -f <from date e.g. 2022-01-01> -t <till date e.g. 2022-06-01> -s <server url e.g. https://gitlab.com>`