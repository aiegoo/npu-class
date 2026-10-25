# Raspberry Pi 5 + AI HAT+ (13 TOPS) 설치/확인 v3

대상: Raspberry Pi 5 (8GB), AI HAT+ (Hailo-8L), Camera Module 3, Raspberry Pi OS 64-bit Trixie.
기준 자료: `NPU_Step1_RaspberryPi5_AI_HAT_Setup_Guide.docx`, `NPU_Step2_수업용_모델_데이터_사전준비_가이드.docx`.
현재 상태: 장비 조립과 OS 설치는 완료됐다는 전제.

## 0. 구성 파일

- `npu_setup.sh`: 설치 명령만 1/2/3단계로 실행(재부팅은 직접 수행).
- `npu_check1.sh`: OS, 호스트명, 네트워크 및 EEPROM 확인.
- `npu_check2.sh`: 카메라·NPU 확인, 카메라 프리뷰(5초), 공식 YOLO Detection(최대 15초), 선택형 공식 Pose(최대 15초).
- `npu_check3.sh`: Hailo Apps 패키지·모델·폴더·버전 확인, Detection/Simple/Pose 각 최대 20초.
- `SHA256SUMS.txt`: 다운로드 파일 비교용 체크섬(PC에서 생성한 값).

단계별 확인 스크립트는 패키지를 설치하거나 시스템 설정을 변경하지 않습니다. 공식 데모 실행 시에는 해당 프로그램이 자체 임시 파일 등을 만들 수 있습니다.

## 1. 관리자 Windows PC에서 최초 1회

1. ZIP을 신뢰할 수 있는 위치에 풀고, `.sh` 4개가 있는 폴더에서 PowerShell을 엽니다.
2. `ipconfig`에서 관리자 PC IPv4 확인 (예시: `192.168.0.100`).
3. 그 폴더에서 다음 명령을 실행하고 **25대 작업이 끝날 때까지 창을 유지**합니다.

```powershell
py -m http.server 8000
```

관리자 PC와 Raspberry Pi는 서로 연결되는 동일/허용된 네트워크에 있어야 합니다. 회사 방화벽이 8000 포트를 막을 수 있습니다. HTTP 서버는 신뢰할 수 있는 내부망에서만 실행하세요.

> 주의: 이전 ZIP이 Microsoft Defender에서 트로이 목마로 탐지된 이력이 있습니다. 이번 ZIP은 중첩 압축을 없앴지만 탐지가 없어질 것이라고 보장할 수 없습니다. 재탐지 시 백신을 끄거나 예외를 추가하지 말고, 파일을 격리한 상태에서 조직 보안 담당자나 Microsoft에 분석을 의뢰하세요.

## 2. 각 Raspberry Pi에서 스크립트 4개 다운로드

아래 주소는 **예시**입니다. `192.168.0.100`을 관리자 PC 실제 IP로 변경합니다.

```bash
for f in npu_setup.sh npu_check1.sh npu_check2.sh npu_check3.sh; do
  curl -fL "http://192.168.0.100:8000/$f" -o "$HOME/$f" || break
done
ls -lh ~/npu_setup.sh ~/npu_check1.sh ~/npu_check2.sh ~/npu_check3.sh
```

다운로드에 실패하면 다음 작업으로 넘어가지 않습니다. `sudo bash`로 설치 스크립트를 실행하지 마세요.

## 3. 그대로 따라 할 실행 순서

```bash
# 1단계 — OS 업데이트와 EEPROM (Word Step 1)
bash ~/npu_setup.sh 1
sudo reboot

# 재부팅 후 1단계 검사
bash ~/npu_check1.sh

# 2단계 — 카메라 사진 촬영 및 Hailo 패키지 설치
bash ~/npu_setup.sh 2
sudo reboot

# 재부팅 후 2단계 검사 (사람이 실제 영상을 눈으로 확인)
bash ~/npu_check2.sh

# 3단계 — Hailo Apps, Detection/Pose 리소스, 교육용 폴더
bash ~/npu_setup.sh 3

# 3단계 검사 (Detection/Simple/Pose 실제 영상 확인)
bash ~/npu_check3.sh

# 모두 확인한 뒤 정상 종료
sudo shutdown -h now
```

반드시 **각 단계가 끝나고, 재부팅이 완전히 완료된 다음** 다음 줄을 실행해야 합니다. 위 코드 블록을 한꺼번에 복사·실행하지 마세요(재부팅 이후 부분은 따로 입력해야 합니다).

## 4. 사람이 실제로 확인해야 하는 것

| 시점 | 자동 결과 | 수동으로 확인할 것 |
| --- | --- | --- |
| check1 | OS Trixie, aarch64, RPi 5, 네트워크 | 장비명(`npu-01` 등)이 **다른 장비와 중복되지 않는지**, EEPROM 표시 |
| check2 | 카메라 imx708, 사진 파일, HAILO8L, /dev/hailo0, PCIe | `test.jpg` 내용, 5초 프리뷰, 공식 YOLO 화면의 객체 탐지 박스; 공식 Pose는 선택 |
| check3 | Apps 명령어, TAPPAS pkg-config, HEF 파일, 폴더/버전 파일 | Detection: 박스·FPS / Simple: 영상·FPS / Pose: 사람 관절(Skeleton)·FPS |

**중요:** `[PASS]`는 해당 명령/파일/장치 확인을 통과했다는 뜻이고, **영상을 눈으로 보고 정상 판정했다는 뜻은 아닙니다.** `[MANUAL]`은 사람이 화면을 직접 확인해야 합니다.

각 시연이 자동으로 끝나는 것은 정상입니다. 카메라 프리뷰는 5초, 공식 Detection/Pose는 최대 15초, Hailo Apps 세 시연은 각각 최대 20초입니다. 종료 전에 화면이 꺼지거나 오류가 나타나면 해당 장비에서 중단하고 점검하세요.

## 5. 이전 Hailo Apps 설치 경고 관련

기준 장비에서 확인된 설치 오류/경고:

- Hailo Apps 내부에서 `pkg-config --variable=tappas_postproc_lib_dir hailo-apps-core` 조회 실패
- 실제 장비에서는 `hailo-tappas-core` (5.1.0)로 조회 성공
- 이를 근거로 `hailo-all`이 잘못 설치됐다고 단정할 수 없음

v3는 **Hailo 공식 `install.sh`를 임의로 고치지 않습니다.** 설치 후 `hailo-apps-core` 또는 `hailo-tappas-core`의 사용 가능 여부를 검사합니다. 경고가 있어도 3단계가 종료됐고 Detection/Pose가 정상 동작한다면 그 결과를 바탕으로 판단합니다. 설치 자체가 오류 종료된다면 다음 단계로 진행하지 않습니다.

`pip` 의존성 경고도 임의로 패키지 추가 설치해 숨기지 않습니다. 실제 Detection/Pose 기능이 실패하는 경우 관련 오류를 먼저 확인하세요.

## 6. Hailo Apps 버전을 25대에서 일치시키려면

첫 번째 기준 장비 검증 완료 후 다음 명령으로 해당 Git 커밋(40글자)을 확인합니다.

```bash
git -C ~/hailo-apps rev-parse HEAD
```

나머지 24대에 동일 버전을 적용하려면 관리자 PC의 `npu_setup.sh` 파일 상단 `set -euo pipefail` 다음에 다음 줄을 **한 번만** 추가하고 배포하면 됩니다. (실제 해시는 첫 번째 장비에서 받은 값으로 교체)

```bash
HAILO_APPS_REF="실제_40자리_Git_SHA"
```

코드를 편집하기 어렵다면 처음에는 그대로 배포할 수 있으나, 설치한 날짜에 따라 저장소의 코드가 바뀔 위험은 남습니다. HailoRT·TAPPAS 패키지 버전까지 엄격히 맞추려면 APT 저장소 버전 관리도 별도로 필요합니다.

## 7. 원래 워드 가이드에서 그대로 유지·의도적으로 생략한 내용

- **유지**: apt 업데이트/전체 업그레이드, EEPROM, 카메라 촬영, `dkms`, `hailo-all`, Hailo Apps 설치, Detection·Pose 리소스, 교육 폴더/시스템 정보 저장.
- **check 스크립트에 배치**: OS/네트워크/Hostname/EEPROM, 카메라 미리보기, 공식 YOLO·선택 Pose, 패키지 및 HEF 확인, Detection/Simple/Pose 시연.
- **의도적으로 자동 실행하지 않음**: Wi-Fi 비밀번호 재설정 등 **문제 해결용 명령**, 선택 사항인 모델 다운로드 `--dry-run`(실제 다운로드가 이뤄짐), 지원하지 않는 `retrain` 그룹.
- **가이드에 구체적 제작·다운로드 명령 없음**: 수업 공통 이미지·영상. 빈 폴더만 생성되므로 수업 원본 데이터는 따로 준비해야 함.

## 8. 검증 상태

- 이번 패키지는 Bash 구문 검사·아카이브 파일 검사를 거쳤습니다.
- 실제 Raspberry Pi 5에서 **v3 전체 실행은 아직 검증되지 않았습니다**.
- 이미 3단계 설치까지 끝난 기준 장비에서는 **설치 스크립트를 다시 실행하지 말고**, 새 확인 스크립트만 필요한 단계부터 실행하세요.
- 기준 장비에서 check2·check3를 통과한 다음 나머지 장비에 확대하는 것을 권장합니다.
