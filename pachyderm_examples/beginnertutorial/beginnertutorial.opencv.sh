#!/bin/bash

# beginnertutorial.opencv.sh

function usage {
  echo "Usage: beginnertutorial.opencv.sh"
  echo "-d: delete all pachyderm resources for tutorial"
  echo "-h: help"
  echo "-i: interactive prompt to continue after each step"
  echo "-z: timezone, default ${defaults[timezone]}"
  echo "Examples:"
  echo "beginnertutorial.opencv.sh"
  echo "beginnertutorial.opencv.sh -i"
  echo "beginnertutorial.opencv.sh -d"
}

function log {
  local line=$1
  echo "$(TZ=$timezone date +%F_%T.%6N_%Z): $line"
}

function interactivePrompt {
  $interactive || return
  read -N1 -p "Press q to quit, R to run non-interactively or any other key to continue interactively.. "
  echo
  [[ $REPLY == [qQ]* ]] && exit
  [[ $REPLY == R* ]] && interactive=false
}

function clean {
  local repo=$rawfilesRepo
  local pipeline
  local es
  local cmd

  log "Switch to $context context"
  cmd="pachctl config set active-context $context"
  echo "$cmd"
  $cmd
  echo

  log "Delete pipelines ${pipelines[*]}"
  for pipeline in ${pipelines[*]}; do
    log "Delete pipeline $pipeline"
    cmd="pachctl delete pipeline $pipeline"
    echo "$cmd"
    $cmd
    echo
  done

  log "Delete $repo repo"
  cmd="pachctl delete repo $repo"
  echo "$cmd"
  $cmd
  es=$?
  echo

  if ((es != 0)); then
    log >&2 "Failed to delete $repo repo error $es"
    log "Force delete $repo repo"
    cmd="pachctl delete repo -f -v $repo"
    echo "$cmd"
    $cmd
    echo
  fi

  log "Delete $project project"
  cmd="pachctl delete project $project"
  echo "$cmd"
  $cmd
  es=$?
  echo

  log "Delete $context context and switch to default context"
  pachctl config set active-context default
  cmd="pachctl config delete context $context"
  echo "$cmd"
  $cmd
  echo

}

declare -A defaults=(
  [sleepSeconds]=10
  [timeoutSeconds]=20
  [timezone]=America/New_York
)

while getopts "dhiz:" opt; do
  case $opt in
    d) clean=true;;
    i) interactive=true;;
    z) timezone=$OPTARG;;
    h) usage; exit 0;;
    *) usage; exit 1
  esac
done
shift $((OPTIND-1))

# defaults
: ${clean:=false}
: ${interactive:=false}
: ${sleepSeconds:=${defaults[sleepSeconds]}}
: ${timeoutSeconds:=${defaults[timeoutSeconds]}}
: ${timezone:=${defaults[timezone]}}

# variables

project=video-to-frame-traces
context=$project
rawfilesRepo=raw_videos_and_images

converter=video_mp4_converter
flattener=image_flattener
tracer=image_tracer
gifer=movie_gifer
shuffler=content_shuffler
collager=content_collager

declare -a pipelines=($converter $flattener $tracer $gifer $shuffler $collager)

log "Show pachyderm version"
cmd="pachctl version"
echo "$cmd"
$cmd || exit 2
echo

if $clean; then
  clean
  exit
fi

log "Create project $project"
cmd="pachctl create project $project"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Show current active context"
cmd="pachctl config get active-context"
echo "$cmd"
origContext=$($cmd)
echo "$origContext"
echo
interactivePrompt

contextConfig=$(cat <<EOF
{
  "cluster_deployment_id": "dev",
  "project": "$project"
}
EOF
)

log "Create new $context context for $project project"
echo "pachctl config set context $context <<EOF
$contextConfig
EOF"
pachctl config set context $context <<EOF
$contextConfig
EOF
echo
interactivePrompt

log "Change active context from $origContext to $context"
cmd="pachctl config set active-context $context"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Show all projects"
cmd="pachctl list projects"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Create repo $rawfilesRepo to store raw videos and images"
cmd="pachctl create repo $rawfilesRepo"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Show all repos"
cmd="pachctl list repos"
echo "$cmd"
$cmd
echo
interactivePrompt

file=liberty.jpg
srcpath=https://raw.githubusercontent.com/pachyderm/docs-content/main/images/opencv/liberty.jpg
log "Upload $file file from $srcpath to repo branch $rawfilesRepo@master"
cmd="pachctl put file $rawfilesRepo@master:$file -f $srcpath"
echo "$cmd"
$cmd
echo
interactivePrompt

file=cat-sleeping.MOV
srcpath=https://storage.googleapis.com/docs-tutorial-resoruces/cat-sleeping.MOV
log "Upload $file file from $srcpath to repo branch $rawfilesRepo@master"
cmd="pachctl put file $rawfilesRepo@master:$file -f $srcpath"
echo "$cmd"
$cmd
echo
interactivePrompt

file=robot.png
srcpath=https://raw.githubusercontent.com/pachyderm/docs-content/main/images/opencv/robot.jpg
log "Upload $file file from $srcpath to repo branch $rawfilesRepo@master"
cmd="pachctl put file $rawfilesRepo@master:$file -f $srcpath"
echo "$cmd"
$cmd
echo
interactivePrompt

file=highway.MOV
srcpath=https://storage.googleapis.com/docs-tutorial-resoruces/highway.MOV
log "Upload $file file from $srcpath to repo branch $rawfilesRepo@master"
cmd="pachctl put file $rawfilesRepo@master:$file -f $srcpath"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Show all files in $rawfilesRepo repo"
cmd="pachctl list files $rawfilesRepo@master"
echo "$cmd"
$cmd
echo
interactivePrompt

cat <<EOF > $converter.yaml
pipeline:
  name: $converter
input:
  pfs:
    repo: $rawfilesRepo
    glob: "/*"
transform:
  image: lbliii/$converter:1.0.14
  cmd:
    - python3
    - /$converter.py
    - --input
    - /pfs/$rawfilesRepo/
    - --output
    - /pfs/out/
autoscaling: true
EOF

log "Converter pipeline 1 file $converter.json"
cat $converter.yaml
echo

log "Create $converter pipeline 1 from $converter.yaml"
cmd="pachctl create pipeline -f $converter.yaml"
echo "$cmd"
$cmd
echo
interactivePrompt

cat <<EOF > $flattener.yaml
pipeline:
  name: $flattener
input:
  pfs:
    repo: $converter
    glob: "/*"
transform:
  image: lbliii/$flattener:1.0.0
  cmd:
    - python3
    - /$flattener.py
    - --input
    - /pfs/$converter
    - --output
    - /pfs/out/
autoscaling: true
EOF

log "Flattener pipeline 2 file $flattener.json"
cat $flattener.yaml
echo

log "Create $flattener pipeline 2 from $flattener.yaml"
cmd="pachctl create pipeline -f $flattener.yaml"
echo "$cmd"
$cmd
echo
interactivePrompt

cat <<EOF > $tracer.yaml
pipeline:
  name: $tracer
description: A pipeline that performs image edge detection by using the OpenCV library.
input:
  union:
    - pfs:
        repo: $rawfilesRepo
        glob: "/*.{png,jpg,jpeg}"
    - pfs:
        repo: $flattener
        glob: "/*"
transform:
  image: lbliii/$tracer:1.0.8
  cmd:
    - python3
    - /$tracer.py
    - --input
    - /pfs/$rawfilesRepo
    - /pfs/$flattener
    - --output
    - /pfs/out/
autoscaling: true
EOF

log "Tracer pipeline 3 file $tracer.json"
cat $tracer.yaml
echo

log "Create $tracer pipeline 3 from $tracer.yaml"
cmd="pachctl create pipeline -f $tracer.yaml"
echo "$cmd"
$cmd
echo
interactivePrompt

cat <<EOF > $gifer.yaml
pipeline:
  name: $gifer
description: A pipeline that converts frames into a gif using the OpenCV library.
input:
  union:
    - pfs:
        repo: $flattener
        glob: "/*/"
    - pfs:
        repo: $tracer
        glob: "/*/"
transform:
  image: lbliii/$gifer:1.0.5
  cmd:
    - python3
    - /$gifer.py
    - --input
    - /pfs/$flattener
    - /pfs/$tracer
    - --output
    - /pfs/out/
autoscaling: true
EOF

log "Gifer pipeline 4 file $gifer.json"
cat $gifer.yaml
echo

log "Create $gifer pipeline 4 from $gifer.yaml"
cmd="pachctl create pipeline -f $gifer.yaml"
echo "$cmd"
$cmd
echo
interactivePrompt

cat <<EOF > $shuffler.yaml
pipeline:
  name: $shuffler
description: A pipeline that collapses our inputs into one datum for the collager.
input:
  union:
    - pfs:
        repo: $gifer
        glob: "/"
    - pfs:
        repo: $rawfilesRepo
        glob: "/*.{png,jpg,jpeg}"
    - pfs:
        repo: $tracer
        glob: "/*.{png,jpg,jpeg}"

transform:
  image: lbliii/$shuffler:1.0.0
  cmd:
    - python3
    - /$shuffler.py
    - --input
    - /pfs/$gifer
    - /pfs/$rawfilesRepo
    - /pfs/$tracer
    - --output
    - /pfs/out/
autoscaling: true
EOF

log "Shuffler pipeline 5 file $shuffler.json"
cat $shuffler.yaml
echo

log "Create $shuffler pipeline 5 from $shuffler.yaml"
cmd="pachctl create pipeline -f $shuffler.yaml"
echo "$cmd"
$cmd
echo
interactivePrompt

cat <<EOF > $collager.yaml
pipeline:
  name: $collager
description: A pipeline that creates a static HTML collage.
input:
  pfs:
    glob: "/"
    repo: $shuffler


transform:
  image: lbliii/$collager:1.0.64
  cmd:
    - python3
    - /$collager.py
    - --input
    - /pfs/$shuffler
    - --output
    - /pfs/out/
autoscaling: true
EOF

log "Collager pipeline 6 file $collager.json"
cat $collager.yaml
echo

log "Create $collager pipeline 6 from $collager.yaml"
cmd="pachctl create pipeline -f $collager.yaml"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Show all projects"
cmd="pachctl list projects"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Show all repos"
cmd="pachctl list repos"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Show all pipelines"
cmd="pachctl list pipelines"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Sleep $sleepSeconds.."
sleep $sleepSeconds
echo

log "Show all commits"
cmd="pachctl list commits"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Sleep $sleepSeconds.."
sleep $sleepSeconds
echo

log "Show jobs for $collager pipeline"
cmd="pachctl list jobs --pipeline $collager"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Show files in $collager repo"
cmd="pachctl list files $collager@master"
echo "$cmd"
$cmd
echo
interactivePrompt

log "Keeping $context as current active context - restore original context $origContext if desired with following command"
cmd="pachctl config set active-context $origContext"
echo "$cmd"

echo "Done"

