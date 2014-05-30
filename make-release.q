#!/usr/bin/env qore
#
# This script creates qdb from doc file and qdb.q source code
#
%new-style

ReadOnlyFile r("README.md");
string help = r.read(-1);
help = replace(help, '"', '\"');

ReadOnlyFile q("qdb.q");
string qdb = q.read(-1);
qdb = replace(qdb, '@HELPSTR@', help);


File o();
o.open2("qdb", O_CREAT | O_TRUNC | O_WRONLY, 0755);
o.write(qdb);

