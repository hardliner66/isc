# isc
Inter Subsystem Call

redirects calls from windows to linux subsystem (Bash on Windows 10) and redirects output back to caller
e.g.:
isc ls -la

build server:
dub build -c server

build client:
dub build -c client