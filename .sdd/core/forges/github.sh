# shellcheck shell=sh
# shellcheck disable=SC2034 # FORGE_NAME is read by the commands that load this file
# GitHub, through the gh CLI. The only file that calls gh; loaded by forge_load when the project
# config says `forge = github`. gh's built-in --jq turns its JSON into tab-separated fields, so
# sdd itself needs no jq. A PR line is: <branch> <number> <state> <review> <ci> <url> <head sha>,
# with state OPEN|MERGED|CLOSED, review the reviewDecision (or empty), and ci one of
# none | passing | pending: <names> | failing: <names>.

FORGE_NAME=GitHub
# jq for one PR object; failing beats pending beats passing.
FORGE_JQ='def bad: (.conclusion // .state // "") as $c
		| ["FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE"] | index([$c]) != null;
	def waiting: ((.status // "COMPLETED") != "COMPLETED") or ((.state // "") == "PENDING") or ((.state // "") == "EXPECTED");
	def names(f): [.[] | select(f) | (.name // .context)] | join(", ");
	[.headRefName, .number, .state, (.reviewDecision // ""),
	 (.statusCheckRollup // [] | if length == 0 then "none"
		elif any(.[]; bad) then "failing: " + names(bad)
		elif any(.[]; waiting) then "pending: " + names(waiting)
		else "passing" end),
	 .url, .headRefOid] | @tsv'
FORGE_FIELDS=headRefName,number,state,reviewDecision,statusCheckRollup,url,headRefOid

# forge_ready: gh is installed and logged in; otherwise prints how to fix it and fails.
forge_ready() {
	command -v gh >/dev/null 2>&1 || { echo "gh is not installed (https://cli.github.com)"; return 1; }
	gh auth status >/dev/null 2>&1 || { echo "gh is not logged in (run: gh auth login)"; return 1; }
}

# forge_pr_list: one PR line per pull request, newest first.
forge_pr_list() { gh pr list --state all --limit 200 --json "$FORGE_FIELDS" --jq ".[] | $FORGE_JQ"; }

# forge_pr_state <branch>: the newest PR line for that branch, or nothing.
forge_pr_state() { gh pr list --head "$1" --state all --limit 1 --json "$FORGE_FIELDS" --jq ".[] | $FORGE_JQ"; }

# forge_pr_create <branch> <base> <title> <body file>: open a PR; prints its URL.
forge_pr_create() { gh pr create --head "$1" --base "$2" --title "$3" --body-file "$4"; }

# forge_pr_edit <number> <body file>: replace the PR's body.
forge_pr_edit() { gh pr edit "$1" --body-file "$2" >/dev/null; }

# forge_pr_merge <number> <sha>: merge with a merge commit, only if the PR head is still <sha>.
forge_pr_merge() { gh pr merge "$1" --merge --match-head-commit "$2"; }
