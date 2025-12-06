# docker-git-exif-resize
This is a fork of [docker-git-pull-push](https://github.com/skwinnik/docker-git-pull-push), but with the added functionality of resizing images and scrubbing potentially sensitive EXIF data before uploading.
*I am ***not*** a programmer, but can sometimes bash together bits of code until they work. This is the result of many hours of fumbling. It works for me, but please use this with caution and expect it to break.*

## Why make this?
I use [Obsidian](https://obsidian.md/} along with [Quartz](https://quartz.jzhao.xyz/) for my website, and want to have any changes I make locally automatically update my site with minimal friction. The original git-push-pull was great for syncing, but didn't address 2 concerns I had about adding images to my content.

### 1. EXIF metadata privacy
If I embed a photo taken on my phone, I want to make sure the file doesn't include any personally identifying data. [Geotagged](https://en.wikipedia.org/wiki/Geotagging) GPS coordinates of my home, for example.
This is accomplished using an [ExifTool](https://exiftool.org/), which scrubs ALL EXIF metadata from the image except colorspace and orientation (image rotation) data.

### 2. Image Resizing
I also don't necessarily need or want images to be full resolution, so all images are resized to set the long side to `IMAGE_MAX_SIZE`. This is done with [ImageMagick](https://imagemagick.org/).
However, I might want larger images *sometimes*, so resizing is skipped if the filename ends in "_hires".

Crucially, both operations are done BEFORE committing or pushing the images, so that there should be no images in the commit history still containing sensitive data or unnecessarily using up your [repository limit](https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits).

***PLEASE NOTE THAT THIS SCRIPT MODIFIES THE LOCAL IMAGES IN THE WORKING DIRECTORY***
If you don't want to lose the original image size and exif data, *copy* images into the working directory, leaving the originals safely elsewhere.

## Setup
1. [Generate an SSH key on your local machine](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).
2. [Deploy the key to your repo](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys). The [ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) method might also work, but I haven't tried it.
3. Build the Docker image (see below)
4. Run it! 

## Build it!
To build the Docker image, clone the repository, navigate to the repo directory, and run:
```
docker build -t "git-exif-resize:latest" .
```

## Run it!
### Variables
- `GIT_REPO` - The URL of the github repository. Should be in the format `ssh://git@github.com/user/repository.git`
- `GIT_BRANCH`- Defaults to `master`
- `GIT_ORIGIN` - Defaults to `origin`
- `COMMIT_USER` - Your GitHub username.
- `COMMIT_EMAIL` - Your GitHub email.
- `WORKING_DIR` - Working directory inside the container. Defaults to `/git` I recommend leaving this default and binding to an external directory.
- `FILES_TO_COMMIT` - List of files to commit. Defaults to `.` which will commit all files in the working directory.
- `SLEEP_INTERVAL` - Time in seconds between checks for file updates. Defaults to `600` (10 min)
- `SUPPORTED_FILES` - Comma separated list of image file extensions that the EXIF scrubbing and resizing script will look for in the working directory. Defaults to `png,jpg,jpeg,gif`. Currently, I've only tested these 4. ExifTools and ImageMagick can support many more. If you want to try other, you can add them here and see what happens!
- `RESIZE_IMAGES` - Boolean to enable image resizing. Defaults to `true`
- `IMAGE_SIZE_MAX` - Maximum pixel length/width of images. Images will be resized so that the long side is equal to this value. Defaults to "800"

### Docker Compose
```
services:
    git-exif-resize:
        image: git-exif-resize:latest
        container_name: git-exif-resize
        environment:
            - GIT_REPO=ssh://git@github.com/user/repository.git
            - GIT_BRANCH=master
            - GIT_ORIGIN=origin
            - COMMIT_USER=Username
            - COMMIT_EMAIL=git@example.com
            - WORKING_DIR=/git
            - FILES_TO_COMMIT=.
            - SLEEP_INTERVAL=600
            - SUPPORTED_FILES=png,jpg,jpeg,gif
            - RESIZE_IMAGES=true
            - IMAGE_SIZE_MAX=800
        volumes:
            - type: bind
              source: "/path/to/git/repo" # Path to the git repo on the local machine from which changes will be pushed.
              target: /git
            - type: bind
              source: "/path/to/ssh" # Path to the folder on local machine containing the id_rsa SSH key
              target: /ssh
        restart: unless-stopped
```

### Docker Run Command
```
docker run --name git-push -d  \
    -e GIT_REPO="ssh://git@github.com/user/repository.git" \
    -e GIT_BRANCH="master" \
    -e GIT_ORIGIN="origin" \
    -e COMMIT_USER="Username" \
    -e COMMIT_EMAIL="git@example.com" \
    -e WORKING_DIR="/git" \
    -e FILES_TO_COMMIT="." \
    -e SLEEP_INTERVAL="800" \
	-e SUPPORTED_FILES="png,jpg,jpeg,gif" \
	-e RESIZE_IMAGES="true" \
	-e IMAGE_SIZE_MAX="800" \
    -v /path/to/git/repo:/git \
    -v /path/to/ssh:/ssh git-push:latest
```
