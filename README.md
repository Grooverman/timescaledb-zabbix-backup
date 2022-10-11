# TimescaleDB Conversion, Backup and Restore Tool for Zabbix Databases.

[TimescaleDB](https://docs.timescale.com/timescaledb/latest/) is a [PostgreSQL extension](https://www.postgresql.org/docs/current/external-extensions.html) that improves Zabbix' [Housekeeper](https://www.zabbix.com/documentation/current/en/manual/web_interface/frontend_sections/administration/general#housekeeper) performance by orders of magnitude. 
It replaces the [partitioning scripts](https://github.com/zabbix-tools/zabbix-pgsql-partitioning) that we used to use for this purpose, in an [elegant and efficient way](https://blog.zabbix.com/zabbix-time-series-data-and-timescaledb/6642/). 

Zabbix [integrates with it seamlessly](https://www.zabbix.com/documentation/current/en/manual/appendix/install/timescaledb), you can configure the retention periods directly on the web interface.
![image](https://user-images.githubusercontent.com/87875608/194992981-7431e9ab-ba0f-4dd6-94e9-aeaabcb6a070.png)

The `restore.sh` script allows you to restore a backup made with `backup.sh` with minimal downtime, since all the "history" and "trends" data are restored later, after your Zabbix Server has been started (optional). 

You can also use these scripts to convert a normal PostgreSQL database into a TimescaleDB enabled database. 

### Installation
```
git clone https://github.com/Grooverman/timescaledb-zabbix-backup.git
mkdir /backup
chown postgres /backup
```
To override default options like backup directory, database user, schema and chunk sizes, create a file named `backup.conf` on the same directory where the scripts will reside, and define in it those variables. 
