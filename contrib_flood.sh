#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage function
usage() {
    cat << "EOF"
Usage: ./contrib_flood.sh -r <repo_url> -s <start_date> [-e <end_date>] [--fuzzy]

Options:
  -r <repo_url>     Repository URL (required).
  -s <start_date>   Start date in the format `yyyy-mm-dd` (required).
  -e <end_date>     End date in the format `yyyy-mm-dd` for using a date-range (optional).
  --fuzzy           Enable fuzzy date selection from given range (optional).
EOF
    exit 1
}

# Global variables
repo_url=""
start_date=""
end_date=""
fuzzy_mode=false
repo_name=""
formatted_dates=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r) repo_url="$2"; shift ;;
        -s) start_date="$2"; shift ;;
        -e) end_date="$2"; shift ;;
        --fuzzy) fuzzy_mode=true ;;
        *) echo -e "${RED}Unknown parameter: $1${NC}"; usage ;;
    esac
    shift
done

# Validate arguments
if [ -z "$repo_url" ] || [ -z "$start_date" ]; then
    echo -e "${RED}Repository URL and Start Date are required!${NC}"
    usage
fi

# Extract repo name from URL
repo_name=$(basename "$repo_url" .git)

# Function to format dates
get_formatted_dates() {
    if [ -z "$end_date" ]; then
        formatted_dates=("$(date -d "$start_date" +"%a %b %d 00:00 %Y %z")")
    else
        start_sec=$(date -d "$start_date" +"%s")
        end_sec=$(date -d "$end_date" +"%s")

        if [ "$start_sec" -gt "$end_sec" ]; then
            echo -e ">>${RED} Start date is after end date. Please provide a valid range.${NC}"
            exit 1
        fi

        curr=$start_sec
        while [ "$curr" -le "$end_sec" ]; do
            formatted_dates+=("$(date -d "@$curr" +"%a %b %d 00:00 %Y %z")")
            curr=$((curr + 86400)) # Increment by one day
        done
    fi
    echo -e ">>${YELLOW} Finished formatting dates${NC}"
}

# Function to apply fuzzy mode
get_fuzzy_dates() {
    if [ ${#formatted_dates[@]} -gt 1 ]; then
        echo -e ">>${BLUE} Fuzzy mode enabled${NC}"
        indices=($(shuf -i 0-$((${#formatted_dates[@]} - 1)) -n $(shuf -i 1-${#formatted_dates[@]} -n 1)))
        for index in "${indices[@]}"; do
            unset 'formatted_dates[index]'
        done
    else
        echo -e ">>${RED} Fuzzy mode is only supported for a date range${NC}"
    fi
}

# Clone repository
clone_repo_if_not_exists() {
    if [ -d "$repo_name" ]; then
        echo -e ">>${YELLOW} Git repo dir already exists, proceeding${NC}"
    else
        echo -e ">>${YELLOW} Cloning repo...${NC}"
        git clone "$repo_url"
    fi
    cd "$repo_name"

    # Initialize main branch if repository is empty
    if [ "$(git branch --show-current)" = "" ]; then
        git checkout -b main
        echo "Initialized repository" > README.md
        git add README.md
        git commit -m "Initialize repository"
        git push origin main
    fi
}

# Create dummy commits
create_dummy_commits() {
    echo -e ">>${YELLOW} Creating dummy commits for ${#formatted_dates[@]} dates, this might take a while...${NC}"
    for date in "${formatted_dates[@]}"; do
        echo "Dummy commit on $date" > dummy.txt
        git add dummy.txt
        GIT_COMMITTER_DATE="$date" git commit --date="$date" -m "Dummy commit for $date"
    done
}

# Push changes to remote
push_changes() {
    git push origin main -f > /dev/null
    if [ $? -eq 0 ]; then
        echo -e ">>${GREEN} SUCCESS!${NC}"
    else
        echo -e ">>${RED} FAILURE!${NC}"
    fi
}

# Main script execution
get_formatted_dates
if $fuzzy_mode; then get_fuzzy_dates; fi
clone_repo_if_not_exists
create_dummy_commits
push_changes
