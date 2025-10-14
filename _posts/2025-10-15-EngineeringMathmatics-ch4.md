---
title: EngineeringMathmatics Chapter 4
date: 2025-10-15 06:05:00 +0900
categories: [others, math, engineering mathmatics]
tags: [math, chernoff, hoeffding, mgf]     # TAG names should always be lowercase
math: true
description: Engineering Mathmatics Chapter 4 정리
---

# Lecture 8

## Moment generating function

일단 모멘트는 통계에서 확률분포를 수로 나타내는 값이다.
예를 들어
- 1차 moment -> 평균 $\mathbb{E}[X]$
- 2차 moment -> 분산 $\mathbb{E}[(X-\mathbb{E}[X])^2]$
- ...

>  $\mathbb{E}[(X-\mathbb{E}[X])^2]$ 는 Central moment라고 한다. 밑에서 다루는 MGF는 Moment generating이지, Central moment generating이 아님에 유의하자
{: .prompt-tip}

이런 것들을 이끌어낼 moment generating function을 정의해보자라는 것이 아이디어.

$X$의 Moment generating function은 기댓값이 발산하지 않을 때

$$
M_X (t) = E[e^{tX}]
$$

로 정의된다.
이 함수는 미분하면 모멘트를 생성하는데,

$$
M_{X} ' (t) = E[Xe^{tX}]
$$

여기서 $t=0$을 대입하면 $M'_{X} (0) = E[X]$ 로 평균이 나오는 것을 확인할 수 있다.

그리고 이 MGF는 **분포를 결정하는 함수**로, 동일한 분포라면 동일한 MGF를 가진다.<br>
e.g. $N(\mu ,\sigma^2)$의 MGF는 $M_X (t) = e^{\mu t + \frac{1}{2} \sigma^2 t^2}$


### Property

이제 아이디어와 정의를 알았으니 몇가지 성질과 lemma를 짚고 넘어가자.

> $X$, $Y$가 독립이라면 아래가 성립한다.
>
> $$
> M_{X+Y} (t) = M_X (t)  M_Y (t) 
> $$
{: .prompt-info}

> $$
> \Pr(X\ge a) = \Pr(e^{tX} \ge e^ta) \le \frac{\mathbb{E}[e^{tX}]}{e^{ta}}
> $$
{: .prompt-info}

위 부등식은 Markov 부등식을 그대로 적용한 식인데, $\mathbb{E}[e^{tX}]$면 $M_X (t)$로 작성할 수 있음을 알 수 있다.
여기서 $t$는 임의로 둔 변수이기에 우리가 맘대로 조정할 수 있는데 생각해보면 보통의 경우 tightest bound를 구하는 것이 목표이므로
우변을 최소로 만드는 $t$를 알게 되면 좋을 것 같다.
다만 $t$의 범위에 유의해야 하는데

$$
\Pr(X \ge a) \le \min_{t > 0} \frac{\mathbb{E}[e^{tX}]}{e^{ta}}
$$

$$
\Pr(X \le a) \le \min_{t < 0} \frac{\mathbb{E}[e^{tX}]}{e^{ta}}
$$

위처럼 정리할 수 있겠다. 이것이 **chernoff's inequality**이다. ($\because$ 지수함수는 밑이 1보다 작으면 감소함수)


## Poisson Trial

$$
\begin{align*}
X&= \sum^n_{i=1} X_i \: \text{where}\: X_1, X_2, ..., X_n \:\text{are indep} \\
X_i &\sim \text{Bernoulli}(p_i)
\end{align*}
$$

위처럼 정의된 분포를 푸아송(Poisson) 분포라 한다. 
이항 분포와 다르게 각 베르누이 시행의 확률 $p_i$가 다른 것이 특징이다.

- $\mu = \mathbb{E}[X] = \sum \mathbb{E}[X_i] = \sum p_i$
- $M_{X_i} = p_i e^{t \times 1} + (1-p_i)e^{t \times 0} = 1+ p_i (e^t -1) \le e^{p_i (e^t -1)}$
- $M_{X} =\prod^n_{i=1} M_{X_i}  \le e^{\mu(e^t -1)}$


### Chernoff bound for Poisson Distribution

> 여기서는 먼저 tight하지만 쓰기 어려운 bound를 먼저 제시하고
> lose 하지만 쓰지 쉬운 bound를 제시한다.
{: .prompt-tip}

> **Theorem**
>
> $$
> \Pr(X \ge (1 + \delta)\mu) \le \left( \frac{e^{\delta}}{(1 + \delta)^{1 + \delta}} \right)^{\mu}, \quad \forall \, \delta > 0.
> $$
{: .prompt-info}

**Proof**

$$
\Pr(X \ge (1 + \delta)\mu) = \Pr(e^{tX} \ge e^{t(1 + \delta)\mu}) 
\le \frac{\mathbb{E}[e^{tX}]}{\exp(t(1 + \delta)\mu)} 
\quad (\text{Markov's inequality})
$$

여기서 우변을 ln 취한 후 미분하면 $t=\ln(1+\delta)$에서 최소를 가짐을 알 수 있다.
대입하면, 

$$
\Pr(X \ge (1 + \delta)\mu) \le \left( \frac{e^ \delta}{(1+\delta)^{(1 + \delta)}} \right) ^\mu
$$

푸아송 분포의 Chernoff bound를 구할 수 있다.

### Other variations

아래 내용들의 증명은 결국 $\left( \frac{e^ \delta}{(1+\delta)^{(1 + \delta)}} \right) ^\mu \le \text{(some value)}$
를 증명하는 꼴이라 생략한다.


> $$
> \Pr(X \ge (1 + \delta)\mu) \le \exp(-\mu \delta^2 / 3), \quad \text{for } 0 < \delta \le 1.
> \quad (0<\delta< 1)
> $$
{: .prompt-info}

> $$
> \Pr(X \ge R) \le 2^{-R}.
> \quad (R\ge6\mu)
> $$
{: .prompt-info}


> $$
> \Pr(X \le (1 - \delta)\mu) \le \left( \frac{e^{-\delta}}{(1 - \delta)^{1 - \delta}} \right)^{\mu}.
> $$
{: .prompt-info}

> $$
> \Pr(X \le (1 - \delta)\mu) \le \exp(-\mu \delta^2 / 2).
> \quad (0<\delta< 1)
> $$
{: .prompt-info}

> $$
> \Pr(|X - \mu| \ge \delta \mu) \le 2 \exp(-\mu \delta^2 / 3).
> $$
>
> 앞선 두 부등식을 합친 꼴이다.
{: .prompt-info}

> $\Pr(X_i =1)=\Pr(X_i =-1)=1/2$ 인 경우, 아래와 같이 더 좁은 bound를 제시할 수 있다.
>
> $$
> \Pr(X \ge a) \le \exp\left(-\frac{a^2}{2n}\right). \quad (a>0)
> $$
{: .prompt-info}

마지막 부등식은 추가적인 내용이 들어가기에 설명을 덧붙히자면, 
$M_{X_i} = \frac{1}{2} (e^t + e^{-t})$이기에 테일러 전개를 활용하여
$\mathbb{E}[e^{tX}] = \sum_{j=0}^{\infty} \frac{t^{2j}}{(2j)!} \le \sum_{j=0}^{\infty} \frac{1}{j!} \left( \frac{t^2}{2} \right)^j = e^{t^2 / 2}$ 로 더 좁은 범위를 구할 수 있고 이를 이용해서 $t=a/n$일 때의 최솟값을 구하면 얻을 수 있다.


> Corollary
>
> $$
> \Pr(|X| \ge a) \le 2e^{-a^2 / 2n}.
> $$
{: .prompt-info}





# Lecture 9

## Set balancing

예시로 학습하자.

> **Set balancing** <br>
> $m$ 명의 사람들 각각 $n$개의 속성(0 또는 1)이 있다고 하자. 
> 우리의 목표는 $m$ 명의 사람을 2개의 그룹으로 나누는 것이고 이때 두 그룹의 속성이 비슷하였으면 한다.
> 즉,
>
> $$ | \{ p \in A \:| \:p\: \text{has property}\: i \}| \approx | p \in \bar{A}\: |\: p \:\text{has property}\: i | , \:\forall i.$$
>
> 이길 원한다.
{: .prompt-info}

이 문제를 수학적으로 표현하기 위해서 $j$ 번째 사람이 $i$ 속성을 가질경우 $a_{ij}=1$로 표기하자.
이러한 표기의 장점은 문제를 행렬로 나타낼 수 있다는 것이다.<br>
$\vec{b}$를 $j$ 번째 사람이 $A$ 그룹의 속한 여부를 나타내도록 $-1, 1$을 부여하자.
그러면 불균형의 정도를 아래처럼 작성할 수 있을 것이다.

$$
\begin{pmatrix}
a_{11} & a_{12} & \cdots & a_{1m} \\
a_{21} & a_{22} & \cdots & a_{2m} \\
\vdots & \vdots & \ddots & \vdots \\
a_{n1} & a_{n2} & \cdots & a_{nm}
\end{pmatrix}
\begin{pmatrix}
b_1 \\ 
b_2 \\ 
\vdots \\ 
b_m
\end{pmatrix}
=
\begin{pmatrix}
c_1 \\ 
c_2 \\ 
\vdots \\ 
c_n
\end{pmatrix}
$$

이렇게 문제를 변환하면 처음 묻고자 했던 그룹을 나누는 상황은 결국

$$
\min_{\vec{b} \in \{-1,1\}^m} \|A\vec{b}\|_{\infty}
\;\Longleftrightarrow\;
\min_{\vec{b} \in \{-1,1\}^m} \max_i |c_i|
$$

위 최적화 문제와 동일해 진다.

여기서 질문: **$\vec{b}$ 를 랜덤(independent, $p=1/2$)하게 고를 때 얼마나 좋은 결과를 얻을 수 있을까?**

> **Theorem**
>
> $$ 
> \Pr\!\left( \|A\vec{b}\|_{\infty} \ge \sqrt{4m \ln n} \right) \le \dfrac{2}{n}. 
> $$
{: .prompt-info}

각 $c_i$의 합으로 확률을 생각하면 이 문제는 곧 $|c_i| \ge \sqrt{4m \ln n}$이 $2/n^2$의 최대 확률을 가질 수 있는지에 대한 물음이다.
$2/n$이 $2/n^2$으로 바뀐 이유는 UB를 적용했기 때문이다.

문제를 풀기 위해 각 속성, 즉 $i$ 번째 줄을 고려하자.
$k=\sum_j a_ij$ ($i$ 번째 행의 1의 개수)로 잡자.
자명하게도, $k \le \sqrt{4m \ln n}$ 이면 $\sum_j a_{ij}bj \le \sqrt{4m \ln n}$ 일 것이다.

$k > \sqrt{4m \ln n}$ 이면 ($b_i$가 랜덤하게 정해지는 상황이므로) 
$Z-i = \sum_j a_ijbj$는 independent, random, $p=1/2$인 $\{+1, -1\}$들로 구성될 것이다.
이건 곧 [Other variations](#other-variations)에서 다루었던 equal probability 상황과 동일하므로 
$\Pr(|X| \ge a) \le 2e^{-a^2 / 2n}$를 적용할 수 있다.
부등식을 적용하면,

$$
\Pr\left( |Z_i| > \sqrt{4m \ln n} \right) \le 2 \exp\left( -\frac{4m \ln n}{2k} \right) \le 2 \exp(-2 \ln n) = \frac{2}{n^2}.
$$

$\because k \le m$. 한편 $k > \sqrt{4m \ln n}$ 가정으로 분모는 $0$이 아님이 보장된다. $\square$

## Hoeffding bound

**Hoeffding bound**는 구간에 종속된 확률변수에 대한 bound를 제공한다.

서로 독립인 확률변수 $X_1, X_2, ..., X_n$에 대해 $\forall i \in [1,n], \mathbb{E}[X_i] = \mu \:\text{and}\: \Pr(a \le X_i \le b) =1$ 라면

$$
\Pr\left( \left| \frac{1}{n} \sum_i X_i - \mu \right| \ge \epsilon \right) \le 2 \exp\left( \frac{-2n\epsilon^2}{(b - a)^2} \right)
$$

더 일반적으로는, <br>
서로 독립인 확률변수 $X_1, X_2, ..., X_n$에 대해 $\forall i \in [1,n], \mathbb{E}[X_i] = \mu_iD \:\text{and}\: \Pr(a \le X_i \le b) =1$ 라면

$$
\Pr\left( \left| \sum_i X_i - \sum_i \mu_i \right| \ge \epsilon \right) \le 2 \exp\left( \frac{-2\epsilon^2}{\sum_i (b_i - a_i)^2} \right)
$$


### Proof

증명은 Hoeffding's Lemma에서 출발한다.

> 확률변수 $X$가 $\Pr(X \in [a,b])=1$로 bounded이고 $\mathbb{E}[X]=0$일때 모든 $\lambda>0$에 대해
>
> $$
> \mathbb{E}[e^{\lambda X}] \le e^{\lambda^2 (b - a)^2 / 8}
> $$
{: .prompt-info}

위 lemma의 증명순서는 아래와 같다.
0. $a=b=0$인 경우 자명하므로, $a<0$, $b>0$만을 고려한다.
1. $e^{\lambda x}$가 convex function이므로 convex의 일반화 식을 사용하여 부등식을 세운다.<br>
    $e^{\lambda x} \le \frac{b - x}{b - a} e^{\lambda a} + \frac{x - a}{b - a} e^{\lambda b}$
2. 양변에 Expectation을 취한 후 대소 관계를 이용해 $\mathbb{E}[X]$를 없애고 $e^{L(\lambda (b - a))}$로 정리한다. <br>
   $L(h) = \frac{ha}{b - a} + \ln\left( 1 + \frac{a - e^{h} a}{b - a} \right)$
3. 미분하고 2계도 함수까지 구하면 $L(0)=L'(0)=0$, $L'' (0)=\frac{1}{4}$라는 것을 알 수 있다.
4. 테일러 정리로 $L(h) \le \frac{1}{8} h^2$

따라서 $\mathbb{E}[e^{\lambda X}] \le e^{\frac{1}{8}\lambda^2 (b - a)^2 }$

---

이를 바탕으로 Hoeffding bound를 증명하자.

먼저 $Z_i = X_i - \mathbb{E}[X_i]$,  $Z = \frac{1}{n} \sum_i Z_i$ 로 두자.
Markov 부등식에 의해, 모든 $\lambda > 0$에 대해

$$
\Pr(Z \ge \epsilon) = \Pr(e^{\lambda Z} \ge e^{\lambda \epsilon}) 
\le e^{-\lambda \epsilon} \mathbb{E}[e^{\lambda Z}]
\le e^{-\lambda \epsilon} \prod_i \mathbb{E}[e^{\lambda Z_i / n}]
\le e^{-\lambda \epsilon} \prod_i e^{\lambda^2 (b - a)^2 / 8n^2}
= e^{-\lambda \epsilon + \lambda^2 (b - a)^2 / 8n}
$$

$\lambda = \dfrac{4 n \epsilon}{(b-a)^2}$으로 잡으면,

$$
\Pr\left( \frac{1}{n} \sum_i X_i - \mu \ge \epsilon \right)
= \Pr(Z \ge \epsilon)
\le e^{- \frac{2n\epsilon^2}{(b - a)^2}}
$$

$\Pr(Z\le - \epsilon)$일 떄도 $\lambda = -\dfrac{4 n \epsilon}{(b-a)^2}$으로 잡으면,

$$
\Pr\left( \frac{1}{n} \sum_i X_i - \mu \le -\epsilon \right)
= \Pr(Z \le - \epsilon)
\le e^{- \frac{2n\epsilon^2}{(b - a)^2}}
$$

두 범위를 UB 하면 special case에서의 Hoeffding bound을 구할 수 있다.

# Conclusion

이 장에서는 MGF, Poisson Trial, Chernoff inequality, Set balancing, Hoeffding bound를 다루었다.
추가적인 예제는 공부에 도움이 된다고 느껴지면 올릴 예정이다.