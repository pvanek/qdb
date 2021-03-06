#!/usr/bin/env qore
#
# The MIT License (MIT)
#
# Copyright (c) 2014 Petr Vanek <petr@yarpen.cz>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


%new-style
%exec-class Main
# qdb is used with new qore, but also with older versions (xml, yaml, ...)
%disable-warning deprecated

%requires linenoise
%requires SqlUtil

%try-module xml
%define NO_XML
%endtry

%try-module yaml
%define NO_YAML
%endtry

%try-module json
%define NO_JSON
%endtry

%try-module QorusClientCore
%define NO_QORUS
%endtry

const VERSION = "0.4";


const options = (
        "help" : "help,h",
        "version" : "version,v",
    );

const HELPSTR = "@HELPSTR@";

sub help(*int status)
{
    printf("Usage:\n");
    printf("%s <connection>\n", get_script_name());
    printf("   connection can be any Qore connection string.\n");
    printf("   E.g.: pgsql:test/test@test%localhost\n");
    printf("\n");
    printf("Use internal command 'help' for more info\n");
    printf("\n");
    if (exists status)
        exit(status);
}

sub get_version()
{
    printf("%s\n", VERSION);
    exit(0);
}


class AbstractOutput
{
    private {
        string m_type;
    }

    constructor(string type)
    {
        m_type = type;
    }

    string type() { return m_type; }

    abstract putLine(hash row, string type, hash describe);
    abstract putEndLine();

} # class AbstractOutput


class StdoutOutput inherits AbstractOutput
{
    constructor() : AbstractOutput("stdout")
    {
    }

    putLine(hash row, string type, hash describe)
    {
        string mask;
        list values;
        string title;
        list key;
        string separator;

        HashIterator it(row);
        while (it.next())
        {
            hash desc;
            if (exists describe{it.getKey()})
                desc = describe{it.getKey()};
            else
                desc.maxsize = 20;

            int max = desc.maxsize < it.getKey().size() ? it.getKey().size() : desc.maxsize;
            if (desc.type == NT_DATE && max < 19)
                max = 19;
            push key, it.getKey();
            title += sprintf("%%-%ds ", max);
            
            switch (desc.type)
            {
                case NT_STRING:
                    push values, it.getValue();
                    mask += sprintf("%%-%ds ", max);
                    separator += strmul("-", max) + " ";
                    break;
                case NT_DATE:
                    push values, format_date("YYYY-MM-DD HH:mm:SS", it.getValue());
                    mask += "%-s ";
                    separator += strmul("-", 19) + " ";
                    break;
                default:
                    push values, it.getValue();
                    mask += sprintf("%%%ds ", max);
                    separator += strmul("-", max) + " ";
            }
        } 
        mask = mask.substr(0, mask.size()-1) + "\n";

        if (type == "header")
        {
            title = title.substr(0, title.size()-1) + "\n";
            vprintf(title, key);
            printf(separator + "\n");
        }

        vprintf(mask, values);
    }

    putEndLine() {}

} # class StdoutOutput

%ifndef NO_XML
class XMLOutput inherits AbstractOutput
{
    constructor() : AbstractOutput("xml") {}

    putLine(hash row, string type, hash describe)
    {
        if (type == "header")
        {
            printf("<xml version=\"1.0\" encoding=\"%s\">\n", get_default_encoding());
            printf("<resultset>\n");
        }
        printf("%s\n", Xml::makeFormattedXMLFragment( ( "row" : row ), get_default_encoding()));
    }

    putEndLine()
    {
        printf("</resultset>");
    }

} # class XMLOutput
%endif

%ifndef NO_YAML
class YamlOutput inherits AbstractOutput
{
    constructor() : AbstractOutput("yaml") {}

    putLine(hash row, string type, hash describe)
    {
        if (type == "header")
        {
            printf("---\n");
        }
        printf("  - %s", YAML::makeYAML(row));
    }

    putEndLine()
    {
        printf("...\n");
    }
} # class YamlOutput
%endif

%ifndef NO_JSON
class JsonOutput inherits AbstractOutput
{
    constructor() : AbstractOutput("json") {}

    putLine(hash row, string type, hash describe)
    {
        if (type == "header")
        {
            printf("[\n");
            printf("    %s\n", Json::makeFormattedJSONString(row));
        }
        else
            printf("   ,%s\n", Json::makeFormattedJSONString(row));
    }

    putEndLine()
    {
        printf("]\n");
    }
} # class JsonOutput
%endif


class Main
{
    private {
        string connstr;
        Datasource ds;
        SqlUtil::Database db;
        int limit = 100;
        int verbose = 0;
        *hash describe;
        string output = "console";

        hash outputs = ( "console" : new StdoutOutput(),
%ifndef NO_XML
                         "xml" : new XMLOutput(),
%endif
%ifndef NO_YAML
                         "yaml" : new YamlOutput(),
%endif
%ifndef NO_JSON
                         "json" : new JsonOutput(),
%endif
                       );

        hash commands = ( "history" : "callHistory",
                          "h" : "callHistory",
                          "commit" : "callCommit",
                          "rollback" : "callRollback",
                          "tables" : "showTables",
                          "views" : "showViews",
                          "sequences" : "showSequences",
                          "procedures" : "showProcedures",
                          "functions" : "showFunctions",
                          "packages" : "showPackages",
                          "types" : "showTypes",
                          "mviews" : "showMViews",
                          "desc" : "describeObject",
                          "describe" : "describeObject",
                          "limit" : "setLimit",
                          "verbose": "setVerbose",
                          "output" : "setOutput",
                          "quit" : "quit",
                          "q" : "quit",
                          "help" : "callHelp",
                          "?" : "callHelp",
                        );

        hash expansions = (
                          "sf" : "select * from ",
                          "scf" : "select count(*) from ",
                        );
    }

    constructor()
    {
        GetOpt go(options);
        hash opts = go.parse(\ARGV);
        if (opts.help)
            help(0);
        if (opts.version)
            get_version();
        if (!elements ARGV)
            help(1);

        connstr = string(ARGV[0]);
%ifndef NO_QORUS
	qorus_client_init2();
        try {
            ds = omqclient.getDatasource(connstr);
        }
        catch (ex) {
#            printf("Qorus client found, but dbparams does not contain: %n\n", connstr);
#            printf("    Continuing with regular connection\n");
        }
%endif

        if (!exists ds)
            ds = new Datasource(connstr);
        ds.setAutoCommit(False);

        db = new SqlUtil::Database(ds, ("native_case" : True) );

        Linenoise::history_set_max_len(100);

        try
            Linenoise::history_load(getConfigFile());
        catch (ex)
            printf("History load: %s - %s\n", ex.err, ex.desc);

        Linenoise::set_callback(\self.lineCallback());

        #printf("Connected to: %n\n", ds.getClientVersion());
        setLimit();
        setVerbose();
        setOutput();

        mainLoop();
    }


    private mainLoop()
    {
        on_exit Linenoise::history_save(getConfigFile());

        while (True)
        {
            *string line = Linenoise::line(getPrompt());
            if (!exists line) {
                printf("^C signal caught. Exiting.\n");
                break;
            }
            else if (line == "")
            {
                # the empty line is returned on terminal resize
                continue;
            }
            
            # TODO/FIXME: ; should be command separator. Allow multiline sql statements.
            if (line[line.size()-1] == ";")
                line = line.substr(0, line.size()-1);

            if (!callCommand(line))
            {
                Linenoise::history_add(line);
                callSQL(line);
            }
        }

        if (ds.inTransaction())
        {
            printf("Connection is in transaction. Rollbacking...\n");
            ds.rollback();
        }
    }


    private list lineCallback(string str)
    {
        list ret = ();
        HashIterator it(commands);
        string rx = sprintf("^%s", str);
        while (it.next())
        {
            if (it.getKey().regex(rx))
               push ret, it.getKey()+" ";
        }

        HashIterator eit(expansions);
        while (eit.next())
        {
            if (eit.getKey() == str)
               push ret, eit.getValue();
        }
        return ret;
    }


    bool callCommand(string line)
    {
        list strs = line.split(" ");
        string cmd = shift strs;
        if (has_key(commands, cmd))
        {
            call_object_method_args(self, commands{cmd}, strs);
            return True;
        }
      
        return False;
    }


    callSQL(string sql)
    {
        date start = now();
        date end;
        
        int count = 0;

        try
        {
            bool header = False;
            describe = NOTHING;
            SQLStatement stmt(ds);
            on_exit stmt.close();
            stmt.prepareRaw(sql);
            while (stmt.next())
            {
                any ret = stmt.fetchRow();

                if (!exists describe)
                    describe = stmt.describe();

                switch (ret.typeCode())
                {
                    case NT_HASH:
                        outputHash(ret, header);
                        header = True;
                        count++;
                        break;
                    case NT_INT:
                        count += ret;
                        break;
                    default:
                        printf("unhandled/raw DB result (res.type()): %N\n", ret);
                }

                if (limit > 0 && count >= limit)
                {
                    break;
                }
            }

            outputs{output}.putEndLine();
        }
        catch (ex)
        {
            printf("\n");
            printf("DB ERROR: %s: %s\n", ex.err, ex.desc);
        }
        end = now();
        
        printf("\n");
        if (limit > 0 && count >= limit)
        {
            printf("User row limit reached: %d\n", limit);
        }
        printf("rows affected: %d\n", count);
        printf("Duration: %n\n", end - start);
        printf("\n");
    }


    outputHash(hash h, bool hasHeader)
    {
        outputs{output}.putLine(h, hasHeader ? "datarow" : "header", describe);
    }


    callHistory()
    {
        list h = Linenoise::history();
        ListIterator it(h);
        int cnt = h.size();

        any val = shift argv;
        if (val != int(val))
            val = NOTHING;
        else
            val = int(val);

        while (it.next())
        {
            if (val && cnt-val > it.index())
                continue;
            printf("%4d: %s\n", it.index(), it.getValue());
        }
    }

    callHelp()
    {
        printf("commands list: %y\n", keys commands);
        printf("%s\n", HELPSTR);
    }

    string getPrompt()
    {
        string ret = sprintf("SQL tran:%s %s:%s@%s%%%s> ",
                              ds.inTransaction() ? 'Y' : 'n',
                              ds.getDriverName(),
                              ds.getUserName(),
                              ds.getDBName(),
                              ds.getHostName()
                             );
        return ret;
    }

    *string getConfigFile()
    {
        try
        {
            string pwd = getpwuid2(getuid()).pw_dir;
            return sprintf("%s/.%s.cfg", pwd, get_script_name());
        }
        catch (ex)
            printf("Config File ERROR: %s - %s\n", ex.err, ex.desc);
        return NOTHING;
    }

    callCommit()
    {
        try
            ds.commit();
        catch (ex)
            printf("Commit ERROR: %s - %s\n", ex.err, ex.desc);
    }

    callRollback()
    {
        try
            ds.rollback();
        catch (ex)
            printf("Commit ERROR: %s - %s\n", ex.err, ex.desc);
    }

    showObjects(string objType, *string filter) {
        string method = sprintf("%sIterator", objType);
        my ListIterator it = call_object_method(db, method);

        printf("\n%ss\n", objType);
        printf("-----------------------------\n");

        while (it.next())
        {
            if (!exists filter)
                printf("%s\n", it.getValue());
            else if (it.getValue().upr().regex(filter.upr()))
                printf("%s\n", it.getValue());
        }
        
        printf("\n");
    }

    showTables()
    {
        showObjects("table", shift argv);
    }

    showViews()
    {
        showObjects("view", shift argv);
    }

    showSequences()
    {
        showObjects("sequence", shift argv);
    }

    showFunctions()
    {
        showObjects("function", shift argv);
    }

    showProcedures()
    {
        showObjects("procedure", shift argv);
    }

    showPackages()
    {
        showObjects("package", shift argv);
    }

    showTypes()
    {
        showObjects("type", shift argv);
    }

    showMViews()
    {
        showObjects("materializedView", shift argv);
    }
    
    setLimit()
    {
        any val = shift argv;
        if (!exists val)
        {
            printf("Current limit: %s\n", limit ? limit : 'unlimited');
            return;
        }
        if (val != int(val))
        {
            printf("Cannot set limit to value: %n. Use numeric value.\n", val);
            return;
        }
        
        limit = int(val);
    }


    setVerbose()
    {
        any val = shift argv;
        if (!exists val)
        {
            printf("Current verbosity: %d\n", verbose);
            return;
        }
        if (val != int(val) || val < 0)
        {
            printf("Cannot set verbosity to value: %n. Use numeric value >= 0\n", val);
            return;
        }

        verbose = int(val);
    }

    setOutput()
    {
        any val = shift argv;
        if (!exists val)
        {
            printf("Current output method: %s. Available %n\n", output, keys outputs);
            return;
        }
        if (!inlist(val, keys outputs))
        {
            printf("Cannot set output mode to to value: %n. Use string value from %n\n", val, keys outputs);
            return;
        }

        output = val;
    }


    quit()
    {
        ds.rollback();
        exit(0);
    }
    

    hash describeColumn(SqlUtil::AbstractColumn c)
    {
        return (
             "name" : c.name,
             "type" : c.native_type,
             "size" : c.size,
             "null" : c.nullable ? 'Y' : 'N',
             "default" : c.def_val,
             "comment" : c.comment,
             );
    }

    describeTable(string name)
    {
        SqlUtil::AbstractTable tab = db.getTable(name);
        printf("Name: %s\n", tab.getName());
        printf("SQL Name: %s\n", tab.getSqlName());

        describe = (
                "name" : ( "type" : NT_STRING, "maxsize" : 35 ),
                "type" : ( "type" : NT_STRING, "maxsize" : 20 ),
                "size" : ( "type" : NT_INT, "maxsize" : 6 ),
                "null" : ( "type" : NT_STRING, "maxsize" : 1 ),
                "default" : ( "type" : NT_STRING, "maxsize" : 22 ),
                "comment" : ( "type" : NT_STRING, "maxsize" : 30 ),
            );

        {
            # Columns
            printf("\nColumns:\n");
            HashIterator it = tab.describe().iterator();
            bool hasHeader = False;
            while (it.next())
            {
                 outputHash(describeColumn(it.getValue()), hasHeader);
                 if (!hasHeader) hasHeader = True;
            }
        }

        # PK
        if (tab.getPrimaryKey().empty())
        {
            printf("\nPrimary Key: none\n");
        }
        else
        {
            printf("\nPrimary Key:\n");
            HashIterator it = tab.getPrimaryKey().iterator();
            bool hasHeader = False;
            while (it.next())
            {
                outputHash(describeColumn(it.getValue()), hasHeader);
                if (!hasHeader) hasHeader = True;
            }
        }

        if (!verbose)
        {
            printf("\nDescribe limited by verbosity. Use: \"verbose 1\" to show indexes and more\n");
            return;
        }

        # Indexes
        if (tab.getIndexes().empty())
        {
            printf("\nIndexes: none\n");
        }
        else
        {
            my HashIterator it = tab.getIndexes().iterator();
            while (it.next())
            {
                printf("\nIndex: %s (%s)\n", it.getValue().name, (it.getValue().unique ? 'unique' : 'non-unique'));

                printf("Index Columns:\n");
                HashIterator cit = it.getValue().columns.iterator();
                bool hasHeader = False;
                while (cit.next())
                {
                    outputHash(describeColumn(cit.getValue()), hasHeader);
                    if (!hasHeader) hasHeader = True;
                }
            }
        }

        # Triggers
        if (tab.getTriggers().empty())
        {
            printf("\nTriggers: none\n");
        }
        else
        {
            HashIterator it = tab.getTriggers().iterator();
            while (it.next())
            {
                printf("Trigger: %s\n", it.getValue().name);
                if (verbose > 1)
                    printf("Source Code:\n%s\n", it.getValue().src);
                else
                    printf("\nDescribe limited by verbosity. Use: \"verbose 2\" to show source codes\n");
            }
        }
    }
    
    bool describeObject(string name, string type)
    {
        ListIterator it(call_object_method(db, sprintf("list%ss", type)));
        while (it.next())
        {
            if (it.getValue().upr() == name)
            {
                if (type == "Table")
                    describeTable(name);
                else
                {
                    ObjectIterator obj(call_object_method(db, sprintf("get%s", type), name));
                    bool hasHeader = False;
                    string src;
                    while (obj.next())
                    {
                        if (obj.getKey() == "src")
                        {
                            src = obj.getValue();
                            continue;
                        }
                        outputHash(obj.getValuePair(), hasHeader);
                        if (!hasHeader) hasHeader = True;
                    }
                    if (verbose > 1)
                        printf("Source Code:\n%s\n", src);
                    else
                        printf("\nDescribe limited by verbosity. Use: \"verbose 2\" to show source codes\n");
                    
                }
                    
                return True;
            }
        }
        return False;
    }

    describeObject()
    {
        *softstring name = shift argv;
        if (!exists name)
        {
            printf("No object name provided\n");
            return;
        }

        name = name.upr();
        # find object type
        list m = ("Table", "View", "Sequence", "Type", "Package", "Procedure", "Function", "MaterializedView");
        foreach string i in (m)
        {
            try {
	        if (describeObject(name, i))
                    return;
            }
            catch (ex) {
                printf("%s: %s\n", ex.err, ex.desc);
            }
        }
    }

} # class Main

