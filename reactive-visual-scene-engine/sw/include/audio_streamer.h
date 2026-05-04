/**
 * audio_streamer.h
 * Streams a pre-decoded song from PS DDR (embedded const array) into BRAM
 * one chunk at a time, advancing on each PL wrap event.
 *
 * BRAM holds song_chunk_samples (= 32768) samples = ~2.97s at 11025 Hz.
 * Audio reader plays chunk N while PS writes chunk N+1 into the same BRAM
 * (PS easily outruns the audio reader — no double-buffer needed).
 *
 * End-of-song behavior:
 *   - Loop mode ON  (default): jump back to chunk 0 and keep playing.
 *   - Loop mode OFF: pause; visuals freeze on the last chunk's content
 *     until restart() or set_loop(1) is called.
 */

#ifndef AUDIO_STREAMER_H
#define AUDIO_STREAMER_H

#include "xil_types.h"

/* Initialize: write chunk 0 to BRAM, clear wrap flag, set loop=ON. */
int  audio_streamer_init(void);

/* Poll wrap flag; if set, write next chunk to BRAM and advance position.
 * Call this every few ms in the main loop. */
void audio_streamer_process(void);

/* Jump back to chunk 0 (does NOT immediately rewrite BRAM — just resets the
 * counter; the next wrap event will write chunk 0). */
void audio_streamer_restart(void);

/* Force chunk 0 into BRAM right now (use after restart to skip the wait). */
void audio_streamer_reload_first(void);

/* Loop mode: 0 = play once + pause at end; 1 = loop forever. */
void audio_streamer_set_loop(u8 loop_enable);
u8   audio_streamer_get_loop(void);

/* Pause / resume streaming. When paused, BRAM contents stay frozen so audio
 * reader keeps looping the same chunk. */
void audio_streamer_set_paused(u8 paused);
u8   audio_streamer_is_paused(void);

/* Silence: pause streamer AND fill BRAM with zeros so audio reader plays
 * silence -> features go to 0 -> visuals show silent state. Used by
 * play_demo.ps1 on Ctrl-C exit. */
void audio_streamer_silence(void);

/* Status helpers (for UART status display). */
u32  audio_streamer_current_chunk(void);
u32  audio_streamer_total_chunks(void);
u8   audio_streamer_is_finished(void);  /* 1 if song ended in play-once mode */

#endif /* AUDIO_STREAMER_H */
