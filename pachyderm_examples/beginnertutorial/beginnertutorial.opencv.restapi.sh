#!/bin/bash

# beginnertutorial.opencv.restapi.sh

function usage {
  echo "Usage: beginnertutorial.opencv.restapi.sh"
  echo "-d: delete all pachyderm resources for tutorial"
  echo "-h: help"
  echo "-i: interactive prompt to continue after each step"
  echo "-z: timezone, default ${defaults[timezone]}"
  echo "Examples:"
  echo "beginnertutorial.opencv.restapi.sh"
  echo "beginnertutorial.opencv.restapi.sh -i"
  echo "beginnertutorial.opencv.restapi.sh -d"
}

function log {
  local line=$1
  echo "$(TZ=$timezone date +%F_%T.%6N_%Z): $line"
}

# convert json on stdin to form that can be embedded as a string in other json
# escape doublequotes and backslashes and delete newlines
function escapeJsonAsString {
  sed 's/["\\]/\\&/g' | tr -d '\n'
}

function interactivePrompt {
  $interactive || return
  read -N1 -p "Press q to quit, R to run non-interactively or any other key to continue interactively.. "
  echo
  [[ $REPLY == [qQ]* ]] && exit
  [[ $REPLY == R* ]] && interactive=false
}

# send API request with curl
function curlCall {
  local api=$1
  local params=$2

  echo "API: $api"
  echo -n "Request: "
  echo "$params" | jq

  echo -n "Response: "
  curl -s http://localhost/api/$api -d@- <<EOF | jq
$params
EOF
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
api=versionpb_v2.API/GetVersion
params='{}'
curlCall $api "$params" || exit 2
echo
interactivePrompt

if $clean; then
  clean
  exit
fi

log "Create project $project"
api=pfs_v2.API/CreateProject
params=$(cat <<EOF
{
  "project": {
    "name": "$project"
  }
}
EOF
)
curlCall $api "$params"
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
pachctl config get active-context
echo
interactivePrompt

log "Show all projects before creating pipelines"
api=pfs_v2.API/ListProject
params='{}'
curlCall $api "$params"
echo
interactivePrompt

log "Create repo $rawfilesRepo to store original videos and images"
api=pfs_v2.API/CreateRepo
params=$(cat <<EOF
{
  "repo": {
    "name": "$rawfilesRepo",
    "project": {
      "name": "$project"
    }
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

log "Show all repos before creating pipelines"
api=pfs_v2.API/ListRepo
params='{}'
curlCall $api "$params"
echo
interactivePrompt

file=liberty.jpg
srcpath=https://raw.githubusercontent.com/pachyderm/docs-content/main/images/opencv/liberty.jpg
log "Upload $file file from $srcpath to repo branch $rawfilesRepo@master"
api=pfs_v2.API/ModifyFile
params=$(cat <<EOF
{
  "set_commit": {
    "repo": {
      "name": "$rawfilesRepo",
      "project": {"name": "$project"},
      "type": "user"
     },
     "branch": {
       "repo": {
         "name": "$rawfilesRepo",
         "project": {"name": "$project"},
         "type": "user"
       },
       "name": "master"
     }
  }
}
{
  "add_file": {
    "path": "$file",
    "url": {
      "URL": "$srcpath"
    }
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

file=cat-sleeping.MOV
srcpath=https://storage.googleapis.com/docs-tutorial-resoruces/cat-sleeping.MOV
log "Upload $file file from $srcpath to repo branch $rawfilesRepo@master"
api=pfs_v2.API/ModifyFile
params=$(cat <<EOF
{
  "set_commit": {
    "repo": {
      "name": "$rawfilesRepo",
      "project": {"name": "$project"},
      "type": "user"
     },
     "branch": {
       "repo": {
         "name": "$rawfilesRepo",
         "project": {"name": "$project"},
         "type": "user"
       },
       "name": "master"
     }
  }
}
{
  "add_file": {
    "path": "$file",
    "url": {
      "URL": "$srcpath"
    }
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

file=robot.png
srcpath=https://raw.githubusercontent.com/pachyderm/docs-content/main/images/opencv/robot.jpg
log "Upload $file file from $srcpath to repo branch $rawfilesRepo@master"
api=pfs_v2.API/ModifyFile
params=$(cat <<EOF
{
  "set_commit": {
    "repo": {
      "name": "$rawfilesRepo",
      "project": {"name": "$project"},
      "type": "user"
     },
     "branch": {
       "repo": {
         "name": "$rawfilesRepo",
         "project": {"name": "$project"},
         "type": "user"
       },
       "name": "master"
     }
  }
}
{
  "add_file": {
    "path": "$file",
    "url": {
      "URL": "$srcpath"
    }
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

file=highway.MOV
srcpath=https://storage.googleapis.com/docs-tutorial-resoruces/highway.MOV
log "Upload $file file from $srcpath to repo branch $rawfilesRepo@master"
api=pfs_v2.API/ModifyFile
params=$(cat <<EOF
{
  "set_commit": {
    "repo": {
      "name": "$rawfilesRepo",
      "project": {"name": "$project"},
      "type": "user"
    },
    "branch": {
      "repo": {
        "name": "$rawfilesRepo",
        "project": {"name": "$project"},
        "type": "user"
      },
      "name": "master"
    }
  }
}
{
  "add_file": {
    "path": "$file",
    "url": {
      "URL": "$srcpath"
    }
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

log "Show all files in $rawfilesRepo repo"
api=pfs_v2.API/ListFile
params=$(cat <<EOF
{
  "file": {
    "commit": {
      "repo": {
        "name": "$rawfilesRepo",
        "project": {"name": "$project"},
        "type": "user"
      },
      "branch": {
        "repo": {
          "name": "$rawfilesRepo",
          "project": {"name": "$project"},
          "type": "user"
        },
        "name": "master"
      }
    }
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

cat <<EOF > $converter.json
{
  "pipeline": {
    "name": "$converter",
    "project": {
      "name": "$project"
    }
  },
  "input": {
    "pfs": {
      "repo": "$rawfilesRepo",
      "glob": "/*"
    }
  },
  "transform": {
    "image": "lbliii/$converter:1.0.14",
    "cmd": [
      "python3",
      "/$converter.py",
      "--input",
      "/pfs/$rawfilesRepo/",
      "--output",
      "/pfs/out/"
    ]
  },
  "autoscaling": true
}
EOF

log "Converter pipeline 1 file $converter.json"
jq <$converter.json
echo

log "Create $converter pipeline 1 from $converter.json"
api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$converter.json)"
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

cat <<EOF > $flattener.json
{
  "pipeline": {
    "name": "$flattener",
    "project": {
      "name": "$project"
    }
  },
  "input": {
    "pfs": {
      "repo": "$converter",
      "glob": "/*"
    }
  },
  "transform": {
    "image": "lbliii/$flattener:1.0.0",
    "cmd": [
      "python3",
      "/$flattener.py",
      "--input",
      "/pfs/$converter",
      "--output",
      "/pfs/out/"
    ]
  },
  "autoscaling": true
}
EOF

log "Flattener pipeline 2 file $flattener.json"
jq <$flattener.json
echo

log "Create $flattener pipeline 2 from $flattener.json"
api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$flattener.json)"
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

cat <<EOF > $tracer.json
{
  "pipeline": {
    "name": "$tracer",
    "project": {
      "name": "$project"
    }
  },
  "description": "A pipeline that performs image edge detection by using the OpenCV library",
  "input": {
    "union": [
      {
        "pfs": {
          "repo": "$rawfilesRepo",
          "glob": "/*.{png,jpg,jpeg}"
        }
      },
      {
        "pfs": {
          "repo": "$flattener",
          "glob": "/*"
        }
      }
    ]
  },
  "transform": {
    "image": "lbliii/$tracer:1.0.8",
    "cmd": [
      "python3",
      "/$tracer.py",
      "--input",
      "/pfs/$rawfilesRepo",
      "/pfs/$flattener",
      "--output",
      "/pfs/out/"
    ]
  },
  "autoscaling": true
}
EOF

log "Tracer pipeline 3 file $tracer.json"
jq <$tracer.json
echo

log "Create $tracer pipeline 3 from $tracer.json"
api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$tracer.json)"
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

cat <<EOF > $gifer.json
{
  "pipeline": {
    "name": "$gifer",
    "project": {
      "name": "$project"
    }
  },
  "description": "A pipeline that converts frames into a gif using the OpenCV library",
  "input": {
    "union": [
      {
        "pfs": {
          "repo": "$flattener",
          "glob": "/*/"
        }
      },
      {
        "pfs": {
          "repo": "$tracer",
          "glob": "/*/"
        }
      }
    ]
  },
  "transform": {
    "image": "lbliii/$gifer:1.0.5",
    "cmd": [
      "python3",
      "/$gifer.py",
      "--input",
      "/pfs/$flattener",
      "/pfs/$tracer",
      "--output",
      "/pfs/out/"
    ]
  },
  "autoscaling": true
}
EOF

log "Gifer pipeline 4 file $gifer.json"
jq <$gifer.json
echo

log "Create $gifer pipeline 4 from $gifer.json"
api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$gifer.json)"
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

cat <<EOF > $shuffler.json
{
  "pipeline": {
    "name": "$shuffler",
    "project": {
      "name": "$project"
    }
  },
  "description": "A pipeline that collapses our inputs into one datum for the collager",
  "input": {
    "union": [
      {
        "pfs": {
          "repo": "$gifer",
          "glob": "/"
        }
      },
      {
        "pfs": {
          "repo": "$rawfilesRepo",
          "glob": "/*.{png,jpg,jpeg}"
        }
      },
      {
        "pfs": {
          "repo": "$tracer",
          "glob": "/*.{png,jpg,jpeg}"
        }
      }
    ]
  },
  "transform": {
    "image": "lbliii/$shuffler:1.0.0",
    "cmd": [
      "python3",
      "/$shuffler.py",
      "--input",
      "/pfs/$gifer",
      "/pfs/$rawfilesRepo",
      "/pfs/$tracer",
      "--output",
      "/pfs/out/"
    ]
  },
  "autoscaling": true
}
EOF

log "Shuffler pipeline 5 file $shuffler.json"
jq <$shuffler.json
echo

log "Create $shuffler pipeline 5 from $shuffler.json"
api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$shuffler.json)"
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

cat <<EOF > $collager.json
{
  "pipeline": {
    "name": "$collager",
    "project": {
      "name": "$project"
    }
  },
  "description": "A pipeline that creates a static HTML collage",
  "input": {
    "pfs": {
      "glob": "/",
      "repo": "$shuffler"
    }
  },
  "transform": {
    "image": "lbliii/$collager:1.0.64",
    "cmd": [
      "python3",
      "/$collager.py",
      "--input",
      "/pfs/$shuffler",
      "--output",
      "/pfs/out/"
    ]
  },
  "autoscaling": true
}
EOF

log "Collager pipeline 6 file $collager.json"
jq <$collager.json
echo

log "Create $collager pipeline 6 from $collager.json"
api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$collager.json)"
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

log "Show all projects after creating pipelines"
api=pfs_v2.API/ListProject
params='{}'
curlCall $api "$params"
echo
interactivePrompt

log "Show all repos after creating pipelines"
api=pfs_v2.API/ListRepo
params='{}'
curlCall $api "$params"
echo
interactivePrompt

log "Show all pipelines created"
api=pps_v2.API/ListPipeline
params='{}'
curlCall $api "$params"
echo
interactivePrompt

log "Sleep $sleepSeconds.."
sleep $sleepSeconds
echo

log "Show all commits"
api=pfs_v2.API/ListCommitSet
params=$(cat <<EOF
{
  "project": {
    "name": "$project"
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt


log "Sleep $sleepSeconds.."
sleep $sleepSeconds
echo

log "Show jobs for $collager pipeline"
api=pps_v2.API/ListJob
params=$(cat <<EOF
{
  "pipeline": {
    "name": "$collager",
    "project": {
      "name": "$project"
    }
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

log "Show files in $collager repo"
api=pfs_v2.API/ListFile
params=$(cat <<EOF
{
  "file": {
    "commit": {
      "repo": {
        "name": "$collager",
        "project": {"name": "$project"},
        "type": "user"
      },
      "branch": {
        "repo": {
          "name": "$collager",
          "project": {"name": "$project"},
          "type": "user"
        },
        "name": "master"
      }
    }
  }
}
EOF
)
curlCall $api "$params"
echo
interactivePrompt

log "Keeping $context as current active context - run following command to restore original context $origContext if desired"
cmd="pachctl config set active-context $origContext"
echo "$cmd"

echo "Done"

