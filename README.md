# TimescaleDB Conversion, Backup and Restore Tool for Zabbix Databases.

[TimescaleDB](https://docs.timescale.com/timescaledb/latest/) is PostgreSQL extension that improves Zabbix' Housekeeper performance by orders of magnitude. 
It replaces the partitioning scripts that we used to use for this purpose, in an elegant and efficient way. 

Zabbix integrates with it seamlessly, you can configure the retention period directly on the web interface.
![image](https://user-images.githubusercontent.com/87875608/194992981-7431e9ab-ba0f-4dd6-94e9-aeaabcb6a070.png)

The `restore.sh` script allows you to restore a backup made with `backup.sh` with minimal downtime, since all the "history" and "trends" data are restored later, after your Zabbix Server has been started (optional). 

You can also use these scripts to convert a normal PostgreSQL database into a TimescaleDB enabled database. 

### Installation
```
git clone https://github.com/Grooverman/timescaledb-zabbix-backup.git
mkdir /backup
chown postgres /backup
```
To override the default options, like backup directory, database user, schema and chunk sizes, create a file named `backup.conf` on the same directory where the scripts will reside, and define in it those variables. 
