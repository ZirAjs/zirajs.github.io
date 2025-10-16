---
title: NetworkSecurity.hash
date: 2025-10-20 12:23:20 +0900
categories: [others, NetworkSecurity]
tags: [hash]     # TAG names should always be lowercase
math: true
---

# Introduction

## A Hash function?

임의의 길이의 입력값을 고정된 길이의 값으로 대응하는 함수이다.
간단하게 $y=x \; (\text{mod} 2^n)$ 같은 것도 된다.

해시함수의 분류는 암호학적으로 안전한 해시함수인지에 따른 분류와 key 값이 존재하는지 여부에 따른 분류가 있고,
각각
- Cryptographic / Non-Cryptographic hash
- Keyed / Unkeyed hash
로 분류한다.
그러나 우리는 암호학적 해시함수에 집중하고자한다.

## Cryptographic hash function (CHF)

암호학에서 사용할 수 있는 함수들을 의미.
최소한 avalanche effect로 조금만 입력값이 바뀌어도 완전히 다른 해시를 반환해야 할 것이다.

구체적으로는 아래의 성질을 가지고 있어야 한다. 

- One way (단방향성)
- Collision-resistance (충돌 저항성)
- Second pre-image resistance 
  (충돌 저항성이지만, 특정 입력에 대한 충돌을 찾는 것에 대한 저항성)
- pseudo randomness (의사-임의성)
- Non-malleability 
  (h(x1), h(x2) 간의 relation이 사라짐. manipulation 불가)


**Random Oracle model**. 

이상적인 hash function이다.
radomness가 보장되고 collison이 없는 모델.
아래와 같이 동작하기를 희망한다.

1. 실행 초기, oracle의 table은 비어 있다.
2. hash를 요청받으면 table에 이미 그 값이 있는지 확인한다.
3. 만약 없다면 랜덤한 output 문자열을 생성하고 입력값과 output 문자열을 table에 저장하고 output만 반환한다.
4. 만약 있다면, key-value pair로 찾아서 반환한다.

**Independence Theorem**

어떠한 해시 함수에 대해서 전체 정의역 X의 부분집합인 X0의 h(x)를 조사했다고 하자.
이때 X-X0에서 새로운 원소의 해시값을 계산하면 치역의 각 원소가 나올 확률은 1/|Y|로 동일하다.
Formal한 정의는 아래와 같다.

Suppose $h:X \rightarrow Y$ satisfies the random oracle model, and $X_0 \subset X$.<br>
Suppose the values of $h(x)$ have been determined for $x \in X_0$
then $P[h(z) = y] = 1/|Y|$ for all $y \in Y$ and for all $x \in (X-X_0)$

**$h(x)$에 대한 기존 정보가 미래의 $h(x)$에 영향을 주지 않는다**는 것이 중요하다.


### Applications

- password storing
- file modification 
- digital signature
- commitment

### Collision Attack

단방향성을 이용해서 공격을 하는 것이다.

> Goal: $h:X \rightarrow Y$에서 특정 $y$에 대해 $h(x)=y$인 $x$를 찾자.
>
> Algorithm: 랜덤한 $x \in X$을 고른다. 해시값이 같다면 성공, 아니면 반복. $q$ 회 반복 후 강제 종료

분석해보자.
평균적으로 성공할 확률은 

$$
\epsilon  = 1 - \left(1 - 1/ |Y| \right)^q \approx \frac{q}{|Y|}
$$

대략 $\|Y\| = 2^m$으로 두면 절반의 확률로 성공하기 위해서 $q\approx 2^{m-1}$정도 시도해야한다.

근데 bruteforce에서 당연히 우리가 골랐던 수를 또 고르진 않았을 것이다.
생일문제처럼 bruteforce 할 때 여사건으로 접근하는 것이 맞을 것이다.
$i=1$부터 $i=k$까지 충돌하지 않을 가능성은 


$$
\begin{align*}
&p_{\text{NO_collision}} = \prod_{i=1}^{k} \left( 1- \frac{i}{n}\right)
\approx e ^{-k^2 / (2n)} \\
&(\because 1-x \approx e^{-x} )\\
&p_{\text{collision}} = 1-  e ^{-k^2 / (2n)} 
\end{align*} \\
$$

더 정리해보면, 

$$
k= \sqrt{2n \times \ln\left(\frac{1}{1-p}\right)}
$$

따라서 해시함수의 길이는 충분히 커야 한다는 결론을 얻을 수 있다.
위 계산에 따르면, 0.5의 확률로 충돌을 일으키기 위해서 $k\approx \sqrt(n) = 2^{m/2}$ 정도의 해싱이 필요함을 알 수 있다.($m$은 해시의 비트 길이).

## Merkle-Damgärd structure

이제 해시함수로 긴 입력을 처리하는 것을 개발하고자 한다.
만약 안전한 해시 함수 $h$를 개발했다고 하자.
그러면 이 함수가 **임의의 길의의 입력값을 받을 수 있도록** 해야한다.
Merkle-Damgärd 구조는 작은 정의역의 해시함수로 긴 입력 문자열을 handle할 수 있도록 한다.

MD는 $h:\left\\{ 0,1 \right\\} ^{n+b} \rightarrow \left\\{ 0,1 \right\\}^{n}$인 해시 함수를 필요로 한다.
그리고 과정은 아래와 같다,

//TODO 

