#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>

int main(int argc, char *argv[]) {

    // Initialize syslog: program name NULL, LOG_USER facility 
    openlog(NULL, LOG_PID, LOG_USER);

    if (argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguments. Expected 2 arguments.");
        closelog();
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr = argv[2];

    // Log the debug message before writing 
    syslog(LOG_DEBUG, "Writing '%s' to '%s'", writestr, writefile);

    // Try opening the file 
    FILE *fp = fopen(writefile, "w");
    if (fp == NULL) {
        syslog(LOG_ERR, "Error opening file: %s", writefile);
        closelog();
        return 1;
    }

    // Write the content 
    if (fputs(writestr, fp) == EOF) {
        syslog(LOG_ERR, "Error writing to file: %s", writefile);
        fclose(fp);
        closelog();
        return 1;
    }

    fclose(fp);
    closelog();
    return 0;
}