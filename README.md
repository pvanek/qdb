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

### Available commands

Note: Some commands make sense on special DBMS only.

* quit : rollback and exit the application
* history [integer] : it shows history of commands. The latest items are displayed only if is the integer value provided.
* commit : Commit current transaction. See Transaction Handling.
* rollback : Rollback current transaction. See Transaction Handling.
* limit [integer] : display current row limit or set the limit to integer value.  Values <= 0 mean unlimited.
* verbose [integer] : set the verbosity level for describe commands
* describe <objectname> : show object properties. Eg. table's columns, PK, indexes, etc. You can increase verbose level to get more info.
* desc <objectname> : an alias fro describe
* tables : list all tables
* views : list all views
* sequences : list all sequences
* procedures : list all procedures
* functions : list all functions
* packages : list all packages
* types : list all named types
* mviews : list all materialized views


### Expansion Helpers

Various string shortcuts can be expanded by <TAB> to longer strings to speed up typing.

* sf : select * from 
* scf : select count(*) from 

