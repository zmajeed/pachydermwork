#!/bin/bash

# beginnertutorial.opencv.restapi.sh

function usage {
  echo "Usage: beginnertutorial.opencv.restapi.sh"
}

function log {
  local line=$1
  echo "$(TZ=$timezone date +%F_%T.%6N_%Z): $line"
}

function curlCall1 {
  local api=$1
  local params=$(cat)

  echo "API: $api"
  echo -n "Request: "
  echo "$params" | jq

  echo -n "Response: "
  curl -s http://localhost/api/$api -d@- <<EOF | jq
$params
EOF
}

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

# converts json on stdin to form that can be embedded as a string in other json
# escapes doublequotes and backslashes and deletes newlines
function escapeJsonAsString {
  sed 's/["\\]/\\&/g' | tr -d '\n'
}

function clean {
  local repo=$rawfilesRepo
  local pipeline
  local es
  local cmd

  echo "Delete pipelines ${pipelines[*]}"
  for pipeline in ${pipelines[*]}; do
    echo "Delete pipeline $pipeline"
    cmd="pachctl delete pipeline $pipeline"
    echo "$cmd"
    $cmd
    echo
  done

  echo "Delete repo $repo"
  cmd="pachctl delete repo $repo"
  echo "$cmd"
  $cmd
  es=$?
  echo

  if ((es != 0)); then
    echo "Failed to delete repo $repo error $es"
    echo "Force delete repo $repo"
    cmd="pachctl delete repo -f -v $repo"
    echo "$cmd"
    $cmd
    echo
  fi

  echo "Delete project $project"
  cmd="pachctl delete project $project"
  echo "$cmd"
  $cmd
  es=$?
  echo

}

declare -A defaults=(
  [sleepSeconds]=10
  [timeoutSeconds]=20
  [timezone]=America/New_York
)

while getopts "df:hn:p:P:z:" opt; do
  case $opt in
    d) clean=true;;
    p) pipeline=$OPTARG;;
    z) timezone=$OPTARG;;
    h) usage; exit 0;;
    *) usage; exit 1
  esac
done
shift $((OPTIND-1))

# defaults
: ${clean:=false}
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

#{ jq -C <<<'{"repo": {"name": "testrepo_3"}, "description": "Test repo 3"}'; echo; echo; }|tee >(sed -E 's/\x1b[[0-9;]*m//g' | curl -s http://localhost/api/pfs_v2.API/CreateRepo -d@-)
# echo '{"cluster_deployment_id": "dev", "project": "video-to-frame-traces"}'|{ jq -C; echo; echo; }|tee >(sed -E 's/\x1b[[0-9;]*m//g'|nl)

log "Check pachyderm version"
#curlCall1 versionpb_v2.API/GetVersion <<EOF || exit 2
curlCall versionpb_v2.API/GetVersion <<EOF || exit 2
{}
EOF
echo

exit

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

log "Show current active context"
cmd="pachctl config get active-context"
echo "$cmd"
origContext=$($cmd)
echo "$origContext"
echo

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

log "Change active context from $origContext to $context"
cmd="pachctl config set active-context $context"
echo "$cmd"
$cmd
pachctl config get active-context
echo

log "Show all projects"
api=pfs_v2.API/ListProject
params='{}'
curlCall $api "$params"
echo

log "Create repo $rawfilesRepo to store raw videos and images"
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

log "Show all repos"
api=pfs_v2.API/ListRepo
params='{}'
curlCall $api "$params"
echo

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

log "Converter pipeline file $converter.json"
cat $converter.json
echo

api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$converter.json)"
}
EOF
)
curlCall $api "$params"
echo

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

log "Flattener pipeline file $flattener.json"
cat $flattener.json
echo

api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$flattener.json)"
}
EOF
)
curlCall $api "$params"
echo

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

log "Tracer pipeline file $tracer.json"
cat $tracer.json
echo

api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$tracer.json)"
}
EOF
)
curlCall $api "$params"
echo

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

log "Gifer pipeline file $gifer.json"
cat $gifer.json
echo

api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$gifer.json)"
}
EOF
)
curlCall $api "$params"
echo

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

log "Shuffler pipeline file $shuffler.json"
cat $shuffler.json
echo

api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$shuffler.json)"
}
EOF
)
curlCall $api "$params"
echo

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

log "Collager pipeline file $collager.json"
cat $collager.json
echo

api=pps_v2.API/CreatePipelineV2
params=$(cat <<EOF
{
  "create_pipeline_request_json": "$(escapeJsonAsString <$collager.json)"
}
EOF
)
curlCall $api "$params"
echo

log "Show all projects"
cmd="pachctl list projects"
echo "$cmd"
$cmd
echo

log "Show all repos"
cmd="pachctl list repos"
echo "$cmd"
$cmd
echo

log "Show all pipelines"
cmd="pachctl list pipelines"
echo "$cmd"
$cmd
echo

echo "Sleep $sleepSeconds.."
sleep $sleepSeconds
echo

log "Show all commits"
cmd="pachctl list commits"
echo "$cmd"
$cmd
echo

echo "Sleep $sleepSeconds.."
sleep $sleepSeconds
echo

log "Show jobs for $collager pipeline"
cmd="pachctl list jobs --pipeline $collager"
echo "$cmd"
$cmd
echo

log "Show files in $collager repo"
cmd="pachctl list files $collager@master"
echo "$cmd"
$cmd
echo

log "Keeping $context as current active context - run following command to restore original context $origContext if desired"
cmd="pachctl config set active-context $origContext"
echo "$cmd"

echo "Done"

