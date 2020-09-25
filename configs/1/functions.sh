#!/usr/bin/env bash

lab-setup-docker-compose() {
  cp "$lab_dir"/configs/1/docker-compose.yml "$lab_dir"/
}

lab-setup-container() {
  lab-kc-config-pg-driver
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

lab-pg-bash() {(
  cd "$lab_dir"
  docker-compose exec pg bash
)}
