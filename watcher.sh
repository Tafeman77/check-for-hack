#!/bin/bash

# Defining the file to monitor
PASSWD_FILE="/etc/passwd"
# Storing the initial checksum of the file
CHECKSUM_FILE="/var/tmp/passwd_checksum.txt"
# Log file for SSH connection IPs
LOGFILE="/var/log/passwd_ssh_changes.log"

# Checking if the checksum file exists; if not, creating one
if [ ! -f "$CHECKSUM_FILE" ]; then
    md5sum "$PASSWD_FILE" > "$CHECKSUM_FILE"
    echo "Initial checksum of $PASSWD_FILE has been stored on $(date)" >> "$LOGFILE"
fi

# Define monitoring log file
LOG_FILE="/var/log/user_monitor.log"

# Ensure log file exists and has proper permissions
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

# Initial check of logged-in users
previous_users=$(who | awk '{print $1}' | sort | uniq)

# Log initial state
echo "Starting user login monitoring at $(date)" >> "$LOG_FILE"
echo "Initial users logged in:" >> "$LOG_FILE"
echo "$previous_users" >> "$LOG_FILE"
echo "----------------------------------------" >> "$LOG_FILE"

# Also display to terminal
echo "Starting user login monitoring at $(date)"
echo "Initial users logged in:"
echo "$previous_users"
echo "----------------------------------------"

# Running an infinite loop to check every 1 seconds
while true; do
    # Reading the stored checksum
    OLD_CHECKSUM=$(cat "$CHECKSUM_FILE")
    # Calculating the current checksum
    NEW_CHECKSUM=$(md5sum "$PASSWD_FILE" | awk '{print $1}')

    # Comparing the old and new checksums
    if [ "$OLD_CHECKSUM" != "$NEW_CHECKSUM" ]; then
        echo "ALERT: The file $PASSWD_FILE has been modified on $(date)!" >> "$LOGFILE"
        # Logging current SSH connections with IPs
        echo "Active SSH connections at the time of change:" >> "$LOGFILE"
        ss -ant | grep -e "ESTAB" | grep ":22" | tr -s ' ' | cut -d' ' -f5 | cut -d':' -f1 | sort -u >> "$LOGFILE"
        echo "----------------------------------------" >> "$LOGFILE"
        # Updating the stored checksum to the new value
        md5sum "$PASSWD_FILE" > "$CHECKSUM_FILE"
    else
        echo "No changes detected in $PASSWD_FILE at $(date)." >> "$LOGFILE"
 
    # Get current logged-in users
    current_users=$(who | awk '{print $1}' | sort | uniq)
    
    # Compare current users with previous users
    if [ "$current_users" != "$previous_users" ]; then
        # Log change detection
        echo "Change detected at $(date)" >> "$LOG_FILE"
        
        # Find users who logged in
        new_users=$(comm -13 <(echo "$previous_users") <(echo "$current_users"))
        if [ -n "$new_users" ]; then
            echo "New users logged in:" >> "$LOG_FILE"
            echo "$new_users" >> "$LOG_FILE"
            # Display to terminal
            echo "New users logged in:"
            echo "$new_users"
        fi
        
        # Find users who logged out
        logged_out=$(comm -23 <(echo "$previous_users") <(echo "$current_users"))
        if [ -n "$logged_out" ]; then
            echo "Users logged out:" >> "$LOG_FILE"
            echo "$logged_out" >> "$LOG_FILE"
            # Display to terminal
            echo "Users logged out:"
            echo "$logged_out"
        fi
        
        # Log current users
        echo "Current users logged in:" >> "$LOG_FILE"
        echo "$current_users" >> "$LOG_FILE"
        echo "----------------------------------------" >> "$LOG_FILE"
        
        # Display to terminal
        echo "Current users logged in:"
        echo "$current_users"
        echo "----------------------------------------"
        
        # Update previous_users for the next iteration
        previous_users="$current_users"
    fi

    # Waiting for 1 seconds before the next check
    sleep 1
done
