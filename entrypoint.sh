#!/bin/sh
set -e -x

# Verify our environment variables are set
[ -z "${GIT_REPO}" ] && { echo "Need to set GIT_REPO"; exit 1; }
[ -z "${GIT_BRANCH}" ] && { echo "Need to set GIT_BRANCH"; exit 1; }
[ -z "${GIT_ORIGIN}" ] && { echo "Need to set GIT_ORIGIN"; exit 1; }
[ -z "${COMMIT_USER}" ] && { echo "Need to set COMMIT_USER"; exit 1; }
[ -z "${COMMIT_EMAIL}" ] && { echo "Need to set COMMIT_EMAIL"; exit 1; }
[ -z "${WORKING_DIR}" ] && { echo "Need to set WORKING_DIR"; exit 1; }
[ -z "${FILES_TO_COMMIT}" ] && { echo "Need to set FILES_TO_COMMIT"; exit 1; }
[ -z "${SLEEP_INTERVAL}" ] && { echo "Need to set SLEEP_INTERVAL"; exit 1; }
[ -z "${SUPPORTED_FILES}" ] && { echo "Need to set SUPPORTED_FILES"; exit 1; }
if [[ "${RESIZE_IMAGES}" == true ]]; then
	[ -z "${IMAGE_SIZE_MAX}" ] && { echo "Need to set IMAGE_SIZE_MAX"; exit 1;}
fi

# Change to our working directory
cd ${WORKING_DIR}

# Set up our SSH Key
if [ ! -d ~/.ssh ]; then
	echo "SSH Key was not found. Configuring SSH Key."
	mkdir ~/.ssh
	cat /ssh/id_rsa > ~/.ssh/id_rsa
	chmod 700 ~/.ssh
	chmod 600 ~/.ssh/id_rsa

	echo -e "Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile=/dev/null\n" > ~/.ssh/config
fi

# Check to see if the given directory already has an initialized
# git repository.
if [ ! -d "${WORKING_DIR}/.git" ]; then
	echo "Git repository not found. Initializing repository."
	git init
	git config --global --add safe.directory ${WORKING_DIR}
	git config --global init.defaultBranch main
	git remote add ${GIT_ORIGIN} ${GIT_REPO}
	git fetch
	git checkout -t ${GIT_ORIGIN}/${GIT_BRANCH}
fi

git config --global --add safe.directory ${WORKING_DIR}
# Configure our user and email to commit as.
git config user.name "${COMMIT_USER}"
git config user.email "${COMMIT_EMAIL}"

# Loop forever and push new changes at the given interval
while true; do
	# Sleep for the given interval.
	sleep ${SLEEP_INTERVAL}

	# Reset our variable for checking whether or not changes were found.
	CHANGES_FOUND=""

	# Check to see if there are changes
	CHANGES=`git status -s | cut -c 4-`
	if [ -z "${CHANGES}" ]; then
		echo "No changes detected."
		#safely pull if no changes
		git pull --rebase
		continue
	fi

	#Loop through changed files and scrub EXIF
	IFS=$'\n' # make newlines the only separator
	for CHANGED_FILE in ${CHANGES}; do
		CHANGED_FILE_EXT=`echo "${CHANGED_FILE##*.}" | tr '[:upper:]' '[:lower:]'` #extract file extension and convert to lowercase
		if [[ -f ${CHANGED_FILE} ]]; then #check if file exists
			if [[ ${SUPPORTED_FILES} == "*${CHANGED_FILE_EXT}*" ]]; then #check if filetype is supported
				if [[ ${RESIZE_IMAGES} == true ]]; then #Check if resize is enabled
					if [[ ${CHANGED_FILE} == "*_hires." ]]; then #check if tagged hires
						echo "Image tagged as hires. Skipping resize."
					else
						magick ${CHANGED_FILE} -resize ${IMAGE_SIZE_MAX}x${IMAGE_SIZE_MAX}\> ${CHANGED_FILE} #Resize image
					fi
				fi
				exiftool -all= -P --icc_profile:all -overwrite_original -tagsfromfile @ -Orientation -colorspacetags ${CHANGED_FILE}	#Remove EXIF data
			else
				echo "Filetype not supported for resize and EXIF removal:" ${CHANGED_FILE}
			fi
		else
			echo "File doesn't exist anymore:" ${CHANGED_FILE}
		fi
	done

	# Check to see if we need to commit all.
	if [[ "${FILES_TO_COMMIT}" == "." ]]; then
		git add .
		CHANGES_FOUND="1"
	fi

	# Loop through our files to commit and see if we need to commit them.
	for changed_file in ${CHANGES}; do
		for watched_file in ${FILES_TO_COMMIT}; do
			if [[ "${changed_file}" == "${watched_file}" ]]; then
				CHANGES_FOUND="1"
				git add ${changed_file}
			fi
		done
	done

	# Commit and push the detected changes if they are found.
	if [ ! -z "${CHANGES_FOUND}" ]; then
		echo "Changes detected."
		git commit -m "Update detected changes."

		#pull after commit
		git pull --rebase
		git push ${GIT_ORIGIN} ${GIT_BRANCH}
	fi
done
