function git() {
	if [[ "$1" == "cd" ]]; then
		cd $(env git root)
	elif [[ "$1" == "branch" && -z "$2" ]]; then
		list-branches-with-description
	elif [[ "$1" == "comment" && -z "$2" ]]; then
		git branch --edit-description
	elif [[ "$1" == "mark" && ! -z "$2" ]]; then
		branch="$(git rev-parse --abbrev-ref HEAD)"
		comment="$(git config "branch.${branch}.description")"
		git config "branch.${branch}.description" "[${2}]${comment}"
	elif [[ "$1" == "unmark" && ! -z "$2" ]]; then
		branch=$(git rev-parse --abbrev-ref HEAD)
		comment=$(git config "branch.${branch}.description")
		git config "branch.${branch}.description" "$(echo $comment | sed "s/\[${2}\]//g")"
	elif [[ "$1" == "finish" && -z "$2" ]]; then
		git mark finished
	elif [[ "$1" == "unfinish" && -z "$2" ]]; then
		git unmark finished
  elif [[ "$1" == "pr" && "$2" == "codespell" ]]; then
		if /usr/bin/git branch | grep -E ' main$' >/dev/null; then
			branch=$(git branch --merged main)
		else
			branch=$(git branch --merged master)
		fi
    echo "Checking code for typos (git diff $branch..HEAD | grep -v ^- | codespell -):"
    git diff $branch..HEAD | grep -v ^- | codespell -
    echo "Checking commit messages for typos (git log $branch..HEAD | codespell -):"
    git log $branch..HEAD | codespell -
	else
		env git "$@"
	fi
}

function list-branches-with-description() {
  # Define colors.
	Blue='\e[01;34m'
	White='\e[01;37m'
	Red='\e[01;31m'
	Green='\e[01;32m'
	Yellow='\e[01;33m'
	Cyan='\e[01;36m'
	Pink='\e[01;35m'
	Reset='\e[0m'
	FancyX='\342\234\227'
	Checkmark='\342\234\223'

	# Get all branches.
	branches=$(git for-each-ref --format='%(refname)' refs/heads/ | sed 's|refs/heads/||')

  # Initialize lists.
	head="${White}F${Reset}|${White}PR${Reset}|${White}M${Reset}|${White}Name${Reset}|${White}References${Reset}|${White}Description${Reset}\n"
	finished_list=""
	pr_list=""
	merged_list=""
	finished_pr_list=""
	finished_pr_merged_list=""
	rest_list=""
	end_list=""

  if /usr/bin/git branch | grep -E ' main$' >/dev/null; then
    main_merged=$(git branch --merged main)
  else
    main_merged=$(git branch --merged master)
  fi

	# Loop over all branches.
	for branch in $branches; do

    # Get branch description.
  	desc=$(git config branch.$branch.description)

  	# Check if branch is finished.
      if [[ $desc =~ \[finished\] ]]; then
  	    desc=$(echo ${desc} | sed 's/\[finished\]//g')
  			finished="${Green}${Checkmark}${Reset}|"
  			finished_bool=true
  		else
  			finished="${Red}${Checkmark}${Reset}|"
  			finished_bool=false
  		fi

  		# Check if branch has PR.
  		if [[ $desc =~ \[pr\] ]]; then
  			desc=$(echo ${desc} | sed 's/\[pr\]//g')
  			pr="${Green}${Checkmark}${Reset}|"
  			pr_bool=true
  		else
  			pr="${Red}${Checkmark}${Reset}|"
  			pr_bool=false
  		fi

  		# Check if branch is merged.
  		if [[ ! -z $(echo $main_merged | grep "${branch}") ]]; then
  			merged="${Green}${Checkmark}${Reset}|"
  			merged_bool=true
	  	else
  			merged="${Red}${Checkmark}${Reset}|"
    		merged_bool=false
      fi

  		branch_raw=$branch
	  	# Check if current branch.
			other_refs_raw="$(git show $branch_raw --color -s --pretty='%C(auto)%d' --decorate-refs-exclude='refs/heads/*' --decorate=short)"
			other_refs_raw="$(echo $other_refs_raw | sed 's/^ //g')"

      other_refs="|"
      if [[ $other_refs_raw != "" ]]; then
        other_refs="${other_refs_raw}|"
      fi

      if [ $branch == $(git rev-parse --abbrev-ref HEAD) ]; then
        branch="${Green}${branch}${Reset}|${other_refs}"
      else
        branch="${White}${branch}${Reset}|${other_refs}"
  		fi

  		if [[ $branch_raw == "master" ]] || [[ $branch_raw == "main" ]]; then
  			end_list="${finished}${pr}${merged}${branch}${Blue}${desc}${Reset}\n"
  		elif [[ $finished_bool == "true" && $pr_bool == "true" && $merged_bool == "true" ]]; then
  			finished_pr_merged_list="${finished_pr_merged_list}${finished}${pr}${merged}${branch}${Blue}${desc}${Reset}\n"
  		elif [[ $finished_bool == "true" && $pr_bool == "true" ]]; then
  			finished_pr_list="${finished_pr_list}${finished}${pr}${merged}${branch}${Blue}${desc}${Reset}\n"
  		elif [[ $finished_bool == "true" ]]; then
  			finished_list="${finished_list}${finished}${pr}${merged}${branch}${Blue}${desc}${Reset}\n"
  		elif [[ $pr_bool == "true" ]]; then
  			pr_list="${pr_list}${finished}${pr}${merged}${branch}${Blue}${desc}${Reset}\n"
  		elif [[ $merged_bool == "true" ]]; then
  			merged_list="${merged_list}${finished}${pr}${merged}${branch}${Blue}${desc}${Reset}\n"
  		else
  			rest_list="${rest_list}${finished}${pr}${merged}${branch}${Blue}${desc}${Reset}\n"
  		fi
  done

  printf "$(printf "${head}${rest_list}${finished_list}${pr_list}${finished_pr_list}${finished_pr_merged_list}${merged_list}${end_list}" | column -s '|' -t)\n"
}
