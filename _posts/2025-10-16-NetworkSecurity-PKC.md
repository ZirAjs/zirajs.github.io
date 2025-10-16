---
title: NetworkSecurity.PKC_Application
date: 2025-10-16 13:38:13 +0900
categories: [others, NetworkSecurity]
tags: [RSA, ElGamal]    
---


# Public key infrastructure (PKI)

## What is PKI?

PKC의 키는 누구나 만들 수 있음. 그러나 인터넷 상에서 누가 누군지를 어떻게 증명할까?
내가 나만의 pubkey랑 privatekey를 생성해도 누가 무엇을 믿고 나라는 것을 알 수 있을까?
따라서 인터넷에서는 인증서라는 것이 필요하다.
그리고 인증서를 만들기 위해서
- 누가 발행했는지
- 무엇이 들어가있는지
- 어디어 쓰이는지
- 유효한지
- 어떻게 관리할지

위 질문들의 답을 찾아야 한다.


**Certificate**란 public key를 그 소유자의 정보와 bind하기 위한 전자 문서를 의미한다.
Certificate은 **Certificate Authority(CA)** 또는 **Trusted Third Party**에서 발급한다.
실제 예시로는 Verisign 같은 CA는 Amazon.com에 대한 certificate를 발생한다.

일반적으로, signiture은 CA가 생성해준다.
이에 대해서 한 줄로 요약하자면 Certificate 과정은 CA가 CA의 자신의 private key로 서명(sign)해서 어떠한 서버의 public key + 식별 정보(DN)가 맞음을 조증하는 문서이다.

## PKI Components

- **Registration Authority (RA)**
  - 발급을 위한 authentication 진행.
  - 결과를 CA에게 전달
- **Certificate Authority (CA)**
  - cert를 발행하는 주체.
  - CA를 신뢰하고 사용하는 주체(브라우저)는 CA의 pubkey를 복사해야 한다.
  - RA의 업무도 할 수도 있다.
- Directory Service  
- **Revocation Service**
  - 발급한 cert를 revoke.
  - Certificate Revocation List (CRL), Onlilne Certificate Status Checking (OCSP)


CA domain의 user는 unique 해야하며, CA의 역할은 identity, pubkey를 bind 하는 역할을 한다.
RA는 일부 CA의 일을 줄이는 역할로, Identification, User key gen, CA interface, key-cert management 등의 서비스를 제공한다.

![](/assets/blog/pkc-application/0.png)

* Serial Number: Used to uniquely identify the certificate within the CA.
* **Subject**: The person, or entity identified. Aka Distinguished name (DN)
  Has several fields like (e.g. domain name)
* Signature Algorithm: Algorithm used to create the signature (with a hash function).
* **Issuer**: The entity that verified the information and issued the certificate.
* Valid-From: The date the certificate is first valid from.
* Valid-To: The expiration date.
* Key-Usage: Purpose of the public key (e.g. encipherment, signature, cert. signing).
* **Public Key**: The public key of the subject.
* <ins>**Signature**</ins>: The actual signature to verify that it came from the issuer.

> Thumbprint: 전체 cert의 Hash value. cert에 포함되지는 않는다.
{: .prompt-tip}

DN애서 여러 필드가 존재한다. organization, name, locality 등 여러 내용이 저장된다는 것을 기억하면 된다.


## CA Hierarchy

![](/assets/blog/pkc-application/1.png)

CA는 실제로는 계층 구조를 가지고 있다. 특별한 점은 Root CA의 경우 그것을 보증한 다른 CA가 없다는 점이다.
여기서 Self-signed certificate라는 개념이 등장한다.

![](/assets/blog/pkc-application/2.png)


**Self-signed certificate**이란 root-CA처럼 바른 CA가 보증할 수 없는 경우나, test용 서버, 또는 돈을 아끼기 위한 경우에 사용된다.
이것의 문제점은 revocation에 있다. 만약 root CA가 털린다면 어떻게 revoke할 것인가?
실제로 이러한 일이 발생한다면, 해당 인증서를 신뢰하는 모든 시스템에서 그 인증서를 제거하고 재발급하는 방법밖에 없다.

## Certificate lifecyle

이제 certificate이 어떻게 관리되는지를 보고자 한다.

### 1. Generation

일단 서명받을 keypair을 생성해야 할 것이다.
주체는? **서버의 소유자**가 하는 것이 옳을 것이다. 왜냐하면 non-repudiation, 즉 부인 방지를 위해서는 서버가 자신이 사용할 키를 생성하는 것이 합리적이기 때문이다.
이것은 **Dual key pair model**이라고 하며, 서명용, 암호화용 키를 분리하라는 원칙이다.

### 2. Revocation

일단 revoke가 왜 필요한지부터 다루자.
예를 들어 cert가 잘못 issued 되었을 수도 있고, key가 털린 경우도 있고, passphrase를 잊었을 수도 있고, privatekey를 잃어벼렸을 수도 있다.

CA는 이런 상황에서 cert를 revoke할 수 있는데,
rovoke 상태를 relying party(e.g. browser)이 확인할 수 있는 방법으로는 CRL, OCSP가 있다.
cert 안에는 미리 어디서 revocation 상태를 확인할지에 대한 정보를 저장해둔다.

**Certificate Revocation List (CRL)**

CRL은 자기 자신과 rovoked cert들에 대한 정보를 담고 있다.
serial number, rovocation data, Next update date, CA Signed, etc.
그리고 당연하게도, 이 리스트는 공개되어 있어야 한다. 보통 `CRL distribution point`라는 이름으로 list에 대한 url를 볼 수 있다.

![](/assets/blog/pkc-application/3.png)
_https://www.thesslstore.com/blog/crl-explained-what-is-a-certificate-revocation-list/_
이 방식의 단점으로는 Cert의 유효기간이 다 다르다 보니, revocation 정보를 실시간으로 배포할 수 없다는 점이다. 게다가 CRL의 크기는 점점 커진다.


**Onlilne Certificate Status Checking (OCSP)**

OCSP는 아예 웹서버를 만들자는 생각이다. CA / CA의 위임자(CA delegated) / 제3자가 운영하는 OCSP 서버에 브라우저가 Cert의 serial number를 제출하면 Signed Response를 반환하는 구조이다.
당연하게도 이 서버의 url은 Cert에 포함되어 있다.

![](/assets/blog/pkc-application/4.png)
_https://arstechnica.com/information-technology/2017/07/https-certificate-revocation-is-broken-and-its-time-for-some-new-tools/, Credit: Scott Helme_

이 구조 또한 문제점들이 있다. <br>

1. Privacy: OCSP 서버는 유저가 방문한 서버를 알 수 있다.
2. Availability: rOCSP서버가 다운되면 서비스 이용 불가.


**OCSP stapling**

OCSP의 문제점을 보완하기 위해 revocation 상태를 fetch하는 주체를 server로 변경하는 것이다. cert를 제공하는 서버가 미리 ocsp를 받아와서 캐싱해둔 후 그것을 유저에게 전달하는 것이다. 


##  PKI's issues and mitigations

### Issues

1. 아무 CA가 아무 이름으로 서명 가능. 가짜 cert랑 진짜랑 구분이 불가능함
2. revoked cert에 대한 overhead 증가
3. cert의 verification은 브라우저마다 상이
4. 사용자가 cert 경고를 무시하기도 함

### Mitigations

Certificate에 등급을 두자!

1. Domain Validation (DV) cert : 도메인을 실제로 제어하는 지에 대한 것. Let's encrypt 같은거.
  일반적으로 WHOIS에 등록된 이메일로 확인.
2. Organization validation (OV) cert: 도메인 + 조직 정보까지 포함
3. Extended validation (EV) cert: 도메인, 조직, 물리적 주소, 법적 존재 여부까지 확인한다. 이것부턴 실제 서류작업이 필요.
  인터넷에서 초록색 표시가 있는 사이트들

**Certificate Transparency**

CA의 인증서를 공개적인 로그의 형식으로 남겨서 기록하자.

> DigiNotar 사건
>
> 공인 CA 기업인 DigiNotar이 해킹당해서 google.com이 공격자에게 발급된 적이 있다.
> 그리고 다른 해킹 사건에서 MITM에 사용됐다. 
> 원인은 가짜인증서의 존재여부가 안 알려졌기 때문이다.
> 따라서 모든 발급된 인증서를 볼 수 있게 하자는 취지.
{: .prompt-info}
