#!/bin/bash
COLOR_INFO="\033[1;34m"
COLOR_ERROR="\033[1;31m"
COLOR_WARNING="\033[1;33m"
COLOR_RESET="\033[0m"

log_info() {
	echo -e "${COLOR_INFO}$1${COLOR_RESET}"
}

log_error() {
	echo -e "${COLOR_ERROR}$1${COLOR_RESET}" >&2
}

log_warning() {
	echo -e "${COLOR_WARNING}$1${COLOR_RESET}"
}

log_normal() {
	echo -e "$1"
}

ISSUE_JSON=
GITHUB_ORG=tonydail
GITHUB_REPO=microservices-ops

display-help() {
	echo "Available Commands:"
	echo "  git-checkout <branch>   Checkout to the specified branch."
	echo "  git-commit <message>     Commit changes with the specified message."
	echo "  github-load-issue-details <issue_number>   Load issue details from GitHub."
	echo "  github-get-issue-title   Get the title of the loaded issue."
	echo "  github-get-issue-labels  Get the labels of the loaded issue."
	echo "  github-issue-is-enhancement   Check if the loaded issue is an enhancement."
	echo "  github-issue-is-bug      Check if the loaded issue is a bug."
	echo "  github-issue-is-hotfix   Check if the loaded issue is a hotfix."
}

is_direct_function_call() {
	local caller="$1"
	if [[ -z "$caller" || "$caller" == "main" || "$caller" == "source" ]]; then
		return 0 # True: It is a direct call
	else
		return 1 # False: It was called by another function
	fi
}

# Start GitHub Specific Functions
github-load-issue-details-json() {
	if is_direct_function_call "${FUNCNAME[1]}"; then
		display-help
		return 1
	fi

	if [ -z "$1" ]; then
		echo "Unable to load issue details: issue number is required."
		return 1
	fi

	if [ -z "$ISSUE_JSON" ]; then

		local issue_number="$1"
		ISSUE_JSON=$(gh issue view "$issue_number" --repo $GITHUB_ORG/$GITHUB_REPO --json title,labels,body)
	fi
}

github-issue-has-label() {
	if is_direct_function_call "${FUNCNAME[1]}"; then
		display-help
		return 1
	fi

	local label="$1"
	if [ -z "$label" ]; then
		echo "Label is required."
		return 1
	fi

	local labels
	labels=$(github-get-issue-labels)
	if echo "$labels" | grep -q "$label"; then
		return 0 # Label exists
	else
		return 1 # Label does not exist
	fi
}

github-display-issue-details() {
	local issue_number="$1"
	gh issue view "$issue_number" --repo $GITHUB_ORG/$GITHUB_REPO
}

github-get-issue-title() {
	if is_direct_function_call "${FUNCNAME[1]}"; then
		display-help
		return 1
	fi
	echo "$ISSUE_JSON" | jq -r '.title'
}

github-get-issue-labels() {
	if is_direct_function_call "${FUNCNAME[1]}"; then
		display-help
		return 1
	fi
	echo "$ISSUE_JSON" | jq -r '.labels[].name'
}

github-get-issue-type() {
	if is_direct_function_call "${FUNCNAME[1]}"; then
		display-help
		return 1
	fi
	if github-issue-has-label "feature"; then
		echo "feature"
	elif github-issue-has-label "bug"; then
		echo "bugfix"
	elif github-issue-has-label "hotfix"; then
		echo "hotfix"
	else
		echo "unknown"
	fi
}

github-issue-list() {
	if is_direct_function_call "${FUNCNAME[1]}"; then
		display-help
		return 1
	fi
	gh issue list --repo $GITHUB_ORG/$GITHUB_REPO
}

github-verify-issue-exists() {
	if is_direct_function_call "${FUNCNAME[1]}"; then
		display-help
		return 1
	fi
	local issue_number="$1"
	if [ -z "$issue_number" ]; then
		echo "Issue number is required."
		return 1
	fi

	if gh issue view "$issue_number" --repo $GITHUB_ORG/$GITHUB_REPO >/dev/null 2>&1; then
		return 0 # Issue exists
	else
		return 1 # Issue does not exist
	fi
}


# End GitHub Specific Functions

# Start Git Functions

git-get-current-branch() {
	echo "$(git rev-parse --abbrev-ref HEAD)"
}

git-does-branch-exist() {
	local branch="$1"
	if git rev-parse --verify "$branch" >/dev/null 2>&1; then
		return 0 # Branch exists
	else
		return 1 # Branch does not exist
	fi
}

git-is-worktree-clean() {
	if [ -z "$(git status --porcelain)" ]; then
		return 0 # Clean
	else
		return 1 # Not clean
	fi
}

git-already-on-branch() {
	local branch="$1"
	local current_branch
	current_branch=$(git-get-current-branch)
	if [ "$current_branch" == "$branch" ]; then
		return 0 # Already on the branch
	else
		return 1 # Not on the branch
	fi
}

# End Git Functions

get-full-commit-message() {
	local commit_message="$1"
	local issue_number="$2"
	if [ -z "$issue_number" ]; then
		echo ""
	else
		echo " (#$issue_number)"
	fi
	local full_commit_message="${commit_message} (${GITHUB_ORG}/${GITHUB_REPO}-#${issue_number})"
	echo "$full_commit_message"

}

infer-issue-key-from-branch() {
	local current_branch
	current_branch=$(git-get-current-branch)
	if [[ "$current_branch" =~ ^(feature|bugfix|hotfix)/([0-9]+)- ]]; then
		echo "${BASH_REMATCH[2]}"
	else
		echo ""
	fi
}

format-branch-name() {
	local issue_number="$1"
	local issue_type="$2"
	local title="$3"
	local branch_name="${issue_type}/${issue_number}-$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
	echo "$branch_name"
}

git-checkout() {
	local branch="$1"
	local base_branch="${2:-develop}" # Default to 'develop' if not provided
	if git rev-parse --verify "$branch" >/dev/null 2>&1; then
		git checkout "$branch"
	else
		git checkout -b "$branch" "$base_branch"
	fi
}

# Helper function to handle git commit with orgname/ops-repo-#issue key in the message
# Checks that the current branch is not a protected branch (develop, main, master) and that the issue key can be inferred from the branch name.
# If the checks pass, it prompts the user to confirm that they have staged their changes before committing.
git-commit() {
	local issue_key
	local current_branch
	current_branch=$(git-get-current-branch)
	if [ "$current_branch" == "develop" ] || [ "$current_branch" == "main" ] || [ "$current_branch" == "master" ]; then
		log_warning "You are on the '$current_branch' protected branch. Commits can only be made from a feature/bugfix/hotfix branch."
		return 1
	fi
	issue_key=$(infer-issue-key-from-branch)
	if [ -z "$issue_key" ]; then
		log_warning "Unable to infer issue key from the current branch. Please ensure you are on a branch that follows the naming convention: <type>/<issue_number>-<description>."
		return 1
	fi

	command git status

	log_info "Ensure that you have staged your changes before committing. Use 'git add <files>' to stage changes."
	log_info "Continue with commit? (y/n)"
	read -r response
	if [[ "$response" != "y" && "$response" != "Y" ]]; then
		log_warning "Aborting commit."
		return 1
	fi
	local message="$1"

	message=$(get-full-commit-message "$message" "$issue_key")

	command git commit -m "$message"
}

# Helper function to start work on a GitHub issue by creating a new branch based on the issue type and title.
# It checks if the issue exists, verifies that it has the "ready-to-start" label, and prompts the user for confirmation before creating the branch.
# It also checks if the current working tree is clean before switching branches.
# The branch name is formatted as <issue_type>/<issue_number>-<issue_title>.
# The base branch can be specified as an optional second argument, defaulting to "develop" if not provided.
# Checks are made to ensure that the user is not already on the target branch and that the branch does not already exist before creating it.
start-work() {
	ISSUE_JSON=
	local issue_key=
	local base_branch=

	if [ -z "$1" ]; then
		github-issue-list
		log_info "Please provide an issue number to start work on."
		log_info "Usage: start-work <issue_number>"
		return 1
	else
		clear
		echo ""
		echo ""
		issue_key="$1"
		base_branch="${2:-develop}" # Default to 'develop' if not provided

		if ! github-verify-issue-exists "$issue_key"; then
			log_error "Issue #$issue_key does not exist in the repository $GITHUB_ORG/$GITHUB_REPO."
			return 1
		fi

		github-display-issue-details "$issue_key"

		github-load-issue-details-json "$issue_key"
		if ! github-issue-has-label "ready-to-start"; then
			log_warning "Issue #$issue_key: '$(github-get-issue-title)' is NOT labeled as 'ready-to-start'. Please ensure the issue is ready before starting work."
			return 1
		fi


		echo "Start work on this issue? (y/n)"
		read -r response
		if [[ "$response" != "y" && "$response" != "Y" ]]; then
			log_info "Aborting start work on issue #$issue_key."
			return 1
		fi


		local issue_type=$(github-get-issue-type)
		if [ "$issue_type" == "unknown" ]; then
			log_error "Unable to determine issue type for issue #$issue_key. Please ensure the issue has a valid label (enhancement, bug, hotfix)."
			return 1
		fi

		local title
		local branch_name
		title=$(github-get-issue-title)

		branch_name=$(format-branch-name "$issue_key" "$issue_type" "$title")

		if git-already-on-branch "$branch_name"; then
			log_info "You are already on the branch '$branch_name'."
			return 0
		fi

		if git-does-branch-exist "$branch_name"; then
			log_info "Branch '$branch_name' already exists. Switching to that branch..."
			if ! git-is-worktree-clean; then
				log_warning "Warning: Your working tree is not clean. Please commit or stash your changes before switching branches and call start-work again."
				return 1
			fi
			git-checkout "$branch_name"
			return 0
		fi

		log_info "Branch '$branch_name' will be created from the base branch: '$base_branch'"
		log_info "Continue? (y/n)"
		read -r response
		if [[ "$response" != "y" && "$response" != "Y" ]]; then
			log_error "Aborting start work on issue #$issue_key."
			return 1
		fi

		if ! git-is-worktree-clean; then
			log_warning "Your working tree is not clean. Please commit or stash your changes before switching branches and call start-work again."
			return 1
		fi

		git-checkout "$branch_name" "$base_branch"

		log_info "Ready to work on issue #$issue_key: $title"

		ISSUE_JSON=
	fi

	return 0
}

# Override the git commit command to include issue key in the commit message
# Other git commands will be passed through to the original git command
git() {
	if [ "$1" == "commit" ]; then
		local msg=""
		shift

		while [ "$#" -gt 0 ]; do
			if [ "$1" = "-m" ] && [ -n "$2" ]; then
				msg="$2"
				shift 2
			else
				# Collect any other flags if passed, or just step forward
				shift
			fi
		done

		git-commit "$msg"
	else
		command git "$@"
	fi
}
