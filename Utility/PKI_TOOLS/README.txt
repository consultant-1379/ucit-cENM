Script delete_entity.sh
This script is used by create_delete_entity.sh

Script create_delete_entity.sh
Help:
./create_delete_entity.sh -h
Usage: ./create_delete_entity.sh [-e number_of_days] <entity name>[,<entity name>][,<entity name>][,....]

The script will use delete_entity.sh and will create an executable with a limited time validity.
The executable can be used on ENM to delete only the entity specified inside the executable.

Example for entity "foo" and "bar"

./create_delete_entity.sh foo,bar

Will create an executable named: delete_entity_foo_bar_from_db
