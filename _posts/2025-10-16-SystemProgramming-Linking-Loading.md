---
title: SystemProgramming Linking & Loading
date: 2025-10-16 16:05:30 +0900
categories: [others, systemprogramming]
tags: [construction, linking, loading, linker, loader]     # TAG names should always be lowercase
---

🚧Under construction. Only contains one lecture🚧

# Symbols

global symbol, external symbol, local symbol이 존재한다. 

**global symbol**: 모듈에 의해 정의된 symbol 중 다른 모듈에 의해 참조될 수 있는것.
    e.g. non-static variables, functions
**external symbol**: global symbol이 어느 모듈의 입장에서 사용될 경우 external symbol로 불리게 된다.
    e.g. `external`
**local symbols**: 해당 모듈에서만 쓰이는 symbol
    e.g. `static` 

> local variable은 symbol이 **아니다**
{:.prompt-warn}


![](/assets/blog/systemprogramming/linkandload/0.png)

## Symbol Strength

기본적으로 모든 symbol은 strong 속성을 가진다.
그리고 weak symbol은 명시적으로 요청한 경우에만 사용된다.

이 속성의 목적은 겹치는 symbol이 존재할 경우 어느 symbol을 할지 모르는 경우를 방지하기 위함이다.

```c
#pragma weak weak_somesym_somename
```

## Symbol Section and `COMMON`

<div style="overflow-x:auto;">
  <table style="width:100%; table-layout:auto;">
    <thead>
      <tr>
        <th>Type</th>
        <th>Common Section</th>
        <th>Section</th>
        <th>Remarks</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Function</td>
        <td>No (default / -fno-common)</td>
        <td><code>.text</code></td>
        <td>code</td>
      </tr>
      <tr>
        <td rowspan="2">Global var</td>
        <td>No (default / -fno-common)</td>
        <td><code>.data</code> / <code>.bss</code></td>
        <td>value != 0 → <code>.data</code><br>value == 0 → <code>.bss</code></td>
      </tr>
      <tr>
        <td>Yes (-fcommon, GCC &lt; v10)</td>
        <td><code>COMMON</code> / <code>.data</code> / <code>.bss</code></td>
        <td>uninitialized → <code>COMMON</code> (tentative); otherwise <code>.data</code>/<code>.bss</code></td>
      </tr>
      <tr>
        <td>*</td>
        <td>External</td>
        <td>UNDEFINED</td>
        <td></td>
      </tr>
    </tbody>
  </table>
</div>

여기서 COMMON은 이제 사용이 안 되는 부분인데 linker rule을 보면 알 수 있다.

Rule1. 여러 strong symbol은 금지. **단, COMMON은 예외**
Rule2. strong symbol이  COMMON 안에 하나, 밖에 하나일 경우 COMMON 밖을 선택.
Rule3. 여러 COMMON symbol이 있을 경우 랜덤하게 선택.
=> 문제지점. 그래서 금지됨
Rule4. weak symbol, strong symbol이 있을 경우 weak는 strong으로 relocated

Rule3는 그냥 보더라서 프로그램의 integrity를 해칠 수 있고, 게다가 가짜 elf를 제공할 경우, poisoning도 가능하므로 금지됐다.

> 아래와 같이 lib를 static하게 빌드하되, common section을 사용한 경우,
> 
> ```shell
> gcc -o2 -fcommon -c trim.c
> ar rcv libtrim.a trim.o
> ```
> 
> `gcc -O2 -fno-common vlun vuln.c -L. -ltrim`으로 빌드하더라도 라이브러리가 COMMON을 사용하므로 여전히 위험하다.
{: .prompt-warn}

**Take-aways!**
- Avoid global variables!
- When using one,
  - Use static if possible
  - Initialize
  - Use `extern`
- Do not let other library access important data of your code.

# Symbol Relocation

여러 object 파일들은 실행되면서 프로그램 메모리에 같이 올라가게 된다.
그리고 ELF 파일 자체는 다른 메모리에 뭐가 들어갈지 모르기 일단 자기의 정보들만 올린다 (Note: bss는 어차피 0이므로 실행파일 크기를 낮추기 위해 따로 저장한다).
그러나, 외부 symbol을 호출해야 할 때는 어떻게 할까?

예를 들어 `main.c`에서 `foo.c`의 `foo()`를 호출하는 경우를 예시로 들겠다.

objdump를 사용하여 살펴보면, call 부분은 아래와 같다.
```
22:  e8 00 00 00 00     call  27 <main+0x27>
            23: R_X86_64_PLT32   foo-0x04
```
보면 `00 00 00 00`으로 채워진 부분은 아직 linking이 일어나지 않은 부분이다.
`23: R_X86_64_PLT32`에 집중하자. 이것의 의미는 `23`번째, 즉 `00 00 00 00` 부분이 `R_X86_64_PLT32   foo-0x04`로 채워져야 함을 의미한다.

external varibles 또한 위와 비슷하게 나온다.

`R_X86_64_PLT32`는 relocation entry라고 부른다. 실제로 구조체로 구현되어 있으며 아래와 같다.
```c
typedef struct{
    long offset;    // reference 기준 offset
    long type:32,   // relocation 타입 
         symbol:32; // syboltable에서 index
    long addend;    // relocation expression의 addend
} ELF64Rela
```
이에 따라 `23:R_X86_64_PLT32   foo-0x04`을 해석해보면:
- `23`: offset
- `R_X86_64_PLT32`: type
- `foo`: symbol
- `-0x4`: addend

### Relocation entry type

아래 내용에서 4-byte relocation addr는 `00 00 00 00` 부분을 의미한다.

- `R_X86_64_64/32[S]`: 절대 주소. [S]는 sign 나타냄
  4-byte relocation addr = 실제주소
- `R_X86_64_PC32`: object를 가리키는 PC-relative addressing
  PC + 4-byte relocation addr = 접근하려는 object
- `R_X86_64_PLT32`: PLT를 가리키는 PC-relative addressing
  PC + 4-byte relocation addr = 접근하려는 PLT

위 내용을 기준으로 실제로 계산하는 법을 다룬다.

**예제**

`0: R_X86_64_64 buf [+0]` <br>
=> `*(void *)((char *) (addr_of_section + r.offset(=0:))) = *(__int64 *)((char*)(addr_of_r.symbol + r.addend(=[+0])))`


`5: R_X86_64_PC32 foo-0x4` <br>
=> `*(void *)((char *) (addr_of_section + r.offset(=5:))) = *(__int64 *)((char*)(addr_of_r.symbol + r.addend(=[-0x4]) - [address_of_section + r.offset(=5:)]))`<br>
복잡해보이니 쉽게 써보았다.
당연히, 아까 `00 00 00 00` 부분을 바꾸는 것이 목적이다. 그래서 `addr_of_section + r.offset(=5:)` 주소를 목적지로 하는 것이다. 
아까 처음 예시에서도, `22: e8 00 00 00 00` 이었으므로 `00`이 시작하는 `23`을 offset으로 정의한 것이다. 
그러면 거기에 무슨 값을 저장할거냐면, pc-relative addressing으로 정의한 foo 함수의 주소를 넣을 것이다. 그러면 자연스레 `call foo`가 되기 때문이다.
원래 주소가 `r.symbol + r.addend`이었으므로 거기에 `section + r.offset`을 빼주면, pc-relative한 주소가 될 것이다.
어? 근데 왜 `r.addend`가 4가 되는 것인가 의문이 들 것이다. 이것은 이미 PC가 증가했을 거기 때문에, `00`이 끝나는 지점을 기준으로 pc를 생각하면 `section + r.offset + 4`가 되었을 것이다. 이것을 보정해주기 위해 -4바이트를 `r.addend`에 저장한 것이다.

> x86_64는 가변 길이 ISA이다. 
> 다행히 가변 길이와 상관없이 `$RIP(PC)`는 무조건 **다음 instruction**을 가리킨다.
>
> 한편 이것을 활용한 reversing 방어 기법도 있다.
{: .prompt-tip}

> 결과적으로는 우리가 당연히 기대하는 방식으로 relocation이 이루어진다. 
> 그러므로 그것을 염두해 두고 이해하면 어려움이 적다.
{: .prompt-tip}


