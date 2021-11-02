#!/bin/bashf
set -euo pipefail

function validate_path {
    echo "Running validate_path"
    if [[ -z "$input_file" ]]; then
      echo "Usage: $0 Missing path parameter -p" >&2
      usage
      exit 1
    fi

    if [[ ! -e "$input_file" ]]; then
      echo "Given SQL path ($input_file) does not exist" >&2
      exit 1
    fi

    if [[ ! -f "$input_file" ]]; then
      echo "Given SQL path ($input_file) is not a file" >&2
      exit 1
    fi
}

function zip_and_send_to_aws {
    echo "Running zip_and_send_to_aws"
    # Zip the output

    local output_name=$(basename "$temp_sql_filepath" ".tsv")
    local output_zip_path="$PWD/$output_name.zip"
    local zip_password="$(head -c8 /dev/urandom | base64)"
    zip --encrypt --junk-paths --password="$zip_password" "$output_zip_path" "$temp_sql_filepath"

    s3_path="s3://$BUCKET/audit/"
    echo "Uploading to S3 at $s3_path" >&2
    aws s3 cp "$output_zip_path" "$s3_path"
    rm "$output_zip_path"
    echo "Removed zip file $output_zip_path" >&2
    echo "Wrote $s3_path$output_name (password: $zip_password)" >&2
}

function clean_up_tempt_file {
    echo "Running clean_up_tempt_file"
    # Finish up
    rm "$temp_sql_filepath"
    temp_sql_filepath=""
    echo "Removed temporary file $temp_sql_filepath" >&2
}

function create_temp_file {
  temp_sql_filepath="$(mktemp -d)/update.sql"
  echo "Created temporary file $temp_sql_filepath" >&2
}

# Global variables
input_file=""
temp_sql_filepath=""
options=":p:" # p for Path

usage() { echo "$0 usage:" && grep " .)\ #" $0; exit 0; }
while getopts $options opt; do
  case $opt in
    p) # SQL Path. Defines the path to the SQL script that we want to run. Optional (default: ./audit.sql)
      input_file=${OPTARG} ;;
    :)
      echo "Missing option argument for -$OPTARG" >&2;
      usage
      exit 1;;
    \?)
      echo "Unknown option: -$OPTARG" >&2;
      usage
      exit 1;;
    *)
      echo "Error parsing options: -$OPTARG" >&2;
      usage
      exit 1;;
    
  esac
done

validate_path

# Create a temporary empty SQL file to populate
create_temp_file

# Use a python script to parse out the accepted list and turn this into an SQL script to be run in next step
python3 generateSQL.py $input_file $temp_sql_filepath

{ cat "$temp_sql_filepath"; } \
| docker run -i --rm mariadb mariadb \
    --host "$DATABASE_HOST" \
    --user "$DATABASE_USER" \
    -p"$DATABASE_PASS" \
    openeyes \

clean_up_tempt_file