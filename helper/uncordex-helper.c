/*
 * Uncordex helper.
 *
 * macOS grants Bluetooth access per app. Terminal apps such as Terminal and
 * Warp declare no Bluetooth use, so macOS stops blueutil without asking.
 * This helper lives inside Uncordex.app, which declares Bluetooth use. It
 * runs one command as its child, so macOS asks about (and remembers)
 * "Uncordex" instead of the terminal app.
 *
 * Usage: uncordex-helper [--output PREFIX] COMMAND [ARGS...]
 *   --output PREFIX  write the command's output to PREFIX.out and PREFIX.err,
 *                    then its exit status to PREFIX.status (written last).
 */
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;
static volatile pid_t child = 0;

static void forward(int sig) {
  if (child > 0) kill(child, sig);
}

static void write_status(const char *prefix, int code) {
  char path[PATH_MAX], temporary[PATH_MAX];
  FILE *file;
  if (prefix == NULL) return;
  snprintf(path, sizeof(path), "%s.status", prefix);
  snprintf(temporary, sizeof(temporary), "%s.status.tmp", prefix);
  file = fopen(temporary, "w");
  if (file == NULL) return;
  fprintf(file, "%d\n", code);
  fclose(file);
  rename(temporary, path);
}

int main(int argc, char **argv) {
  const char *status_file = NULL;
  char out_path[PATH_MAX], err_path[PATH_MAX];
  int first = 1, code, status, result;
  pid_t spawned;
  struct sigaction action;
  posix_spawn_file_actions_t actions;

  if (argc > 2 && strcmp(argv[1], "--output") == 0) {
    status_file = argv[2];
    first = 3;
  }
  if (first >= argc) {
    fprintf(stderr, "usage: uncordex-helper [--output PREFIX] COMMAND [ARGS...]\n");
    write_status(status_file, 64);
    return 64;
  }

  memset(&action, 0, sizeof(action));
  action.sa_handler = forward;
  sigemptyset(&action.sa_mask);
  sigaction(SIGTERM, &action, NULL);
  sigaction(SIGINT, &action, NULL);
  sigaction(SIGHUP, &action, NULL);

  posix_spawn_file_actions_init(&actions);
  if (status_file != NULL) {
    snprintf(out_path, sizeof(out_path), "%s.out", status_file);
    snprintf(err_path, sizeof(err_path), "%s.err", status_file);
    posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, out_path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, err_path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  }
  result = posix_spawn(&spawned, argv[first], &actions, NULL, &argv[first], environ);
  posix_spawn_file_actions_destroy(&actions);
  if (result != 0) {
    fprintf(stderr, "uncordex-helper: cannot run %s: %s\n", argv[first], strerror(result));
    write_status(status_file, 127);
    return 127;
  }
  child = spawned;
  while (waitpid(spawned, &status, 0) < 0) {
    if (errno != EINTR) {
      write_status(status_file, 1);
      return 1;
    }
  }
  code = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
  write_status(status_file, code);
  return code;
}
