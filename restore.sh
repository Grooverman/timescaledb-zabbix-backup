#!/bin/bash

# define backup directory, schema and user
backup_dir="/backup"
schema="public"
dbuser="zabbix"
history_chunk_time_interval=86400
trends_chunk_time_interval=2592000

# read config file to override default values above
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
config_file=$SCRIPT_DIR/backup.conf
if test -f "$config_file"
then
	source $config_file
fi

# define database name
if [[ $# < 2 ]]
then
	echo "Please specify a destination database and a backup file."
	echo "Example:"
	echo ""
	echo "    ./restore.sh zabbix /backup/zabbix__2022-10-10-124517.bkp.tar"
        echo ""
	exit
fi
database=$1

# define backup file name
if ! test -f "$2"
then
	echo "File \"$2\" doesn't exist."
	exit 1
fi
backup_file=$2

# confirm from user
echo "Restoring from backup file: $backup_file"
echo "Directory where the backup will be inflated: $backup_dir"
echo "Restoring to database: $database"
echo "Database schema used: $schema"
echo "Database user for Zabbix: $dbuser"
echo ""
while true; do
read -p "Do you want to proceed? (yes/no) " yn
case $yn in 
	yes ) echo Restoring...; echo '';
		break;;
	no ) echo Aborted.;
		exit;;
	* ) echo Invalid response.;;
esac
done

# untar backup file
echo "Extracting files..."
sudo tar -xvf $backup_file -C $backup_dir || exit 1
echo ""

# try to create database
sudo -u postgres \
	createdb -O $dbuser -E Unicode -T template0 $database &>/dev/null

# make sure timescaledb is activated
echo "Activating timescaldb..."
echo "CREATE EXTENSION IF NOT EXISTS timescaledb SCHEMA $schema CASCADE;" \
	| sudo -u postgres psql $database || exit 1
echo ""

# restore database
number_of_dump_files=$(ls /backup | grep -c '\.dump')
if [[ $number_of_dump_files -eq 0 ]]
then
	echo "ERROR: Dump file not found!"; exit 1
elif [[ $number_of_dump_files -gt 1 ]]
then
	echo "ERROR: More than one dump file."
	echo "Move extra files away before starting."; exit 1
elif [[ $number_of_dump_files -eq 1 ]]
then
	echo "Restoring database..."
	dump_file=$(ls $backup_dir | grep '\.dump')
	sudo -u postgres \
		pg_restore --exit-on-error -Fc -d $database $backup_dir/$dump_file \
		|| exit 1
	sudo rm -f $backup_dir/$dump_file
else
	echo "ERROR: There was a problem finding the extracted dump file!"; exit 1
fi
echo ""

# define list of hystory tables
l="history"
l="$l history_uint"
l="$l history_log"
l="$l history_text"
l="$l history_str"
history_tables=$l

# define list of trend tables
l="trends"
l="$l trends_uint"
trends_tables=$l

# create hypertables
for table in $history_tables
do
	i=$history_chunk_time_interval
	c="SELECT create_hypertable('$table', 'clock', chunk_time_interval => $i);"
	echo $c && echo $c | sudo -u postgres psql $database || exit 1
done
for table in $trends_tables
do
	i=$trends_chunk_time_interval
	c="SELECT create_hypertable('$table', 'clock', chunk_time_interval => $i);"
	echo $c && echo $c | sudo -u postgres psql $database || exit 1
done
echo ""

c="UPDATE config SET db_extension='timescaledb',hk_history_global=1,hk_trends_global=1;"
echo "$c"
echo "$c" | sudo -u postgres psql $database
echo ""

echo "From this point on you can safely start Zabbix Server and Frontend."
read -n 1 -s -r -p "Press any key to continue"
echo ""

# restore data from csv to hypertables
echo "Restoring history data..."
for table in $history_tables
do
	sudo gzip -f -d $backup_dir/$table.csv.gz || exit 1
	c="\COPY $table FROM $backup_dir/$table.csv DELIMITER ',' CSV"
	echo $c
	sudo -u postgres \
		psql -d $database -c "$c" || exit 1
	sudo rm -f $backup_dir/$table.csv
done
echo ""
echo "Restoring trends data..."
for table in $trends_tables
do
	# check if zabbix-server has been started during the restore
	declare -i oldest_record=$(
		echo "SELECT clock FROM $table ORDER BY clock ASC LIMIT 1;" \
		| sudo -u postgres psql -qtAX $database)
	# uncompress csv file
	sudo gzip -f -d $backup_dir/$table.csv.gz || exit 1
	# copy csv data to table
	c="\COPY $table FROM $backup_dir/$table.csv"
	c="$c DELIMITER ',' CSV"
	if [[ $oldest_record -gt 0 ]]
	then
		c="$c WHERE clock < $oldest_record"
	fi
	echo $c
	sudo -u postgres \
		psql -d $database -c "$c" || exit 1
	# remove csv file
	sudo rm -f $backup_dir/$table.csv
done
echo ""

echo "Done."
exit 
