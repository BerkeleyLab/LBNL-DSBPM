/*
 * My memcpy to deal with unaligned addresses
 */

#ifndef _MEMCPY2_H_
#define _MEMCPY2_H_

void * memcpy2(void *dst0, const void *src0, size_t length);
void * memmove2(void *s1, const void *s2, size_t n);
void bcopy2(const void *s1, void *s2, size_t n);

#endif
