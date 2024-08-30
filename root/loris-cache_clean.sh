#!/bin/bash

#
# loris-cache_clean.sh DIR REDUCE_TO MAX_AGE
#
# Cron script for maintaining the loris cache size.
#
# CAUTION - This script deletes files. Be careful where you point it!
#

IMG_CACHE_DIR="$1"
REDUCE_TO=${2:=1048576} # default 1GB
MAX_AGE=${3:=60} # max age in minutes

echo -ne "$(date +[%c]) "
echo "starting"

# Check that the image cache directory...
# ...is below a certain size and...
# ...and when it is larger, start deleting files accessed more than a certain
# number of days ago until the cache is smaller than the configured size.

# Note the name of the variable __REDUCE_TO__: this should not be the total
# amount of space you can afford for the cache, but instead the total space
# you can afford MINUS the amount you expect the cache to grow in between
# executions of this script.

current_usage () {
        # Standard implementation (slow):
        #du -sk $IMG_CACHE_DIR | cut -f 1                     # Fine for a few GB...

        # Alternative implementation #2 (faster, requires dedicated cache mount):
        df -P "$IMG_CACHE_DIR" | tail -n 1 | awk '{print $3}'
}

delete_total=0
usage=$(current_usage)
start_size=$usage
run=1
while [ $usage -gt $REDUCE_TO ] && [ $MAX_AGE -ge -1 ]; do
        run=0

        # files. loop (instead of -delete) so that we can keep count
        for f in $(find $IMG_CACHE_DIR -type f -amin +$MAX_AGE); do
                rm $f
                let delete_total+=1
        done

        # If the for loop above is not working well for you, you can try uncommenting
        # the alternate implementation below; this version requires write access to
        # /tmp and uses awk, but it allows progress to be monitored by examining temp
        # files, and its use of xargs may make it more tolerant of very large lists.
        #### begin alternate code ####
        #tmpfile=/tmp/loris-cache-clean-$MAX_AGE.tmp
        #find $IMG_CACHE_DIR -type f -atime +$MAX_AGE > $tmpfile
        #line_count=`wc $tmpfile | awk '{print $1}'`
        #let delete_total+=$line_count
        #cat $tmpfile | xargs rm
        #### end alternate code ####

        echo -ne "$(date +[%c]) "
        echo "in progress - max age = $MAX_AGE, Delete total = $delete_total"

        # empty directories
        find $IMG_CACHE_DIR -mindepth 1 -type d -empty -delete

        let MAX_AGE-=1
        usage=$(current_usage)
done

echo -ne "$(date +[%c]) "
if [ $run == 0 ]; then
        echo -ne "Deleted $delete_total files to "
        echo "get cache from $start_size kb to $usage kb."
else
        echo "Cache at $usage kb (no deletes required)."
fi
