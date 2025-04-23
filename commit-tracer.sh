#!/bin/bash

TARGET_DIR="."
SORT_MODE="none"
FILTER_BRANCH=""
EXCLUDE_BRANCH=""

# Resolve the current directory name if TARGET_DIR is "."
resolve_dir_name() {
    if [[ "$1" == "." ]]; then
        basename "$(pwd)"
    else
        basename "$1"
    fi
}

# Display help message
show_help() {
    echo "Usage: $(basename "$0") [options] [directory]"
    echo
    echo "Options:"
    echo "  -s,  --sort             Sort output by date in ascending order"
    echo "  -S,  --SORT             Sort output by date in descending order"
    echo "  -fb, --filter-branch    Show only commits from the specified branch"
    echo "  -eb, --exclude-branch   Exclude commits from the specified branch"
    echo "  -h,  --help             Display this help message"
    echo
    echo "If no directory is specified, the current directory is used."
    exit 0
}

# Parse optional parameters
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -s|--sort)
            if [[ -n "$2" && "$2" != -* ]]; then
                echo "Warning: No input is required for sorting. Sorting is based on repository commit dates."
                exit 1
            fi
            SORT_MODE="asc"
            shift
            ;;
        -S|--SORT)
            if [[ -n "$2" && "$2" != -* ]]; then
                echo "Warning: No input is required for sorting. Sorting is based on repository commit dates."
                exit 1
            fi
            SORT_MODE="desc"
            shift
            ;;
        -fb|--filter-branch)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: No branch provided for filtering. Please specify a branch name."
                exit 1
            fi
            FILTER_BRANCH="$2"
            shift
            ;;
        -eb|--exclude-branch)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: No branch provided for exclusion. Please specify a branch name."
                exit 1
            fi
            EXCLUDE_BRANCH="$2"
            shift
            ;;
        -h|--help) show_help ;;
        *) TARGET_DIR="$1" ;;
    esac
    shift
done

# Check if the specified directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: The specified directory '$TARGET_DIR' does not exist."
    exit 1
fi

# Resolve the directory name for display
DIR_NAME=$(resolve_dir_name "$TARGET_DIR")

REPOS=()

# Collect valid Git repos
for dir in "$TARGET_DIR"/*/; do
    [ -d "$dir/.git" ] && REPOS+=("$dir")
done

# Apply branch filtering to calculate the actual total
FILTERED_REPOS=()
for dir in "${REPOS[@]}"; do
    cd "$dir" || continue

    latest_commit=$(git for-each-ref --sort=-committerdate \
        --format="%(refname:short)|%(objectname:short)|%(subject)|%(authorname)|%(committerdate:iso8601)" \
        refs/remotes/origin/ | head -n 1)

    full_branch=$(echo "$latest_commit" | cut -d'|' -f1)
    branch=$(git rev-parse --abbrev-ref "$full_branch" 2>/dev/null || echo "$full_branch")
    branch=$(echo "$branch" | awk '{gsub(/^origin\//, ""); print}')

    # Apply branch filtering
    if [[ -n "$FILTER_BRANCH" && "$branch" != "$FILTER_BRANCH" ]]; then
        cd - > /dev/null
        continue
    fi

    if [[ -n "$EXCLUDE_BRANCH" && "$branch" == "$EXCLUDE_BRANCH" ]]; then
        cd - > /dev/null
        continue
    fi

    FILTERED_REPOS+=("$dir")
    cd - > /dev/null
done

# Update TOTAL to reflect the filtered repositories
TOTAL=${#FILTERED_REPOS[@]}
CURRENT=0
OUTPUT=()

echo "Fetching most recent commits from $TOTAL repositories in: $DIR_NAME"
echo

# Progress bar
show_progress() {
    percent=$(( CURRENT * 100 / TOTAL ))
    bar_length=$(( percent / 2 ))
    bar=$(printf "%${bar_length}s" | tr ' ' '#')
    printf "\rProgress: [%-50s] %3d%%" "$bar" "$percent"
}

# Extract latest commit info per repo
for dir in "${FILTERED_REPOS[@]}"; do
    cd "$dir" || continue

    repo_name=$(basename "$(pwd)")
    git fetch --quiet --all

    latest_commit=$(git for-each-ref --sort=-committerdate \
        --format="%(refname:short)|%(objectname:short)|%(subject)|%(authorname)|%(committerdate:iso8601)" \
        refs/remotes/origin/ | head -n 1)

    full_branch=$(echo "$latest_commit" | cut -d'|' -f1)
    branch=$(git rev-parse --abbrev-ref "$full_branch" 2>/dev/null || echo "$full_branch")
    branch=$(echo "$branch" | awk '{gsub(/^origin\//, ""); print}')
    commit_hash=$(echo "$latest_commit" | cut -d'|' -f2)
    commit_title=$(echo "$latest_commit" | cut -d'|' -f3)
    author_name=$(echo "$latest_commit" | cut -d'|' -f4)
    commit_datetime=$(echo "$latest_commit" | cut -d'|' -f5)
    commit_date=$(date -d "$commit_datetime" "+%Y-%m-%d %H:%M")

    # Store full record with sortable date
    OUTPUT+=("$repo_name|$branch|$commit_hash - $commit_title ($author_name)|$commit_date")

    cd - > /dev/null
    CURRENT=$((CURRENT + 1))
    show_progress
done

# Ensure the progress bar reaches 100%
show_progress

echo -e "\n\nFormatted Output:\n"

# Sort if needed
if [[ "$SORT_MODE" == "asc" ]]; then
    IFS=$'\n' OUTPUT=($(printf "%s\n" "${OUTPUT[@]}" | sort -t'|' -k4,4))
elif [[ "$SORT_MODE" == "desc" ]]; then
    IFS=$'\n' OUTPUT=($(printf "%s\n" "${OUTPUT[@]}" | sort -t'|' -k4,4r))
fi

# Check if OUTPUT is empty
if [[ ${#OUTPUT[@]} -eq 0 ]]; then
    echo "No results to show."
    exit 0
fi

# Compute column widths
max_repo=0
max_branch=$(printf "Branch" | wc -c)  # Ensure the minimum width is the header length
max_commit=0
max_date=$(printf "Date" | wc -c)      # Ensure the minimum width is the header length

for line in "${OUTPUT[@]}"; do
    repo=$(echo "$line" | cut -d'|' -f1)
    branch=$(echo "$line" | cut -d'|' -f2)
    commit=$(echo "$line" | cut -d'|' -f3)
    date=$(echo "$line" | cut -d'|' -f4)

    [ ${#repo} -gt $max_repo ] && max_repo=${#repo}
    [ ${#branch} -gt $max_branch ] && max_branch=${#branch}
    [ ${#commit} -gt $max_commit ] && max_commit=${#commit}
    [ ${#date} -gt $max_date ] && max_date=${#date}
done

# Header
printf "%-${max_repo}s | %-${max_branch}s | %-${max_commit}s | %s\n" "Repository" "Branch" "Last Commit" "Date"
printf "%-${max_repo}s-+-%-${max_branch}s-+-%-${max_commit}s-+-%s\n" "$(printf '─%.0s' $(seq 1 $max_repo))" \
                                                                "$(printf '─%.0s' $(seq 1 $max_branch))" \
                                                                "$(printf '─%.0s' $(seq 1 $max_commit))" \
                                                                "$(printf '─%.0s' $(seq 1 $max_date))──"  

# Aligned Output
for line in "${OUTPUT[@]}"; do
    repo=$(echo "$line" | cut -d'|' -f1)
    branch=$(echo "$line" | cut -d'|' -f2)
    commit=$(echo "$line" | cut -d'|' -f3)
    date=$(echo "$line" | cut -d'|' -f4)

    printf "%-${max_repo}s | %-${max_branch}s | %-${max_commit}s | [%s]\n" "$repo" "$branch" "$commit" "$date"
done