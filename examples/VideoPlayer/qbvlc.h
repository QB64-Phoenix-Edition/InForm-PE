/*-----------------------------------------------------------------------------------------------------------------------
  libvlc video bridge for QB64-PE
  Copyright (c) 2026 Tony3068
  Licensed under the MIT License (see LICENSE.txt). macOS support added for
  InForm-PE by Fellippe Heitor.
-----------------------------------------------------------------------------------------------------------------------*/
/*=============================================================================
  qbvlc.h  -  libvlc 3.x video bridge for QB64-PE   (Windows, Linux and macOS)

  * Header-only: QB64-PE compiles it together with your program via
    DECLARE LIBRARY "qbvlc"  (see VLCHandles.bi).  No extra compiler flags.
  * libvlc is loaded AT RUNTIME (LoadLibrary / dlopen), so no VLC SDK headers
    or import libraries are needed to build.  Only the VLC 3.x runtime.
  * VLC decodes on its own threads into a memory buffer (RV32 = BGRA, the same
    byte order as a QB64 32-bit image).  Your BASIC loop polls for a new frame.
    No ON TIMER, no window, no callbacks into BASIC.
  * Audio is played by VLC itself (on by default, volume 100).

  Everything is prefixed qbvlc_ / qbv_ to avoid clashing with QB64's own code.
=============================================================================*/
#ifndef QBVLC_H
#define QBVLC_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#define QBV_YIELD() Sleep(0)
#else
#include <dlfcn.h>
#include <sched.h>
#define QBV_YIELD() sched_yield()
#endif

#define QBVLC_MAX 8 /* simultaneous videos */

/* ---- libvlc 3.x function / callback signatures (all opaque pointers = void*)
 */
typedef void *(*qbv_lock_cb)(void *, void **);
typedef void (*qbv_unlock_cb)(void *, void *, void *const *);
typedef void (*qbv_display_cb)(void *, void *);
typedef unsigned (*qbv_setup_cb)(void **, char *, unsigned *, unsigned *,
                                 unsigned *, unsigned *);
typedef void (*qbv_cleanup_cb)(void *);

typedef void *(*qbv_f_new)(int, const char *const *);
typedef void (*qbv_f_vp)(void *);
typedef void *(*qbv_f_media_new)(void *, const char *);
typedef void *(*qbv_f_mp_new)(void *);
typedef int (*qbv_f_play)(void *);
typedef void (*qbv_f_set_pause)(void *, int);
typedef int (*qbv_f_get_state)(void *);
typedef int64_t (*qbv_f_get_time)(void *);
typedef void (*qbv_f_set_time)(void *, int64_t);
typedef int (*qbv_f_set_vol)(void *, int);
typedef int (*qbv_f_get_vol)(void *);
typedef void (*qbv_f_set_mute)(void *, int);
typedef void (*qbv_f_set_cbs)(void *, qbv_lock_cb, qbv_unlock_cb,
                              qbv_display_cb, void *);
typedef void (*qbv_f_set_fmtcbs)(void *, qbv_setup_cb, qbv_cleanup_cb);
typedef float (*qbv_f_get_fps)(void *);

typedef struct {
  int used;
  void *mp;              /* libvlc_media_player_t*                       */
  volatile int lock;     /* spinlock guarding buf[], fresh, bw, bh        */
  unsigned char *buf[2]; /* [0]=VLC writes here, [1]=latest finished frame */
  unsigned char *stage;  /* reader-side copy with alpha forced to 255      */
  size_t stage_cap;
  int bw, bh;          /* size of buf[] (what VLC delivers)             */
  int sw, sh;          /* size of the frame last handed to BASIC        */
  int nat_w, nat_h;    /* native size of the video                      */
  int req_w, req_h;    /* size requested by the caller (0 = native)     */
  volatile int fresh;  /* buf[1] holds a frame BASIC has not taken yet  */
  volatile int frames; /* total frames decoded                          */
} qbv_slot;

static struct {
  void *lib;
  void *inst;
  int err;
  qbv_f_new f_new;
  qbv_f_vp f_release;
  qbv_f_media_new f_media_path, f_media_loc;
  qbv_f_vp f_media_release;
  qbv_f_mp_new f_mp_new;
  qbv_f_vp f_mp_release, f_mp_stop;
  qbv_f_play f_mp_play;
  qbv_f_set_pause f_mp_pause;
  qbv_f_get_state f_mp_state;
  qbv_f_get_time f_mp_time, f_mp_length;
  qbv_f_set_time f_mp_set_time;
  qbv_f_set_vol f_a_set_vol;
  qbv_f_get_vol f_a_get_vol;
  qbv_f_set_mute f_a_mute;
  qbv_f_set_cbs f_v_cbs;
  qbv_f_set_fmtcbs f_v_fmt;
  qbv_f_get_fps f_mp_fps; /* optional: may stay NULL */
  qbv_slot slot[QBVLC_MAX + 1];
} qbvlc_g;

/* ---- tiny spinlock (gcc builtins; same on MinGW and Linux) -------------- */
static void qbv_lock(volatile int *l) {
  while (__sync_lock_test_and_set(l, 1))
    QBV_YIELD();
}
static void qbv_unlock(volatile int *l) { __sync_lock_release(l); }

static qbv_slot *qbv_get(int32_t h) {
  if (h < 1 || h > QBVLC_MAX)
    return NULL;
  if (!qbvlc_g.slot[h].used)
    return NULL;
  return &qbvlc_g.slot[h];
}

/* ---- runtime loading of libvlc ------------------------------------------ */
static void *qbv_sym(const char *name) {
#ifdef _WIN32
  return (void *)GetProcAddress((HMODULE)qbvlc_g.lib, name);
#else
  return dlsym(qbvlc_g.lib, name);
#endif
}

static void *qbv_open_lib(void) {
#ifdef _WIN32
  void *h = (void *)LoadLibraryA("libvlc.dll"); /* next to the .exe / on PATH */
  if (h)
    return h;
  {
    const char *envs[3] = {"ProgramW6432", "ProgramFiles", "ProgramFiles(x86)"};
    int i;
    for (i = 0; i < 3; i++) {
      const char *d = getenv(envs[i]);
      char dir[MAX_PATH + 32], path[MAX_PATH + 64];
      if (!d)
        continue;
      snprintf(dir, sizeof dir, "%s\\VideoLAN\\VLC", d);
      snprintf(path, sizeof path, "%s\\libvlc.dll", dir);
      h = (void *)LoadLibraryExA(path, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
      if (h) {
        if (!getenv("VLC_PLUGIN_PATH")) {
          char pp[MAX_PATH + 64];
          snprintf(pp, sizeof pp, "%s\\plugins", dir);
          SetEnvironmentVariableA("VLC_PLUGIN_PATH", pp);
        }
        return h;
      }
    }
  }
  return NULL;
#elif defined(__APPLE__)
  /* libvlc.dylib next to the program or on the library path, else VLC.app.
     VLC.app must match the program's architecture (use the Universal or the
     Apple Silicon build of VLC on an arm64 Mac). */
  void *h = dlopen("libvlc.dylib", RTLD_NOW);
  if (h)
    return h;
  {
    const char *home = getenv("HOME");
    char dirs[2][1024];
    int i;
    snprintf(dirs[0], sizeof dirs[0], "/Applications/VLC.app/Contents/MacOS");
    snprintf(dirs[1], sizeof dirs[1], "%s/Applications/VLC.app/Contents/MacOS",
             home ? home : "");
    for (i = 0; i < 2; i++) {
      char path[1100];
      /* libvlc finds libvlccore through an @rpath that only VLC.app itself
         provides, so load libvlccore first by its full path */
      snprintf(path, sizeof path, "%s/lib/libvlccore.dylib", dirs[i]);
      if (!dlopen(path, RTLD_NOW | RTLD_GLOBAL))
        continue;
      snprintf(path, sizeof path, "%s/lib/libvlc.dylib", dirs[i]);
      h = dlopen(path, RTLD_NOW);
      if (h) {
        if (!getenv("VLC_PLUGIN_PATH")) {
          char pp[1100];
          snprintf(pp, sizeof pp, "%s/plugins", dirs[i]);
          setenv("VLC_PLUGIN_PATH", pp, 0);
        }
        return h;
      }
    }
  }
  return NULL;
#else
  void *h = dlopen("libvlc.so.5", RTLD_NOW);
  if (!h)
    h = dlopen("libvlc.so", RTLD_NOW);
  return h;
#endif
}

#define QBV_LOAD(field, name)                                                  \
  {                                                                            \
    void *p_ = qbv_sym(name);                                                  \
    if (!p_)                                                                   \
      return 0;                                                                \
    memcpy(&qbvlc_g.field, &p_, sizeof(p_));                                   \
  }

static int qbv_load_syms(void) {
  QBV_LOAD(f_new, "libvlc_new")
  QBV_LOAD(f_release, "libvlc_release")
  QBV_LOAD(f_media_path, "libvlc_media_new_path")
  QBV_LOAD(f_media_loc, "libvlc_media_new_location")
  QBV_LOAD(f_media_release, "libvlc_media_release")
  QBV_LOAD(f_mp_new, "libvlc_media_player_new_from_media")
  QBV_LOAD(f_mp_release, "libvlc_media_player_release")
  QBV_LOAD(f_mp_stop,
           "libvlc_media_player_stop") /* 3.x only (4.0 renamed it) */
  QBV_LOAD(f_mp_play, "libvlc_media_player_play")
  QBV_LOAD(f_mp_pause, "libvlc_media_player_set_pause")
  QBV_LOAD(f_mp_state, "libvlc_media_player_get_state")
  QBV_LOAD(f_mp_time, "libvlc_media_player_get_time")
  QBV_LOAD(f_mp_length, "libvlc_media_player_get_length")
  QBV_LOAD(f_mp_set_time, "libvlc_media_player_set_time")
  QBV_LOAD(f_a_set_vol, "libvlc_audio_set_volume")
  QBV_LOAD(f_a_get_vol, "libvlc_audio_get_volume")
  QBV_LOAD(f_a_mute, "libvlc_audio_set_mute")
  QBV_LOAD(f_v_cbs, "libvlc_video_set_callbacks")
  QBV_LOAD(f_v_fmt, "libvlc_video_set_format_callbacks") { /* optional symbol */
    void *p_ = qbv_sym("libvlc_media_player_get_fps");
    if (p_)
      memcpy(&qbvlc_g.f_mp_fps, &p_, sizeof(p_));
  }
  return 1;
}

/* returns 1 when libvlc is loaded and an instance exists; else sets err */
static int qbv_init(void) {
  if (qbvlc_g.inst)
    return 1;
  if (!qbvlc_g.lib) {
    qbvlc_g.lib = qbv_open_lib();
    if (!qbvlc_g.lib) {
      qbvlc_g.err = 1;
      return 0;
    }
    if (!qbv_load_syms()) {
      qbvlc_g.err = 2;
      return 0;
    }
  }
  {
    const char *full[] = {
        "--quiet",   "--no-video-title-show", "--no-osd", "--avcodec-hw=none",
#if !defined(_WIN32) && !defined(__APPLE__)
        "--no-xlib",
#endif
    };
    const char *mini[] = {"--quiet"};
    qbvlc_g.inst = qbvlc_g.f_new((int)(sizeof full / sizeof full[0]), full);
    if (!qbvlc_g.inst)
      qbvlc_g.inst = qbvlc_g.f_new(1, mini);
    if (!qbvlc_g.inst) {
      qbvlc_g.err = 3;
      return 0;
    }
  }
  return 1;
}

/* ---- libvlc video callbacks (run on VLC's threads) ---------------------- */
static unsigned qbv_cb_setup(void **opaque, char *chroma, unsigned *width,
                             unsigned *height, unsigned *pitches,
                             unsigned *lines) {
  qbv_slot *s = (qbv_slot *)(*opaque);
  unsigned nw = *width, nh = *height, w = nw, h = nh;
  size_t bytes;
  unsigned char *a, *b;

  if (nw == 0 || nh == 0)
    return 0;
  s->nat_w = (int)nw;
  s->nat_h = (int)nh;
  if (s->req_w < 0 && s->req_h < 0) { /* fit inside a box, shrink only */
    double bw = -(double)s->req_w, bh = -(double)s->req_h;
    double k = bw / nw < bh / nh ? bw / nw : bh / nh;
    if (k < 1.0) {
      w = (unsigned)(nw * k + 0.5);
      h = (unsigned)(nh * k + 0.5);
    }
  } else if (s->req_w > 0 && s->req_h > 0) {
    w = (unsigned)s->req_w;
    h = (unsigned)s->req_h;
  } else if (s->req_w > 0) {
    w = (unsigned)s->req_w;
    h = (unsigned)(((double)nh * w) / nw + 0.5);
  } else if (s->req_h > 0) {
    h = (unsigned)s->req_h;
    w = (unsigned)(((double)nw * h) / nh + 0.5);
  }
  if (w < 1)
    w = 1;
  if (h < 1)
    h = 1;

  memcpy(chroma, "RV32", 4); /* 32-bit B,G,R,x in memory = QB64 32-bit image */
  *width = w;
  *height = h;
  pitches[0] = w * 4;
  lines[0] = h;

  bytes = (size_t)w * h * 4;
  a = (unsigned char *)calloc(1, bytes);
  b = (unsigned char *)calloc(1, bytes);
  if (!a || !b) {
    free(a);
    free(b);
    return 0;
  }

  qbv_lock(&s->lock);
  free(s->buf[0]);
  free(s->buf[1]);
  s->buf[0] = a;
  s->buf[1] = b;
  s->bw = (int)w;
  s->bh = (int)h;
  s->fresh = 0;
  qbv_unlock(&s->lock);
  return 1;
}

static void qbv_cb_cleanup(void *opaque) { (void)opaque; }

static void *qbv_cb_lock(void *opaque, void **planes) {
  qbv_slot *s = (qbv_slot *)opaque;
  planes[0] = s->buf[0];
  return NULL;
}

static void qbv_cb_unlock(void *opaque, void *picture, void *const *planes) {
  qbv_slot *s = (qbv_slot *)opaque;
  unsigned char *t;
  (void)picture;
  (void)planes;
  qbv_lock(&s->lock);
  t = s->buf[0];
  s->buf[0] = s->buf[1];
  s->buf[1] = t; /* newest -> buf[1] */
  s->fresh = 1;
  s->frames++;
  qbv_unlock(&s->lock);
}

static void qbv_cb_display(void *opaque, void *picture) {
  (void)opaque;
  (void)picture;
}

/*=============================================================================
  Functions called from BASIC (all lowercase on purpose)
=============================================================================*/

/* 1 if libvlc could be loaded, else 0 (see qbvlc_last_error) */
int32_t qbvlc_probe(void) {
  qbvlc_g.err = 0;
  return qbv_init() ? 1 : 0;
}

/* last error code: 0 none, 1 libvlc not found / wrong bitness, 2 libvlc is
   not 3.x, 3 libvlc_new failed, 4 media failed, 5 no free slot, 6 player
   failed, 7 play failed */
int32_t qbvlc_last_error(void) { return qbvlc_g.err; }

/* Open a file or URL and start playing (audio on).  req_w/req_h = 0 -> native
   size; one of them > 0 -> VLC scales to that with aspect kept; both > 0 ->
   exact; both < 0 -> shrink (aspect kept) to fit inside -req_w x -req_h.
   Returns a handle 1..8, or 0 on failure. */
int32_t qbvlc_open(const void *path_, int32_t req_w, int32_t req_h) {
  const char *path = (const char *)path_;
  int32_t i;
  qbv_slot *s = NULL;
  void *media, *mp;

  qbvlc_g.err = 0;
  if (!path || !path[0]) {
    qbvlc_g.err = 4;
    return 0;
  }
  if (!qbv_init())
    return 0;
  for (i = 1; i <= QBVLC_MAX; i++)
    if (!qbvlc_g.slot[i].used) {
      s = &qbvlc_g.slot[i];
      break;
    }
  if (!s) {
    qbvlc_g.err = 5;
    return 0;
  }

  memset((void *)s, 0, sizeof *s);
  if (req_w < 0 && req_h < 0) {
    s->req_w = req_w;
    s->req_h = req_h;
  } /* fit box */
  else {
    s->req_w = req_w > 0 ? req_w : 0;
    s->req_h = req_h > 0 ? req_h : 0;
  }

  media = strstr(path, "://") ? qbvlc_g.f_media_loc(qbvlc_g.inst, path)
                              : qbvlc_g.f_media_path(qbvlc_g.inst, path);
  if (!media) {
    qbvlc_g.err = 4;
    return 0;
  }
  mp = qbvlc_g.f_mp_new(media);
  qbvlc_g.f_media_release(media);
  if (!mp) {
    qbvlc_g.err = 6;
    return 0;
  }

  qbvlc_g.f_v_cbs(mp, qbv_cb_lock, qbv_cb_unlock, qbv_cb_display, s);
  qbvlc_g.f_v_fmt(mp, qbv_cb_setup, qbv_cb_cleanup);
  s->mp = mp;
  s->used = 1;
  if (qbvlc_g.f_mp_play(mp) != 0) {
    qbvlc_g.err = 7;
    qbvlc_g.f_mp_release(mp);
    memset((void *)s, 0, sizeof *s);
    return 0;
  }
  return i;
}

/* Stop playback and free everything for this handle. */
void qbvlc_close(int32_t h) {
  qbv_slot *s = qbv_get(h);
  if (!s)
    return;
  if (s->mp) {
    qbvlc_g.f_mp_stop(s->mp); /* after this no more callbacks arrive */
    qbvlc_g.f_mp_release(s->mp);
    s->mp = NULL;
  }
  free(s->buf[0]);
  free(s->buf[1]);
  free(s->stage);
  memset((void *)s, 0, sizeof *s);
}

/* Close every video and release libvlc.  Call before your program ends. */
void qbvlc_shutdown(void) {
  int32_t i;
  for (i = 1; i <= QBVLC_MAX; i++)
    qbvlc_close(i);
  if (qbvlc_g.inst) {
    qbvlc_g.f_release(qbvlc_g.inst);
    qbvlc_g.inst = NULL;
  }
}

/* If a new frame is ready: returns the address of a BGRA (alpha=255) copy of it
   and sets stage_w/stage_h.  Returns 0 when there is nothing new.  The memory
   is owned by the library and stays valid until the next qbvlc_acquire / close.
 */
uintptr_t qbvlc_acquire(int32_t h) {
  qbv_slot *s = qbv_get(h);
  size_t need, n, i;
  const uint32_t *src;
  uint32_t *dst;

  if (!s)
    return 0;
  qbv_lock(&s->lock);
  if (!s->fresh || !s->buf[1]) {
    qbv_unlock(&s->lock);
    return 0;
  }
  need = (size_t)s->bw * s->bh * 4;
  if (s->stage_cap < need) {
    free(s->stage);
    s->stage = (unsigned char *)malloc(need);
    s->stage_cap = s->stage ? need : 0;
    if (!s->stage) {
      qbv_unlock(&s->lock);
      return 0;
    }
  }
  n = (size_t)s->bw * s->bh;
  src = (const uint32_t *)s->buf[1];
  dst = (uint32_t *)s->stage;
  for (i = 0; i < n; i++)
    dst[i] = src[i] | 0xFF000000u;
  s->sw = s->bw;
  s->sh = s->bh;
  s->fresh = 0;
  qbv_unlock(&s->lock);
  return (uintptr_t)s->stage;
}

int32_t qbvlc_stage_w(int32_t h) {
  qbv_slot *s = qbv_get(h);
  return s ? s->sw : 0;
}
int32_t qbvlc_stage_h(int32_t h) {
  qbv_slot *s = qbv_get(h);
  return s ? s->sh : 0;
}
int32_t qbvlc_native_w(int32_t h) {
  qbv_slot *s = qbv_get(h);
  return s ? s->nat_w : 0;
}
int32_t qbvlc_native_h(int32_t h) {
  qbv_slot *s = qbv_get(h);
  return s ? s->nat_h : 0;
}
int32_t qbvlc_frames(int32_t h) {
  qbv_slot *s = qbv_get(h);
  return s ? s->frames : 0;
}

/* libvlc state: 0 nothing, 1 opening, 2 buffering, 3 playing, 4 paused,
                 5 stopped, 6 ended, 7 error  (invalid handle -> 7) */
int32_t qbvlc_state(int32_t h) {
  qbv_slot *s = qbv_get(h);
  if (!s || !s->mp)
    return 7;
  return qbvlc_g.f_mp_state(s->mp);
}

void qbvlc_pause(int32_t h, int32_t p) {
  qbv_slot *s = qbv_get(h);
  if (s && s->mp)
    qbvlc_g.f_mp_pause(s->mp, p ? 1 : 0);
}

void qbvlc_seek(int32_t h, int32_t ms) {
  qbv_slot *s = qbv_get(h);
  if (s && s->mp)
    qbvlc_g.f_mp_set_time(s->mp, (int64_t)ms);
}

int32_t qbvlc_time(int32_t h) {
  qbv_slot *s = qbv_get(h);
  return (s && s->mp) ? (int32_t)qbvlc_g.f_mp_time(s->mp) : 0;
}

int32_t qbvlc_length(int32_t h) {
  qbv_slot *s = qbv_get(h);
  return (s && s->mp) ? (int32_t)qbvlc_g.f_mp_length(s->mp) : 0;
}

void qbvlc_set_volume(int32_t h, int32_t v) {
  qbv_slot *s = qbv_get(h);
  if (s && s->mp)
    qbvlc_g.f_a_set_vol(s->mp, v);
}

int32_t qbvlc_get_volume(int32_t h) {
  qbv_slot *s = qbv_get(h);
  return (s && s->mp) ? qbvlc_g.f_a_get_vol(s->mp) : 0;
}

void qbvlc_mute(int32_t h, int32_t m) {
  qbv_slot *s = qbv_get(h);
  if (s && s->mp)
    qbvlc_g.f_a_mute(s->mp, m ? 1 : 0);
}

/* Restart a player that has ended/stopped (libvlc 3.x cannot seek after the
   end). Playback begins again from the start; the frame counter is reset. */
void qbvlc_restart(int32_t h) {
  qbv_slot *s = qbv_get(h);
  if (!s || !s->mp)
    return;
  qbvlc_g.f_mp_stop(s->mp);
  qbv_lock(&s->lock);
  s->fresh = 0;
  s->frames = 0;
  qbv_unlock(&s->lock);
  qbvlc_g.f_mp_play(s->mp);
}

/* Frame rate x 1000 (libvlc's value if available, else measured). 0 = unknown.
 */
int32_t qbvlc_fps(int32_t h) {
  qbv_slot *s = qbv_get(h);
  float f = 0.0f;
  int64_t t;
  if (!s || !s->mp)
    return 0;
  if (qbvlc_g.f_mp_fps)
    f = qbvlc_g.f_mp_fps(s->mp);
  if (f > 0.5f)
    return (int32_t)(f * 1000.0f + 0.5f);
  t = qbvlc_g.f_mp_time(s->mp);
  if (t > 500 && s->frames > 0)
    return (int32_t)(((int64_t)s->frames * 1000000) / t);
  return 0;
}

#endif /* QBVLC_H */
