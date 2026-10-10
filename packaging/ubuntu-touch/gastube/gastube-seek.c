/* Seeks the system player's new media-hub session once, 2.5s after it
 * appears. Lomiri stops GasTube's process group. setsid() leaves that
 * group, so this process keeps running inside the click profile.
 */
#include <errno.h>
#include <gio/gio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define DEST "com.lomiri.MediaHub.Service"
#define SESSIONS "/com/lomiri/MediaHub/Service/sessions"
#define PLAYER "org.mpris.MediaPlayer2.Player"
#define TRACKS "org.mpris.MediaPlayer2.TrackList"
#define MAX_SESSIONS 128
#define KEY_MAX 8192

static gint64 now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (gint64)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static void resume_paths(char *dir, size_t dir_len) {
  const char *home = g_get_home_dir();
  const char *data = g_getenv("XDG_DATA_HOME");
  if (data != NULL && data[0] != '\0') {
    g_snprintf(dir, dir_len, "%s/gastube.alphaliu01/player-resume", data);
  } else {
    g_snprintf(
        dir, dir_len, "%s/.local/share/gastube.alphaliu01/player-resume", home);
  }
}

static GDBusConnection *session_bus(void) {
  GError *error = NULL;
  GDBusConnection *bus = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
  if (bus == NULL) {
    fprintf(stderr, "gastube-seek: bus error=%s\n", error->message);
    g_error_free(error);
  }
  return bus;
}

static GVariant *call_sync(
    GDBusConnection *bus,
    const char *path,
    const char *interface,
    const char *method,
    GVariant *args,
    const GVariantType *reply) {
  GError *error = NULL;
  GVariant *result = g_dbus_connection_call_sync(
      bus, DEST, path, interface, method, args, reply,
      G_DBUS_CALL_FLAGS_NONE, 3000, NULL, &error);
  if (result == NULL && error != NULL) {
    g_error_free(error);
  }
  return result;
}

static int session_ids(GDBusConnection *bus, int *ids, int max_ids) {
  GVariant *result = call_sync(
      bus, SESSIONS, "org.freedesktop.DBus.Introspectable", "Introspect",
      NULL, G_VARIANT_TYPE("(s)"));
  if (result == NULL) return 0;
  const char *xml = NULL;
  g_variant_get(result, "(&s)", &xml);
  int count = 0;
  const char *cursor = xml;
  while (cursor != NULL && count < max_ids) {
    cursor = strstr(cursor, "name=\"");
    if (cursor == NULL) break;
    cursor += 6;
    char *end = NULL;
    long value = strtol(cursor, &end, 10);
    if (end != cursor && *end == '"') {
      ids[count++] = (int)value;
    }
  }
  g_variant_unref(result);
  return count;
}

static int contains_id(const int *ids, int count, int id) {
  for (int i = 0; i < count; i++) {
    if (ids[i] == id) return 1;
  }
  return 0;
}

/* Part after the last slash, matching the key GasTube writes. */
static int track_key(GDBusConnection *bus, int id, char *key, size_t key_len) {
  char path[160];
  g_snprintf(path, sizeof path, "%s/%d/TrackList", SESSIONS, id);
  GVariant *tracks = call_sync(
      bus, path, "org.freedesktop.DBus.Properties", "Get",
      g_variant_new("(ss)", TRACKS, "Tracks"), G_VARIANT_TYPE("(v)"));
  if (tracks == NULL) return 0;
  GVariant *wrapped = g_variant_get_child_value(tracks, 0);
  GVariant *array = g_variant_get_variant(wrapped);
  g_variant_unref(wrapped);
  g_variant_unref(tracks);
  if (array == NULL || g_variant_n_children(array) < 1) {
    if (array != NULL) g_variant_unref(array);
    return 0;
  }
  const char *track_id = NULL;
  g_variant_get_child(array, 0, "&s", &track_id);
  char owned[1024];
  g_strlcpy(owned, track_id == NULL ? "" : track_id, sizeof owned);
  g_variant_unref(array);
  if (owned[0] == '\0') return 0;

  GVariant *uri_value = call_sync(
      bus, path, TRACKS, "GetTracksUri", g_variant_new("(s)", owned),
      G_VARIANT_TYPE("(s)"));
  if (uri_value == NULL) return 0;
  const char *uri = NULL;
  g_variant_get(uri_value, "(&s)", &uri);
  const char *slash = uri == NULL ? NULL : strrchr(uri, '/');
  const char *tail = slash == NULL ? uri : slash + 1;
  if (tail == NULL) tail = "";
  g_strlcpy(key, tail, key_len);
  g_variant_unref(uri_value);
  return key[0] != '\0';
}

static int seek_session(GDBusConnection *bus, int id, long ms) {
  char path[128];
  g_snprintf(path, sizeof path, "%s/%d", SESSIONS, id);
  GError *error = NULL;
  GVariant *result = g_dbus_connection_call_sync(
      bus, DEST, path, PLAYER, "Seek",
      g_variant_new("(t)", (guint64)ms * 1000), NULL, G_DBUS_CALL_FLAGS_NONE,
      3000, NULL, &error);
  if (error != NULL) {
    fprintf(stderr, "gastube-seek: seek error=%s\n", error->message);
    g_error_free(error);
    return 0;
  }
  if (result != NULL) g_variant_unref(result);
  return 1;
}

static void read_pending(const char *path, long *ms, char *key, size_t key_len) {
  *ms = 0;
  key[0] = '\0';
  FILE *file = fopen(path, "r");
  if (file == NULL) return;
  char line[64];
  if (fgets(line, sizeof line, file) == NULL) {
    fclose(file);
    return;
  }
  *ms = strtol(line, NULL, 10);
  if (fgets(key, (int)key_len, file) != NULL) {
    size_t len = strlen(key);
    if (len > 0 && key[len - 1] == '\n') key[len - 1] = '\0';
  }
  fclose(file);
}

static void write_text(const char *path, const char *text) {
  char tmp[4096];
  g_snprintf(tmp, sizeof tmp, "%s.tmp", path);
  FILE *file = fopen(tmp, "w");
  if (file == NULL) return;
  fputs(text, file);
  fclose(file);
  rename(tmp, path);
}

int main(void) {
  if (setsid() < 0) {
    fprintf(stderr, "gastube-seek: setsid errno=%d\n", errno);
  } else {
    fprintf(stderr, "gastube-seek: setsid ok\n");
  }

  char dir[1024];
  resume_paths(dir, sizeof dir);
  g_mkdir_with_parents(dir, 0755);
  char lock_path[1200];
  char pending_path[1200];
  char beat_path[1200];
  g_snprintf(lock_path, sizeof lock_path, "%s/seek-helper.lock", dir);
  g_snprintf(pending_path, sizeof pending_path, "%s/pending-seek", dir);
  g_snprintf(beat_path, sizeof beat_path, "%s/seek-helper.heartbeat", dir);

  int lock = open(lock_path, O_RDWR | O_CREAT, 0644);
  if (lock < 0 || flock(lock, LOCK_EX | LOCK_NB) < 0) {
    fprintf(stderr, "gastube-seek: already running\n");
    return 0;
  }

  GDBusConnection *bus = NULL;
  long seen_ms = -1;
  char seen_key[KEY_MAX];
  seen_key[0] = '\0';
  int snapshot[MAX_SESSIONS];
  int snapshot_count = 0;
  int armed_id = -1;
  gint64 armed_at = 0;
  gint64 deadline = 0;
  fprintf(stderr, "gastube-seek: ready\n");

  for (;;) {
    write_text(beat_path, "");
    if (bus == NULL) bus = session_bus();

    long ms = 0;
    char key[KEY_MAX];
    read_pending(pending_path, &ms, key, sizeof key);
    if (ms != seen_ms || strcmp(key, seen_key) != 0) {
      seen_ms = ms;
      g_strlcpy(seen_key, key, sizeof seen_key);
      armed_id = -1;
      snapshot_count = bus == NULL ? 0 : session_ids(bus, snapshot, MAX_SESSIONS);
      deadline = now_ms() + 20000;
      if (ms >= 5000 && key[0] != '\0') {
        fprintf(
            stderr, "gastube-seek: request ms=%ld sessions=%d\n", ms,
            snapshot_count);
      }
    }

    gint64 now = now_ms();
    if (bus != NULL && ms >= 5000 && key[0] != '\0' && now < deadline) {
      int ids[MAX_SESSIONS];
      int count = session_ids(bus, ids, MAX_SESSIONS);
      int newest = -1;
      for (int i = 0; i < count; i++) {
        if (contains_id(snapshot, snapshot_count, ids[i])) continue;
        if (ids[i] < newest) continue;
        char found[KEY_MAX];
        if (!track_key(bus, ids[i], found, sizeof found)) continue;
        if (strcmp(found, key) != 0) continue;
        newest = ids[i];
      }
      if (newest >= 0) {
        if (armed_id != newest) {
          armed_id = newest;
          armed_at = now;
          fprintf(stderr, "gastube-seek: saw session=%d\n", newest);
        }
        if (now - armed_at >= 2500) {
          int ok = seek_session(bus, newest, ms);
          fprintf(
              stderr, "gastube-seek: seek once session=%d ms=%ld age=%.1f ok=%d\n",
              newest, ms, (now - armed_at) / 1000.0, ok);
          write_text(pending_path, "0\n\n");
          seen_ms = 0;
          seen_key[0] = '\0';
          armed_id = -1;
        }
      }
    } else if (ms >= 5000 && key[0] != '\0' && now >= deadline) {
      fprintf(stderr, "gastube-seek: gave up ms=%ld\n", ms);
      write_text(pending_path, "0\n\n");
      seen_ms = 0;
      seen_key[0] = '\0';
      armed_id = -1;
    }

    g_usleep(250 * 1000);
  }
}
