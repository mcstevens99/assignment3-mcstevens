// systemcalls.c

#include "systemcalls.h"

#include <stdbool.h>
#include <stdarg.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <errno.h>

/**
 * Executes a command using system()
 *
 * @param cmd The command string to execute
 * @return true if system() ran successfully AND the command returned exit code 0,
 *         false otherwise
 */
bool do_system(const char *cmd)
{
    if (cmd == NULL) {
        return false;
    }

    int status = system(cmd);

    // Check if system() call failed or
    // Check if command did't exit normally or not with exit code 0
    if (status == -1 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) return false;

    // Otherwise is success 
    return true;
}

/**
 * Executes a command using fork(), execv(), and waitpid()
 *
 * @param count Number of parameters (command + arguments)
 * @param ...   First argument is the absolute path of the executable,
 *              remaining arguments are passed to execv()
 *
 * @return true if command executed successfully and returned exit code 0,
 *         false otherwise
 */
bool do_exec(int count, ...)
{
    if (count < 1) return false;

    va_list args;
    va_start(args, count);

    // Build argv array for execv()
    char *command[count + 1];
    for (int i = 0; i < count; i++) {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL; // execv() requires NULL termination

    va_end(args);

    if (command[0] == NULL) return false;

    pid_t pid = fork();

    // Check if fork() failed
    if (pid < 0) return false;

    // Child process: command execution
    if (pid == 0) {
        // execute the command
        execv(command[0], command);

        // If execv() returns, it failed
        _exit(EXIT_FAILURE);
    }

    // Parent process: wait for child
    int status;
    pid_t ret;
    do {
        ret = waitpid(pid, &status, 0);
    } while (ret == -1 && errno == EINTR);  // retry if interrupted by signal

    // Check if the child didn't exited normally or if the exit code wasn't 0
    if (ret == -1 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) return false;

    return true;
}

/**
 * Executes a command but redirects stdout to a file
 *
 * @param outputfile Full path of output file
 * @param count      Number of command parameters
 * @param ...        command[0] = executable path (absolute),
 *                   remaining args passed to execv()
 *
 * @return true on success, false otherwise
 */
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    if (outputfile == NULL || count < 1) return false;

    va_list args;
    va_start(args, count);

    char *command[count + 1];
    for (int i = 0; i < count; i++) {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;

    va_end(args);

    if (command[0] == NULL) return false;

    pid_t pid = fork();

    // Check if fork() failed
    if (pid < 0) return false;

    // Child process: redirect stdout before executing
    if (pid == 0) {        

        // Open output file with permissions rw-r--r--
        int fd = open(outputfile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        
        // Check if failed to open fd
        if (fd < 0) _exit(EXIT_FAILURE);

        // Check result of duplicate file descriptor to stdout
        if (dup2(fd, STDOUT_FILENO) < 0) {
            close(fd);
            _exit(EXIT_FAILURE);
        }

        close(fd);

        // Execute program
        execv(command[0], command);

        // If execv() returns, it failed
        _exit(EXIT_FAILURE);
    }

    // Parent process: wait for child
    int status;
    pid_t ret;
    do {
        ret = waitpid(pid, &status, 0);
    } while (ret == -1 && errno == EINTR);

    // Check if the child didn't exited normally or if the exit code wasn't 0
    if (ret == -1 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) return false;

    return true;
}