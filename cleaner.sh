#!/bin/bash

source ./progress_bar.sh

main() {
  server=$1
  project=$2
  from=$3
  to=$4

  gitlab_graphql_url=$server/api/graphql

  has_next_page=true
  end_cursor=

  while $has_next_page; do
    project_response=$(curl -s -w %{http_code} \
      -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $GITLAB_TOKEN" \
      -d "$(jq -c -n --arg query "
    {
      project(fullPath: \"$project\") {
        id
        pipelines(updatedBefore: \"$to\", updatedAfter: \"$from\", after: \"$end_cursor\") {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            jobs {
              nodes {
                id
                name
                stage {
                  name
                },
                artifacts {
                  nodes {
                    name
                  }
                }
              }
            }
          }
        }
      }
    }" '{"query":$query}')" \
      $gitlab_graphql_url)

    # last 3 characters is the status code
    project_response_body=${project_response:0:$((${#project_response} - 3))}
    project_response_status_code=${project_response:$((${#project_response} - 3)):$((${#project_response}))}

    has_next_page=$(echo "$project_response_body" | jq -r '.data.project.pipelines.pageInfo.hasNextPage')
    end_cursor=$(echo "$project_response_body" | jq -r '.data.project.pipelines.pageInfo.endCursor')

    project_json=$(echo "$project_response_body" | jq -r '.data.project')
    project_id=$(echo "$project_json" | jq -r '.id' | sed 's/gid:\/\/gitlab\/Project\///')

    pipeline_count=$(echo "$project_json" | jq -r '.pipelines.nodes | length')

    # Make sure that the progress bar is cleaned up when user presses ctrl+c
    enable_trapping
    # Create progress bar
    setup_scroll_area

    if [[ $pipeline_count > 0 ]]; then
      for p in $(seq 0 $(($pipeline_count - 1))); do
        draw_progress_bar $((p * 100 / pipeline_count))

        pipeline_json=$(echo "${project_json}" | jq -r ".pipelines.nodes[$p]")
        pipeline_id=$(echo "${pipeline_json}" | jq -r ".id" | sed 's/gid:\/\/gitlab\/Ci::Pipeline\///')

        echo "======= Processing pipeline $pipeline_id ======="

        job_count=$(echo "${pipeline_json}" | jq -r ".jobs.nodes | length")

        echo "Found ${job_count} jobs"

        if [[ $job_count > 0 ]]; then
          for j in $(seq 0 $(($job_count - 1))); do
            job_json=$(echo "${pipeline_json}" | jq -r ".jobs.nodes[$j]")
            job_id=$(echo "${job_json}" | jq -r ".id" | sed 's/gid:\/\/gitlab\/Ci::Build\///')
            artifact_count=$(echo "${job_json}" | jq -r ".artifacts.nodes | length")

            if [[ $artifact_count == 0 ]]; then
              echo "Skipping processing, no artifacts to remove"
            else
              echo "Job $job_id has $artifact_count artifacts"

              delete_response=$(curl -s -w %{http_code} \
                -X POST \
                -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
                $server/api/v4/projects/$project_id/jobs/$job_id/erase)
              delete_response_body=${delete_response:0:$((${#delete_response} - 3))}
              delete_response_status_code=${delete_response:$((${#delete_response} - 3)):$((${#delete_response}))}

              echo $delete_response_status_code
            fi
          done
        fi

        echo -e "======= End =======\n"
      done
    else
      has_next_page=false
      echo "No pipeline found within this period $from - $to"
    fi

    destroy_scroll_area
  done
}

# get inputs
while getopts p:f:t:s: flag; do
  case "${flag}" in
  p) project=${OPTARG} ;;
  f) from=${OPTARG} ;; # inclusive
  t) to=${OPTARG} ;;   # exclusive
  s) server=${OPTARG} ;;
  esac
done

main $server $project $from $to
