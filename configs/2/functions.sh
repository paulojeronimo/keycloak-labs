#!/usr/bin/env bash

lab-setup-docker-compose() {
  cp "$lab_dir"/configs/2/docker-compose.yml "$lab_dir"/
}

lab-setup-container() {
  lab-kc-config-jdbc-driver
}

lab-kc-config-jdbc-driver() {(
  local module_dir=container/modules/system/layers/base/com/microsoft/sqlserver/main
  local jar_copy=tmp/${mssql_jdbc_jar##*/}
  cd "$lab_dir"
  echo "Setting up SQL Server DataSource ..."
  [ -f $jar_copy ] || {
    echo "Please download $mssql_jdbc_jar to \"$jar_copy\" ..."
    return 1
  }
  echo "Copying \"$jar_copy\" to \"$module_dir\""
  mkdir -p $module_dir
  cp $jar_copy $module_dir/
  echo "Creating file \"$module_dir/module.xml\" ..."
  cat > $module_dir/module.xml <<EOF
<?xml version="1.0"?>
<module xmlns="urn:jboss:module:1.3" name="com.microsoft.sqlserver">
  <resources>
    <resource-root path="${jar_copy##*/}"/>
  </resources>
  <dependencies>
    <module name="javax.api"/>
    <module name="javax.transaction.api"/>
  </dependencies>
</module>
EOF
)}

lab-sqlcmd() {(
  cd "$lab_dir"
  docker-compose exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P p0ssW0rD
)}
