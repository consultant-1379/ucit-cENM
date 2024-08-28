#!/bin/bash
#
files=$(ls delete_entity_*_from_db)
#
for f in $files
do
  entities=$(echo $f | sed -e 's/delete_entity_//' -e 's/_from_db//' -e 's/_/,/g' )
   ./create_delete_entity.sh $entities
done
#
