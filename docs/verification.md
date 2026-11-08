# 검증 계획과 재현

[프로젝트 소개](../README.md) · [설계 구조](architecture.md) · [최근 전체 실행](../results/summary.txt)

## 검증 매트릭스

| 테스트벤치 | 자극·관찰 지점 | 자동 판정 기준 |
| --- | --- | --- |
| [tb_frame_check](../tb/tb_frame_check.v) | 4유형 × (0·최댓값·랜덤 100), 에러 코드 1~8 / FIFO 프레임 | 416건, 비트 단위 기대값 비교 |
| [tb_double_dabble_check](../tb/tb_double_dabble_check.v) | 입력 0~511 / BCD 출력과 done | 512건, 백·십·일 자리 비교 |
| [tb_ascii_check](../tb/tb_ascii_check.v) | 정상 408, 에러 1~8, unknown 분기 / ASCII valid·data | 417건, 문자·공백·LF·추가 바이트 비교 |
| [tb_arbiter_control](../tb/tb_arbiter_control.v) | 입력 동시 발생, FIFO Full, pop / push·ready·프레임 순서 | writes=13, reads=13, fail=0 |
| [tb_packetizer_stall](../tb/tb_packetizer_stall.v) | can_issue 중단·재개 / 출력 valid·다음 문자 | errors=0 |
| [tb_packetizer_distance](../tb/tb_packetizer_distance.v) | 거리 응답 / FSM·DD 시작·완료·ASCII | bytes=15, errors=0 |
| [tb_packetizer_error_fsm](../tb/tb_packetizer_error_fsm.v) | 에러 응답 / 상태 이동·메시지·IDLE 복귀 | bytes=22, errors=0, state=0 |
| [tb_tx_fifo_flow](../tb/tb_tx_fifo_flow.v) | 응답 입력부터 TX FIFO write까지 | bytes=14, errors=0 |
| [tb_almost_compare](../tb/tb_almost_compare.v) | 같은 입력, FIFO pop 정지 / Full과 Almost Full 제어 비교 | saved=32/32, dropped=1/0 |
| [tb_tx_e2e_auto](../tb/tb_tx_e2e_auto.v) | 정상 20 + 에러 8 / 실제 직렬 TX 핀 | 28패킷, 예상·수신 504바이트, 실패 0 |

`tb_almost_compare`의 Full 경로 유실 1건은 의도적으로 재현한 비교 결과입니다. 현재 Almost Full 경로는 유실 0이어야 통과합니다.

## E2E 비교 방식

1. Watch·Stopwatch·SR04·DHT11 각각 0, 최댓값, 랜덤 3건을 생성합니다.
2. 에러 코드 1~8을 각 1건 입력합니다.
3. 입력 데이터로 기대 ASCII 바이트 배열을 구성합니다.
4. TX 하강 에지로 Start를 감지하고 데이터 bit 중앙을 샘플링합니다.
5. LSB부터 8bit를 조립해 기대 배열과 순서대로 비교하고 Stop bit를 검사합니다.
6. LF로 패킷을 구분하고 패킷 수, 전체 바이트 수, FIFO drain·TX idle을 확인합니다.

100 MHz / `F_COUNT=651` 조건에서 `BAUD_TIME=104160 ns`를 사용합니다. Baud 설정을 바꾸면 수신 샘플링 기준도 함께 수정해야 합니다.

## 실행과 결과 판정

```powershell
$env:VIVADO_BIN = 'C:\Xilinx\Vivado\2020.2\bin'
python run.py
python run.py tb_frame_check tb_ascii_check
```

`run.py`는 RTL·TB를 임시 디렉터리로 복사한 뒤 `xvlog → xelab → xsim` 순서로 실행합니다. 매 실행마다 새 디렉터리를 사용하므로 이전 로그와 결과가 섞이지 않습니다. 상세 로그와 WDB/VCD의 위치는 콘솔에 표시합니다. 장시간 직렬 E2E는 WDB만 생성합니다.

프로세스 종료 코드만으로 PASS를 판정하지 않습니다. 각 테스트에 기대하는 `RESULT` 행이 존재하고 오류·타임아웃이 없어야 합니다. 시뮬레이터 도구별 제한 시간은 600초입니다.

| 결과 파일 | 내용 |
| --- | --- |
| `results/summary.txt` | 전체 10개 테스트의 RESULT와 최종 판정 |
| `results/summary.json` | 실행 시각, 테스트별 판정, 실행에 사용한 RTL·TB·runner SHA-256 |
| `results/selected_summary.*` | 일부 테스트만 실행한 결과, Git 추적 제외 |

## 결과를 해석할 때의 범위

이 결과는 포함된 테스트 자극에서 송신 경로가 기대값과 일치했음을 보여줍니다. 랜덤 테스트 개수는 기능 커버리지 달성률과 같지 않습니다. E2E 입력은 응답 FIFO 공간을 확인한 후 넣으며, 모든 상위 입력이 임의 속도로 발생해도 무손실이라는 보장은 하지 않습니다.

별도 확인이 필요한 항목은 전체 Top 통합, RX 수신, 보드 통신 실측, 합성·타이밍 분석, 추가 reset 경계·장시간 부하·공정한 중재 검증입니다. 현재 Arbiter는 고정 우선순위를 사용합니다.
