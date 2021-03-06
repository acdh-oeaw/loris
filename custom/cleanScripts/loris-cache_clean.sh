#!/bin/bash

#
# loris-cache_clean.sh
#
# Cron script for maintaining the loris cache size.
#
# CAUTION - This script deletes files. Be careful where you point it!
#

LOG="/var/log/loris/cache_clean.log"

echo -ne "$(date +[%c]) " >> $LOG
echo "starting" >> $LOG

# Check that the image cache directory...
IMG_CACHE_DIR="/var/cache/loris"

# ...is below a certain size and...
#REDUCE_TO=1048576 #1 gb
REDUCE_TO=512000 #500 mb TODO change this to desired size
# REDUCE_TO=1073741824 # 1 TB
# REDUCE_TO=2147483648 # 2 TB

# ...and when it is larger, start deleting files accessed more than a certain
# number of days ago until the cache is smaller than the configured size.

# Note the name of the variable __REDUCE_TO__: this should not be the total
# amount of space you can afford for the cache, but instead the total space
# you can afford MINUS the amount you expect the cache to grow in between
# executions of this script.

current_usage () {
        # Standard implementation (slow):
        du -sk $IMG_CACHE_DIR | cut -f 1                     # Fine for a few GB...

        # Alternative implementation #1 (faster, requires quota setup):
        # quota -Q -u loris | grep sdb1 | awk '{ print $2 }' # ...much faster!!
        # Note that you'll like need to change the name of the filesystem above if
        # using the `quota` version.

        # Alternative implementation #2 (faster, requires dedicated cache mount):
        # df -P | grep /data | awk '{print $3}'
        # Note that using df is fast, but it assumes that your cache has its own
        # dedicated mounted partition. Replace "/data" with the appropriate mount
        # point in the code above to use this option.
}

delete_total=0
max_age=60 # minutes
usage=$(current_usage)
start_size=$usage
run=1
while [ $usage -gt $REDUCE_TO ] && [ $max_age -ge -1 ]; do
        run=0

        # files. loop (instead of -delete) so that we can keep count
        for f in $(find $IMG_CACHE_DIR -type f -amin +$max_age); do
                rm $f
                let delete_total+=1
        done

        # If the for loop above is not working well for you, you can try uncommenting
        # the alternate implementation below; this version requires write access to
        # /tmp and uses awk, but it allows progress to be monitored by examining temp
        # files, and its use of xargs may make it more tolerant of very large lists.
        #### begin alternate code ####
        #tmpfile=/tmp/loris-cache-clean-$max_age.tmp
        #find $IMG_CACHE_DIR -type f -atime +$max_age > $tmpfile
        #line_count=`wc $tmpfile | awk '{print $1}'`
        #let delete_total+=$line_count
        #cat $tmpfile | xargs rm
        #### end alternate code ####

        echo -ne "$(date +[%c]) " >> $LOG
        echo "in progress - max age = $max_age, Delete total = $delete_total" >> $LOG

        # empty directories
        find $IMG_CACHE_DIR -mindepth 1 -type d -empty -delete

        let max_age-=1
        usage=$(current_usage)
done

echo -ne "$(date +[%c]) " >> $LOG
if [ $run == 0 ]; then
        echo -ne "Deleted $delete_total files to " >> $LOG
        echo "get cache from $start_size kb to $usage kb." >> $LOG
else
        echo "Cache at $usage kb (no deletes required)." >> $LOG
fi
