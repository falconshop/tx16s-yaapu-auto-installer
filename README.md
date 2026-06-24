# Yaapu TX16S Installer

[팰콘샵](https://www.falconshop.co.kr)에서 제작한 **Yaapu 텔레메트리 스크립트**를 자동으로 설치해 주는 Windows용 설치 도구입니다. RadioMaster **TX16S (MK2 / MK3)** 조종기 전용이며, MK3에서는 **ArduPilot 드론용 모델/설정까지 한 번에** 적용할 수 있습니다.

A one-click Windows installer that copies the **Yaapu Telemetry Script** onto a RadioMaster **TX16S (MK2 / MK3)** SD card — with an optional **ArduPilot drone model & config** setup on MK3.

> 이 도구는 **설치 도우미**일 뿐입니다. Yaapu 텔레메트리 스크립트 자체는 **Alessandro Apostoli (yaapu)** 님의 [FrskyTelemetryScript](https://github.com/yaapu/FrskyTelemetryScript) 이며, 실행 시 GitHub에서 최신본을 받아옵니다.
> This is only an **installer**. The Yaapu Telemetry Script itself is by **Alessandro Apostoli (yaapu)** — see [FrskyTelemetryScript](https://github.com/yaapu/FrskyTelemetryScript). It is downloaded from GitHub at runtime.

---

## 주요 기능 / Features

- **한국어 / English** 선택
- **MK3 / MK2** 모델 선택 (해상도에 맞는 파일만 스마트 압축 해제)
- GitHub에서 최신 Yaapu 자동 다운로드 (실시간 진행률, 이미 받은 파일은 재사용)
- SD카드 드라이브 자동 인식 후 선택
- 복사 중 **일시정지(아무 키) / 중단(ESC)** — 배터리 방전 등에 대응
- 다운로드 / 압축 해제 / 복사 실패에 대한 오류 처리
- **(MK3 전용) ArduPilot 드론 모델 설치** *(선택)*
  - 대상 모델 슬롯 선택(덮어쓰기 시 자동 `.bak` 백업) 또는 새 슬롯 생성
  - Yaapu config(`Enable CRSF` / `Disable all sounds`) 자동 적용
  - 부팅 시 해당 모델이 선택되도록 설정
  - **공장 출고 상태** 모델 자동 인식 → "새 조종기는 여기를 선택하세요" 안내

---

## 필요 조건 / Requirements

- **Windows 10 / 11**
- **인터넷 연결** (Yaapu 파일 다운로드, 약 177MB)
- **EdgeTX**가 설치된 RadioMaster **TX16S MK2 또는 MK3**
- USB 케이블 (조종기 USB Storage 모드) 또는 SD 카드 리더기

---

## 사용법 / How to use

1. 이 저장소를 받습니다. **Code ▸ Download ZIP** 후 압축을 풀거나, Releases에서 내려받습니다.
2. 압축을 푼 폴더에서 **`Yaapu_TX16S_Installer (PS).bat`** 을 더블클릭해 실행합니다.
   - Windows SmartScreen 경고가 뜨면: **추가 정보(More info) ▸ 실행(Run anyway)**.
3. 화면 안내에 따라 **언어 → 조종기 모델 → 진행 확인** 을 선택합니다.
4. 다운로드 / 압축 해제가 끝나면, 조종기를 **USB로 연결**하고 조종기 화면에서 **USB Storage (SD)** 를 선택한 뒤, 목록에서 **SD카드 드라이브**를 고릅니다.
5. 파일 복사가 진행됩니다. *(아무 키 = 일시정지, ESC = 중단)*
6. **(MK3)** 원하면 "드론 모델 설정"에서 대상 슬롯을 골라 모델/설정을 설치합니다.
7. 마지막에 표시되는 **설정 방법 안내**를 따릅니다. 동일 내용이 `Yaapu 설정 방법.txt`로도 저장됩니다.


---

## 설치 후 직접 해야 하는 설정 / Manual settings

일부 설정은 파일로 자동화할 수 없어 **직접 입력**해야 합니다.

**조종기(TX)**
- `SYS > ExpressLRS` : **Telem Ratio = 1:2**, **Packet Rate = 333Hz**
  *(이 값은 ELRS 모듈 내부에 저장되어 파일로 바꿀 수 없습니다.)*
- Yaapu 소리를 듣고 싶으면 : `SYS > Yaapu config > Disable all sounds = no`
  *(드론 모델을 설치하면 기본은 음소거로 적용됩니다.)*

**ArduPilot (비행 컨트롤러)**
- `RC_OPTIONS = 8960`
- (MK3 드론 모델) `FLTMODE_CH = 6` — ELRS는 CH5가 2단이라 비행모드를 **CH6 (SE 스위치)** 에 둡니다.
- (MK2 4in1/FrSky 모듈) `SERIALx_PROTOCOL = 10`, `SERIALx_OPTIONS = 7`, `RSSI_TYPE = 3`

---

## 다시 설치 / 업데이트

- **재설치** : 받은 파일을 그대로 둔 채 다시 실행하면, 다운로드 없이 곧바로 재설치됩니다.
- **최신 버전으로 업데이트** : `yaapu.zip` 파일과 `FrskyTelemetryScript-master` 폴더를 삭제한 뒤 다시 실행하면 GitHub에서 최신본을 새로 받습니다.

---

## 안전장치 / Safety

드론 모델 설치는 **MK3에서만**, 그리고 `model1.yml` 템플릿이 함께 있을 때만 동작합니다. 기존 설정을 덮어쓰기 전에는 항상 확인을 거치며, 다음 파일을 자동 백업합니다.

- `MODELS\model<N>.yml` → `…\model<N>.yml.bak`
- `MODELS\labels.yml` → `…\labels.yml.bak`
- `RADIO\radio.yml` → `…\radio.yml.bak`

> 모델을 직접 손보신 분은, 덮어쓰기 대신 **[ 새 모델 슬롯 만들기 ]** 를 사용하면 기존 모델을 전혀 건드리지 않습니다.

---

## 배포 구성 파일 / Files

| 파일 | 필수 | 설명 |
|---|:---:|---|
| `Yaapu_TX16S_Installer (PS).bat` | 설치 스크립트 본체 |
| `model1.yml` | 드론 모델 템플릿 (MK3 드론 설치용) |
| `drone.cfg` | Yaapu 설정 프리셋 |
| `drone.reload` | Yaapu 설정 리로드 신호 |
| `factory_model1.yml` | "새 조종기" 인식용 (없어도 동작) |

`*` Yaapu 텔레메트리만 설치할 거라면 `.bat` 하나만으로도 동작합니다(드론 모델 단계는 자동으로 건너뜀).

---

## 크레딧 / Credits

- **Yaapu Telemetry Script** — Alessandro Apostoli ([@yaapu](https://github.com/yaapu)) · [FrskyTelemetryScript](https://github.com/yaapu/FrskyTelemetryScript)
- **EdgeTX** — [edgetx.org](https://edgetx.org)
- **Installer** — [FALCONSHOP](https://falconshop.co.kr)

## 면책 / Disclaimer

이 도구와 동봉된 설정은 **있는 그대로 제공**되며, 사용에 따른 책임은 사용자에게 있습니다. 드론은 실제로 비행하는 장비이므로, 설치 후 반드시 **채널/스위치/비행모드/페일세이프**를 직접 확인하고 안전한 환경에서 점검하십시오.

This tool and the bundled config are provided **as-is**, without warranty. Drones are real flying hardware — after installation, **always verify channels, switches, flight modes and fail-safe** before flying.
