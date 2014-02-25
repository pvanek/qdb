qdb
===

An universal database client for command line. Currently supported DBMS:
* Oracle
* Postgresql
* MySQL (or clones/forks)


## Requirements

* Qore programming language: qore.org
* Linenoise module for Qore
* SqlUtil module for Qore


## Basic Usage

```
./qdb oracle:scott/tiger@dbname
```

The connection string is constructed as in [standard Qore connection](http://docs.qore.org/current/lang/html/group__dbi__functions.html#gad95f3a076d1818cc722c516543e29858)

Then the SQL prompt appears to enter raw SQL statements.

By default is the output of select statement limited to display only 100 rows. Use 'limit <integer>' command to modify this behavior.

Press <TAB> for command/expansion automatic completion.
There are more keyboard shortcuts avalable - see Qore Linenoise documentation.

### Transaction Handling

qdb disables potential autocommit for all DBMS. Commit has to be performed manually. Transaction in progress is rollbacked by default on application exit.

Status of transaction is displayed in SQL prompt - value after "tran:" string.

Out of transaction:
```
SQL tran:n oracle:hr@orcl%10.211.55.7
```

In transaction:
```
SQL tran:Y oracle:hr@orcl%10.211.55.7
```

### Available commands

Note: Some commands make sense on special DBMS only.

* quit : rollback and exit the application
* history [integer] : it shows history of commands. The latest items are displayed only if is the integer value provided.
* commit : Commit current transaction. See "Transaction Handling".
* rollback : Rollback current transaction. See "Transaction Handling".
* limit [integer] : display current row limit or set the limit to integer value.  Values <= 0 mean unlimited.
* verbose [integer] : set the verbosity level for describe commands
* output [string] : set the data result display. See "Supported Output Formats"
* describe objectname : show object properties. Eg. table's columns, PK, indexes, etc. You can increase verbose level to get more info.
* desc objectname : an alias for describe
* tables [filter] : list all tables. Optional filter is case insensitive substring or regular expression.
* views [filter] : list all views. Optional filter is case insensitive substring or regular expression.
* sequences [filter] : list all sequences. Optional filter is case insensitive substring or regular expression.
* procedures [filter] : list all procedures. Optional filter is case insensitive substring or regular expression.
* functions [filter] : list all functions. Optional filter is case insensitive substring or regular expression.
* packages [filter] : list all packages. Optional filter is case insensitive substring or regular expression.
* types [filter] : list all named types. Optional filter is case insensitive substring or regular expression.
* mviews [filter] : list all materialized views. Optional filter is case insensitive substring or regular expression.


### Supported Output Formats

There are bunch of output formats available. Current format can be obtained by ```output``` command.
Using ```output xml``` you can switch standard output to XML.
Currently available formats:

* console - a classic command line "tabular" output
* xml - XML output. The root tag is ```resultset``` and each row is using tag ```row```
* json - TODO
* yaml - one YAML document per statement


### Expansion Helpers

Various string shortcuts can be expanded by <TAB> to longer strings to speed up typing.

* sf : select * from 
* scf : select count(*) from 


## Sample Usage

```
lister:qdb pvanek$ ./qdb oracle:hr/hr@orcl%10.211.55.7:1521
Current limit: 100
Current verbosity: 0
SQL tran:n oracle:hr@orcl%10.211.55.7> tables 

table               
--------------------
REGIONS             
LOCATIONS           
DEPARTMENTS         
JOBS                
EMPLOYEES           
JOB_HISTORY         
COUNTRIES           

SQL tran:n oracle:hr@orcl%10.211.55.7> desc countries
Name: COUNTRIES
SQL Name: hr.COUNTRIES

Columns:

name                 native_type          size nullable def_val comment             
-------------------- -------------------- ---- -------- ------- --------------------
country_id           char                    2        0         Primary key of countries table.
country_name         varchar2               40        1         Country name        
region_id            number                  0        1         Region ID for the country. Foreign key to region_id column in the departments table.

Primary Key:

name                 native_type          size nullable def_val comment             
-------------------- -------------------- ---- -------- ------- --------------------
country_id           char                    2        0         Primary key of countries table.

Describe limited by verbosity. Use: "verbose 1" to show indexes and more
SQL tran:n oracle:hr@orcl%10.211.55.7> select * from countries;

country_id           country_name         region_id           
-------------------- -------------------- --------------------
AU                   Australia                               3
BR                   Brazil                                  2
CH                   Switzerland                             1
DE                   Germany                                 1
EG                   Egypt                                   4
HK                   HongKong                                3
IN                   India                                   3
JP                   Japan                                   3
MX                   Mexico                                  2
NL                   Netherlands                             1
UK                   United Kingdom                          1
ZM                   Zambia                                  4

rows affected: 12
Duration: <time: 0 seconds>

SQL tran:Y oracle:hr@orcl%10.211.55.7> quit
```


