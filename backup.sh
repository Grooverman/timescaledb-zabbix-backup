#!/bin/bash

# define backup directory
backup_dir="/backup"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
config_file=$SCRIPT_DIR/backup.conf
if test -f "$config_file"
then
        source $config_file
fi

# define database name
if [[ $# == 0 ]]
then
        echo "Please specify a database name."
        exit
fi
database=$1

# define output file name
now=$(date +"%Y-%m-%d-%H%M%S")
output=$database\__$now.bkp.tar

# define list of hypertables
l="history"
l="$l history_uint"
l="$l history_log"
l="$l history_text"
l="$l history_str"
l="$l trends"
l="$l trends_uint"
list=$l

# dump database excluding timescaledb schemas and data 
s="pg_dump -Fc "
for table in $list
do
        s="$s --exclude-table-data=$table"
done
s="$s --exclude-schema=_timescaledb* --exclude-schema=timescaledb*"
s="$s $database >$backup_dir/$database.dump"
pg_dump_command_string=$s
su - postgres -c "$pg_dump_command_string"

# copy data from hypertables to csv files
for table in $list
do
        wc="*"
        s="psql -c"
        s="$s \"\\COPY (SELECT $wc FROM $table)"
        s="$s TO '$backup_dir/$table.csv'"
        s="$s DELIMITER ',' CSV\" $database"
        psql_command_string=$s
        su - postgres -c "$psql_command_string"
done

# create tarball
cd $backup_dir
tar -cvf $output $database.dump --remove-files
for table in $list
do
        # compress csv files
        gzip $table.csv
        # add to tarball
        tar -rf $output $table.csv.gz --remove-files
done

echo "Done."
