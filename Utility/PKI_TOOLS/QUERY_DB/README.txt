Script create_query.sh
Help:
./create_query.sh -h
Usage: ./create_query.sh [-e number_of_days] script_file

The script will use provided shell script (must end with .sh) and will create an executable with a limited time validity.

./create_query.sh foo.sh

Will create an executable named: ad_hoc_tool_foo
