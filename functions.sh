#!/usr/bin/env bash
# Purpose: Provide functions for this lab
# References:
#   Ref1: https://stackoverflow.com/questions/35006457/choosing-between-0-and-bash-source
#   Ref2: https://mikefarah.gitbook.io/yq/commands/write-update

# Ref1
lab_functions=${BASH_SOURCE[0]}
lab_dir=`cd "$(dirname "$lab_functions")"; pwd`
echo "Loading file \"$lab_functions\" ..."

lab-load-config() {
  local config="$lab_dir"/config
  source "$config" 2> /dev/null || {
    config="$lab_dir"/config.sample
    source "$config"
  }
  echo "File \"$config\" loaded!"
}

lab-mktmp() {
  [ -d "$lab_dir"/tmp ] || {
    echo "Creating dir \"$lab_dir/tmp\" ..."
    mkdir "$lab_dir"/tmp
  }
}

lab-cd() { cd "$lab_dir"; }

lab-check-tools() {
  local ok=true
  local tool
  for tool in $required_tools; do
    which $tool &> /dev/null || { echo "$tool is missing!"; ok=false; }
  done
  $ok && echo "Your system is good! All the required tools are installed." || return $?
}

lab-set() {
  local lab_to_set=$lab_dir/configs/$1
  if [ -d "$lab_to_set" ]; then
    echo "Setting lab configuration to $1"
    sed "s/\(initial_configs=\)0/\1$1/g" config.sample > config
    lab-restart
  else
    echo "Lab configuration $1 does not exists!"
  fi
}

lab-setup() {
  local lab_nb_dir=$lab_dir/configs/$initial_configs
  source "$lab_nb_dir"/functions.sh
  (
    cd "$lab_dir"
    [ -f docker-compose.yml ] && return || {
      echo "Setting up docker-compose.yml from \"$lab_nb_dir/docker-compose.yml\" ..."
      lab-setup-docker-compose
    }
    [ -d container ] || {
      local f=lab-setup-container; type $f &> /dev/null && $f
      [ $initial_configs != 0 ] && lab-setup-configs $initial_configs || {
        echo "Skipping the setup of initial configuration files ..."
      }
    }
  )
}

lab-restart() {
  for f in $(declare -F | grep lab- | cut -d' ' -f3); do unset -f $f; done
  cd "$lab_dir"
  rm docker-compose.yml
  rm -rf container
  source ./functions.sh
  cd - &> /dev/null
}

lab-setup-configs() {(
  local dir=$1
  cd "$lab_dir"
  echo "Setting up initial configurations for container from configs/$dir ..."
  rsync --exclude={docker-compose.yml,functions.sh} -r configs/0/ container/
  local f_diff
  local f_orig
  for f in $(find configs/$dir -type f); do
    f_orig=container/${f#configs/*/}
    if [ "${f##*.}" = "diff" ]; then
      f_diff=$f
      f_orig=${f_orig%.diff}
      [ -f $f_orig ] && patch $f_orig < $f_diff
      # NOTE: standalone-openshift.xml.diff (for example) can be made in this way:
      # $ cd container/; f=configuration/standalone-openshift.xml
      # $ cp ../configs/0/$f ./$f.original
      # $ diff --strip-trailing-cr -uNr $f.original $f > ${f#configuration/}.diff
    else
      mkdir -p `dirname $f_orig`
      case ${f##*/} in
        docker-compose.yml|functions.sh) continue;;
      esac
      cp $f $f_orig
    fi
  done
)}

lab-config() {
  (cd "$lab_dir"; docker-compose config)
}

lab-up() {
  (cd "$lab_dir"; docker-compose up "$@")
}

lab-logs() {
  (cd "$lab_dir"; docker-compose logs "$@")
}

lab-ps() {
  (cd "$lab_dir"; docker-compose ps "$@")
}

lab-top() {
  (cd "$lab_dir"; docker-compose top "$@")
}

lab-stop() {
  local c=${1:-lab}
  (cd "$lab_dir"; docker-compose stop $c)
}

lab-down() {
  (cd "$lab_dir"; docker-compose down "$@")
}

lab-kc-bash() {
  (cd "$lab_dir"; docker-compose exec kc bash)
}

lab-kc-get-config() {(
  local config=/opt/eap/standalone/configuration/$wildfly_config
  cd "$lab_dir"
  docker-compose exec kc cat $config > tmp/$wildfly_config &&
  echo "File \"$PWD/tmp/$wildfly_config\" copied from \"$config\" (in kc container)!"
)}

lab-functions() {
  echo "Available functions for this lab:"
  set | grep "^lab-.*()"
}

lab-load-config
lab-mktmp
lab-check-tools
lab-setup
lab-functions
