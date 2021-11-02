#!/bin/bashf
set -euo pipefail

function validate_path {
    echo "Running validate_path"
    if [[ -z "$sql_path" ]]; then
      echo "Usage: $0 Missing path parameter -p" >&2
      usage
      exit 1
    fi

    if [[ ! -e "$sql_path" ]]; then
      echo "Given SQL path ($sql_path) does not exist" >&2
      exit 1
    fi

    if [[ ! -f "$sql_path" ]]; then
      echo "Given SQL path ($sql_path) is not a file" >&2
      exit 1
    fi
}

function validate_sql {
    echo "Running validate_sql"
    for trigger_word in delete insert update; do
    if context="$(cat "$sql_path" | grep -C2 --colour=always -i "$trigger_word")"; then
        echo '---' >&2
        echo "$context" >&2
        echo '---' >&2
        echo >&2
        echo "$sql_path contains a dangerous word ($trigger_word) 😱" >&2
        echo 'Please review the diff and confirm execution.' >&2
        echo >&2

        select reply in Continue Abort ; do
        if [[ "$reply" = 'Abort' ]]; then
            echo 'Aborting' >&2
            exit 1
        fi
        break
        done
    fi
    done
}

function run_sql {
    local set_params_sql="set @health_board='^(?:$board_regex)$';"
    echo "Running SQL with addition sql: ${set_params_sql}"
    { echo -n "$set_params_sql"; cat "$sql_path"; } \
    | docker run -i --rm mariadb mariadb \
        --host "$DATABASE_HOST" \
        --user "$DATABASE_USER" \
        -p"$DATABASE_PASS" \
        openeyes \
        > "$temp_filepath"
}

function zip_and_send_to_aws {
    echo "Running zip_and_send_to_aws"
    # Zip the output

    local output_name=$(basename "$temp_filepath" ".tsv")
    local output_zip_path="$PWD/$output_name.zip"
    local zip_password="$(head -c8 /dev/urandom | base64)"
    zip --encrypt --junk-paths --password="$zip_password" "$output_zip_path" "$temp_filepath"

    s3_path="s3://$BUCKET/audit/"
    echo "Uploading to S3 at $s3_path" >&2
    aws s3 cp "$output_zip_path" "$s3_path"
    rm "$output_zip_path"
    echo "Removed zip file $output_zip_path" >&2
    echo "Wrote $s3_path$output_name (password: $zip_password)" >&2
}

function create_user_lists {
    python3 createLists.py $board_name $temp_filepath
}

function clean_up_tempt_file {
    echo "Running clean_up_tempt_file"
    # Finish up
    rm "$temp_filepath"
    temp_filepath=""
    echo "Removed temporary file $temp_filepath" >&2
}

function create_temp_file {
  temp_filepath="$(mktemp -d)/users_$board_name.tsv"
  echo "Created temporary file $temp_filepath" >&2
}

function run_script_per_board {
    # Run the query
    echo "Running run_script_per_board"
    for board_config in "${BOARDS_CONFIG[@]}"
    do
      IFS=';' read -ra CONFIG_ARRAY <<< "$board_config"
      local board_name=${CONFIG_ARRAY[0]}
      local board_regex=${CONFIG_ARRAY[1]}
      create_temp_file
      run_sql
      #zip_and_send_to_aws
      create_user_lists
      clean_up_tempt_file
    done
}


# Global variables
sql_path="./getUsers.sql"
set_params_sql=""
temp_filepath=""
config_path="./config.sh"

BOARDS_CONFIG=("Grampian;NHS Grampian|NHSGrampian|NHSG" "Forth_Valley;NHS Forth Valley|NHSFV")

validate_path
validate_sql
run_script_per_board