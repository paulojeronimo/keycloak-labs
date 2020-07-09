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
  $ok && echo "Your system is good! All the required tools are installed."
}

lab-setup() {(
  cd "$lab_dir"
  [ -f docker-compose.yml ] || {
    echo "Generating file \"$PWD/docker-compose.yml\" ..."
    # Ref2
    yq w docker-compose.template.yml services.kc.image $kc_image |
    if [ $initial_configs = 0 ]; then
      yq d - services.kc.volumes > docker-compose.yml
    else
      cat - > docker-compose.yml
    fi
  }
  [ -d container ] || {
    lab-kc-config-pg-driver
    [ $initial_configs != 0 ] && lab-setup-configs 1 || {
      echo "Skipping the setup of initial configuration files ..."
    }
  }
)}

lab-restart() {
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
  rsync -r configs/0/ container/
  local f_diff
  local f_orig
  for f in $(find configs/$dir -type f); do
    if [ "${f##*.}" = "diff" ]; then
      f_diff=$f
      f_orig=container/${f#configs/?/}
      f_orig=${f_orig%.diff}
      [ -f $f_orig ] && patch $f_orig < $f_diff
      # NOTE: the patch file ($f_diff) generation is made with this command (for example):
      # f=configuration/standalone-openshift.xml; diff --strip-trailing-cr -uNr configs/{0,1}/$f > configs/1/$f.diff
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

lab-kc-config-pg-driver() {(
  local module_dir=container/modules/system/layers/base/org/postgresql/jdbc/main
  local jar_copy=tmp/${postgresql_jar##*/}
  cd "$lab_dir"
  echo "Setting up PostgreSQL DataSource ..."
  [ -f $jar_copy ] || {
    echo "Downloading file \"${postgresql_jar##*/}\" to \"$jar_copy\" ..."
    wget -c $postgresql_jar -O $jar_copy
  }
  echo "Copying \"$jar_copy\" to \"$module_dir\""
  mkdir -p $module_dir
  cp $jar_copy $module_dir/
  echo "Creating file \"$module_dir/module.xml\" ..."
  cat > $module_dir/module.xml <<EOF
<?xml version="1.0"?>
<module xmlns="urn:jboss:module:1.3" name="org.postgresql">
  <resources>
    <resource-root path="${postgresql_jar##*/}"/>
  </resources>
  <dependencies>
    <module name="javax.api"/>
    <module name="javax.transaction.api"/>
  </dependencies>
</module>
EOF
)}

lab-kc-get-config() {(
  local config=/opt/eap/standalone/configuration/$wildfly_config
  cd "$lab_dir"
  docker-compose exec kc cat $config > tmp/$wildfly_config &&
  echo "File \"$PWD/tmp/$wildfly_config\" copied from \"$config\" (in kc container)!"
)}

lab-pg-bash() {(
  cd "$lab_dir"
  docker-compose exec pg bash
)}

lab-functions() {
  echo "Available functions in \"$lab_dir/functions.sh\":"
  set | grep "^lab-.*()"
}

lab-load-config
lab-mktmp
lab-check-tools || return $?
lab-setup
lab-functions
