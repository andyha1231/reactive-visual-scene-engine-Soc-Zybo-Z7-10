/**
 * audio_streamer.c
 * Implements the streaming loop described in audio_streamer.h.
 *
 * Wire-up:
 *   PL audio_sample_reader sets WRAP_FLAG (scene_ctrl 0x18) every BRAM wrap.
 *   PS polls the flag in audio_streamer_process(); when set, clears it and
 *   writes the next song chunk into BRAM via the AXI BRAM controller.
 */

#include "xil_io.h"
#include "audio_streamer.h"
#include "scene_ctrl_regs.h"
#include "song_data.h"

/* Internal state */
static u32 chunk_idx;       /* index of the chunk currently being PLAYED */
static u32 num_chunks;      /* ceil(song_total_samples / song_chunk_samples) */
static u8  loop_mode;       /* 1 = loop forever, 0 = play once + pause */
static u8  paused;          /* 1 = stop streaming new chunks */
static u8  finished;        /* 1 = song ended (play-once mode only) */

/* ------------------------------------------------------------------ */
/* Helpers                                                            */
/* ------------------------------------------------------------------ */

static inline u32 wrap_flag_read(void) {
    return Xil_In32(SCENE_CTRL_REG(WRAP_FLAG_OFFSET)) & 0x1u;
}

static inline void wrap_flag_clear(void) {
    Xil_Out32(SCENE_CTRL_REG(WRAP_FLAG_OFFSET), 0x1u);
}

/* Write song_chunk_samples samples starting at song_data[start_sample] into
 * BRAM (PS-visible at BRAM_CTRL_BASE_ADDR). If start_sample + chunk would
 * run past song_total_samples, the tail is padded with zeros (silence). */
static void write_chunk_to_bram(u32 start_sample) {
    u32 i;
    for (i = 0; i < song_chunk_samples; i++) {
        u32 src_idx = start_sample + i;
        s16 sample;
        if (src_idx < song_total_samples)
            sample = song_data[src_idx];
        else
            sample = 0;
        /* Each BRAM word is 32-bit; audio in low 16 bits, upper zero. */
        Xil_Out32(BRAM_SAMPLE_ADDR(i), (u32)((u16)sample));
    }
}

/* ------------------------------------------------------------------ */
/* Public API                                                         */
/* ------------------------------------------------------------------ */

int audio_streamer_init(void) {
    chunk_idx  = 0;
    num_chunks = (song_total_samples + song_chunk_samples - 1) / song_chunk_samples;
    loop_mode  = 1;          /* default: loop ON */
    paused     = 0;
    finished   = 0;

    write_chunk_to_bram(0);
    wrap_flag_clear();
    return 0;
}

void audio_streamer_process(void) {
    if (paused || finished) return;
    if (!wrap_flag_read())  return;

    /* Wrap fired -> the audio reader just finished playing chunk_idx and is
     * now replaying it from address 0 (because BRAM still holds chunk_idx
     * data). We need to write chunk_idx+1 NOW so when the reader gets to
     * those addresses, it sees the new data.
     *
     * PS finishes the 32K-sample write in ~1-2 ms; reader takes ~2.97 s to
     * traverse the buffer. PS easily wins the race. */
    wrap_flag_clear();

    chunk_idx++;
    if (chunk_idx >= num_chunks) {
        if (loop_mode) {
            chunk_idx = 0;
        } else {
            finished  = 1;
            chunk_idx = num_chunks - 1;   /* hold last chunk for status display */
            return;
        }
    }

    write_chunk_to_bram(chunk_idx * song_chunk_samples);
}

void audio_streamer_restart(void) {
    chunk_idx = 0;
    finished  = 0;
    write_chunk_to_bram(0);
    wrap_flag_clear();
}

void audio_streamer_reload_first(void) {
    write_chunk_to_bram(0);
}

void audio_streamer_set_loop(u8 loop_enable) {
    loop_mode = loop_enable ? 1 : 0;
    /* If we'd previously hit end-of-song and now turn looping back on,
     * clear the finished flag so process() resumes. */
    if (loop_enable && finished) {
        finished  = 0;
        chunk_idx = 0;
        write_chunk_to_bram(0);
        wrap_flag_clear();
    }
}

u8 audio_streamer_get_loop(void) {
    return loop_mode;
}

void audio_streamer_set_paused(u8 p) {
    paused = p ? 1 : 0;
    if (!paused) {
        /* On resume, start fresh from current chunk so we don't get stuck
         * waiting for a wrap that already happened while we were paused. */
        wrap_flag_clear();
    }
}

u8 audio_streamer_is_paused(void) {
    return paused;
}

u32 audio_streamer_current_chunk(void) {
    return chunk_idx;
}

u32 audio_streamer_total_chunks(void) {
    return num_chunks;
}

u8 audio_streamer_is_finished(void) {
    return finished;
}

void audio_streamer_silence(void) {
    /* Pause + fill BRAM with zeros so audio reader plays silence.
     * Features go to 0 -> scenes go to silent/dim state. */
    paused = 1;
    for (u32 i = 0; i < song_chunk_samples; i++) {
        Xil_Out32(BRAM_SAMPLE_ADDR(i), 0);
    }
    wrap_flag_clear();
}
