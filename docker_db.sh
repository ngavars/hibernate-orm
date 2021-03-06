#! /bin/bash

mysql_5_7() {
    docker rm -f mysql || true
    docker run --name mysql -e MYSQL_USER=hibernate_orm_test -e MYSQL_PASSWORD=hibernate_orm_test -e MYSQL_DATABASE=hibernate_orm_test -p3306:3306 -d mysql:5.7 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
}

mysql_8_0() {
    docker rm -f mysql || true
    docker run --name mysql -e MYSQL_USER=hibernate_orm_test -e MYSQL_PASSWORD=hibernate_orm_test -e MYSQL_DATABASE=hibernate_orm_test -p3306:3306 -d mysql:8.0.21 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
}

mariadb() {
    docker rm -f mariadb || true
    docker run --name mariadb -e MYSQL_USER=hibernate_orm_test -e MYSQL_PASSWORD=hibernate_orm_test -e MYSQL_DATABASE=hibernate_orm_test -e MYSQL_ROOT_PASSWORD=hibernate_orm_test -p3306:3306 -d mariadb:10.5.8 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
}

postgresql_9_5() {
    docker rm -f postgres || true
    docker run --name postgres -e POSTGRES_USER=hibernate_orm_test -e POSTGRES_PASSWORD=hibernate_orm_test -e POSTGRES_DB=hibernate_orm_test -p5432:5432 -d postgres:9.5
}

db2() {
    docker rm -f db2 || true
    docker run --name db2 --privileged -e DB2INSTANCE=orm_test -e DB2INST1_PASSWORD=orm_test -e DBNAME=orm_test -e LICENSE=accept -e AUTOCONFIG=false -e ARCHIVE_LOGS=false -e TO_CREATE_SAMPLEDB=false -e REPODB=false -p 50000:50000 -d ibmcom/db2:11.5.5.0
    # Give the container some time to start
    OUTPUT=
    while [[ $OUTPUT != *"INSTANCE"* ]]; do
        echo "Waiting for DB2 to start..."
        sleep 10
        OUTPUT=$(docker logs db2)
    done
    docker exec -t db2 su - orm_test bash -c ". /database/config/orm_test/sqllib/db2profile && /database/config/orm_test/sqllib/bin/db2 'connect to orm_test' && /database/config/orm_test/sqllib/bin/db2 'CREATE USER TEMPORARY TABLESPACE usr_tbsp MANAGED BY AUTOMATIC STORAGE'"
}

mssql() {
    docker rm -f mssql || true
    docker run --name mssql -d -p 1433:1433 -e "SA_PASSWORD=Hibernate_orm_test" -e ACCEPT_EULA=Y microsoft/mssql-server-linux:2017-CU13
    sleep 5
    n=0
    until [ "$n" -ge 5 ]
    do
        # We need a database that uses a non-lock based MVCC approach
        # https://github.com/microsoft/homebrew-mssql-release/issues/2#issuecomment-682285561
        docker exec mssql bash -c 'echo "create database hibernate_orm_test collate SQL_Latin1_General_CP1_CI_AS; alter database hibernate_orm_test set READ_COMMITTED_SNAPSHOT ON" | /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P Hibernate_orm_test -i /dev/stdin' && break
        echo "Waiting for SQL Server to start..."
        n=$((n+1))
        sleep 5
    done
    if [ "$n" -ge 5 ]; then
      echo "SQL Server failed to start and configure after 25 seconds"
    else
      echo "SQL Server successfully started"
    fi
}

oracle() {
    docker rm -f oracle || true
    # We need to use the defaults
    # SYSTEM/Oracle18
    docker run --shm-size=1536m --name oracle -d -p 1521:1521 quillbuilduser/oracle-18-xe
    until [ "`docker inspect -f {{.State.Health.Status}} oracle`" == "healthy" ];
    do
        echo "Waiting for Oracle to start..."
      sleep 10;
    done
    echo "Oracle successfully started"
    # We increase file sizes to avoid online resizes as that requires lots of CPU which is restricted in XE
    docker exec oracle bash -c "source /home/oracle/.bashrc; bash -c \"
cat <<EOF | \$ORACLE_HOME/bin/sqlplus sys/Oracle18@localhost/XE as sysdba
alter database tempfile '/opt/oracle/oradata/XE/temp01.dbf' resize 400M;
alter database datafile '/opt/oracle/oradata/XE/system01.dbf' resize 1000M;
alter database datafile '/opt/oracle/oradata/XE/sysaux01.dbf' resize 600M;
alter database datafile '/opt/oracle/oradata/XE/undotbs01.dbf' resize 300M;
alter database add logfile group 4 '/opt/oracle/oradata/XE/redo04.log' size 500M reuse;
alter database add logfile group 5 '/opt/oracle/oradata/XE/redo05.log' size 500M reuse;
alter database add logfile group 6 '/opt/oracle/oradata/XE/redo06.log' size 500M reuse;

alter system switch logfile;
alter system switch logfile;
alter system switch logfile;
alter system checkpoint;

alter database drop logfile group 1;
alter database drop logfile group 2;
alter database drop logfile group 3;
EOF\""
}

if [ -z ${1} ]; then
    echo "No db name provided"
    echo "Provide one of:"
    echo -e "\tmysql_5_7"
    echo -e "\tmysql_8_0"
    echo -e "\tmariadb"
    echo -e "\tpostgresql_9_5"
    echo -e "\tdb2"
    echo -e "\tmssql"
    echo -e "\toracle"
else
    ${1}
fi