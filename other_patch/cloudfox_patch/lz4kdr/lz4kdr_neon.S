/* SPDX-License-Identifier: Dual BSD/GPL */
/*
 * lz4kdr_neon.S -- NEON-accelerated match-length scanning for LZ4KDR
 *
 * ARMv8 NEON implementation of repeat_end().  Compares 16 bytes at a
 * time using the SIMD unit instead of the default 8-byte scalar loop.
 * When a mismatch is found within the 16-byte chunk, a short unrolled
 * 4-byte-at-a-time scalar probe locates the exact byte offset.
 *
 * Called from within kernel_neon_begin()/kernel_neon_end() context.
 * The caller must have CONFIG_KERNEL_MODE_NEON=y and performed the
 * {kernel_neon_begin()} before calling this function.
 *
 * Calling convention (AAPCS64):
 *   x0 -- q  (match position pointer, already advanced by REPEAT_MIN)
 *   x1 -- r  (current position pointer, already advanced by REPEAT_MIN)
 *   x2 -- in_end_safe  (r limit for the main loop, in_end - NR_COPY_MIN)
 *   x3 -- in_end       (original input end, for the scalar tail)
 * Returns x0 = pointer to first mismatch in r stream
 *
 * Clobbers: x0-x5, v0-v3.  Preserves x30 (LR) for the C caller.
 */

#include <linux/linkage.h>
#include <asm/assembler.h>

	.text
	.align 4

SYM_FUNC_START(lz4kdr_repeat_end_neon)
	/* NOTE: The C caller (repeat_end() in lz4kdr_encode.c) already
	 * advances q and r by REPEAT_MIN (4) bytes before calling this
	 * function -- do NOT add q += 4 / r += 4 here. */

	/*
	 * Main NEON loop: compare 16 bytes per iteration.
	 * We check r <= in_end_safe before each iteration (same as the
	 * C do-while condition).
	 */
.Lneon_loop:
	cmp	x1, x2
	b.hi	.Lscalar_tail		/* r > in_end_safe, finish scalar */

	ld1	{v0.16b}, [x0], #16
	ld1	{v1.16b}, [x1], #16
	eor	v2.16b, v0.16b, v1.16b	/* non-zero lanes = mismatch */

	/* Check if the entire 16-byte chunk matched */
	umaxv	b3, v2.16b
	mov	w4, v3.b[0]
	cbz	w4, .Lneon_loop		/* all 16 bytes matched */

	/*
	 * Mismatch found somewhere in this 16-byte window.
	 * Rewind the pointers and do a short unrolled scalar scan
	 * (4 bytes at a time) to find the exact byte.
	 */
	sub	x0, x0, #16
	sub	x1, x1, #16

	/* Scan in 4-byte chunks (unrolled to minimise branch cost) */
.Lscan_4:
	ldr	w4, [x0], #4
	ldr	w5, [x1], #4
	cmp	w4, w5
	bne	.Lfound_diff4

	ldr	w4, [x0], #4
	ldr	w5, [x1], #4
	cmp	w4, w5
	bne	.Lfound_diff4

	ldr	w4, [x0], #4
	ldr	w5, [x1], #4
	cmp	w4, w5
	bne	.Lfound_diff4

	ldr	w4, [x0], #4
	ldr	w5, [x1], #4
	cmp	w4, w5
	bne	.Lfound_diff4

	/* Should not reach here (NEON already found a mismatch) */
	b	.Lneon_loop

	/*
	 * Found a 4-byte mismatch.  Rewind and find the exact byte.
	 * Returns x0 = pointer to the first mismatching byte in r stream.
	 *
	 * NOTE: ldrb post-increments x1 past the loaded byte, so when
	 * bne is taken, x1 points AFTER the mismatching byte. We fix
	 * this at .Ldone_sub1 by rewinding 1 byte.
	 */
.Lfound_diff4:
	sub	x0, x0, #4
	sub	x1, x1, #4

	ldrb	w4, [x0], #1
	ldrb	w5, [x1], #1
	cmp	w4, w5
	bne	.Ldone_sub1

	ldrb	w4, [x0], #1
	ldrb	w5, [x1], #1
	cmp	w4, w5
	bne	.Ldone_sub1

	ldrb	w4, [x0], #1
	ldrb	w5, [x1], #1
	cmp	w4, w5
	bne	.Ldone_sub1

	/* Must be the 4th byte -- x1 is at start + 3, which is correct */
	mov	x0, x1
	ret

.Ldone_sub1:
	sub	x1, x1, #1		/* rewind past the post-increment */
	mov	x0, x1
	ret

	/*
	 * Scalar tail: past in_end_safe, compare byte-by-byte
	 * until we hit in_end or find a mismatch.
	 */
.Lscalar_tail:
	cmp	x1, x3
	b.hs	.Ldone2_end		/* r >= in_end, reached end of input */
	ldrb	w4, [x0], #1
	ldrb	w5, [x1], #1
	cmp	w4, w5
	b.ne	.Ldone2_mismatch
	b	.Lscalar_tail

.Ldone2_mismatch:
	sub	x1, x1, #1		/* rewind past the post-increment */
	mov	x0, x1
	ret

.Ldone2_end:
	/* Reached end of input without mismatch -- return current position */
	mov	x0, x1
	ret
SYM_FUNC_END(lz4kdr_repeat_end_neon)